local M = {}

-- Error handling wrapper for shell commands
function M.safe_shell_command(cmd, error_msg)
  local config = require('llm.config')
  local debug_mode = config.get('debug')
  
  -- Debug the command being executed (only in debug mode)
  if debug_mode then
    vim.notify("safe_shell_command executing: " .. cmd, vim.log.levels.DEBUG)
  end

  -- Try using vim.fn.system again, now with improved escaping
  -- Append '2>&1' to redirect stderr to stdout
  local cmd_with_stderr = cmd .. " 2>&1"
  if debug_mode then
    vim.notify("Executing with system(): " .. cmd_with_stderr, vim.log.levels.DEBUG)
  end
  local result = vim.fn.system(cmd_with_stderr)

  if result == nil then
     vim.notify("vim.fn.system() returned nil for command: " .. cmd, vim.log.levels.ERROR)
     return nil
  end

  if debug_mode then
    vim.notify("system() result (raw): " .. vim.inspect(result), vim.log.levels.DEBUG) -- Debug raw result
  end
  
  -- Debug the result (truncated if too long) (only in debug mode)
  if debug_mode and result and #result > 0 then
    local truncated = #result > 200 and result:sub(1, 200) .. "..." or result
    vim.notify("Command result: " .. truncated, vim.log.levels.DEBUG)
  elseif debug_mode then
    vim.notify("Command returned empty result", vim.log.levels.WARN)
    
    -- Try to get more information about what went wrong
    if cmd:match("llm") then
      -- Check if the API key is set
      local key_check_cmd = "llm keys"
      local key_result = io.popen(key_check_cmd):read("*a")
      if key_result and key_result ~= "" then
        vim.notify("API keys are set. Check fragment identifier and network connection.", vim.log.levels.INFO)
      else
        vim.notify("No API keys found. Set an API key with 'llm keys set'", vim.log.levels.ERROR)
      end
      
      -- Check if the fragment exists
      if cmd:match("-f") then
        local fragment_name = cmd:match('-f%s+"([^"]+)"')
        if fragment_name then
          local fragment_check_cmd = "llm fragments show " .. fragment_name .. " 2>&1"
          local fragment_result = io.popen(fragment_check_cmd):read("*a")
          if fragment_result and fragment_result:match("Error") then
            vim.notify("Fragment not found: " .. fragment_name, vim.log.levels.ERROR)
          end
        end
      end
    end
  end
  
  return result
end

-- Check if llm is installed
function M.check_llm_installed()
  local result = M.safe_shell_command("which llm 2>/dev/null", 
    "Failed to check if llm is installed")
  
  if not result or result == "" then
    vim.api.nvim_err_writeln("llm CLI tool not found. Please install it with 'pip install llm' or 'brew install llm'")
    return false
  end
  return true
end

return M
