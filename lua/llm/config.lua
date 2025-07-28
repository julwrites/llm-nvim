-- llm/config.lua - Centralized Configuration Management
-- License: Apache 2.0

local M = {}
local listeners = {}
local validate = require('llm.core.utils.validate')

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
  auto_update_cli = {
    default = false,
    type = "boolean",
    desc = "Enable or disable auto-updates for the LLM CLI"
  },
  auto_update_interval_days = {
    default = 7,
    type = "number",
    desc = "Interval in days for checking for updates"
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
    -- Return a deepcopy of all *actual* values, not the internal structure
    local current_values = {}
    for k_option, _ in pairs(M.options) do
      current_values[k_option] = M.get(k_option) -- Recursively call M.get for each key
    end
    return current_values
  end

  local option_entry = M.options[key]
  if option_entry == nil then
    -- This case should ideally be caught by M.defaults having all valid keys
    -- or process_config filtering unknown keys.
    -- If an unknown key is passed, returning nil is appropriate.
    return nil
  end

  if type(option_entry) == 'table' then
    if option_entry.value ~= nil then
      return option_entry.value -- User-set value
    elseif option_entry.default ~= nil then
      return option_entry.default -- Default value from M.defaults
    end
  end
  -- This case should ideally not be reached if options are always tables
  -- from M.defaults or {value=...} from user config.
  -- However, returning option_entry directly might be a fallback for unforeseen structures
  -- or if M.options contains direct values not conforming to {value=...} or {default=...}.
  -- For robustness, if it's not a table with 'value' or 'default', but the key exists,
  -- it might be a direct value (though current setup logic aims to wrap these).
  -- If it's a table but doesn't have .value or .default (e.g. just {type="...", desc="..."}),
  -- then it implies no value is set and no default value exists, so nil is appropriate.
  if type(option_entry) == 'table' and option_entry.value == nil and option_entry.default == nil then
    return nil -- No user-set value and no default value defined for this key
  end
  return option_entry -- Fallback for direct values or unexpected structures
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
