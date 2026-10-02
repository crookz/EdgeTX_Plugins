-- BDCellBatt: compact per-cell voltage widget for EdgeTX colour radios
-- Picks the largest font that fits the zone, so no overlapping text.
-- Install: /WIDGETS/BDCellBatt/main.lua on the SD card

local name = "BDCellBatt"

local options = {
  { "Source", SOURCE, 0 },            -- pack voltage sensor (RxBt). Blank = auto-find RxBt
  { "Cells",  VALUE, 0, 0, 12 },      -- 0 = auto-detect on connect
  { "LiHV",   BOOL, 0 },              -- off = LiPo (4.20V full), on = LiHV (4.35V full)
  { "Warn",   VALUE, 0, 0, 400 },     -- per-cell yellow, x0.01V. 0 = use BDConfig
  { "Crit",   VALUE, 0, 0, 380 },     -- per-cell red / empty, x0.01V. 0 = use BDConfig
  { "Color",  COLOR, WHITE },         -- normal text colour
  { "Alerts", BOOL, 1 },              -- voice alerts at Warn / Crit
}

local FONTS = { XXLSIZE, DBLSIZE, MIDSIZE, 0, SMLSIZE }
local C_WARN = lcd.RGB(255, 190, 0)
local C_CRIT = lcd.RGB(255, 60, 60)
local PAD = 3
local ALERT_DELAY = 200   -- must stay below a threshold 2s before alerting (10ms ticks)
local CRIT_REPEAT = 1000  -- repeat the critical alert every 10s
local CONFIG = "/WIDGETS/BDCellBatt/BDConfig.lua"
local DEF_WARN, DEF_CRIT = 3.50, 3.30          -- armed: under load, with sag
local DEF_REST_WARN, DEF_REST_CRIT = 3.70, 3.50 -- disarmed: at rest

-- Thresholds in volts per cell: a non-zero widget option wins, else BDConfig, else defaults.
-- The options only override the armed thresholds; resting ones come from BDConfig.
-- BDConfig is shared by all models; it is read when a model loads or its options change.
local function loadThresholds(w)
  local chunk = loadScript(CONFIG)
  local cfg = chunk and chunk()
  if type(cfg) ~= "table" then cfg = {} end
  local o = w.options
  w.warn = o.Warn ~= 0 and o.Warn / 100 or tonumber(cfg.warn) or DEF_WARN
  w.crit = o.Crit ~= 0 and o.Crit / 100 or tonumber(cfg.crit) or DEF_CRIT
  w.restWarn = tonumber(cfg.restWarn) or DEF_REST_WARN
  w.restCrit = tonumber(cfg.restCrit) or DEF_REST_CRIT
end

-- Arm state from FC telemetry. CRSF: Betaflight's FM text ends in "*" when disarmed.
-- FrSky: Tmp1 ones digit is flags 1 = ready, 2 = arming prevented, 4 = armed.
-- Neither present: assume armed, so the lower under-load thresholds apply.
local function isArmed()
  local fm = getValue("FM")
  if type(fm) == "string" and fm ~= "" then return string.sub(fm, -1) ~= "*" end
  local t1 = getValue("Tmp1")
  if type(t1) == "number" then
    local d = math.floor(t1) % 10
    if d >= 1 and d <= 7 then return d >= 4 end
  end
  return true
end

-- warn, crit for the current arm state
local function limits(w)
  if w.armed == false then return w.restWarn, w.restCrit end
  return w.warn, w.crit
end

local function resetAlerts(w)
  w.alerted, w.pend, w.since, w.packSeen = 0, 0, getTime(), false
  w.band, w.bandSince = nil, nil
end

local function create(zone, opts)
  local w = { zone = zone, options = opts, cells = 0, alerted = 0, pend = 0, since = 0, nextAlert = 0 }
  loadThresholds(w)
  return w
end

local function update(w, opts)
  w.options = opts
  w.cells = 0
  loadThresholds(w)
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
    w.armed = isArmed()
    -- a real pack reads above (armed) Crit at connect; USB power alone never does
    if w.cellV > w.crit then w.packSeen = true end
  elseif not live then
    w.cells = 0 -- re-detect cell count after a pack swap
    resetAlerts(w)
  end
  w.live = live
end

-- Voice alerts: once when dropping to Warn, at Crit repeating while armed (once when disarmed).
-- After Crit, the voltage is also spoken each time it drops into a lower 0.1V band.
-- Level and band only go down until the link drops, so load sag recovery doesn't re-trigger.
local function alerts(w)
  local o, cv = w.options, w.cellV
  if o.Alerts ~= 1 or not w.live or not cv or not w.packSeen then return end
  local warn, crit = limits(w)
  local lvl = 0
  if cv <= crit then lvl = 2 elseif cv <= warn then lvl = 1 end
  local cv100 = math.floor(cv * 100 + 0.5)
  local band = math.floor(cv100 / 10) -- 0.1V band, e.g. 3.27V -> 32

  local now = getTime()
  if lvl ~= w.pend then w.pend, w.since = lvl, now end
  -- time spent below the last called-out band (restarts whenever it isn't)
  if not (w.band and band < w.band) then w.bandSince = now end

  if lvl > 0 and now - w.since >= ALERT_DELAY and
     (lvl > w.alerted or (lvl == 2 and w.armed and now >= w.nextAlert)) then
    if lvl == 2 then
      playFile("clobat.wav")
      playHaptic(15, 0)
      w.nextAlert = now + CRIT_REPEAT
      w.band, w.bandSince = math.min(w.band or band, band), now
    else
      playFile("lowbat.wav")
    end
    playNumber(cv100, UNIT_VOLTS, PREC2)
    w.alerted = math.max(w.alerted, lvl)
  elseif w.band and now - w.bandSince >= ALERT_DELAY then
    -- stayed in a lower band for 2s: speak the new voltage
    playNumber(cv100, UNIT_VOLTS, PREC2)
    w.band, w.bandSince = band, now
    w.nextAlert = now + CRIT_REPEAT
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
  local warn, crit = limits(w)

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
