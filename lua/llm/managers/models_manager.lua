-- llm/managers/models_manager.lua - Model management functionality
-- License: Apache 2.0

local M = {}

-- Forward declarations
local api = vim.api
local fn = vim.fn
local utils = require('llm.utils')
local config = require('llm.config')
local styles = require('llm.styles') -- Added for highlighting

-- Get available providers with valid API keys
local function get_available_providers()
  local keys_manager = require('llm.managers.keys_manager')
  local plugins_manager = require('llm.managers.plugins_manager')

  return {
    OpenAI = keys_manager.is_key_set("openai"),
    Anthropic = keys_manager.is_key_set("anthropic"),
    Mistral = keys_manager.is_key_set("mistral"),
    Gemini = keys_manager.is_key_set("gemini"), -- Corrected key name from "google" to "gemini"
    Groq = keys_manager.is_key_set("groq"),
    Ollama = plugins_manager.is_plugin_installed("llm-ollama"), -- Corrected plugin name from "ollama" to "llm-ollama"
    -- Local models are always available
    Local = true
  }
end

-- Check if a specific model is available (used when setting default)
function M.is_model_available(model_line)
  local providers = get_available_providers()

  if model_line:match("OpenAI") then
    return providers.OpenAI
  elseif model_line:match("Anthropic") then
    return providers.Anthropic
  elseif model_line:match("Mistral") then
    return providers.Mistral
  elseif model_line:match("Gemini") then
    return providers.Gemini
  elseif model_line:match("Groq") then
    return providers.Groq
  elseif model_line:match("ollama") then
    return providers.Ollama
  elseif model_line:match("gguf") or model_line:match("local") then
    return providers.Local
  end

  -- Default to true if we can't determine requirements
  return true
end

-- Get available models from llm CLI
function M.get_available_models()
  if not utils.check_llm_installed() then
    return {}
  end

  local result = utils.safe_shell_command("llm models", "Failed to get available models")
  if not result then
    return {}
  end

  local models = {}
  for line in result:gmatch("[^\r\n]+") do
    -- Skip header lines and empty lines
    if not line:match("^%-%-") and line ~= "" and not line:match("^Models:") and not line:match("^Default:") then
      -- Use the whole line for display
      table.insert(models, line)
    end
  end

  return models
end

-- Extract model name from the full model line
function M.extract_model_name(model_line)
  if not model_line or model_line == "" then
    if config.get("debug") then
      vim.notify("extract_model_name called with empty model_line", vim.log.levels.DEBUG)
    end
    return ""
  end

  -- Extract the actual model name (after the provider type)
  local model_name = model_line:match(": ([^%(]+)")
  if model_name then
    -- Trim whitespace
    model_name = model_name:match("^%s*(.-)%s*$")
    return model_name
  end

  -- Try to match format like "Anthropic Messages: anthropic/claude-3-opus-20240229"
  model_name = model_line:match(": ([^%s]+)")
  if model_name then
    return model_name
  end

  -- Fallback to the full line if no patterns match
  -- This ensures we can still find the model in the list
  return model_line
end

-- Set the default model using llm CLI
function M.set_default_model(model_name)
  if not model_name or model_name == "" then
    vim.notify("Model name cannot be empty", vim.log.levels.ERROR)
    return false
  end

  if not utils.check_llm_installed() then
    return false
  end

  local result = utils.safe_shell_command(
    string.format('llm models default %s', model_name),
    "Failed to set default model"
  )

  return result ~= nil
end

-- Get model aliases from llm CLI
function M.get_model_aliases()
  if not utils.check_llm_installed() then
    return {}
  end

  local result = utils.safe_shell_command("llm aliases --json", "Failed to get model aliases")
  if not result then
    return {}
  end

  local aliases = {}

  -- Try to parse JSON output
  local success, parsed = pcall(vim.fn.json_decode, result)
  if success and type(parsed) == "table" then
    aliases = parsed
  else
    -- Fallback to line parsing if JSON parsing fails
    for line in result:gmatch("[^\r\n]+") do
      if not line:match("^%-%-") and not line:match("^Aliases:") then
        local alias, model = line:match("([^%s:]+)%s*:%s*(.+)")
        if alias and model then
          -- Remove any trailing "(embedding)" text
          model = model:gsub("%s*%(embedding%)", "")
          -- Trim whitespace
          model = model:match("^%s*(.-)%s*$")
          aliases[alias] = model
        end
      end
    end
  end

  return aliases
end

-- Set a model alias using llm CLI
function M.set_model_alias(alias, model)
  if not alias or alias == "" then
    vim.notify("Alias cannot be empty", vim.log.levels.ERROR)
    return false
  end
  if not model or model == "" then
    vim.notify("Model cannot be empty", vim.log.levels.ERROR)
    return false
  end

  if not utils.check_llm_installed() then
    return false
  end

  local result = utils.safe_shell_command(
    string.format('llm aliases set %s %s', alias, model),
    "Failed to set model alias"
  )

  return result ~= nil
end

-- Remove a model alias by directly modifying the aliases.json file
function M.remove_model_alias(alias)
  if not alias or alias == "" then
    vim.notify("Alias cannot be empty", vim.log.levels.ERROR)
    return false
  end

  if not utils.check_llm_installed() then
    return false
  end

  -- Try CLI command first with better error handling
  local escaped_alias = alias:gsub("'", "'\\''")
  local cmd = string.format("llm aliases remove '%s'", escaped_alias)

  local result = utils.safe_shell_command(cmd, nil)

  if result then
    return true
  end

  -- If CLI command fails, modify the aliases.json file directly
  local aliases_dir, aliases_file = utils.get_config_path("aliases.json")

  -- If aliases file doesn't exist, nothing to remove
  if not aliases_file then
    vim.notify("Could not find aliases.json file", vim.log.levels.ERROR)
    return false
  end

  -- Read existing aliases
  local aliases_data = {}
  local file = io.open(aliases_file, "r")

  if file then
    local content = file:read("*a")
    file:close()

    -- Parse JSON if file exists and has content
    if content and content ~= "" then
      local success, result
      success, result = pcall(vim.fn.json_decode, content)
      if success and type(result) == "table" then
        aliases_data = result
      else
        vim.notify("Failed to parse aliases JSON: " .. (result or "unknown error"), vim.log.levels.ERROR)
        aliases_data = {} -- Reset to empty table if parsing failed
      end
    end
  else
    vim.notify("Failed to open aliases file for reading", vim.log.levels.ERROR)
    return false
  end

  -- Check if the alias exists
  if aliases_data[alias] == nil then
    vim.notify("Alias '" .. alias .. "' not found in aliases file", vim.log.levels.WARN)
    return false
  end

  -- Remove the alias
  aliases_data[alias] = nil

  -- Write the updated aliases back to the file
  local updated_content = vim.fn.json_encode(aliases_data)
  file = io.open(aliases_file, "w")
  if not file then
    vim.notify("Failed to open aliases file for writing: " .. aliases_file, vim.log.levels.ERROR)
    return false
  end

  file:write(updated_content)
  file:close()

  vim.notify("Successfully removed alias: " .. alias, vim.log.levels.INFO)
  return true
end

-- Select a model to use (now primarily for direct selection, not management)
function M.select_model()
  local models = M.get_available_models()

  if #models == 0 then
    api.nvim_err_writeln("No models found. Make sure llm is properly configured.")
    return
  end

  vim.ui.select(models, {
    prompt = "Select LLM model:",
    format_item = function(item)
      return item
    end
  }, function(choice)
    if not choice then return end

    -- Extract model name from the full model line
    local model_name = M.extract_model_name(choice)

    -- Set the model in config
    config.options.model = model_name

    vim.notify("Model set to: " .. model_name, vim.log.levels.INFO)
  end)
end

-- Populate the buffer with model management content
function M.populate_models_buffer(bufnr)
  local models = M.get_available_models()
  if #models == 0 then
    api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      "# Model Management - No Models Found",
      "",
      "No models found. Make sure llm CLI is properly installed and configured.",
      "Use the [K]eys manager to set up API keys for your providers.",
      "Or use the [P]lugins manager to install required plugins.",
      "",
      "Press [q]uit or use navigation keys ([P]lugins, [K]eys, etc.)"
    })
    return {}, {} -- Return empty lookup tables
  end

  local aliases = M.get_model_aliases()
  local default_model_output = utils.safe_shell_command("llm models default", "Failed to get default model")
  local default_model = ""
  if default_model_output then
    default_model = default_model_output:match("Default model: ([^\r\n]+)") or default_model_output:match("([^\r\n]+)") or ""
  end

  local lines = {
    "# Model Management",
    "",
    "Navigate: [P]lugins [K]eys [F]ragments [T]emplates [S]chemas",
    "Actions: [s]et default [a]dd alias [r]emove alias [c]hat [q]uit",
    "──────────────────────────────────────────────────────────────",
    ""
  }
  -- Create reverse lookup and group models
  local providers = {
    ["OpenAI"] = {},
    ["Anthropic"] = {},
    ["Mistral"] = {},
    ["Gemini"] = {},
    ["Groq"] = {},
    ["Local Models"] = {},
    ["Other"] = {}
  }
  local model_to_aliases = {}
  for alias, model in pairs(aliases) do
    if not model_to_aliases[model] then model_to_aliases[model] = {} end
    table.insert(model_to_aliases[model], alias)
  end

  for _, model_line in ipairs(models) do
    local entry = {
      full_line = model_line,
      model_name = M.extract_model_name(model_line),
      is_default = false,
      aliases = model_to_aliases[M.extract_model_name(model_line)] or {}
    }
    if entry.model_name == default_model then entry.is_default = true end

    local provider_key = "Other"
    if model_line:match("OpenAI") then provider_key = "OpenAI"
    elseif model_line:match("Anthropic") then provider_key = "Anthropic"
    elseif model_line:match("Mistral") then provider_key = "Mistral"
    elseif model_line:match("Gemini") then provider_key = "Gemini"
    elseif model_line:match("Groq") then provider_key = "Groq"
    elseif model_line:match("gguf") or model_line:match("ollama") or model_line:match("local") then provider_key = "Local Models"
    end
    table.insert(providers[provider_key], entry)
  end

  local model_data = {}
  local line_to_model = {}
  local current_line = #lines + 1
  -- Flexible default model matching
  local default_found = false
  for _, provider_models in pairs(providers) do
    for _, model in ipairs(provider_models) do
      if model.is_default then default_found = true; break end
    end
    if default_found then break end
  end
  if not default_found and default_model ~= "" then
    for _, provider_models in pairs(providers) do
      for _, model in ipairs(provider_models) do
        if model.model_name:find(default_model, 1, true) or default_model:find(model.model_name, 1, true) then
          model.is_default = true; default_found = true; break
        end
      end
      if default_found then break end
    end
  end
  -- Add content to buffer
  for provider, provider_models in pairs(providers) do
    if #provider_models > 0 then
      table.insert(lines, provider)
      table.insert(lines, string.rep("─", #provider))
      current_line = current_line + 2
      table.sort(provider_models, function(a, b) return a.full_line < b.full_line end)
      for _, model in ipairs(provider_models) do
        local status = model.is_default and "✓" or " "
        local alias_text = #model.aliases > 0 and " (aliases: " .. table.concat(model.aliases, ", ") .. ")" or ""
        local line = string.format("[%s] %s%s", status, model.full_line, alias_text)
        table.insert(lines, line)
        model_data[model.model_name] = { line = current_line, is_default = model.is_default, full_line = model.full_line, aliases = model.aliases }
        line_to_model[current_line] = model.model_name
        current_line = current_line + 1
      end
      table.insert(lines, "")
      current_line = current_line + 1
    end
  end
  table.insert(lines, "")
  table.insert(lines, "[+] Add custom alias")
  api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- Apply syntax highlighting
  styles.setup_buffer_syntax(bufnr) -- Use styles module

  -- Store lookup tables in buffer variables for keymaps
  vim.b[bufnr].line_to_model = line_to_model
  vim.b[bufnr].model_data = model_data

  return line_to_model, model_data -- Return for direct use if needed
end

-- Setup keymaps for the model management buffer
function M.setup_models_keymaps(bufnr, manager_module)
  manager_module = manager_module or M -- Allow passing self for testing/modularity

  local function set_keymap(mode, lhs, rhs)
    api.nvim_buf_set_keymap(bufnr, mode, lhs, rhs, { noremap = true, silent = true })
  end

  -- Helper function to get model info from current line
  local function get_model_info_under_cursor()
    local current_line = api.nvim_win_get_cursor(0)[1]
    local line_to_model = vim.b[bufnr].line_to_model
    local model_data = vim.b[bufnr].model_data

    if not line_to_model or not model_data then
      if config.get("debug") then
        vim.notify(string.format("Buffer data missing for bufnr %d", bufnr), vim.log.levels.DEBUG)
      end
      return nil, nil
    end

    local model_name = line_to_model[current_line]
    if model_name and model_data[model_name] then
      return model_name, model_data[model_name]
    end

    -- Add debug log if no model info is found for the line
    if config.get("debug") then
      local line_content = api.nvim_buf_get_lines(bufnr, current_line - 1, current_line, false)[1]
      vim.notify(string.format("No model info found for line %d (content: '%s') in bufnr %d",
                               current_line, line_content or "nil", bufnr), vim.log.levels.DEBUG)
    end

    return nil, nil
  end

  -- Set model under cursor as default
  set_keymap('n', 's', string.format([[<Cmd>lua require('%s').set_model_under_cursor(%d)<CR>]], manager_module.__name or 'llm.managers.models_manager', bufnr))

  -- Set alias for model under cursor
  set_keymap('n', 'a', string.format([[<Cmd>lua require('%s').set_alias_for_model_under_cursor(%d)<CR>]], manager_module.__name or 'llm.managers.models_manager', bufnr))

  -- Remove alias for model under cursor
  set_keymap('n', 'r', string.format([[<Cmd>lua require('%s').remove_alias_for_model_under_cursor(%d)<CR>]], manager_module.__name or 'llm.managers.models_manager', bufnr))

  -- Chat with model under cursor
  set_keymap('n', 'c', string.format([[<Cmd>lua require('%s').chat_with_model_under_cursor(%d)<CR>]], manager_module.__name or 'llm.managers.models_manager', bufnr))

  -- Add custom alias (when on the [+] line)
  set_keymap('n', '<CR>', string.format([[<Cmd>lua require('%s').handle_action_under_cursor(%d)<CR>]], manager_module.__name or 'llm.managers.models_manager', bufnr))
end

-- Action functions called by keymaps (now accept bufnr)
function M.set_model_under_cursor(bufnr)
  local model_name, model_info = M.get_model_info_under_cursor(bufnr)
  if not model_name then return end
  if model_info.is_default then
    vim.notify("Model " .. model_name .. " is already the default", vim.log.levels.INFO)
    return
  end

  -- Check if the model is available before setting it as default
  if not M.is_model_available(model_info.full_line) then
    local provider = "unknown"
    if model_info.full_line:match("OpenAI") then provider = "OpenAI"
    elseif model_info.full_line:match("Anthropic") then provider = "Anthropic"
    elseif model_info.full_line:match("Mistral") then provider = "Mistral"
    elseif model_info.full_line:match("Gemini") then provider = "Gemini"
    elseif model_info.full_line:match("Groq") then provider = "Groq"
    elseif model_info.full_line:match("ollama") then provider = "Ollama"
    end

    vim.notify("Cannot set as default: " .. provider .. " API key or plugin not configured", vim.log.levels.ERROR)
    return
  end

  vim.notify("Setting default model to: " .. model_name, vim.log.levels.INFO)
  if M.set_default_model(model_name) then
    config.options.model = model_name
    vim.notify("Default model set to: " .. model_name, vim.log.levels.INFO)
    -- Refresh the current view in the unified manager
    require('llm.managers.unified_manager').switch_view("Models")
  else
    vim.notify("Failed to set default model", vim.log.levels.ERROR)
  end
end

function M.set_alias_for_model_under_cursor(bufnr)
  local model_name, _ = M.get_model_info_under_cursor(bufnr)
  if not model_name then return end
  utils.floating_input({ prompt = "Enter alias for model " .. model_name .. ": " }, function(alias)
    if not alias or alias == "" then
      vim.notify("Alias cannot be empty", vim.log.levels.WARN)
      return
    end
    if M.set_model_alias(alias, model_name) then
      vim.cmd('echo ""')
      vim.defer_fn(function()
        vim.notify("Alias set: " .. alias .. " -> " .. model_name, vim.log.levels.INFO)
        require('llm.managers.unified_manager').switch_view("Models")
      end, 100)
    else
      vim.notify("Failed to set alias", vim.log.levels.ERROR)
    end
  end)
end

function M.chat_with_model_under_cursor(bufnr)
  local model_name, model_info = M.get_model_info_under_cursor(bufnr)
  if not model_name then return end

  -- Check if the model is available before starting chat
  if not M.is_model_available(model_info.full_line) then
    local provider = "unknown"
    if model_info.full_line:match("OpenAI") then provider = "OpenAI"
    elseif model_info.full_line:match("Anthropic") then provider = "Anthropic"
    elseif model_info.full_line:match("Mistral") then provider = "Mistral"
    elseif model_info.full_line:match("Gemini") then provider = "Gemini"
    elseif model_info.full_line:match("Groq") then provider = "Groq"
    elseif model_info.full_line:match("ollama") then provider = "Ollama"
    end

    vim.notify("Cannot chat with model: " .. provider .. " API key or plugin not configured", vim.log.levels.ERROR)
    return
  end

  require('llm.managers.unified_manager').close() -- Close manager before starting chat
  vim.schedule(function()
    require('llm.commands').start_chat(model_name)
  end)
end

function M.handle_action_under_cursor(bufnr)
  local current_line = api.nvim_win_get_cursor(0)[1]
  local line_content = api.nvim_buf_get_lines(bufnr, current_line - 1, current_line, false)[1]
  if line_content and line_content:match("%[+%].*Add custom alias") then
    vim.ui.input({ prompt = "Enter alias name: " }, function(alias)
      if not alias or alias == "" then
        vim.notify("Alias name cannot be empty", vim.log.levels.WARN)
        return
      end
      vim.ui.input({ prompt = "Enter model name: " }, function(model)
        if not model or model == "" then
          vim.notify("Model name cannot be empty", vim.log.levels.WARN)
          return
        end
        if M.set_model_alias(alias, model) then
          vim.cmd('echo ""')
          vim.defer_fn(function()
            vim.notify("Alias set: " .. alias .. " -> " .. model, vim.log.levels.INFO)
            require('llm.managers.unified_manager').switch_view("Models")
          end, 100)
        else
          vim.notify("Failed to set alias", vim.log.levels.ERROR)
        end
      end)
    end)
  end
end

function M.remove_alias_for_model_under_cursor(bufnr)
  local model_name, model_info = M.get_model_info_under_cursor(bufnr)
  if not model_name then return end
  if not model_info or #model_info.aliases == 0 then
    vim.notify("No aliases found for this model", vim.log.levels.WARN)
    return
  end
  vim.ui.select(model_info.aliases, { prompt = "Select alias to remove:" }, function(alias)
    if not alias then return end
    local _, aliases_file = utils.get_config_path("aliases.json")
    local is_system_alias = false
    if aliases_file then
      local file = io.open(aliases_file, "r")
      if file then
        local content = file:read("*a"); file:close()
        local success, aliases_data = pcall(vim.fn.json_decode, content)
        if success and type(aliases_data) == "table" and aliases_data[alias] == nil then
          is_system_alias = true
        end
      end
    end
    if is_system_alias then
      vim.notify("Cannot remove system alias '" .. alias .. "'.", vim.log.levels.ERROR)
      return
    end
    local confirm = vim.fn.confirm("Remove alias '" .. alias .. "'?", "&Yes\n&No", 2)
    if confirm ~= 1 then return end
    if M.remove_model_alias(alias) then
      vim.notify("Alias removed: " .. alias, vim.log.levels.INFO)
      require('llm.managers.unified_manager').switch_view("Models")
    else
      vim.notify("Failed to remove alias '" .. alias .. "'", vim.log.levels.ERROR)
    end
  end)
end

-- Helper to get model info from buffer variables
function M.get_model_info_under_cursor(bufnr)
  local current_line = api.nvim_win_get_cursor(0)[1]
  local line_to_model = vim.b[bufnr].line_to_model
  local model_data = vim.b[bufnr].model_data

  if not line_to_model or not model_data then
    if config.get("debug") then
      vim.notify(string.format("Buffer data missing for bufnr %d", bufnr), vim.log.levels.DEBUG)
    end
    return nil, nil
  end

  local model_name = line_to_model[current_line]
  if model_name and model_data[model_name] then
    return model_name, model_data[model_name]
  end

  -- Add debug log if no model info is found for the line
  if config.get("debug") then
    local line_content = api.nvim_buf_get_lines(bufnr, current_line - 1, current_line, false)[1]
    vim.notify(string.format("No model info found for line %d (content: '%s') in bufnr %d",
                             current_line, line_content or "nil", bufnr), vim.log.levels.DEBUG)
  end

  return nil, nil
end

-- Main function to open the model manager (now delegates to unified manager)
function M.manage_models()
  require('llm.managers.unified_manager').open_specific_manager("Models")
end

-- Add module name for require path in keymaps
M.__name = 'llm.managers.models_manager'

return M
