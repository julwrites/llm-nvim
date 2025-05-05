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
  local logs_path = M.safe_shell_command(logs_path_cmd, "Failed to get LLM logs path")

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
  local config_dir = M.safe_shell_command(config_dir_cmd, "Failed to get directory name from logs path")

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
    api.nvim_buf_set_lines(buf, 0, -1, false, {opts.default})
  end

  -- Local function to handle confirmation
  local function confirm()
    local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
    local input = table.concat(lines, '\n')
    api.nvim_win_close(win, true)
    if on_confirm then
      on_confirm(input)
    end
  end

  -- Set keymaps using the local confirm function
  api.nvim_buf_set_keymap(buf, 'i', '<CR>', '<cmd>lua require("llm.utils")._confirm_floating_input()<CR>', {noremap = true, silent = true})
  api.nvim_buf_set_keymap(buf, 'n', '<CR>', '<cmd>lua require("llm.utils")._confirm_floating_input()<CR>', {noremap = true, silent = true})
  api.nvim_buf_set_keymap(buf, '', '<Esc>', '<cmd>lua require("llm.utils")._close_floating_input()<CR>', {noremap = true, silent = true})

  -- Store callback in buffer var
  api.nvim_buf_set_var(buf, 'floating_input_callback', function(input)
    if on_confirm then
      on_confirm(input)
    end
  end)

  -- Start in insert mode
  api.nvim_command('startinsert')
end

-- Internal function to confirm floating input
function M._confirm_floating_input()
  local buf = api.nvim_get_current_buf()
  local win = api.nvim_get_current_win()
  local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
  local input = table.concat(lines, '\n')
  local callback = api.nvim_buf_get_var(buf, 'floating_input_callback')
  api.nvim_win_close(win, true)
  if callback then
    callback(input)
  end
end

-- Internal function to close floating input
function M._close_floating_input()
  local win = api.nvim_get_current_win()
  api.nvim_win_close(win, true)
end

-- Create a floating confirmation dialog with styling
function M.floating_confirm(opts)
  local prompt = opts.prompt or "Are you sure?"
  local on_confirm = opts.on_confirm or function() end

  -- Calculate window dimensions
  local width = math.min(math.floor(vim.o.columns * 0.4), 60)
  local height = 5  -- Increased height for better spacing
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
    title = ' '..prompt..' ',
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
  api.nvim_win_set_option(win, 'winhl', 'Normal:LlmConfirmText,NormalFloat:LlmConfirmText,FloatBorder:LlmConfirmBorder,Title:LlmConfirmTitle')

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
  api.nvim_buf_add_highlight(buf, -1, 'LlmConfirmButton', 4, 3, 7)  -- Yes
  api.nvim_buf_add_highlight(buf, -1, 'LlmConfirmButtonCancel', 4, 11, 13)  -- No

  -- Set keymaps with better visual feedback
  api.nvim_buf_set_keymap(buf, 'n', 'y', '<Cmd>lua require("llm.utils")._confirm_floating_dialog(true)<CR>', 
    {noremap = true, silent = true, desc = "Confirm action"})
  api.nvim_buf_set_keymap(buf, 'n', 'Y', '<Cmd>lua require("llm.utils")._confirm_floating_dialog(true)<CR>', 
    {noremap = true, silent = true, desc = "Confirm action"})
  api.nvim_buf_set_keymap(buf, 'n', 'n', '<Cmd>lua require("llm.utils")._confirm_floating_dialog(false)<CR>', 
    {noremap = true, silent = true, desc = "Cancel action"})
  api.nvim_buf_set_keymap(buf, 'n', 'N', '<Cmd>lua require("llm.utils")._confirm_floating_dialog(false)<CR>', 
    {noremap = true, silent = true, desc = "Cancel action"})
  api.nvim_buf_set_keymap(buf, 'n', '<Esc>', '<Cmd>lua require("llm.utils")._confirm_floating_dialog(false)<CR>', 
    {noremap = true, silent = true, desc = "Cancel action"})

  -- Store callback in buffer var
  api.nvim_buf_set_var(buf, 'floating_confirm_callback', on_confirm)
end

function M._confirm_floating_dialog(confirmed)
  local buf = api.nvim_get_current_buf()
  local callback = api.nvim_buf_get_var(buf, 'floating_confirm_callback')
  api.nvim_win_close(0, true)
  callback(confirmed)
end

function M._select_floating_confirm(index)
  local buf = api.nvim_get_current_buf()
  local options = api.nvim_buf_get_var(buf, 'floating_confirm_options')
  local callback = api.nvim_buf_get_var(buf, 'floating_confirm_callback')
  api.nvim_win_close(0, true)
  if options[index] then
    callback(options[index])
  end
end

function M._close_floating_confirm()
  api.nvim_win_close(0, true)
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

-- Escape special pattern characters in a string
function M.escape_pattern(s)
  -- Escape these special pattern characters: ^$()%.[]*+-?
  local escaped = string.gsub(s, "[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1")
  return escaped
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
