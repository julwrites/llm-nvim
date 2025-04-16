-- llm/keys.lua - API key management for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local api = vim.api
local utils = require('llm.utils')

-- Get stored API keys from llm CLI
function M.get_stored_keys()
  if not utils.check_llm_installed() then
    return {}
  end

  local result = utils.safe_shell_command("llm keys", "Failed to get stored keys")
  if not result then
    return {}
  end

  local stored_keys = {}
  for line in result:gmatch("[^\r\n]+") do
    if line ~= "Stored keys:" and line ~= "------------------" and line ~= "" then
      table.insert(stored_keys, line)
    end
  end

  return stored_keys
end

-- Check if an API key is set
function M.is_key_set(key_name)
  local stored_keys = M.get_stored_keys()
  for _, key in ipairs(stored_keys) do
    if key == key_name then
      return true
    end
  end
  return false
end

-- Set an API key by directly modifying the keys.json file
function M.set_api_key(key_name, key_value)
  if not utils.check_llm_installed() then
    return false
  end

  -- Find the keys.json file in the standard locations
  local keys_dir, keys_file = utils.get_config_path("keys.json")
  
  -- If keys file doesn't exist, create it in the default location
  if not keys_file then
    local home = os.getenv("HOME")
    if not home then
      vim.notify("Could not determine home directory", vim.log.levels.ERROR)
      return false
    end
    
    keys_dir = home .. "/.config/io.datasette.llm"
    keys_file = keys_dir .. "/keys.json"
    
    -- Create directory if it doesn't exist
    os.execute("mkdir -p " .. keys_dir)
  end

  -- Read existing keys or create empty table
  local keys_data = {}
  local file = io.open(keys_file, "r")
  
  if file then
    local content = file:read("*a")
    file:close()
    
    -- Parse JSON if file exists and has content
    if content and content ~= "" then
      local success
      success, keys_data = pcall(vim.fn.json_decode, content)
      if not success or type(keys_data) ~= "table" then
        keys_data = {} -- Reset to empty table if parsing failed
      end
    end
  end

  -- Set the key
  keys_data[key_name] = key_value

  -- Write the updated keys back to the file
  local updated_content = vim.fn.json_encode(keys_data)
  file = io.open(keys_file, "w")
  if not file then
    vim.notify("Failed to open keys file for writing: " .. keys_file, vim.log.levels.ERROR)
    return false
  end

  file:write(updated_content)
  file:close()

  vim.notify("Successfully set key for '" .. key_name .. "'", vim.log.levels.INFO)
  return true
end

-- Remove an API key by directly modifying the keys.json file
function M.remove_api_key(key_name)
  if not utils.check_llm_installed() then
    return false
  end

  -- Find the keys.json file in the standard locations
  local _, keys_file = utils.get_config_path("keys.json")

  if not keys_file then
    vim.notify("Could not find keys.json file in standard locations", vim.log.levels.ERROR)
    return false
  end

  -- Check if the file exists and is readable
  local file = io.open(keys_file, "r")
  if not file then
    vim.notify("Keys file not found or not readable: " .. keys_file, vim.log.levels.ERROR)
    return false
  end

  -- Read the current keys
  local content = file:read("*a")
  file:close()

  -- Parse JSON
  local success, keys_data = pcall(vim.fn.json_decode, content)
  if not success or type(keys_data) ~= "table" then
    vim.notify("Failed to parse keys file", vim.log.levels.ERROR)
    return false
  end

  -- Remove the key
  keys_data[key_name] = nil

  -- Write the updated keys back to the file
  local updated_content = vim.fn.json_encode(keys_data)
  file = io.open(keys_file, "w")
  if not file then
    vim.notify("Failed to open keys file for writing", vim.log.levels.ERROR)
    return false
  end

  file:write(updated_content)
  file:close()

  vim.notify("Successfully removed key: " .. key_name, vim.log.levels.INFO)
  return true
end

-- Manage API keys for different LLM providers
function M.manage_keys()
  if not utils.check_llm_installed() then
    return
  end

  -- Create a new buffer for the key manager
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(buf, 'swapfile', false)
  api.nvim_buf_set_name(buf, 'LLM API Keys')

  -- Create a new window
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
    title = ' LLM API Keys ',
    title_pos = 'center',
  }

  local win = api.nvim_open_win(buf, true, opts)
  api.nvim_win_set_option(win, 'cursorline', true)
  api.nvim_win_set_option(win, 'winblend', 0)

  -- Get list of stored keys
  local stored_keys = M.get_stored_keys()

  -- Set buffer content
  local lines = {
    "# LLM API Keys Manager",
    "",
    "Press 's' to set a new key, 'r' to remove a key, 'q' to quit",
    "──────────────────────────────────────────────────────────────",
    "",
    "## Available Providers:",
    ""
  }

  -- List of common API key providers
  local providers = {
    "openai",
    "anthropic",
    "mistral",
    "gemini",
    "groq",
    "perplexity",
    "cohere",
    "replicate",
    "anyscale",
    "together",
    "deepseek",
    "fireworks",
    "aws",   -- for bedrock
    "azure", -- for azure openai
  }

  -- Add stored keys with status
  local stored_keys_set = {}
  for _, key in ipairs(stored_keys) do
    stored_keys_set[key] = true
  end

  -- Add providers to the buffer
  for _, provider in ipairs(providers) do
    local status = stored_keys_set[provider] and "✓" or " "
    table.insert(lines, string.format("[%s] %s", status, provider))
  end

  -- Add custom key section
  table.insert(lines, "")
  table.insert(lines, "## Custom Key:")
  table.insert(lines, "[+] Add custom key")

  api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Set buffer options
  api.nvim_buf_set_option(buf, 'modifiable', false)

  -- Set up syntax highlighting
  utils.setup_buffer_highlighting(buf)

  -- Add key-specific highlighting
  vim.cmd([[
    highlight default LLMKeyAvailable guifg=#98c379
    highlight default LLMKeyMissing guifg=#e06c75
    highlight default LLMKeyAction guifg=#61afef gui=bold
  ]])

  -- Apply syntax highlighting
  local syntax_cmds = {
    "syntax match LLMKeyAvailable /\\[✓\\].*/",
    "syntax match LLMKeyMissing /\\[ \\].*/",
    "syntax match LLMKeyAction /^\\[+\\] Add custom key$/",
  }

  for _, cmd in ipairs(syntax_cmds) do
    vim.api.nvim_buf_call(buf, function()
      vim.cmd(cmd)
    end)
  end

  -- Map of line numbers to provider names
  local line_to_provider = {}
  local provider_start_line = 8 -- Line where providers start
  for i, provider in ipairs(providers) do
    line_to_provider[provider_start_line + i - 1] = provider
  end

  -- Create key manager module for the helper functions
  local key_manager = {}

  function key_manager.set_key_under_cursor()
    local current_line = api.nvim_win_get_cursor(0)[1]
    local provider = line_to_provider[current_line]

    -- Handle custom key
    if current_line == provider_start_line + #providers + 2 then
      -- Prompt for custom key name
      vim.ui.input({
        prompt = "Enter custom key name: "
      }, function(custom_name)
        if not custom_name or custom_name == "" then return end

        -- Create a floating window for secure key input
        key_manager.create_key_input_window(custom_name)
      end)
      return
    end

    if not provider then return end

    -- Create a floating window for secure key input
    key_manager.create_key_input_window(provider)
  end

  -- Create a floating window for secure key input
  function key_manager.create_key_input_window(provider_name)
    -- Create a new buffer for the key input
    local buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    api.nvim_buf_set_option(buf, 'swapfile', false)

    -- Set buffer content with instructions
    local lines = {
      "Enter API key for '" .. provider_name .. "':",
      "",
      "", -- Empty line for input
      "",
      "Press <Enter> to save, <Esc> to cancel"
    }
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    -- Calculate window size and position
    local width = math.min(60, math.floor(vim.o.columns * 0.6))
    local height = 7
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    -- Create the floating window
    local opts = {
      relative = 'editor',
      width = width,
      height = height,
      row = row,
      col = col,
      style = 'minimal',
      border = 'rounded',
      title = ' Set API Key ',
      title_pos = 'center',
    }

    local win = api.nvim_open_win(buf, true, opts)

    -- Set cursor position to the input line
    api.nvim_win_set_cursor(win, { 3, 0 })

    -- Enter insert mode
    vim.cmd('startinsert')

    -- Set buffer as modifiable
    api.nvim_buf_set_option(buf, 'modifiable', true)

    -- Set up syntax highlighting
    utils.setup_buffer_highlighting(buf)

    -- Add key-specific highlighting
    vim.cmd([[
      highlight default LLMKeyPrompt guifg=#61afef gui=bold
      highlight default LLMKeyInstructions guifg=#98c379
    ]])

    -- Apply syntax highlighting
    local syntax_cmds = {
      "syntax match LLMKeyPrompt /^Enter API key for.*/",
      "syntax match LLMKeyInstructions /^Press <Enter>.*/",
    }

    for _, cmd in ipairs(syntax_cmds) do
      vim.api.nvim_buf_call(buf, function()
        vim.cmd(cmd)
      end)
    end

    -- Set keymaps
    local function set_keymap(mode, lhs, rhs, opts)
      api.nvim_buf_set_keymap(buf, mode, lhs, rhs, opts or { noremap = true, silent = true })
    end

    -- Save key on Enter
    set_keymap('i', '<CR>', [[<Cmd>lua require('llm.key_manager').save_key_from_input()<CR>]])
    set_keymap('n', '<CR>', [[<Cmd>lua require('llm.key_manager').save_key_from_input()<CR>]])

    -- Cancel on Escape
    set_keymap('i', '<Esc>', [[<Cmd>lua require('llm.key_manager').cancel_key_input()<CR>]])
    set_keymap('n', '<Esc>', [[<Cmd>lua require('llm.key_manager').cancel_key_input()<CR>]])

    -- Store the provider name for later use
    vim.b[buf].provider_name = provider_name
  end

  -- Save the key from the input window
  function key_manager.save_key_from_input()
    local buf = api.nvim_get_current_buf()
    local provider_name = vim.b[buf].provider_name

    -- Get the key from the input line
    local key_value = api.nvim_buf_get_lines(buf, 2, 3, false)[1]

    -- Close the window
    vim.api.nvim_win_close(0, true)

    -- Close the key manager window too
    for _, win in ipairs(api.nvim_list_wins()) do
      local buf_name = api.nvim_buf_get_name(api.nvim_win_get_buf(win))
      if buf_name:match("LLM API Keys") then
        api.nvim_win_close(win, true)
        break
      end
    end

    -- Set the key
    vim.schedule(function()
      if key_value and key_value ~= "" then
        -- Use the set_api_key function with the key value
        if M.set_api_key(provider_name, key_value) then
          vim.notify("Key for '" .. provider_name .. "' has been set", vim.log.levels.INFO)

          -- Reopen the key manager window to show the updated status
          vim.schedule(function()
            M.manage_keys()
          end)
        else
          vim.notify("Failed to set key for '" .. provider_name .. "'", vim.log.levels.ERROR)

          -- Reopen the key manager window
          vim.schedule(function()
            M.manage_keys()
          end)
        end
      else
        vim.notify("No key provided, operation cancelled", vim.log.levels.WARN)

        -- Reopen the key manager window
        vim.schedule(function()
          M.manage_keys()
        end)
      end
    end)
  end

  -- Cancel key input
  function key_manager.cancel_key_input()
    local buf = api.nvim_get_current_buf()
    local provider_name = vim.b[buf].provider_name

    -- Close the window
    vim.api.nvim_win_close(0, true)

    vim.notify("Key input for '" .. provider_name .. "' cancelled", vim.log.levels.INFO)

    -- Reopen the key manager window
    vim.schedule(function()
      M.manage_keys()
    end)
  end

  function key_manager.remove_key_under_cursor()
    local current_line = api.nvim_win_get_cursor(0)[1]
    local provider = line_to_provider[current_line]

    if not provider then return end

    -- Check if the key exists
    if not stored_keys_set[provider] then
      vim.notify("No key found for '" .. provider .. "'", vim.log.levels.WARN)
      return
    end

    -- Use vim.fn.confirm for a more compact dialog
    local choice = vim.fn.confirm("Remove key for '" .. provider .. "'?", "&Yes\n&No", 2)
    
    if choice ~= 1 then return end
    
    -- Close the window and remove the key
    vim.api.nvim_win_close(0, true)
    
    vim.schedule(function()
      if M.remove_api_key(provider) then
        vim.notify("Key for '" .. provider .. "' has been removed", vim.log.levels.INFO)
        
        -- Reopen the key manager window to show the updated status
        vim.schedule(function()
          M.manage_keys()
        end)
      else
        vim.notify("Failed to remove key for '" .. provider .. "'", vim.log.levels.ERROR)
        
        -- Reopen the key manager window
        vim.schedule(function()
          M.manage_keys()
        end)
      end
    end)
  end

  -- Set keymaps
  local function set_keymap(mode, lhs, rhs)
    api.nvim_buf_set_keymap(buf, mode, lhs, rhs, { noremap = true, silent = true })
  end

  -- Set a key for the provider under cursor
  set_keymap('n', 's', [[<cmd>lua require('llm.key_manager').set_key_under_cursor()<CR>]])

  -- Remove a key for the provider under cursor
  set_keymap('n', 'r', [[<cmd>lua require('llm.key_manager').remove_key_under_cursor()<CR>]])

  -- Close window
  set_keymap('n', 'q', [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])
  set_keymap('n', '<Esc>', [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])

  -- Store the key manager module
  package.loaded['llm.key_manager'] = key_manager
end

return M
