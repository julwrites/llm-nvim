-- llm/utils/shell.lua - Shell command utilities
-- License: Apache 2.0

local M = {}
local config = require('llm.config')

-- Private helper to log debug messages
local function debug_log(message, level)
  if config.get('debug') then
    vim.notify(message, level or vim.log.levels.DEBUG)
  end
end

-- Execute shell command safely with error handling
function M.safe_shell_command(cmd, error_msg)
  debug_log("Executing command: " .. cmd)
  
  local cmd_with_stderr = cmd .. " 2>&1"
  local result = vim.fn.system(cmd_with_stderr)

  if result == nil then
    debug_log("Command returned nil: " .. cmd, vim.log.levels.ERROR)
    return nil
  end

  -- Trim whitespace from result
  result = result:gsub("^%s*(.-)%s*$", "%1")

  if result == "" then
    debug_log("Command returned empty result", vim.log.levels.WARN)
    if error_msg then
      vim.notify(error_msg, vim.log.levels.ERROR)
    end
  else
    debug_log("Command result: " .. (result:len() > 200 and result:sub(1, 200) .. "..." or result))
  end

  return result
end

-- Check if command exists in PATH
function M.command_exists(cmd)
  local check_cmd = string.format("command -v %s >/dev/null 2>&1", cmd)
  return os.execute(check_cmd) == 0
end

-- Check if llm is installed and available
function M.check_llm_installed()
  if not M.command_exists("llm") then
    vim.notify("llm CLI not found. Install with: pip install llm or brew install llm", 
      vim.log.levels.ERROR)
    return false
  end
  return true
end

-- Execute command and return status, stdout, stderr
function M.execute(cmd)
  local handle = io.popen(cmd .. " 2>&1", "r")
  if not handle then return nil, "Failed to execute command" end
  
  local output = handle:read("*a")
  local success, _, exit_code = handle:close()
  
  return success and exit_code == 0, output, exit_code
end

return M
