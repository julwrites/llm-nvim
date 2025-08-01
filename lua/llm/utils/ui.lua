local M = {}

local api = vim.api

-- Common buffer configuration
local DEFAULT_BUFFER_OPTS = {
  buftype = 'nofile',
  bufhidden = 'wipe',
  swapfile = false
}

-- Convert content string to lines array
local function content_to_lines(content)
  local lines = {}
  for line in content:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end
  return lines
end

-- Configure a buffer with standard options
local function configure_buffer(buf, opts)
  for opt, val in pairs(DEFAULT_BUFFER_OPTS) do
    api.nvim_buf_set_option(buf, opt, val)
  end

  if opts.name then
    api.nvim_buf_set_name(buf, opts.name)
  end

  if opts.filetype then
    api.nvim_buf_set_option(buf, 'filetype', opts.filetype)
  end

  if opts.content then
    api.nvim_buf_set_lines(buf, 0, -1, false, content_to_lines(opts.content))
  end
end

function M.create_split_buffer()
  local buf = api.nvim_create_buf()
  api.nvim_open_win(buf, true)
  return buf
end

function M.create_buffer_with_content(content, buffer_name, filetype)
  M.create_split_buffer()
  local buf = api.nvim_get_current_buf()
  configure_buffer(buf, {
    name = buffer_name or 'LLM Output',
    filetype = filetype,
    content = content
  })
  return buf
end

function M.replace_buffer_with_content(content, buffer, filetype)
  configure_buffer(buffer, {
    filetype = filetype,
    content = content
  })
  return buffer
end

-- Common window configuration
local function get_window_config(width_ratio, height_ratio, title)
  local width = math.floor(vim.o.columns * width_ratio)
  local height = math.floor(vim.o.lines * height_ratio)
  return {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = 'rounded',
    title = ' ' .. (title or 'LLM') .. ' ',
    title_pos = 'center'
  }
end

function M.create_floating_window(buf, title)
  local win = api.nvim_open_win(buf, true, get_window_config(0.8, 0.8, title))
  api.nvim_win_set_option(win, 'cursorline', true)
  api.nvim_win_set_option(win, 'winblend', 0)
  return win
end

-- Common keybindings for floating windows
local function set_floating_keymaps(buf, confirm_cmd, cancel_cmd)
  local keymaps = {
    { mode = 'i', key = '<CR>', cmd = confirm_cmd },
    { mode = 'n', key = '<CR>', cmd = confirm_cmd },
    { mode = '',  key = '<Esc>', cmd = cancel_cmd }
  }

  for _, km in ipairs(keymaps) do
    api.nvim_buf_set_keymap(buf, km.mode, km.key, km.cmd, { noremap = true, silent = true })
  end
end

function M.floating_input(opts, on_confirm)
  local buf = api.nvim_create_buf(false, true)
  local win = api.nvim_open_win(buf, true, get_window_config(0.6, 0.05, opts.prompt or 'Input'))

  if opts.default then
    api.nvim_buf_set_lines(buf, 0, -1, false, { opts.default })
  end

  set_floating_keymaps(buf, 
    '<cmd>lua require("llm.utils")._confirm_floating_input()<CR>',
    '<cmd>lua require("llm.utils")._close_floating_input()<CR>'
  )

  api.nvim_buf_set_var(buf, 'floating_input_callback', function(input)
    if on_confirm then on_confirm(input) end
  end)
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
