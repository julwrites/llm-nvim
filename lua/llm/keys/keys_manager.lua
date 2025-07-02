-- llm/keys/keys_manager.lua - API key management for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local api = vim.api
local utils = require('llm.utils')
local styles = require('llm.styles') -- Added

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

-- Populate the buffer with key management content
function M.populate_keys_buffer(bufnr)
  local stored_keys = M.get_stored_keys()
  local stored_keys_set = {}
  for _, key in ipairs(stored_keys) do stored_keys_set[key] = true end

  local lines = {
    "# API Key Management",
    "",
    "Navigate: [M]odels [P]lugins [F]ragments [T]emplates [S]chemas",
    "Actions: [s]et key [r]emove key [q]uit",
    "──────────────────────────────────────────────────────────────",
    "",
    "## Available Providers:",
    ""
  }

  local providers = {
    "openai", "anthropic", "mistral", "gemini", "groq", "perplexity",
    "cohere", "replicate", "anyscale", "together", "deepseek", "fireworks",
    "aws", "azure",
  }

  local key_data = {}
  local line_to_provider = {}
  local current_line = #lines + 1

  for _, provider in ipairs(providers) do
    local status = stored_keys_set[provider] and "✓" or " "
    local line = string.format("[%s] %s", status, provider)
    table.insert(lines, line)
    key_data[provider] = { line = current_line, is_set = stored_keys_set[provider] or false }
    line_to_provider[current_line] = provider
    current_line = current_line + 1
  end

  table.insert(lines, "")
  table.insert(lines, "## Custom Key:")
  table.insert(lines, "[+] Add custom key")
  local custom_key_line = current_line + 2
  line_to_provider[custom_key_line] = "+" -- Special marker for custom key line

  api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- Apply syntax highlighting
  styles.setup_buffer_syntax(bufnr) -- Use styles module

  -- Store lookup tables in buffer variables
  vim.b[bufnr].line_to_provider = line_to_provider
  vim.b[bufnr].key_data = key_data
  vim.b[bufnr].stored_keys_set = stored_keys_set -- Store for checking in actions

  return line_to_provider, key_data              -- Return for direct use if needed
end

-- Setup keymaps for the key management buffer
function M.setup_keys_keymaps(bufnr, manager_module)
  manager_module = manager_module or M -- Allow passing self

  local function set_keymap(mode, lhs, rhs)
    api.nvim_buf_set_keymap(bufnr, mode, lhs, rhs, { noremap = true, silent = true })
  end

  -- Helper to get provider info
  local function get_provider_info_under_cursor()
    local current_line = api.nvim_win_get_cursor(0)[1]
    local line_to_provider = vim.b[bufnr].line_to_provider
    local key_data = vim.b[bufnr].key_data
    local provider_name = line_to_provider and line_to_provider[current_line]
    if provider_name and key_data and key_data[provider_name] then
      return provider_name, key_data[provider_name]
    elseif provider_name == "+" then -- Handle custom key line
      return "+", nil
    end
    return nil, nil
  end

  -- Set key under cursor
  set_keymap('n', 's',
    string.format([[<Cmd>lua require('%s').set_key_under_cursor(%d)<CR>]],
      manager_module.__name or 'llm.keys.keys_manager', bufnr))

  -- Remove key under cursor
  set_keymap('n', 'r',
    string.format([[<Cmd>lua require('%s').remove_key_under_cursor(%d)<CR>]],
      manager_module.__name or 'llm.keys.keys_manager', bufnr))
end

-- Action functions called by keymaps (now accept bufnr)
function M.set_key_under_cursor(bufnr)
  local provider_name_or_action, _ = M.get_provider_info_under_cursor(bufnr)

  if not provider_name_or_action then
    return
  end

  local function handle_key_setting(p_name, p_value)
    if M.set_api_key(p_name, p_value) then
      vim.notify("Key for '" .. p_name .. "' set", vim.log.levels.INFO)
      require('llm.unified_manager').switch_view("Keys") -- Refresh unified view
    else
      vim.notify("Failed to set key for '" .. p_name .. "'", vim.log.levels.ERROR)
    end
  end

  if provider_name_or_action == "+" then
    -- Handle custom key: Step 1: Get custom key name
    utils.floating_input({ prompt = "Enter custom key name:" }, function(custom_name)
      if not custom_name or custom_name == "" then
        vim.notify("Custom key name cannot be empty.", vim.log.levels.WARN)
        return
      end
      -- Step 2: Get custom key value
      utils.floating_input({ prompt = "Enter API key for " .. custom_name .. ":" }, function(key_value)
        if not key_value or key_value == "" then
          vim.notify("API key value cannot be empty.", vim.log.levels.WARN)
          return
        end
        handle_key_setting(custom_name, key_value)
      end)
    end)
  else
    -- Handle regular provider
    utils.floating_input({ prompt = "Enter API key for " .. provider_name_or_action .. ":" }, function(key_value)
      if not key_value or key_value == "" then
        vim.notify("API key value cannot be empty.", vim.log.levels.WARN)
        return
      end
      handle_key_setting(provider_name_or_action, key_value)
    end)
  end
end

function M.remove_key_under_cursor(bufnr)
  local provider_name, key_info = M.get_provider_info_under_cursor(bufnr)
  if not provider_name or provider_name == "+" then return end -- Cannot remove '+'

  local stored_keys_set = vim.b[bufnr].stored_keys_set
  if not stored_keys_set[provider_name] then
    vim.notify("No key found for '" .. provider_name .. "'", vim.log.levels.WARN)
    return
  end

  utils.floating_confirm({
    prompt = "Remove key for '" .. provider_name .. "'?",
    on_confirm = function() -- Modified to use on_confirm callback
      if M.remove_api_key(provider_name) then
        vim.notify("Key for '" .. provider_name .. "' removed", vim.log.levels.INFO)
        require('llm.unified_manager').switch_view("Keys")
      else
        vim.notify("Failed to remove key for '" .. provider_name .. "'", vim.log.levels.ERROR)
      end
    end
    -- Removed options table as floating_confirm uses Y/N by default
  })
end

-- Helper to get provider info from buffer variables
function M.get_provider_info_under_cursor(bufnr)
  local current_line = api.nvim_win_get_cursor(0)[1]
  local line_to_provider = vim.b[bufnr].line_to_provider
  local key_data = vim.b[bufnr].key_data
  if not line_to_provider or not key_data then
    vim.notify("Buffer data missing", vim.log.levels.ERROR)
    return nil, nil
  end
  local provider_name = line_to_provider[current_line]
  if provider_name == "+" then
    return "+", nil -- Special case for custom key line
  elseif provider_name and key_data[provider_name] then
    return provider_name, key_data[provider_name]
  end
  return nil, nil
end

-- Main function to open the key manager (now delegates to unified manager)
function M.manage_keys()
  require('llm.unified_manager').open_specific_manager("Keys")
end

-- Add module name for require path in keymaps
M.__name = 'llm.keys.keys_manager'

return M
