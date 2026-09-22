-- BDCellBatt: compact per-cell voltage widget for EdgeTX colour radios
-- Picks the largest font that fits the zone, so no overlapping text.
-- Install: /WIDGETS/BDCellBatt/main.lua on the SD card

local name = "BDCellBatt"

local options = {
  { "Source", SOURCE, 0 },            -- pack voltage sensor (RxBt). Blank = auto-find RxBt
  { "Cells",  VALUE, 0, 0, 12 },      -- 0 = auto-detect on connect
  { "Full",   VALUE, 420, 400, 440 }, -- per-cell full, x0.01V (420 LiPo, 435 LiHV)
  { "Warn",   VALUE, 350, 300, 400 }, -- per-cell yellow, x0.01V
  { "Crit",   VALUE, 330, 270, 380 }, -- per-cell red / empty, x0.01V
  { "Color",  COLOR, WHITE },         -- normal text colour
}

local FONTS = { XXLSIZE, DBLSIZE, MIDSIZE, 0, SMLSIZE }
local C_WARN = lcd.RGB(255, 190, 0)
local C_CRIT = lcd.RGB(255, 60, 60)
local PAD = 3

local function create(zone, opts)
  return { zone = zone, options = opts, cells = 0 }
end

local function update(w, opts)
  w.options = opts
  w.cells = 0
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
      if w.cells == 0 then w.cells = math.ceil(v / 4.35) end
      n = w.cells
    end
    w.n, w.packV, w.cellV = n, v, v / n
  elseif not live then
    w.cells = 0 -- re-detect cell count after a pack swap
  end
  w.live = live
end

local function background(w)
  sample(w)
end

local function refresh(w, event, touchState)
  sample(w)
  local z, o = w.zone, w.options
  local full, warn, crit = o.Full / 100, o.Warn / 100, o.Crit / 100

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
