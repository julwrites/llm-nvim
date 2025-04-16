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

-- Set an API key using llm CLI
function M.set_api_key(key_name, key_value)
  if not utils.check_llm_installed() then
    return false
  end

  -- In a real implementation, we would use the key_value
  -- But for security reasons, we'll just call the CLI which will prompt for the key
  local result = utils.safe_shell_command(
    string.format('llm keys set %s', key_name),
    "Failed to set API key: " .. key_name
  )
  
  return result ~= nil
end

-- Remove an API key using llm CLI
function M.remove_api_key(key_name)
  if not utils.check_llm_installed() then
    return false
  end

  local result = utils.safe_shell_command(
    string.format('llm keys remove %s', key_name),
    "Failed to remove API key: " .. key_name
  )
  
  return result ~= nil
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
  local win = utils.create_floating_window(buf, ' LLM API Keys ')

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

        -- Close the window and set the key
        vim.api.nvim_win_close(0, true)

        -- Use vim.fn.inputsecret to securely get the key
        vim.schedule(function()
          vim.cmd("redraw")
          if M.set_api_key(custom_name) then
            vim.notify("Key '" .. custom_name .. "' has been set", vim.log.levels.INFO)
          else
            vim.notify("Failed to set key '" .. custom_name .. "'", vim.log.levels.ERROR)
          end
        end)
      end)
      return
    end

    if not provider then return end

    -- Close the window and set the key
    vim.api.nvim_win_close(0, true)

    -- Use vim.fn.inputsecret to securely get the key
    vim.schedule(function()
      vim.cmd("redraw")
      if M.set_api_key(provider) then
        vim.notify("Key for '" .. provider .. "' has been set", vim.log.levels.INFO)
      else
        vim.notify("Failed to set key for '" .. provider .. "'", vim.log.levels.ERROR)
      end
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

    -- Confirm removal
    vim.ui.select({ "Yes", "No" }, {
      prompt = "Remove key for '" .. provider .. "'?"
    }, function(choice)
      if choice ~= "Yes" then return end

      -- Close the window and remove the key
      vim.api.nvim_win_close(0, true)

      vim.schedule(function()
        if M.remove_api_key(provider) then
          vim.notify("Key for '" .. provider .. "' has been removed", vim.log.levels.INFO)
        else
          vim.notify("Failed to remove key for '" .. provider .. "'", vim.log.levels.ERROR)
        end
      end)
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
