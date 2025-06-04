-- llm/config.lua - Centralized Configuration Management
-- License: Apache 2.0

local M = {}
local listeners = {}
local validate = require('llm.utils.validate')

-- Default configuration with metadata
M.defaults = {
  model = {
    default = nil,
    type = "string",
    desc = "Default model to use (falls back to llm CLI default)"
  },
  system_prompt = {
    default = "You are a helpful assistant.",
    type = "string",
    desc = "Default system prompt for all queries"
  },
  no_mappings = {
    default = false,
    type = "boolean",
    desc = "Disable default key mappings"
  },
  debug = {
    default = false,
    type = "boolean",
    desc = "Enable debug logging"
  },
  -- Add more config options here
}

-- Current configuration
M.options = {}

-- Validate and normalize configuration
local function process_config(opts)
  local processed = {}
  for k, v in pairs(opts) do
    if M.defaults[k] then
      -- Type checking
      if type(v) ~= M.defaults[k].type then
        v = validate.convert(v, M.defaults[k].type)
      end
      -- Ensure proper structure
      if type(v) == 'table' and v.value ~= nil then
        processed[k] = v
      else
        processed[k] = {value = v}
      end
    else
      require('llm.errors').handle('config', 
        "Ignoring unknown config option: "..k, nil, 'warning')
    end
  end
  return processed
end

-- Initialize configuration
function M.setup(opts)
  opts = opts or {}
  
  -- Process and validate new config
  local new_config = process_config(opts)
  
  -- Merge with defaults
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, new_config)
  
  -- Notify listeners
  for _, listener in ipairs(listeners) do
    listener(M.options)
  end
end

-- Get configuration value(s)
function M.get(key)
  if not key then
    return vim.deepcopy(M.options)
  end
  if M.options[key] == nil then
    return nil
  end
  -- Handle both wrapped values and direct values
  if type(M.options[key]) == 'table' and M.options[key].value ~= nil then
    return M.options[key].value
  end
  return M.options[key]
end

-- Register config change listener
function M.on_change(fn)
  table.insert(listeners, fn)
  return function() -- returns unregister function
    for i, listener in ipairs(listeners) do
      if listener == fn then
        table.remove(listeners, i)
        break
      end
    end
  end
end

-- Reset to defaults
function M.reset()
  local defaults = {}
  for k, v in pairs(M.defaults) do
    defaults[k] = v.default
  end
  M.setup(defaults)
end

-- Initialize with empty config
M.setup({})

return M
