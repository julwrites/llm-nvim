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

local llm_nvim_data_dir = vim.fn.stdpath('data') .. '/llm-nvim'
local last_update_file = llm_nvim_data_dir .. '/last_update_check.txt'

-- Ensure the data directory exists
local function ensure_data_dir_exists()
  if vim.fn.isdirectory(llm_nvim_data_dir) == 0 then
    vim.fn.mkdir(llm_nvim_data_dir, "p")
  end
end

-- Get the timestamp of the last update check
function M.get_last_update_timestamp()
  ensure_data_dir_exists() -- Ensure directory exists before attempting to read
  local f = io.open(last_update_file, "r")
  if not f then
    return 0
  end
  local content = f:read("*a")
  f:close()
  local ts = tonumber(content)
  return ts or 0
end

-- Set the timestamp of the last update check
function M.set_last_update_timestamp()
  ensure_data_dir_exists()
  local f = io.open(last_update_file, "w")
  if not f then
    debug_log("Failed to open last_update_check.txt for writing", vim.log.levels.ERROR)
    return
  end
  f:write(tostring(os.time()))
  f:close()
end

function M.run_update_command(cmd)
  local output = vim.fn.system(cmd .. " 2>&1")
  local exit_code = vim.v.shell_error
  return output, exit_code
end

-- Attempt to update the LLM CLI
function M.update_llm_cli()
  M.set_last_update_timestamp()
  local messages = {}
  local success = false
  local final_success_message = ""

  local update_methods = {
    {
      cmd_name = "uv",
      check_exists = true,
      command = "uv tool upgrade llm",
      success_msg = "llm CLI updated successfully via uv."
    },
    {
      cmd_name = "pipx",
      check_exists = true,
      command = "pipx upgrade llm",
      success_msg = "llm CLI updated successfully via pipx."
    },
    {
      cmd_name = "pip",
      check_exists = false, -- Assuming pip is often aliased or directly available if python is
      command = "pip install -U llm",
      success_msg = "llm CLI updated successfully via pip."
    },
    {
      cmd_name = "python-pip",
      check_exists = false, -- Assuming python is in path
      command = "python -m pip install --upgrade llm",
      success_msg = "llm CLI updated successfully via python -m pip."
    },
    {
      cmd_name = "brew",
      check_exists = true,
      command = "brew upgrade llm",
      success_msg = "llm CLI updated successfully via brew."
    }
  }

  for _, method in ipairs(update_methods) do
    debug_log("Attempting to update llm CLI using " .. method.cmd_name .. "...")
    local cmd_to_run = method.command
    local can_run = true

    if method.check_exists then
      if not M.command_exists(method.cmd_name) then
        debug_log(method.cmd_name .. " command not found, skipping.", vim.log.levels.INFO)
        table.insert(messages, method.cmd_name .. " command not found, skipping.")
        can_run = false
      end
    end

    if can_run then
      local output, exit_code = M.run_update_command(cmd_to_run)
      table.insert(messages, cmd_to_run .. ":\n" .. output)

      if exit_code == 0 then
        debug_log(method.success_msg)
        final_success_message = method.success_msg -- Store the specific success message
        success = true
        break -- Exit loop on first success
      else
        debug_log(method.cmd_name .. " update failed with exit code " .. exit_code .. ". Output: " .. output, vim.log.levels.WARN)
      end
    end
  end

  return {
    success = success,
    message = success and final_success_message or table.concat(messages, "\n\n") -- If success, only success message, else all attempts
  }
end

return M