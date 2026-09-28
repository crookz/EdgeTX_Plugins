-- BDCellBatt: compact per-cell voltage widget for EdgeTX colour radios
-- Picks the largest font that fits the zone, so no overlapping text.
-- Install: /WIDGETS/BDCellBatt/main.lua on the SD card

local name = "BDCellBatt"

local options = {
  { "Source", SOURCE, 0 },            -- pack voltage sensor (RxBt). Blank = auto-find RxBt
  { "Cells",  VALUE, 0, 0, 12 },      -- 0 = auto-detect on connect
  { "LiHV",   BOOL, 0 },              -- off = LiPo (4.20V full), on = LiHV (4.35V full)
  { "Warn",   VALUE, 350, 300, 400 }, -- per-cell yellow, x0.01V
  { "Crit",   VALUE, 330, 270, 380 }, -- per-cell red / empty, x0.01V
  { "Color",  COLOR, WHITE },         -- normal text colour
  { "Alerts", BOOL, 1 },              -- voice alerts at Warn / Crit
}

local FONTS = { XXLSIZE, DBLSIZE, MIDSIZE, 0, SMLSIZE }
local C_WARN = lcd.RGB(255, 190, 0)
local C_CRIT = lcd.RGB(255, 60, 60)
local PAD = 3
local ALERT_DELAY = 200   -- must stay below a threshold 2s before alerting (10ms ticks)
local CRIT_REPEAT = 1000  -- repeat the critical alert every 10s

local function create(zone, opts)
  return { zone = zone, options = opts, cells = 0, alerted = 0, pend = 0, since = 0, nextAlert = 0 }
end

local function resetAlerts(w)
  w.alerted, w.pend, w.since = 0, 0, getTime()
end

local function update(w, opts)
  w.options = opts
  w.cells = 0
  resetAlerts(w)
end

local function sourceId(w)
  local s = w.options.Source
  if s and s ~= 0 then return s end
  local f = getFieldInfo("RxBt")
  return f and f.id
end

local function fit(txt, maxW, maxH)
  for _, f in ipairs(FONTS) do
    local tw, th = lcd.sizeText(txt, f)
    if tw <= maxW and th <= maxH then return f, tw, th end
  end
  local tw, th = lcd.sizeText(txt, SMLSIZE)
  return SMLSIZE, tw, th
end

local function drawBatt(x, y, w, h, frac)
  local nubW = math.max(2, math.floor(w / 2))
  lcd.drawFilledRectangle(x + math.floor((w - nubW) / 2), y, nubW, 2, CUSTOM_COLOR)
  lcd.drawRectangle(x, y + 2, w, h - 2, CUSTOM_COLOR)
  local innerH = h - 6
  local fh = math.floor(innerH * frac + 0.5)
  if fh > 0 then
    lcd.drawFilledRectangle(x + 2, y + 4 + innerH - fh, w - 4, fh, CUSTOM_COLOR)
  end
end

local function sample(w)
  local o = w.options
  local live = getRSSI() > 0
  local id = sourceId(w)
  local v = id and getValue(id) or 0
  if type(v) ~= "number" then v = 0 end

  if live and v > 0.5 then
    local n = o.Cells
    if n == 0 then
      -- max per-cell voltage for detection, with a little headroom over full.
      -- Also re-detect upwards if the count is impossible for the voltage: telemetry
      -- can report a low value for a moment at link-up, which would lock in too few cells.
      local vmax = o.LiHV == 1 and 4.40 or 4.25
      if w.cells == 0 or v / w.cells > vmax then w.cells = math.ceil(v / vmax) end
      n = w.cells
    end
    w.n, w.packV, w.cellV = n, v, v / n
  elseif not live then
    w.cells = 0 -- re-detect cell count after a pack swap
    resetAlerts(w)
  end
  w.live = live
end

-- Voice alerts: once when dropping to Warn, repeating while at Crit.
-- Level only escalates until the link drops, so load sag recovery doesn't re-trigger.
local function alerts(w)
  local o, cv = w.options, w.cellV
  if o.Alerts ~= 1 or not w.live or not cv then return end
  local lvl = 0
  if cv <= o.Crit / 100 then lvl = 2 elseif cv <= o.Warn / 100 then lvl = 1 end

  local now = getTime()
  if lvl ~= w.pend then w.pend, w.since = lvl, now end
  if lvl == 0 or now - w.since < ALERT_DELAY then return end

  if lvl > w.alerted or (lvl == 2 and now >= w.nextAlert) then
    if lvl == 2 then
      playFile("clobat.wav")
      playHaptic(15, 0)
      w.nextAlert = now + CRIT_REPEAT
    else
      playFile("lowbat.wav")
    end
    playNumber(math.floor(cv * 100 + 0.5), UNIT_VOLTS, PREC2)
    w.alerted = math.max(w.alerted, lvl)
  end
end

local function background(w)
  sample(w)
  alerts(w)
end

local function refresh(w, event, touchState)
  sample(w)
  alerts(w)
  local z, o = w.zone, w.options
  local full = o.LiHV == 1 and 4.35 or 4.20
  local warn, crit = o.Warn / 100, o.Crit / 100

  -- colour: normal / warn / crit, grey when link is down (last value kept)
  local col = o.Color
  local cv = w.cellV
  if not w.live then
    col = GREY
  elseif cv then
    if cv <= crit then col = C_CRIT elseif cv <= warn then col = C_WARN end
  end

  local frac = 0
  if cv then frac = math.max(0, math.min(1, (cv - crit) / (full - crit))) end

  -- battery icon on the left
  local availH = z.h - 2 * PAD
  local iconW = math.max(8, math.min(18, math.floor(z.h * 0.22)))
  local iconH = math.min(availH, iconW * 2 + 4)
  lcd.setColor(CUSTOM_COLOR, col)
  drawBatt(z.x + PAD, z.y + math.floor((z.h - iconH) / 2), iconW, iconH, frac)

  -- text block
  local tx = PAD + iconW + 5
  local tw = z.w - tx - PAD
  local main = cv and string.format("%.2fV", cv) or "-.--V"
  local sub = cv and string.format("%dS %.2fV", w.n, w.packV) or nil
  local subH = 0
  if sub then
    local sw, sh = lcd.sizeText(sub, SMLSIZE)
    if sw <= tw and availH >= sh + 18 then subH = sh else sub = nil end
  end

  local f, mw, mh = fit(main, tw, availH - subH)
  local y0 = z.y + math.floor((z.h - (mh + subH)) / 2)
  lcd.drawText(z.x + tx, y0, main, f + CUSTOM_COLOR)

  if sub then
    lcd.setColor(CUSTOM_COLOR, GREY)
    lcd.drawText(z.x + tx, y0 + mh, sub, SMLSIZE + CUSTOM_COLOR)
  end
end

return {
  name = name,
  options = options,
  create = create,
  update = update,
  background = background,
  refresh = refresh,
}
