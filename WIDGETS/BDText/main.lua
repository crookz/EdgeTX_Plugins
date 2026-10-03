local name = "BDText"

local function sizeOption(label)
	local sizes = { "Small", "Normal", "Medium", "Double", "Extra large" }
	-- CHOICE is unavailable on older EdgeTX versions; VALUE keeps the same five sizes selectable.
	if CHOICE then
		return { label, CHOICE, 2, sizes }
	end
	return { label, VALUE, 2, 1, 5 }
end

local options = {
	{ "Line 1", STRING, "" },
	sizeOption("Size 1"),
	{ "Color 1", COLOR, WHITE },
	{ "Line 2", STRING, "" },
	sizeOption("Size 2"),
	{ "Color 2", COLOR, WHITE },
	{ "Line 3", STRING, "" },
	sizeOption("Size 3"),
	{ "Color 3", COLOR, WHITE },
	{ "BG enabled", BOOL, 0 },
	{ "BG color", COLOR, GREY },
}

-- Keep this order aligned with sizeOption's 1-based size values.
local FONT_FLAGS = { SMLSIZE, 0, MIDSIZE, DBLSIZE, XXLSIZE }
local PAD = 2
local LINE_GAP = 1

local function create(zone, opts)
	return { zone = zone, options = opts }
end

local function update(widget, opts)
	widget.options = opts
end

local function fitText(text, font, maxWidth)
	local width = lcd.sizeText(text, font)
	if width <= maxWidth then return text end
	-- Remove trailing characters until the ellipsis fits inside the widget zone.
	while #text > 0 do
		text = string.sub(text, 1, -2)
		local candidate = text .. "..."
		width = lcd.sizeText(candidate, font)
		if width <= maxWidth then return candidate end
	end
	return ""
end

local function refresh(widget)
	local zone, opts = widget.zone, widget.options
	-- Do not paint a background unless enabled, leaving the default fully transparent.
	if opts["BG enabled"] == 1 then
		lcd.setColor(CUSTOM_COLOR, opts["BG color"] or GREY)
		lcd.drawFilledRectangle(zone.x, zone.y, zone.w, zone.h, CUSTOM_COLOR)
	end

	local lines = {
		{ opts["Line 1"], opts["Size 1"], opts["Color 1"] },
		{ opts["Line 2"], opts["Size 2"], opts["Color 2"] },
		{ opts["Line 3"], opts["Size 3"], opts["Color 3"] },
	}
	local visible, totalHeight = {}, 0
	for _, line in ipairs(lines) do
		local text = line[1]
		if type(text) == "string" and text ~= "" then
			local size = math.max(1, math.min(5, line[2] or 2))
			local font = FONT_FLAGS[size]
			text = fitText(text, font, zone.w - PAD * 2)
			local _, height = lcd.sizeText(text, font)
			if text ~= "" then
				visible[#visible + 1] = { text = text, font = font, color = line[3] or WHITE, height = height }
				totalHeight = totalHeight + height + LINE_GAP
			end
		end
	end

	if #visible == 0 then return end
	totalHeight = totalHeight - LINE_GAP
	-- Center the group when it fits; preserve chosen font sizes and skip rows below the zone otherwise.
	local y = zone.y + math.max(PAD, math.floor((zone.h - totalHeight) / 2))
	local bottom = zone.y + zone.h - PAD
	for _, line in ipairs(visible) do
		if y + line.height <= bottom then
			lcd.setColor(CUSTOM_COLOR, line.color)
			lcd.drawText(zone.x + PAD, y, line.text, line.font + CUSTOM_COLOR)
		end
		y = y + line.height + LINE_GAP
	end
end

return {
	name = name,
	options = options,
	create = create,
	update = update,
	refresh = refresh,
} 