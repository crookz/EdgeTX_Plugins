-- BDConfigTool.lua
-- EdgeTX widget config editor. Lists widgets, opens the numeric values for a
-- widget, edits them, then saves them back to that widget's BDConfig.lua.

local APP_TITLE = "BDConfigTool"
-- Bump MINOR for routine edits; bump MAJOR and reset MINOR for a major overhaul.
local APP_VERSION_MAJOR = 1
local APP_VERSION_MINOR = 19
local APP_VERSION = tostring(APP_VERSION_MAJOR) .. "." .. tostring(APP_VERSION_MINOR)
local WIDGET_ROOT = "/WIDGETS"
local widgetNames = { "BDCellBatt", "BDELRSTelem", "BDSwitchPRO", "BDVTXBF" }
local MAX_VISIBLE_FIELDS = 8

local selectedWidget = 1
local selectedField = 1
local page = "widgets"
local fieldData = {}
local configData = {}
local configSource = nil
local statusMessage = ""
local readTextFile

-- Load the selected widget's config table and prepare its editable numeric rows.
local function loadWidgetFields()
  local widget = widgetNames[selectedWidget]
  local path = WIDGET_ROOT .. "/" .. widget .. "/BDConfig.lua"

  fieldData = {}
  configData = {}
  configSource = nil
  statusMessage = ""

  local source, sourceErr = readTextFile(path)
  if not source then
    fieldData = { { name = "status", value = "Cannot read BDConfig.lua" } }
    statusMessage = tostring(sourceErr)
    return
  end
  configSource = source

  local chunk = loadScript(path, "tc")
  if type(chunk) ~= "function" then
    fieldData = { { name = "status", value = "No BDConfig.lua" } }
    return
  end

  local ok, cfg = pcall(chunk)
  if not ok then
    fieldData = { { name = "status", value = "Config load error" } }
    statusMessage = tostring(cfg)
    return
  end

  if type(cfg) ~= "table" then
    if cfg == nil then
      fieldData = { { name = "status", value = "Empty config (no table returned)" } }
      statusMessage = "Restore config: deploy BDCellBatt"
    else
      fieldData = { { name = "status", value = "Config returned " .. type(cfg) } }
    end
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

-- Read a complete file using EdgeTX's explicit-file-handle I/O API.
readTextFile = function(path)
  local file, openErr = io.open(path, "r")
  if not file then
    return nil, openErr or "open failed"
  end

  local chunks = {}
  local readOk = true
  local readErr
  while true do
    -- EdgeTX's io library takes the file handle as an argument; handles have no methods.
    local ok, data = pcall(io.read, file, 128)
    if not ok or type(data) ~= "string" then
      readOk = false
      readErr = data or "read failed"
      break
    end
    if #data == 0 then
      break
    end
    chunks[#chunks + 1] = data
  end

  local closeOk = pcall(io.close, file)
  if not readOk or not closeOk then
    return nil, tostring(readErr or "close failed")
  end

  return table.concat(chunks)
end

-- Replace configured numeric values in-place while preserving other source text.
local function updateNumericValues(source, values)
  local output = {}
  local found = {}
  local position = 1

  -- Replace only numeric literals so config comments, spacing, and key order survive saves.
  while position <= #source do
    local newline = string.find(source, "\n", position, true)
    local lineEnd = newline and newline - 1 or #source
    local lineEnding = newline and "\n" or ""
    if newline and lineEnd >= position and string.sub(source, lineEnd, lineEnd) == "\r" then
      lineEnd = lineEnd - 1
      lineEnding = "\r\n"
    end

    local line = string.sub(source, position, lineEnd)
    local prefix, remainder = string.match(line, "^(.-=)(.*)$")
    if prefix then
      local keyText = string.match(string.sub(prefix, 1, -2), "^%s*(.-)%s*$")
      local key
      if values[keyText] ~= nil then
        key = keyText
      else
        for candidate in pairs(values) do
          if keyText == "[" .. string.format("%q", candidate) .. "]" then
            key = candidate
            break
          end
        end
      end

      if key then
        local spacing = string.match(remainder, "^(%s*)") or ""
        local numberText, suffix = string.match(string.sub(remainder, #spacing + 1), "^([+-]?[%d%.]+[eE]?[+-]?%d*)(.*)$")
        if not numberText or not tonumber(numberText) then
          return nil, "Cannot parse value for " .. key
        end
        line = prefix .. spacing .. string.format("%.6f", values[key]) .. suffix
        found[key] = true
      end
    end

    output[#output + 1] = line .. lineEnding
    if not newline then
      break
    end
    position = newline + 1
  end

  for key in pairs(values) do
    if not found[key] then
      return nil, "Config entry not found: " .. key
    end
  end

  return table.concat(output)
end

-- Write text through EdgeTX's explicit-file-handle I/O API and report failures.
local function writeTextFile(path, text)
  local file, openErr = io.open(path, "w")
  if not file then
    return false, openErr or "open failed"
  end

  local okWrite, writeResult, writeErr = pcall(io.write, file, text)
  local okClose = pcall(io.close, file)
  if not okWrite or writeResult == nil or not okClose then
    return false, tostring(writeErr or writeResult or "write failed")
  end

  return true
end

-- Save edited values after verifying a backup, then verify or restore the file.
local function saveWidgetFields()
  local widget = widgetNames[selectedWidget]
  local path = WIDGET_ROOT .. "/" .. widget .. "/BDConfig.lua"

  for i = 1, #fieldData do
    local row = fieldData[i]
    if row and row.name ~= "status" then
      configData[row.name] = row.value
    end
  end

  local editValues = {}
  for key, value in pairs(configData) do
    if type(key) ~= "string" or
       (type(value) ~= "number" and type(value) ~= "string" and type(value) ~= "boolean") then
      return false, "Unsupported config value"
    end
    if type(value) == "number" then
      editValues[key] = value
    end
  end

  local contents, updateErr = updateNumericValues(configSource or "", editValues)
  if not contents then
    return false, updateErr or "Could not update config"
  end

  -- Preserve the original and verify its backup before opening the config for replacement.
  local original, readErr = readTextFile(path)
  if not original then
    return false, "Cannot back up config: " .. tostring(readErr)
  end

  local backupPath = path .. ".bak"
  local backupOk, backupErr = writeTextFile(backupPath, original)
  if not backupOk then
    return false, "Backup failed: " .. tostring(backupErr)
  end

  local backupCheck, backupReadErr = readTextFile(backupPath)
  if backupCheck ~= original then
    return false, "Backup verify failed: " .. tostring(backupReadErr or "data mismatch")
  end

  local writeOk, writeErr = writeTextFile(path, contents)
  local saved = writeOk and readTextFile(path) or nil
  if not writeOk or saved ~= contents then
    -- A failed or partial write must not leave the widget without its prior config.
    local restoreOk = writeTextFile(path, original)
    local restored = restoreOk and readTextFile(path) or nil
    if restoreOk and restored == original then
      return false, "Save failed; original restored"
    end
    return false, "Save/restore failed; .bak preserved"
  end

  return true
end

-- Keep a menu selection within the valid item range.
local function clampIndex(index, maxIndex)
  if index < 1 then
    return 1
  end
  if index > maxIndex then
    return maxIndex
  end
  return index
end

-- Apply one adjustment step to the selected numeric config value.
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

-- Draw the widget-selection page and its navigation hints.
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

-- Draw the selected widget's values, scrolling the selection into view.
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

-- Draw the adjustment page for the currently selected value.
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

-- Initialize menu state when EdgeTX starts the tool.
local function init_func()
  selectedWidget = 1
  selectedField = 1
  page = "widgets"
  loadWidgetFields()
end

-- Handle EdgeTX key events and render the active menu page.
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
