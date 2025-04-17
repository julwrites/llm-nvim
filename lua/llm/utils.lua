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

-- Get the configuration directory and file path for llm
function M.get_config_path(filename)
  local home = os.getenv("HOME")
  if not home then
    vim.notify("Could not determine home directory", vim.log.levels.ERROR)
    return nil, nil
  end

  -- Try standard locations for the config file
  local possible_dirs = {
    home .. "/.config/io.datasette.llm",                     -- Linux/macOS standard
    home .. "/.io.datasette.llm",                            -- Alternative location
    home .. "/Library/Application Support/io.datasette.llm", -- macOS specific
    home .. "/AppData/Roaming/io.datasette.llm",             -- Windows
  }
  
  local config_dir = nil
  local config_file = nil
  
  -- First check if the file exists in any of the locations
  for _, dir in ipairs(possible_dirs) do
    local file_path = dir .. "/" .. filename
    local f = io.open(file_path, "r")
    if f then
      f:close()
      config_dir = dir
      config_file = file_path
      break
    end
  end
  
  -- If file doesn't exist, use the default location
  if not config_file then
    config_dir = possible_dirs[1]  -- Use the first location as default
    config_file = config_dir .. "/" .. filename
  end
  
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
    title = title or ' LLM ',
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
  -- Create syntax groups if they don't exist yet
  vim.cmd([[
    highlight default LLMHeader guifg=#61afef gui=bold
    highlight default LLMSubHeader guifg=#56b6c2 gui=bold
    highlight default LLMInstalled guifg=#98c379 gui=bold
    highlight default LLMNotInstalled guifg=#e06c75
    highlight default LLMAction guifg=#c678dd gui=italic
    highlight default LLMDivider guifg=#3b4048
    highlight default LLMCustom guifg=#e5c07b gui=bold
    highlight default LLMCheckboxInstalled guifg=#98c379 gui=bold
    highlight default LLMCheckboxAvailable guifg=#e06c75
  ]])

  -- Define syntax matching
  local syntax_cmds = {
    -- Headers
    "syntax match LLMHeader /^#.*/",
    "syntax match LLMSubHeader /^##.*/",

    -- Checkboxes
    "syntax match LLMCheckboxInstalled /\\[✓\\]/",
    "syntax match LLMCheckboxAvailable /\\[ \\]/",

    -- Installed/not installed items
    "syntax match LLMInstalled /\\[✓\\].*/",
    "syntax match LLMNotInstalled /\\[ \\].*/",

    -- Action text
    "syntax match LLMAction /Press.*quit/",

    -- Dividers
    "syntax match LLMDivider /^─\\+$/",

    -- Custom items
    "syntax match LLMCustom /\\[+\\].*/",
  }

  -- Apply syntax commands to the buffer
  for _, cmd in ipairs(syntax_cmds) do
    vim.api.nvim_buf_call(buf, function()
      vim.cmd(cmd)
    end)
  end
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
