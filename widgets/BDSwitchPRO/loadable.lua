---------------------------------------------------------------------------
-- The dynamically loadable part of the Lua widget.                      --
--                                                                       --
-- Author:  Philippe Wechsler                                            --
-- Date:    2022-07-24                                                   --
-- Version: 1.0.0                                                        --
-- Source: https://github.com/MadMonkey87/EdgeTX-Goodies                 --
--                                                                       --
-- Copyright (C) Philippe Wechsler                                       --
--                                                                       --
-- License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               --
--                                                                       --
-- This program is free software; you can redistribute it and/or modify  --
-- it under the terms of the GNU General Public License version 2 as     --
-- published by the Free Software Foundation.                            --
--                                                                       --
-- This program is distributed in the hope that it will be useful        --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of        --
-- MERCHANTABILITY or FITNESS FOR borderON PARTICULAR PURPOSE. See the   --
-- GNU General Public License for more details.                          --
---------------------------------------------------------------------------

local zone, options = ...

local HEADER = 40
local COL1   = 10
local HEIGHT = 24

local widget = { }

local libGUI = loadGUI()

local gui = libGUI.newGUI()
local custom = gui.custom({ }, LCD_W - 34, 6, 28, 28)

function custom.draw(focused)
  lcd.drawRectangle(LCD_W - 34, 6, 28, 28, libGUI.colors.primary2)
  lcd.drawFilledRectangle(LCD_W - 30, 19, 20, 3, libGUI.colors.primary2)
  if focused then
    custom.drawFocus()
  end
end

function custom.onEvent(event, touchState)
  if event == EVT_VIRTUAL_ENTER then
    lcd.exitFullScreen()
  end
end

local function hasLabel()
  return widget.options.Label ~= ""
end

local function isPercent()
  return widget.options.Percent == 1
end

-- maps the source range -1024..1024 linearly onto PctLow..PctHigh
local function percentValue(value)
  if value < -1024 then value = -1024 elseif value > 1024 then value = 1024 end
  local low = widget.options.PctLow
  local high = widget.options.PctHigh
  return math.floor(low + (value + 1024) * (high - low) / 2048 + 0.5)
end

-- ActivePos drop-down entries (1-based) as position letters
local ACTIVE_CHOICES = { "", "U", "M", "D", "UM", "MD", "UD" }

-- ActivePos lists the lock switch positions where the slider is active: U, M and/or D.
-- every other position counts as locked. returns nil when no lock is set up
local function lockState()
  local pos = widget.options.ActivePos
  if type(pos) == "number" then
    pos = ACTIVE_CHOICES[pos]
  end
  if widget.options.LockSrc == 0 or pos == nil or pos == "" then
    return nil
  end
  local v = getValue(widget.options.LockSrc)
  if v == nil then
    return nil
  end
  local p = "M"
  if v < -512 then p = "U" elseif v > 512 then p = "D" end
  if string.find(string.upper(pos), p, 1, true) then
    return "active"
  end
  return "locked"
end

-- small padlock, s is the total height in pixels
local function drawLock(x, y, s, color)
  local bh = math.floor(s * 0.6)
  local sh = s - bh
  local bw = math.floor(s * 0.8)
  local sw = math.floor(bw * 0.6)
  local t = math.max(1, math.floor(s / 8))
  lcd.drawRectangle(x + math.floor((bw - sw) / 2), y, sw, sh + t, color, t)
  lcd.drawFilledRectangle(x, y + sh, bw, bh, color)
end

-- small tick, same footprint as the padlock
local function drawTick(x, y, s, color)
  local w = math.floor(s * 0.8)
  local t = math.max(1, math.floor(s / 8))
  for i = 0, t - 1 do
    lcd.drawLine(x, y + math.floor(s * 0.55) + i, x + math.floor(w * 0.35), y + s - 1 + i - t, SOLID, color)
    lcd.drawLine(x + math.floor(w * 0.35), y + s - 1 + i - t, x + w, y + math.floor(s * 0.15) + i, SOLID, color)
  end
end

-- plain name of the lock switch (e.g. SB, L01), without the symbol EdgeTX prefixes
local function lockSourceName()
  local src = widget.options.LockSrc
  local name
  if getSourceName then
    name = getSourceName(src)
  else
    local info = getFieldInfo(src)
    name = info and info.name
  end
  name = string.gsub(name or "", "[^\33-\126]", "")
  return name
end

-- draws a padlock (locked) or tick (active) and the lock switch name just right of left aligned text at (x, top)
local function drawLockStatus(state, text, flags, x, top, color)
  local w, h = lcd.sizeText(text, flags)
  local s = math.max(8, math.floor(h / 2))
  local lx = x + w + 4
  local ly = top + math.floor((h - s) / 2)
  if state == "locked" then
    drawLock(lx, ly, s, color)
  else
    drawTick(lx, ly, s, color)
  end

  local nameFont = SMLSIZE
  if s >= 20 then nameFont = MIDSIZE end
  lcd.drawText(lx + math.floor(s * 0.8) + 3, ly + math.floor(s / 2), lockSourceName(), nameFont + VCENTER + SHADOWED + color)
end

function widget.create(zone, options)
  widget = { zone=zone, options=options, ts = MIDSIZE, yo = 0, ls = SMLSIZE + SHADOWED + CENTER, lyo = 0, lyo2 = 0 }
   
  if widget.zone.w  > 240 then
    widget.ts = XXLSIZE + SHADOWED + CENTER + COLOR_THEME_ACTIVE
    widget.ls = MIDSIZE + SHADOWED + CENTER + COLOR_THEME_PRIMARY3
    widget.yo = widget.zone.h / 2 - 38
    widget.lyo = 25
    widget.lyo2 = 35
  elseif 	widget.zone.w  > 70 then
    widget.ts = DBLSIZE + SHADOWED + CENTER + COLOR_THEME_ACTIVE
    widget.ls = SMLSIZE + SHADOWED + CENTER + COLOR_THEME_PRIMARY3
    widget.yo = widget.zone.h / 2 - 20
    widget.lyo = 10
    widget.lyo2 = 20
  else
    widget.ts = SMLSIZE + SHADOWED + CENTER + COLOR_THEME_PRIMARY2
    widget.ls = SMLSIZE + SHADOWED + CENTER + COLOR_THEME_ACTIVE
    widget.yo = widget.zone.h / 2 - 8
    widget.lyo = 8
    widget.lyo2 = 18
  end
  
  return widget
end

function gui.fullScreenRefresh()
  lcd.drawFilledRectangle(0, 0, LCD_W, HEADER, COLOR_THEME_SECONDARY1)
  if(hasLabel()) then
    lcd.drawText(COL1, HEADER / 2 - 2, widget.options.Label,VCENTER + DBLSIZE + COLOR_THEME_PRIMARY2)
  else
    lcd.drawText(COL1, HEADER / 2 - 2, "Switch PRO",VCENTER + DBLSIZE + COLOR_THEME_PRIMARY2)
  end

  local value = getValue(widget.options.Source)

	local xo = LCD_W / 2
	local yo = (LCD_H - HEADER) / 2 + HEADER

  if(value == nil) then
    lcd.drawText(xo, yo, "NO VALUE", XXLSIZE + SHADOWED + CENTER + COLOR_THEME_ACTIVE + BLINK + INVERS)
  elseif isPercent() then
    local text = percentValue(value) .. "%"
    local flags = XXLSIZE + SHADOWED + VCENTER + COLOR_THEME_ACTIVE
    local tx = COL1 * 4
    lcd.drawText(tx, yo - 20, text, flags)
    local state = lockState()
    if state then
      local _, h = lcd.sizeText(text, flags)
      drawLockStatus(state, text, flags, tx, yo - 20 - math.floor(h / 2), COLOR_THEME_ACTIVE)
    end

    -- bar showing the raw position of the source
    local bw = LCD_W - 2 * COL1 * 4
    local bx = xo - bw / 2
    local by = yo + 40
    local fill = math.floor(bw * (math.max(-1024, math.min(1024, value)) + 1024) / 2048)
    lcd.drawRectangle(bx, by, bw, 16, COLOR_THEME_PRIMARY3)
    lcd.drawFilledRectangle(bx, by, fill, 16, COLOR_THEME_ACTIVE)
  else
    if(value == -1024) then
      lcd.drawText(xo, yo-60, widget.options.SwUp, XXLSIZE + SHADOWED + CENTER + VCENTER + COLOR_THEME_ACTIVE)
      lcd.drawText(xo, yo, widget.options.SwMid, DBLSIZE + SHADOWED + CENTER + VCENTER + COLOR_THEME_PRIMARY3)
      lcd.drawText(xo, yo+60, widget.options.SwDown, DBLSIZE + SHADOWED + CENTER + VCENTER + COLOR_THEME_PRIMARY3)
    elseif(value == 0) then
      lcd.drawText(xo, yo-60, widget.options.SwUp, DBLSIZE + SHADOWED + CENTER + VCENTER + COLOR_THEME_PRIMARY3)
      lcd.drawText(xo, yo, widget.options.SwMid, XXLSIZE + SHADOWED + CENTER + VCENTER + COLOR_THEME_ACTIVE)
      lcd.drawText(xo, yo+60, widget.options.SwDown, DBLSIZE + SHADOWED + CENTER + VCENTER + COLOR_THEME_PRIMARY3)
    elseif(value == 1024) then
      lcd.drawText(xo, yo-60, widget.options.SwUp, DBLSIZE + SHADOWED + CENTER + VCENTER + COLOR_THEME_PRIMARY3)
      lcd.drawText(xo, yo, widget.options.SwMid, DBLSIZE + SHADOWED + CENTER + VCENTER + COLOR_THEME_PRIMARY3)
      lcd.drawText(xo, yo+60, widget.options.SwDown, XXLSIZE + SHADOWED + CENTER + VCENTER + COLOR_THEME_ACTIVE)
    end
  end
end

function libGUI.widgetRefresh()
  local hasLabel = hasLabel()
  local value = getValue(widget.options.Source)

	local xo = widget.zone.x + (widget.zone.w / 2)
	local yo = widget.zone.y + widget.yo

  if (hasLabel) then
    yo = yo + widget.lyo
  end

  if(value == nil) then
    lcd.drawText(xo, yo, "NO VALUE", widget.ts + BLINK + INVERS)
  else

    local textValue = "INVALID VALUE"

    if isPercent() then
        textValue = percentValue(value) .. "%"
    elseif(value == -1024) then
        textValue = widget.options.SwUp
    elseif(value == 0) then
        textValue = widget.options.SwMid
    elseif(value == 1024) then
        textValue = widget.options.SwDown
    end

    if isPercent() then
      local flags = widget.ts - CENTER
      local tx = widget.zone.x + 4
      lcd.drawText(tx, yo, textValue, flags)
      local state = lockState()
      if state then
        drawLockStatus(state, textValue, flags, tx, yo, COLOR_THEME_ACTIVE)
      end
    else
      lcd.drawText(xo, yo, textValue, widget.ts)
    end
  end

  if (hasLabel) then
    lcd.drawText(xo, yo - widget.lyo2, widget.options.Label, widget.ls)
  end

end

function widget.background()

end

function widget.update(options)
  widget.options = options
end

function widget.refresh(event, touchState)
  gui.run(event, touchState)
end

return widget
