-- BDVtxBF: reads the VTX setting from Betaflight (MSP_VTX_CONFIG over CRSF/ELRS)
-- Shows band+channel, frequency, power index and pit mode as the FC actually has them.
-- Install: /WIDGETS/BDVtxBF/main.lua on the SD card

local name = "BDVtxBF"

local options = {
  { "Poll",  VALUE, 2, 1, 10 },   -- seconds between requests
  { "Color", COLOR, WHITE },
}

local MSP_VTX_CONFIG = 88
local CRSF_MSP_REQ, CRSF_MSP_RESP = 0x7A, 0x7B
local ADDR_FC, ADDR_TX = 0xC8, 0xEA

-- default Betaflight vtxtable band order
local BANDS = {
  { "A", { 5865, 5845, 5825, 5805, 5785, 5765, 5745, 5725 } },
  { "B", { 5733, 5752, 5771, 5790, 5809, 5828, 5847, 5866 } },
  { "E", { 5705, 5685, 5665, 5645, 5885, 5905, 5925, 5945 } },
  { "F", { 5740, 5760, 5780, 5800, 5820, 5840, 5860, 5880 } },
  { "R", { 5658, 5695, 5732, 5769, 5806, 5843, 5880, 5917 } },
}

local FONTS = { XXLSIZE, DBLSIZE, MIDSIZE, 0, SMLSIZE }
local PAD = 3

local function create(zone, opts)
  return { zone = zone, options = opts, seq = 0, nextReq = 0, rx = nil, data = nil, t = 0 }
end

local function update(w, opts)
  w.options = opts
end

-- MSPv1 request with no payload, wrapped in a CRSF extended frame
local function sendReq(w, cmd)
  local status = 0x20 + 0x10 + w.seq           -- version 1 + start flag + seq
  local crc = bit32.bxor(0, cmd)               -- size (0) xor cmd
  if crossfireTelemetryPush(CRSF_MSP_REQ, { ADDR_FC, ADDR_TX, status, 0, cmd, crc }) then
    w.seq = (w.seq + 1) % 16
    w.rx = nil
    return true
  end
  return false
end

local function parse(w, b)
  if #b < 5 then return end
  w.data = {
    vtype = b[1], band = b[2], ch = b[3], pwr = b[4], pit = b[5],
    freq = (b[6] or 0) + (b[7] or 0) * 256,
  }
  w.t = getTime()
end

local function handle(w, d)
  local status = d[3]
  if not status then return end
  local seq = bit32.band(status, 0x0F)
  local version = bit32.rshift(bit32.band(status, 0x60), 5)
  local i = 4

  if bit32.btest(status, 0x10) then            -- start of a reply
    if bit32.btest(status, 0x80) then w.rx = nil return end  -- FC reported an error
    local size = d[i]; i = i + 1
    local cmd = MSP_VTX_CONFIG
    if version == 1 then cmd = d[i]; i = i + 1 end
    if cmd ~= MSP_VTX_CONFIG then w.rx = nil return end
    w.rx = { size = size, buf = {}, seq = seq }
  else                                          -- continuation chunk
    if not w.rx or bit32.band(w.rx.seq + 1, 0x0F) ~= seq then w.rx = nil return end
    w.rx.seq = seq
  end

  local rx = w.rx
  while i <= #d and #rx.buf < rx.size do
    rx.buf[#rx.buf + 1] = d[i]
    i = i + 1
  end
  if #rx.buf >= rx.size then
    parse(w, rx.buf)
    w.rx = nil
  end
end

local function poll(w)
  for _ = 1, 10 do
    local cmd, data = crossfireTelemetryPop()
    if cmd == nil then return end
    if cmd == CRSF_MSP_RESP and data[1] == ADDR_TX and data[2] == ADDR_FC then
      handle(w, data)
    end
  end
end

local function fit(txt, maxW, maxH)
  for _, f in ipairs(FONTS) do
    local tw, th = lcd.sizeText(txt, f)
    if tw <= maxW and th <= maxH then return f, tw, th end
  end
  local tw, th = lcd.sizeText(txt, SMLSIZE)
  return SMLSIZE, tw, th
end

local function refresh(w, event, touchState)
  local z, o = w.zone, w.options
  local now = getTime()
  local live = getRSSI() > 0
  local main, sub = "--", "VTX"

  if not crossfireTelemetryPush then
    sub = "no CRSF"
  else
    poll(w)
    if live and now >= w.nextReq then
      if sendReq(w, MSP_VTX_CONFIG) then w.nextReq = now + o.Poll * 100 end
    end

    local d = w.data
    if d then
      if d.vtype == 0 or d.vtype == 255 then
        sub = "no VTX"
      elseif d.band == 0 then                   -- frequency mode
        main = tostring(d.freq)
        sub = "MHz P" .. d.pwr
      else
        local b = BANDS[d.band]
        main = (b and b[1] or ("B" .. d.band)) .. d.ch
        local f = (d.freq > 0 and d.freq) or (b and b[2][d.ch]) or 0
        sub = (f > 0 and (f .. " ") or "") .. "P" .. d.pwr
      end
      if d.pit == 1 then sub = sub .. " PIT" end
    elseif live then
      sub = "reading..."
    end
  end

  local stale = not live or not w.data or (now - w.t) > o.Poll * 300
  local col = stale and GREY or o.Color

  local availW, availH = z.w - 2 * PAD, z.h - 2 * PAD
  local sw, sh = lcd.sizeText(sub, SMLSIZE)
  local subH = (sw <= availW and availH >= sh + 18) and sh or 0

  local f, mw, mh = fit(main, availW, availH - subH)
  local y0 = z.y + math.floor((z.h - (mh + subH)) / 2)

  lcd.setColor(CUSTOM_COLOR, col)
  lcd.drawText(z.x + PAD, y0, main, f + CUSTOM_COLOR)
  if subH > 0 then
    lcd.setColor(CUSTOM_COLOR, GREY)
    lcd.drawText(z.x + PAD, y0 + mh, sub, SMLSIZE + CUSTOM_COLOR)
  end
end

return {
  name = name,
  options = options,
  create = create,
  update = update,
  refresh = refresh,
}
