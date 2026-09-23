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

local MAX_BOXES = 8
local RAW_MIN = -1024
local RAW_MAX = 1024
local RAW_RANGE = RAW_MAX - RAW_MIN

local function getNumBoxes()
  local n = widget.options.Boxes or 3
  if n < 1 then
    n = 1
  elseif n > MAX_BOXES then
    n = MAX_BOXES
  end
  return math.floor(n)
end

local function getBoxLabel(index)
  return widget.options["Box" .. index] or ""
end

--- Map a raw value (RAW_MIN..RAW_MAX) to a 1-based box index by dividing
--- the range into `count` equal segments, the same way the original
--- fixed 3-box (Up/Mid/Down) layout split it into thirds.
local function valueToBoxIndex(value, count)
  local segment = RAW_RANGE / count
  local idx = math.floor((value - RAW_MIN) / segment)
  if idx < 0 then
    idx = 0
  elseif idx > count - 1 then
    idx = count - 1
  end
  return idx + 1
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
  else
    local count = getNumBoxes()
    local active = valueToBoxIndex(value, count)
    local spacing = 60
    for i = 1, count do
      local itemY = yo + (i - 1 - (count - 1) / 2) * spacing
      if i == active then
        lcd.drawText(xo, itemY, getBoxLabel(i), XXLSIZE + SHADOWED + CENTER + VCENTER + COLOR_THEME_ACTIVE)
      else
        lcd.drawText(xo, itemY, getBoxLabel(i), DBLSIZE + SHADOWED + CENTER + VCENTER + COLOR_THEME_PRIMARY3)
      end
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
    local count = getNumBoxes()
    local active = valueToBoxIndex(value, count)
    lcd.drawText(xo, yo, getBoxLabel(active), widget.ts)
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
