-- llm/utils/shell.lua - Shell command utilities
local config = require('llm.config')
-- License: Apache 2.0

local M = {}
local DEBUG = false

-- Simple error notification wrapper
local function notify_error(msg, level)
  vim.notify(msg, level or vim.log.levels.ERROR)
end

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
    notify_error("Command returned nil: " .. cmd)
    return nil, "Command returned nil"
  end

  -- Trim whitespace from result
  result = result:gsub("^%s*(.-)%s*$", "%1")

  if result == "" then
    debug_log("Command returned empty result", vim.log.levels.WARN)
    if error_msg then
      notify_error(error_msg, vim.log.levels.WARN)
      return nil, error_msg
    end
  else
    debug_log("Command result: " .. (result:len() > 200 and result:sub(1, 200) .. "..." or result))
  end

  return result, nil
end

-- Check if command exists in PATH
function M.command_exists(cmd)
  local check_cmd = string.format("command -v %s >/dev/null 2>&1", cmd)
  return os.execute(check_cmd) == 0
end

-- Check if llm is installed and available
function M.check_llm_installed()
  if not M.command_exists("llm") then
    notify_error("llm CLI not found. Install with: pip install llm or brew install llm")
    return false
  end
  return true
end

-- Execute command and return status, stdout, stderr
function M.execute(cmd)
  local handle = io.popen(cmd .. " 2>&1", "r")
  if not handle then 
    notify_error("Failed to execute command: " .. cmd)
    return nil, "Failed to execute command"
  end

  local output = handle:read("*a")
  local success, _, exit_code = handle:close()

  if not success or exit_code ~= 0 then
    notify_error("Command failed with exit code " .. exit_code .. ": " .. cmd)
    return nil, "Command failed"
  end

  return output, nil
end

return M