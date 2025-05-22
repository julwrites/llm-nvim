local M = {}

local api = vim.api

function M.create_split_buffer()
  -- Create a new split
  local buf = api.nvim_create_buf()
  api.nvim_open_win(buf, true)
  return buf
end

-- Create a new buffer with content
function M.create_buffer_with_content(content, buffer_name, filetype)
  M.create_split_buffer() -- This will also swap to the buffer
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

-- Replace an existing buffer with new content
function M.replace_buffer_with_content(content, buffer, filetype)
  local buf = buffer

  -- Set buffer options
  api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(buf, 'swapfile', false)

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
    title = ' ' .. (title or 'LLM') .. ' ', -- Initial title
    title_pos = 'center',
  }

  local win = api.nvim_open_win(buf, true, opts)
  api.nvim_win_set_option(win, 'cursorline', true)
  api.nvim_win_set_option(win, 'winblend', 0)

  return win
end

-- Create a floating input window
function M.floating_input(opts, on_confirm)
  local buf = api.nvim_create_buf(false, true)
  local width = math.floor(vim.o.columns * 0.6)
  local height = 1
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win_opts = {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = opts.prompt or 'Input',
    title_pos = 'center'
  }

  local win = api.nvim_open_win(buf, true, win_opts)

  -- Set default value if provided
  if opts.default then
    api.nvim_buf_set_lines(buf, 0, -1, false, { opts.default })
  end

  -- Set keymaps using the local confirm function
  api.nvim_buf_set_keymap(buf, 'i', '<CR>', '<cmd>lua require("llm.utils")._confirm_floating_input()<CR>',
    { noremap = true, silent = true })
  api.nvim_buf_set_keymap(buf, 'n', '<CR>', '<cmd>lua require("llm.utils")._confirm_floating_input()<CR>',
    { noremap = true, silent = true })
  api.nvim_buf_set_keymap(buf, '', '<Esc>', '<cmd>lua require("llm.utils")._close_floating_input()<CR>',
    { noremap = true, silent = true })

  -- Store callback in buffer var
  api.nvim_buf_set_var(buf, 'floating_input_callback', function(input)
    if on_confirm then
      on_confirm(input)
    end
  end)

  -- Start in insert mode
  api.nvim_command('startinsert')
end

-- Create a floating confirmation dialog with styling
function M.floating_confirm(opts)
  local prompt = opts.prompt or "Are you sure?"
  local on_confirm = opts.on_confirm or function() end

  -- Calculate window dimensions
  local width = math.min(math.floor(vim.o.columns * 0.4), 60)
  local height = 5 -- Increased height for better spacing
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Create window with styling
  local buf = api.nvim_create_buf(false, true)
  local win_opts = {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' ' .. prompt .. ' ',
    title_pos = 'center',
    focusable = true,
    noautocmd = true,
    zindex = 50
  }

  -- Apply highlights before creating window
  api.nvim_set_hl(0, 'LlmConfirmTitle', { fg = '#f8f8f2', bg = '#44475a', bold = true })
  api.nvim_set_hl(0, 'LlmConfirmBorder', { fg = '#6272a4' })
  api.nvim_set_hl(0, 'LlmConfirmText', { fg = '#f8f8f2' })
  api.nvim_set_hl(0, 'LlmConfirmButton', { fg = '#50fa7b', bold = true })
  api.nvim_set_hl(0, 'LlmConfirmButtonCancel', { fg = '#ff5555', bold = true })

  local win = api.nvim_open_win(buf, true, win_opts)

  -- Set window highlights
  api.nvim_win_set_option(win, 'winhl',
    'Normal:LlmConfirmText,NormalFloat:LlmConfirmText,FloatBorder:LlmConfirmBorder,Title:LlmConfirmTitle')

  -- Add compact styled content that fits in 5 lines
  local lines = {
    "┌───────────────────────────────┐",
    "│  Confirm your action          │",
    "└───────────────────────────────┘",
    "",
    "  [Y]es    [N]o"
  }
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Add highlights for the buttons
  api.nvim_buf_add_highlight(buf, -1, 'LlmConfirmButton', 4, 3, 7)         -- Yes
  api.nvim_buf_add_highlight(buf, -1, 'LlmConfirmButtonCancel', 4, 11, 13) -- No

  -- Set keymaps with better visual feedback
  api.nvim_buf_set_keymap(buf, 'n', 'y', '<Cmd>lua require("llm.utils")._confirm_floating_dialog(true)<CR>',
    { noremap = true, silent = true, desc = "Confirm action" })
  api.nvim_buf_set_keymap(buf, 'n', 'Y', '<Cmd>lua require("llm.utils")._confirm_floating_dialog(true)<CR>',
    { noremap = true, silent = true, desc = "Confirm action" })
  api.nvim_buf_set_keymap(buf, 'n', 'n', '<Cmd>lua require("llm.utils")._confirm_floating_dialog(false)<CR>',
    { noremap = true, silent = true, desc = "Cancel action" })
  api.nvim_buf_set_keymap(buf, 'n', 'N', '<Cmd>lua require("llm.utils")._confirm_floating_dialog(false)<CR>',
    { noremap = true, silent = true, desc = "Cancel action" })
  api.nvim_buf_set_keymap(buf, 'n', '<Esc>', '<Cmd>lua require("llm.utils")._confirm_floating_dialog(false)<CR>',
    { noremap = true, silent = true, desc = "Cancel action" })

  -- Store callback in buffer var
  api.nvim_buf_set_var(buf, 'floating_confirm_callback', on_confirm)
end

return M
