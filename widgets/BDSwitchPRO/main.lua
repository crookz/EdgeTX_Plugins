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

local name = "BDSwitchPRO"
local libGUI

function loadGUI()
  if not libGUI then
  	libGUI = loadScript("/WIDGETS/" .. name .. "/libgui.lua")
  end
  return libGUI()
end

local function create(zone, options)
  widget = loadScript("/WIDGETS/" .. name .. "/loadable.lua")(zone, options)
  widget.create(zone, options)
  return widget
end

local function refresh(widget, event, touchState)
  widget.refresh(event, touchState)
end

local function background(widget)
  widget.background()
end

local options = {
  { "Source", SOURCE, 1 },
  { "Label", STRING , "" },
  { "Boxes", VALUE, 3, 2, 8 },
  { "Box1", STRING , "Up" },
  { "Box2", STRING , "Medium" },
  { "Box3", STRING , "Down" },
  { "Box4", STRING , "4" },
  { "Box5", STRING , "5" },
  { "Box6", STRING , "6" },
  { "Box7", STRING , "7" },
  { "Box8", STRING , "8" },
}

local function update(widget, options)
	widget.update(options)
end

return {
  name = name,
  create = create,
  refresh = refresh,
  background = background,
  options = options,
  update = update
}
