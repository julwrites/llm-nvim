-- llm/keys/keys_manager.lua - API key management for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local api = vim.api
local utils = require('llm.utils')
local keys_view = require('llm.keys.keys_view')
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

  local keys_dir, keys_file = utils.get_config_path("keys.json")

  if not keys_file then
    local home = os.getenv("HOME")
    if not home then
      vim.notify("Could not determine home directory", vim.log.levels.ERROR)
      return false
    end
    keys_dir = home .. "/.config/io.datasette.llm"
    keys_file = keys_dir .. "/keys.json"
    os.execute("mkdir -p " .. keys_dir)
  end

  local keys_data = {}
  local file = io.open(keys_file, "r")

  if file then
    local content = file:read("*a")
    file:close()
    if content and content ~= "" then
      local success
      success, keys_data = pcall(vim.fn.json_decode, content)
      if not success or type(keys_data) ~= "table" then
        keys_data = {}
      end
    end
  end

  keys_data[key_name] = key_value

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

  local _, keys_file = utils.get_config_path("keys.json")

  if not keys_file then
    vim.notify("Could not find keys.json file in standard locations", vim.log.levels.ERROR)
    return false
  end

  local file = io.open(keys_file, "r")
  if not file then
    vim.notify("Keys file not found or not readable: " .. keys_file, vim.log.levels.ERROR)
    return false
  end

  local content = file:read("*a")
  file:close()

  local success, keys_data = pcall(vim.fn.json_decode, content)
  if not success or type(keys_data) ~= "table" then
    vim.notify("Failed to parse keys file", vim.log.levels.ERROR)
    return false
  end

  keys_data[key_name] = nil

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
  local all_stored_keys_list = M.get_stored_keys()
  local stored_keys_set = {}
  for _, key in ipairs(all_stored_keys_list) do stored_keys_set[key] = true end

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
  for _, stored_key_name in ipairs(all_stored_keys_list) do
    if not predefined_providers_set[stored_key_name] then
      table.insert(custom_keys_to_display, stored_key_name)
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
        require('llm.unified_manager').switch_view("Keys")
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
      require('llm.unified_manager').switch_view("Keys")
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
      require('llm.unified_manager').switch_view("Keys")
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
  require('llm.unified_manager').open_specific_manager("Keys")
end

M.__name = 'llm.keys.keys_manager'

return M
