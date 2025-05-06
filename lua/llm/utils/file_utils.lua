local M = {}

-- Ensure the configuration directory exists
function M.ensure_config_dir_exists(config_dir)
  if not config_dir or config_dir == "" then
    return false
  end
  
  -- Check if directory exists (simple check using io.open)
  -- Note: This isn't foolproof but avoids complex platform-specific checks
  local test_file = config_dir .. "/.llm_nvim_write_test"
  local f = io.open(test_file, "a")
  if f then
    f:close()
    os.remove(test_file)
    -- Directory exists and is likely writable
    return true
  else
    -- Directory might not exist or isn't writable, try creating it
    local mkdir_cmd = string.format("mkdir -p '%s'", config_dir)
    local success, err = pcall(os.execute, mkdir_cmd)
    if success and err == 0 then
      if require('llm.config').get('debug') then
        vim.notify("Created config directory: " .. config_dir, vim.log.levels.DEBUG)
      end
      return true
    else
      vim.notify("Failed to create config directory: " .. config_dir .. " (Error: " .. tostring(err) .. ")", vim.log.levels.ERROR)
      return false
    end
  end
end

-- Cache for the config directory path
local config_dir_cache = nil
local config_dir_cache_initialized = false

-- Get the configuration directory and file path for llm
function M.get_config_path(filename)
  local config = require('llm.config')
  local debug_mode = config.get('debug')
  
  -- Use cached config directory if available
  if config_dir_cache_initialized and config_dir_cache then
    -- Construct the full path to the file
    local config_file = config_dir_cache .. "/" .. filename
    
    if debug_mode then
      vim.notify("Using cached config path: " .. config_file, vim.log.levels.DEBUG)
    end
    
    return config_dir_cache, config_file
  end
  
  -- Mark as initialized even if we fail, to avoid repeated attempts
  config_dir_cache_initialized = true
  
  -- We'll skip trying to get config path directly and always use logs path method
  -- as per user's instruction: "The config path is the directory of the path returned by the `llm logs path` command."
  if debug_mode then
    vim.notify("Using logs path method to determine config directory", vim.log.levels.DEBUG)
  end
  
  -- Use logs path method as the primary way to get config path
  if debug_mode then
    vim.notify("Getting config path from logs path", vim.log.levels.DEBUG)
  end
  
  -- Step 1: Get the logs path
  local logs_path_cmd = "llm logs path"
  local logs_path = require('llm.utils.shell').safe_shell_command(logs_path_cmd, "Failed to get LLM logs path")

  if not logs_path or logs_path == "" then
    vim.notify("Could not determine LLM logs path using '" .. logs_path_cmd .. "'", vim.log.levels.ERROR)
    return nil, nil
  end

  -- Trim trailing newline/whitespace characters from the logs path
  logs_path = logs_path:gsub("[\r\n]+$", ""):gsub("%s+$", "")
  
  if debug_mode then
    vim.notify("Found logs path: " .. logs_path, vim.log.levels.DEBUG)
  end

  -- Step 2: Get the directory name from the logs path, quoting the path
  -- Use single quotes around the path to handle spaces and special characters
  local config_dir_cmd = string.format("dirname '%s'", logs_path)
  local config_dir = require('llm.utils.shell').safe_shell_command(config_dir_cmd, "Failed to get directory name from logs path")

  if not config_dir or config_dir == "" then
    vim.notify("Could not determine LLM config directory using '" .. config_dir_cmd .. "'", vim.log.levels.ERROR)
    return nil, nil
  end
  
  -- Trim trailing newline characters from the command output
  config_dir = config_dir:gsub("[\r\n]+$", "")
  
  if debug_mode then
    vim.notify("Derived config directory: " .. config_dir, vim.log.levels.DEBUG)
  end

  -- Ensure the directory exists before returning the path
  M.ensure_config_dir_exists(config_dir)
  
  -- Cache the config directory for future calls
  config_dir_cache = config_dir
  
  -- Construct the full path to the file
  local config_file = config_dir .. "/" .. filename
  
  if debug_mode then
    vim.notify("Final config file path: " .. config_file, vim.log.levels.DEBUG)
    
    -- Check if the file exists
    local file = io.open(config_file, "r")
    if file then
      file:close()
      vim.notify("File exists: " .. config_file, vim.log.levels.DEBUG)
    else
      vim.notify("File does not exist: " .. config_file, vim.log.levels.DEBUG)
    end
  end
  
  -- Return the directory and the full file path
  return config_dir, config_file
end

return M
