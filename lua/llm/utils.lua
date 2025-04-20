-- llm/utils.lua - Utility functions for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local api = vim.api
local fn = vim.fn

-- Error handling wrapper for shell commands
function M.safe_shell_command(cmd, error_msg)
  local config = require('llm.config')
  local debug_mode = config.get('debug')
  
  -- Debug the command being executed (only in debug mode)
  if debug_mode then
    vim.notify("safe_shell_command executing: " .. cmd, vim.log.levels.DEBUG)
  end
  
  local success, handle = pcall(io.popen, cmd)
  if not success then
    api.nvim_err_writeln(error_msg or "Failed to execute command: " .. cmd)
    vim.notify("Command failed to execute: " .. cmd, vim.log.levels.ERROR)
    return nil
  end
  
  local result = handle:read("*a")
  local close_success = handle:close()
  
  if not close_success then
    api.nvim_err_writeln("Command execution failed: " .. cmd)
    vim.notify("Command execution failed: " .. cmd, vim.log.levels.ERROR)
    return nil
  end
  
  -- Debug the result (truncated if too long) (only in debug mode)
  if debug_mode and result and #result > 0 then
    local truncated = #result > 200 and result:sub(1, 200) .. "..." or result
    vim.notify("Command result: " .. truncated, vim.log.levels.DEBUG)
  elseif debug_mode then
    vim.notify("Command returned empty result", vim.log.levels.DEBUG)
  end
  
  return result
end

-- Check if llm is installed
function M.check_llm_installed()
  local result = M.safe_shell_command("which llm 2>/dev/null", 
    "Failed to check if llm is installed")
  
  if not result or result == "" then
    api.nvim_err_writeln("llm CLI tool not found. Please install it with 'pip install llm' or 'brew install llm'")
    return false
  end
  return true
end

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
  -- Use cached config directory if available
  if config_dir_cache_initialized and config_dir_cache then
    -- Construct the full path to the file
    local config_file = config_dir_cache .. "/" .. filename
    return config_dir_cache, config_file
  end
  
  -- Mark as initialized even if we fail, to avoid repeated attempts
  config_dir_cache_initialized = true
  
  -- Step 1: Get the logs path
  local logs_path_cmd = "llm logs path"
  local logs_path = M.safe_shell_command(logs_path_cmd, "Failed to get LLM logs path")

  if not logs_path or logs_path == "" then
    vim.notify("Could not determine LLM logs path using '" .. logs_path_cmd .. "'", vim.log.levels.ERROR)
    return nil, nil
  end

  -- Trim trailing newline/whitespace characters from the logs path
  logs_path = logs_path:gsub("[\r\n]+$", ""):gsub("%s+$", "")

  -- Step 2: Get the directory name from the logs path, quoting the path
  -- Use single quotes around the path to handle spaces and special characters
  local config_dir_cmd = string.format("dirname '%s'", logs_path)
  local config_dir = M.safe_shell_command(config_dir_cmd, "Failed to get directory name from logs path")

  if not config_dir or config_dir == "" then
    vim.notify("Could not determine LLM config directory using '" .. config_dir_cmd .. "'", vim.log.levels.ERROR)
    return nil, nil
  end
  
  -- Trim trailing newline characters from the command output
  config_dir = config_dir:gsub("[\r\n]+$", "")

  -- Ensure the directory exists before returning the path
  M.ensure_config_dir_exists(config_dir)
  
  -- Cache the config directory for future calls
  config_dir_cache = config_dir
  
  -- Construct the full path to the file
  local config_file = config_dir .. "/" .. filename
  
  -- Return the directory and the full file path
  return config_dir, config_file
end

-- Create a new buffer with content
function M.create_buffer_with_content(content, buffer_name, filetype)
  -- Create a new split
  api.nvim_command('new')
  local buf = api.nvim_get_current_buf()

  -- Set buffer options
  api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(buf, 'swapfile', false)
  api.nvim_buf_set_name(buf, buffer_name or 'LLM Output')

  -- Set the content
  local lines = {}
  for line in content:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Set filetype for syntax highlighting
  if filetype then
    api.nvim_buf_set_option(buf, 'filetype', filetype)
  end

  return buf
end

-- Create a floating window
function M.create_floating_window(buf, title)
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local opts = {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' ' .. (title or 'LLM') .. ' ',
    title_pos = 'center',
  }

  local win = api.nvim_open_win(buf, true, opts)
  api.nvim_win_set_option(win, 'cursorline', true)
  api.nvim_win_set_option(win, 'winblend', 0)
  
  return win
end

-- Get selected text in visual mode
function M.get_visual_selection()
  local start_pos = fn.getpos("'<")
  local end_pos = fn.getpos("'>")
  local lines = api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)

  if #lines == 0 then
    return ""
  end

  -- Handle single line selection
  if #lines == 1 then
    return string.sub(lines[1], start_pos[3], end_pos[3])
  end

  -- Handle multi-line selection
  lines[1] = string.sub(lines[1], start_pos[3])
  lines[#lines] = string.sub(lines[#lines], 1, end_pos[3])

  return table.concat(lines, "\n")
end

-- Set up syntax highlighting for manager buffers
function M.setup_buffer_highlighting(buf)
  -- Use the centralized styles module for consistent styling
  local styles = require('llm.styles')
  
  -- Setup highlights and syntax patterns
  styles.setup_highlights()
  styles.setup_buffer_syntax(buf)
end

-- Debug function to check fragment aliases
function M.debug_fragment_aliases()
  local config = require('llm.config')
  local debug_mode = config.get('debug')
  
  if not debug_mode then
    vim.notify("Debug mode is disabled. Enable it with require('llm').setup({debug = true})", vim.log.levels.INFO)
    return
  end
  
  local result = M.safe_shell_command("llm fragments --aliases", "Failed to get fragments with aliases")
  if result then
    vim.notify("Current fragments with aliases:\n" .. result, vim.log.levels.INFO)
  else
    vim.notify("Failed to get fragments with aliases", vim.log.levels.ERROR)
  end
  
  -- Also run a direct test of the parsing logic
  local test_result = M.safe_shell_command("llm fragments", "Failed to get fragments")
  if test_result then
    vim.notify("Testing fragment parsing with raw output", vim.log.levels.INFO)
    
    -- Parse the fragments manually to debug
    local fragments = {}
    local current_fragment = nil
    
    for line in test_result:gmatch("[^\r\n]+") do
      if line:match("^%s*-%s+hash:%s+") then
        -- Start of a new fragment
        if current_fragment then
          table.insert(fragments, current_fragment)
        end
        
        local hash = line:match("hash:%s+([0-9a-f]+)")
        current_fragment = {
          hash = hash,
          aliases = {},
          source = "",
          content = "",
          datetime = ""
        }
      elseif current_fragment and line:match("^%s+aliases:") then
        -- Just mark that we're in the aliases section
        vim.notify("Found aliases section", vim.log.levels.INFO)
        current_fragment.in_aliases_section = true
      elseif current_fragment and current_fragment.in_aliases_section and line:match("^%s+-%s+") then
        -- This is an alias line in the format "  - alias_name"
        local alias = line:match("^%s+-%s+(.+)")
        if alias and #alias > 0 then
          table.insert(current_fragment.aliases, alias)
          vim.notify("Added alias: " .. alias, vim.log.levels.INFO)
        end
      elseif current_fragment and current_fragment.in_aliases_section and not line:match("^%s+-%s+") then
        -- We've exited the aliases section
        current_fragment.in_aliases_section = nil
      end
    end
    
    -- Show the parsed fragments
    for i, fragment in ipairs(fragments) do
      local aliases = table.concat(fragment.aliases, ", ")
      if aliases == "" then aliases = "none" end
      vim.notify(string.format("Fragment %d: %s, Aliases: %s", i, fragment.hash:sub(1, 8), aliases), vim.log.levels.INFO)
    end
  end
end

return M
