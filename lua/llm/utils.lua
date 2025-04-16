-- llm/utils.lua - Utility functions for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local api = vim.api
local fn = vim.fn

-- Error handling wrapper for shell commands
function M.safe_shell_command(cmd, error_msg)
  local success, handle = pcall(io.popen, cmd)
  if not success then
    api.nvim_err_writeln(error_msg or "Failed to execute command: " .. cmd)
    return nil
  end
  
  local result = handle:read("*a")
  local close_success = handle:close()
  
  if not close_success then
    api.nvim_err_writeln("Command execution failed: " .. cmd)
    return nil
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
  ]])

  -- Define syntax matching
  local syntax_cmds = {
    -- Headers
    "syntax match LLMHeader /^#.*/",
    "syntax match LLMSubHeader /^##.*/",

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

return M
