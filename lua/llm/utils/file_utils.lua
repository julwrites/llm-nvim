local M = {}

local config = require('llm.config')
local shell = require('llm.utils.shell')

-- Pure functions for path manipulation
local function trim_path(path)
  return path and path:gsub("[\r\n]+$", ""):gsub("%s+$", "") or nil
end

local function join_path(dir, file)
  return dir and file and dir .. "/" .. file or nil
end

local function debug_log(message, level)
  if config.get('debug') then
    vim.notify(message, level or vim.log.levels.DEBUG)
  end
end

-- Cache for the config directory path
local config_dir_cache = nil

local function test_directory_writable(dir)
  if not dir or dir == "" then return false end
  
  local test_file = join_path(dir, ".llm_nvim_write_test")
  local f = io.open(test_file, "a")
  if not f then return false end
  
  f:close()
  os.remove(test_file)
  return true
end

local function create_directory(dir)
  local mkdir_cmd = string.format("mkdir -p '%s'", dir)
  local success, err = pcall(os.execute, mkdir_cmd)
  
  if success and err == 0 then
    debug_log("Created config directory: " .. dir)
    return true
  else
    vim.notify("Failed to create config directory: " .. dir .. " (Error: " .. tostring(err) .. ")", vim.log.levels.ERROR)
    return false
  end
end

function M.ensure_config_dir_exists(config_dir)
  if not config_dir or config_dir == "" then return false end
  return test_directory_writable(config_dir) or create_directory(config_dir)
end

local function get_config_dir_from_logs()
  local logs_path_cmd = "llm logs path"
  local logs_path = trim_path(shell.safe_shell_command(logs_path_cmd, "Failed to get LLM logs path"))
  if not logs_path then return nil end

  debug_log("Found logs path: " .. logs_path)

  local config_dir_cmd = string.format("dirname '%s'", logs_path)
  local config_dir = trim_path(shell.safe_shell_command(config_dir_cmd, "Failed to get directory name from logs path"))
  if not config_dir then return nil end

  debug_log("Derived config directory: " .. config_dir)
  return config_dir
end

function M.get_config_path(filename)
  if not filename then return nil, nil end

  -- Use cached config directory if available
  if config_dir_cache then
    local config_file = join_path(config_dir_cache, filename)
    debug_log("Using cached config path: " .. config_file)
    return config_dir_cache, config_file
  end

  -- Get fresh config directory
  local config_dir = get_config_dir_from_logs()
  if not config_dir then return nil, nil end

  -- Ensure directory exists and cache it
  if M.ensure_config_dir_exists(config_dir) then
    config_dir_cache = config_dir
    local config_file = join_path(config_dir, filename)
    
    debug_log("Final config file path: " .. config_file)
    if io.open(config_file, "r") then
      debug_log("File exists: " .. config_file)
    else
      debug_log("File does not exist: " .. config_file)
    end
    
    return config_dir, config_file
  end

  return nil, nil
end

return M
