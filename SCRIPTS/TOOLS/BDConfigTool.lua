-- BDConfigTool.lua
-- EdgeTX widget config editor. Lists widgets, opens the numeric values for a
-- widget, edits them, then saves them back to that widget's BDConfig.lua.

local APP_TITLE = "BDConfigTool"
local APP_VERSION = 7
local WIDGET_ROOT = "/WIDGETS"
local widgetNames = { "BDCellBatt", "BDELRSTelem", "BDSwitchPRO", "BDVTXBF" }
local MAX_VISIBLE_FIELDS = 8

local selectedWidget = 1
local selectedField = 1
local page = "widgets"
local fieldData = {}
local configData = {}
local statusMessage = ""

local function loadWidgetFields()
  local widget = widgetNames[selectedWidget]
  local path = WIDGET_ROOT .. "/" .. widget .. "/BDConfig.lua"

  fieldData = {}
  configData = {}
  statusMessage = ""

  local input = io.open(path, "r")
  if not input then
    fieldData = { { name = "status", value = "No BDConfig.lua" } }
    return
  end

  local source = input:read("*a")
  input:close()
  if not source or source == "" then
    fieldData = { { name = "status", value = "Invalid config" } }
    return
  end

  local chunk = loadstring(source)
  if not chunk then
    fieldData = { { name = "status", value = "Invalid config" } }
    return
  end

  local ok, cfg = pcall(chunk)
  if not ok or type(cfg) ~= "table" then
    fieldData = { { name = "status", value = "Invalid config" } }
    return
  end

  configData = cfg
  local keys = {}
  for key in pairs(cfg) do
    if type(key) == "string" and type(cfg[key]) == "number" then
      keys[#keys + 1] = key
    end
  end
  table.sort(keys)

  for i = 1, #keys do
    local key = keys[i]
    fieldData[#fieldData + 1] = { name = key, value = cfg[key] }
  end

  if #fieldData == 0 then
    fieldData = { { name = "status", value = "No numeric fields" } }
  end
end

local function saveWidgetFields()
  local widget = widgetNames[selectedWidget]
  local path = WIDGET_ROOT .. "/" .. widget .. "/BDConfig.lua"

  for i = 1, #fieldData do
    local row = fieldData[i]
    if row and row.name ~= "status" then
      configData[row.name] = row.value
    end
  end

  local keys = {}
  for key, value in pairs(configData) do
    if type(key) ~= "string" or
       (type(value) ~= "number" and type(value) ~= "string" and type(value) ~= "boolean") then
      return false, "Unsupported config value"
    end
    keys[#keys + 1] = key
  end
  table.sort(keys)

  local lines = { "-- auto-saved by BDConfigTool\nreturn {\n" }
  for i = 1, #keys do
    local key = keys[i]
    local value = configData[key]
    local valueText
    if type(value) == "number" then
      valueText = string.format("%.6f", value)
    elseif type(value) == "string" then
      valueText = string.format("%q", value)
    else
      valueText = tostring(value)
    end
    lines[#lines + 1] = "  [" .. string.format("%q", key) .. "] = " .. valueText .. ",\n"
  end
  lines[#lines + 1] = "}\n"

  local file, openErr = io.open(path, "w")
  if not file then
    return false, openErr or "open failed"
  end

  local previousOutput = io.output()
  local okWrite, writeErr = pcall(function()
    io.output(file)
    io.write(table.concat(lines))
  end)
  pcall(function()
    io.output(previousOutput)
  end)
  local okClose, closeErr = pcall(function()
    io.close(file)
  end)

  if not okWrite or not okClose then
    return false, writeErr or closeErr or "write failed"
  end

  return true
end

local function clampIndex(index, maxIndex)
  if index < 1 then
    return 1
  end
  if index > maxIndex then
    return maxIndex
  end
  return index
end

local function adjustField(delta)
  local row = fieldData[selectedField]
  if not row or row.name == "status" then
    return
  end

  row.value = row.value + delta
  if row.value < 0 then
    row.value = 0
  end
end

local function renderWidgets()
  lcd.clear()
  lcd.drawText(10, 2, APP_TITLE .. " v" .. APP_VERSION, MIDSIZE)
  lcd.drawText(10, 26, "Widgets", SMLSIZE)

  for i = 1, #widgetNames do
    local y = 50 + (i - 1) * 24
    local prefix = i == selectedWidget and ">" or " "
    lcd.drawText(10, y, prefix .. widgetNames[i], SMLSIZE)
  end

  lcd.drawText(10, 242, "UP/DN move  ENTER open", SMLSIZE)
  lcd.drawText(10, 256, "EXIT/MENU quit", SMLSIZE)
  lcd.refresh()
end

local function renderFieldList()
  local firstField = math.max(1, selectedField - MAX_VISIBLE_FIELDS + 1)
  local lastField = math.min(#fieldData, firstField + MAX_VISIBLE_FIELDS - 1)

  lcd.clear()
  lcd.drawText(10, 2, widgetNames[selectedWidget] .. " v" .. APP_VERSION, MIDSIZE)
  lcd.drawText(10, 26, "Values", SMLSIZE)

  for i = firstField, lastField do
    local row = fieldData[i]
    local y = 50 + (i - firstField) * 22
    local prefix = i == selectedField and ">" or " "
    local valueText = row.value or "--"
    if type(valueText) == "number" then
      valueText = string.format("%.2f", valueText)
    end
    lcd.drawText(10, y, prefix .. row.name, SMLSIZE)
    lcd.drawText(180, y, valueText, SMLSIZE)
  end

  if statusMessage ~= "" then
    lcd.drawText(10, 232, statusMessage, SMLSIZE)
  end
  lcd.drawText(10, 246, "UP/DN move  ENTER edit", SMLSIZE)
  lcd.drawText(10, 258, "EXIT back", SMLSIZE)
  lcd.refresh()
end

local function renderEdit()
  local row = fieldData[selectedField]
  if not row then
    return
  end

  local value = row.value or 0
  lcd.clear()
  lcd.drawText(10, 2, widgetNames[selectedWidget] .. " v" .. APP_VERSION, MIDSIZE)
  lcd.drawText(10, 42, row.name, SMLSIZE)
  lcd.drawText(10, 72, string.format("%.2f", value), MIDSIZE)
  lcd.drawText(10, 226, "LEFT/RIGHT adjust", SMLSIZE)
  lcd.drawText(10, 242, "ENTER save", SMLSIZE)
  lcd.drawText(10, 258, "EXIT cancel", SMLSIZE)
  lcd.refresh()
end

local function init_func()
  selectedWidget = 1
  selectedField = 1
  page = "widgets"
  loadWidgetFields()
end

local function run_func(event)
  if event == nil then
    return 0
  end

  if page == "widgets" then
    if event == EVT_VIRTUAL_PREV then
      selectedWidget = clampIndex(selectedWidget - 1, #widgetNames)
    elseif event == EVT_VIRTUAL_NEXT then
      selectedWidget = clampIndex(selectedWidget + 1, #widgetNames)
    elseif event == EVT_VIRTUAL_ENTER then
      page = "values"
      selectedField = 1
      loadWidgetFields()
      renderFieldList()
      return 0
    elseif event == EVT_VIRTUAL_EXIT or event == EVT_VIRTUAL_MENU then
      return 1
    end

    renderWidgets()
    return 0
  end

  if page == "values" then
    if event == EVT_VIRTUAL_PREV then
      selectedField = clampIndex(selectedField - 1, #fieldData)
    elseif event == EVT_VIRTUAL_NEXT then
      selectedField = clampIndex(selectedField + 1, #fieldData)
    elseif event == EVT_VIRTUAL_ENTER then
      if fieldData[selectedField] and fieldData[selectedField].name ~= "status" then
        page = "edit"
        renderEdit()
        return 0
      end
    elseif event == EVT_VIRTUAL_EXIT then
      page = "widgets"
      renderWidgets()
      return 0
    elseif event == EVT_VIRTUAL_MENU then
      return 1
    end

    renderFieldList()
    return 0
  end

  if page == "edit" then
    local row = fieldData[selectedField]
    if not row then
      page = "values"
      renderFieldList()
      return 0
    end

    if event == EVT_VIRTUAL_PREV or event == EVT_VIRTUAL_LEFT then
      adjustField(-0.05)
    elseif event == EVT_VIRTUAL_NEXT or event == EVT_VIRTUAL_RIGHT then
      adjustField(0.05)
    elseif event == EVT_VIRTUAL_ENTER then
      local ok, err = saveWidgetFields()
      if not ok then
        statusMessage = "Save failed: " .. tostring(err)
        page = "values"
        renderFieldList()
        return 0
      end
      page = "values"
      loadWidgetFields()
      statusMessage = "Saved; reload model to apply"
      renderFieldList()
      return 0
    elseif event == EVT_VIRTUAL_EXIT then
      page = "values"
      renderFieldList()
      return 0
    elseif event == EVT_VIRTUAL_MENU then
      return 1
    end

    renderEdit()
    return 0
  end

  return 0
end

return { run = run_func, init = init_func }
