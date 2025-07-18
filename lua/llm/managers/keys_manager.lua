-- llm/managers/keys_manager.lua - API key management for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local api = vim.api
local llm_cli = require('llm.core.data.llm_cli')
local cache = require('llm.core.data.cache')
local keys_view = require('llm.ui.views.keys_view')
local styles = require('llm.ui.styles')

-- Get stored API keys from llm CLI
function M.get_stored_keys()
    local cached_keys = cache.get('keys')
    if cached_keys then
        return cached_keys
    end

    local keys_json = llm_cli.run_llm_command('keys list --json')
    local keys = vim.fn.json_decode(keys_json)
    cache.set('keys', keys)
    return keys
end

-- Check if an API key is set
function M.is_key_set(key_name)
  local stored_keys = M.get_stored_keys()
  for _, key in ipairs(stored_keys) do
    if key.name == key_name then
      return true
    end
  end
  return false
end

-- Set an API key by directly modifying the keys.json file
function M.set_api_key(key_name, key_value)
    local result = llm_cli.run_llm_command('keys set ' .. key_name .. ' ' .. key_value)
    cache.invalidate('keys')
    return result ~= nil
end

-- Remove an API key by directly modifying the keys.json file
function M.remove_api_key(key_name)
    local result = llm_cli.run_llm_command('keys remove ' .. key_name)
    cache.invalidate('keys')
    return result ~= nil
end

-- Populate the buffer with key management content
function M.populate_keys_buffer(bufnr)
  local all_stored_keys_list = M.get_stored_keys()
  local stored_keys_set = {}
  for _, key in ipairs(all_stored_keys_list) do stored_keys_set[key.name] = true end

  local lines = {
    "# API Key Management",
    "",
    "Navigate: [M]odels [P]lugins [F]ragments [T]emplates [S]chemas",
    "Actions: [s]et key [r]emove key [A]dd custom [q]uit",
    "──────────────────────────────────────────────────────────────",
    "",
    "## Available Providers:",
    ""
  }

  local predefined_providers_list = {
    "openai", "anthropic", "mistral", "gemini", "groq", "perplexity",
    "cohere", "replicate", "anyscale", "together", "deepseek", "fireworks",
    "aws", "azure",
  }
  local predefined_providers_set = {}
  for _, p_name in ipairs(predefined_providers_list) do predefined_providers_set[p_name] = true end

  local key_data = {}
  local line_to_provider = {}
  local current_line = #lines + 1

  for _, provider_name in ipairs(predefined_providers_list) do
    local is_set = stored_keys_set[provider_name] or false
    local status = is_set and "✓" or " "
    local line = string.format("[%s] %s", status, provider_name)
    table.insert(lines, line)
    key_data[provider_name] = { line = current_line, is_set = is_set }
    line_to_provider[current_line] = provider_name
    current_line = current_line + 1
  end

  table.insert(lines, "")

  local custom_keys_to_display = {}
  for _, stored_key in ipairs(all_stored_keys_list) do
    if not predefined_providers_set[stored_key.name] then
      table.insert(custom_keys_to_display, stored_key.name)
    end
  end
  table.sort(custom_keys_to_display)

  if #custom_keys_to_display > 0 then
    table.insert(lines, "## Custom Keys:")
    table.insert(lines, "")
    for _, custom_key_name in ipairs(custom_keys_to_display) do
      local line = string.format("[✓] %s", custom_key_name)
      table.insert(lines, line)
      key_data[custom_key_name] = { line = current_line, is_set = true }
      line_to_provider[current_line] = custom_key_name
      current_line = current_line + 1
    end
    table.insert(lines, "")
  end

  api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  styles.setup_buffer_syntax(bufnr)
  vim.b[bufnr].line_to_provider = line_to_provider
  vim.b[bufnr].key_data = key_data
  vim.b[bufnr].stored_keys_set = stored_keys_set
end

-- Setup keymaps for the key management buffer
function M.setup_keys_keymaps(bufnr, manager_module)
  manager_module = manager_module or M

  local function set_keymap(mode, lhs, rhs)
    api.nvim_buf_set_keymap(bufnr, mode, lhs, rhs, { noremap = true, silent = true })
  end

  set_keymap('n', 's', string.format([[<Cmd>lua require('%s').set_key_under_cursor(%d)<CR>]], manager_module.__name, bufnr))
  set_keymap('n', 'r', string.format([[<Cmd>lua require('%s').remove_key_under_cursor(%d)<CR>]], manager_module.__name, bufnr))
  set_keymap('n', 'A', string.format([[<Cmd>lua require('%s').add_new_custom_key_interactive(%d)<CR>]], manager_module.__name, bufnr))
end

function M.add_new_custom_key_interactive(bufnr)
  keys_view.get_custom_key_name(function(custom_name)
    if not custom_name or custom_name == "" then
      vim.notify("Custom key name cannot be empty. Aborted.", vim.log.levels.WARN)
      return
    end

    keys_view.get_api_key(custom_name, function(key_value)
      if not key_value or key_value == "" then
        vim.notify("API key value cannot be empty. Aborted.", vim.log.levels.WARN)
        return
      end

      if M.set_api_key(custom_name, key_value) then
        vim.notify("Successfully set key for '" .. custom_name .. "'", vim.log.levels.INFO)
        require('llm.ui.unified_manager').switch_view("Keys")
      else
        vim.notify("Failed to set key for '" .. custom_name .. "'. See previous errors for details.", vim.log.levels.ERROR)
      end
    end)
  end)
end

function M.set_key_under_cursor(bufnr)
  local provider_name, _ = M.get_provider_info_under_cursor(bufnr)
  if not provider_name then return end

  keys_view.get_api_key(provider_name, function(key_value)
    if not key_value or key_value == "" then
      vim.notify("API key value cannot be empty. Aborted for " .. provider_name .. ".", vim.log.levels.WARN)
      return
    end
    if M.set_api_key(provider_name, key_value) then
      vim.notify("Key for '" .. provider_name .. "' set", vim.log.levels.INFO)
      require('llm.ui.unified_manager').switch_view("Keys")
    else
      vim.notify("Failed to set key for '" .. provider_name .. "'.", vim.log.levels.ERROR)
    end
  end)
end

function M.remove_key_under_cursor(bufnr)
  local provider_name, key_info = M.get_provider_info_under_cursor(bufnr)
  if not provider_name or provider_name == "+" then return end

  local stored_keys_set = vim.b[bufnr].stored_keys_set
  if not stored_keys_set[provider_name] then
    vim.notify("No key found for '" .. provider_name .. "'", vim.log.levels.WARN)
    return
  end

  keys_view.confirm_remove_key(provider_name, function()
    if M.remove_api_key(provider_name) then
      vim.notify("Key for '" .. provider_name .. "' removed", vim.log.levels.INFO)
      require('llm.ui.unified_manager').switch_view("Keys")
    else
      vim.notify("Failed to remove key for '" .. provider_name .. "'", vim.log.levels.ERROR)
    end
  end)
end

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
    return "+", nil
  elseif provider_name and key_data[provider_name] then
    return provider_name, key_data[provider_name]
  end
  return nil, nil
end

function M.manage_keys()
  require('llm.ui.unified_manager').open_specific_manager("Keys")
end

M.__name = 'llm.managers.keys_manager'

return M
