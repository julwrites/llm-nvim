-- llm/managers/models_manager.lua - Model management functionality
-- License: Apache 2.0

local errors = require('llm.errors')
local M = {}

-- Forward declarations
local api = vim.api
local fn = vim.fn
local llm_cli = require('llm.core.data.llm_cli')
local cache = require('llm.core.data.cache')
local config = require('llm.config')
local styles = require('llm.ui.styles')
local commands = require('llm.commands')

local custom_openai = require('llm.managers.custom_openai')
local models_io = require('llm.managers.models_io')
local models_view = require('llm.ui.views.models_view')

function M.set_custom_openai(new_custom_openai)
    custom_openai = new_custom_openai
end

function M.set_models_io(new_models_io)
    models_io = new_models_io
end

-- Add pattern escape function to vim namespace if it doesn't exist
if not vim.pesc then
  vim.pesc = function(s)
    return string.gsub(s, "[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1")
  end
end

-- Get custom OpenAI models
function M.get_custom_openai_models()
  return custom_openai.custom_openai_models
end

-- Force reload custom OpenAI models
function M.reload_custom_openai_models()
  return custom_openai.load_custom_openai_models()
end

-- Get available providers with valid API keys
local function get_available_providers()
  local keys_manager = require('llm.managers.keys_manager')
  local plugins_manager = require('llm.managers.plugins_manager')

  return {
    -- OpenAI only requires the API key, not a plugin
    OpenAI = keys_manager.is_key_set("openai"),
    Anthropic = keys_manager.is_key_set("anthropic"),
    Mistral = keys_manager.is_key_set("mistral"),
    Gemini = keys_manager.is_key_set("gemini"),                 -- Corrected key name from "google" to "gemini"
    Groq = keys_manager.is_key_set("groq"),
    Ollama = plugins_manager.is_plugin_installed("llm-ollama"), -- Corrected plugin name from "ollama" to "llm-ollama"
    -- Local models are always available
    Local = true
  }
end

-- Check if a specific model is available (used when setting default)
function M.is_model_available(model_line)
  local providers = get_available_providers()
  local model_name = M.extract_model_name(model_line)

  if config.get("debug") then
    vim.notify("Checking if model is available: " .. model_line, vim.log.levels.DEBUG)
    vim.notify("Extracted model name: " .. model_name, vim.log.levels.DEBUG)
  end

  -- Check for custom OpenAI models (from extra-openai-models.yaml)
  if (model_line:match("OpenAI") and model_line:match("%(custom%)")) or
      model_line:match("^Custom OpenAI:") or
      model_line:match("^Azure OpenAI:") then
    if config.get("debug") then
      vim.notify("Checking custom model availability: " .. model_name, vim.log.levels.INFO)
    end
    -- For custom models, check validity using the dedicated function and the extracted name/id
    return custom_openai.is_custom_openai_model_valid(model_name)
  elseif model_line:match("OpenAI") then
    -- Check if this standard-looking OpenAI model is actually a custom one
    if custom_openai.is_custom_openai_model_valid(model_name) then
      if config.get("debug") then
        vim.notify("Identified standard OpenAI line as custom model: " .. model_name, vim.log.levels.INFO)
      end
      return true -- Validity is checked by is_custom_openai_model_valid
    end
    -- Regular OpenAI only requires the API key
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
    local cached_models = cache.get('models')
    if cached_models then
        return cached_models
    end

    local models_json = llm_cli.run_llm_command('models list')
    if not models_json then return {} end
    local models = {}
    for line in models_json:gmatch("[^\r\n]+") do
        if not line:match("^%-%-") and line ~= "" and not line:match("^Models:") and not line:match("^Default:") then
            local provider, model_id = line:match("([^:]+):%s*(.+)")
            if provider and model_id then
                table.insert(models, { provider = provider, id = model_id, name = model_id })
            else
                -- Handle lines without a provider
                table.insert(models, { provider = "Other", id = line, name = line })
            end
        end
    end
    cache.set('models', models)
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

  -- Handle custom OpenAI models specially
  if model_line:match("OpenAI") and model_line:match("%(custom%)") then
    local model_name = model_line:match(": ([^%(]+)")
    if model_name then
      -- Trim whitespace
      model_name = model_name:match("^%s*(.-)%s*$")
      return model_name
    end
  end

  -- Handle "Custom OpenAI:" format as well
  if model_line:match("^Custom OpenAI:") then
    local model_name = model_line:match("^Custom OpenAI:%s*(.+)")
    if model_name then
      -- Trim whitespace
      model_name = model_name:match("^%s*(.-)%s*$")
      return model_name
    end
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
    errors.handle(
      errors.categories.MODEL,
      "Model name cannot be empty",
      nil,
      errors.levels.ERROR
    )
    return false
  end

  local result = llm_cli.run_llm_command('default ' .. model_name)
  return result ~= nil
end

-- Get model aliases from llm CLI
function M.get_model_aliases()
    local cached_aliases = cache.get('aliases')
    if cached_aliases then
        return cached_aliases
    end

    local aliases_json = llm_cli.run_llm_command('aliases list --json')
    if not aliases_json then return {} end
    local aliases = vim.fn.json_decode(aliases_json)
    cache.set('aliases', aliases)
    return aliases
end

-- Set a model alias using llm CLI
function M.set_model_alias(alias, model)
  if not alias or alias == "" then
    errors.handle(
      errors.categories.MODEL,
      "Alias cannot be empty",
      nil,
      errors.levels.ERROR
    )
    return false
  end
  if not model or model == "" then
    errors.handle(
      errors.categories.MODEL,
      "Model cannot be empty",
      nil,
      errors.levels.ERROR
    )
    return false
  end

  local result = llm_cli.run_llm_command('alias set ' .. alias .. ' ' .. model)
  cache.invalidate('aliases')
  return result ~= nil
end

-- Remove a model alias by directly modifying the aliases.json file
function M.remove_model_alias(alias)
  if not alias or alias == "" then
    errors.handle(
      errors.categories.MODEL,
      "Alias cannot be empty",
      nil,
      errors.levels.ERROR
    )
    return false
  end

  local result = llm_cli.run_llm_command('alias remove ' .. alias)
  cache.invalidate('aliases')
  return result ~= nil
end

-- Select a model to use (now primarily for direct selection, not management)
function M.select_model()
  local models = M.get_available_models()

  if #models == 0 then
    api.nvim_err_writeln("No models found. Make sure llm is properly configured.")
    return
  end

  models_view.select_model(models, function(choice)
    if not choice then return end
    local model_name = M.extract_model_name(choice.id)
    config.options.model = model_name
    vim.notify("Model set to: " .. model_name, vim.log.levels.INFO)
  end)
end

-- Populate the buffer with model management content
-- Generate the list of models for the management buffer
function M.generate_models_list()
  local models = M.get_available_models()
  if #models == 0 then
    return {
      lines = {
        "# Model Management - No Models Found",
        "",
        "No models found. Make sure llm CLI is properly installed and configured.",
        "Use the [K]eys manager to set up API keys for your providers.",
        "Or use the [P]lugins manager to install required plugins.",
        "",
        "Press [q]uit or use navigation keys ([P]lugins, [K]eys, etc.)"
      },
      line_to_model_id = {},
      model_data = {}
    }
  end

  local aliases = M.get_model_aliases()
  local default_model_output = llm_cli.run_llm_command('default')
  local default_model = ""
  if default_model_output then
    default_model = default_model_output:match("Default model: (.+)")
  end

  local lines = {
    "# Model Management",
    "",
    "Navigate: [P]lugins [K]eys [F]ragments [T]emplates [S]chemas",
    "Actions: [s]et default [a]dd alias [r]emove alias [c]ustom model [q]uit", -- Updated actions
    "──────────────────────────────────────────────────────────────",
    ""
  }
  -- Create reverse lookup and group models
  local providers = {
    ["OpenAI"] = {},
    ["Custom OpenAI"] = {},
    ["Anthropic"] = {},
    ["Mistral"] = {},
    ["Gemini"] = {},
    ["Groq"] = {},
    ["Local Models"] = {},
    ["Other"] = {}
  }
  local processed_custom_model_ids = {} -- Set to track added custom model IDs

  -- Pre-load custom OpenAI models if not already loaded
  if vim.tbl_isempty(custom_openai.custom_openai_models) then
    custom_openai.load_custom_openai_models()
  end
  local model_to_aliases = {}
  for alias, model in pairs(aliases) do
    if not model_to_aliases[model] then model_to_aliases[model] = {} end
    table.insert(model_to_aliases[model], alias)
  end

  for _, model in ipairs(models) do
    local extracted_name = model.id -- This is the name/id part of the line
    local model_id = model.id                         -- Default model_id to extracted name
    local model_name = model.name                       -- Default model_name to extracted name
    local is_custom = false
    local custom_model_info = nil

    -- Determine provider and potentially find custom model info
    local provider_key = model.provider or "Other"
    if provider_key == "Custom OpenAI" then
      is_custom = true
      -- Find the corresponding custom model data using the extracted name/id
      -- Prioritize matching the extracted name directly to a model_id first
      if custom_openai.custom_openai_models[extracted_name] then
        custom_model_info = custom_openai.custom_openai_models[extracted_name]
        model_id = custom_model_info.model_id
        model_name = custom_model_info.model_name
      else
        -- Fallback: Iterate to find match by model_name if ID didn't match
        for id, info in pairs(custom_openai.custom_openai_models) do
          if info.model_name == extracted_name then
            custom_model_info = info
            model_id = info.model_id -- Use the correct model_id from the found info
            model_name = info.model_name
            break
          end
        end
      end
      -- If still no match, something is wrong, but proceed with extracted values
      if not custom_model_info then
        if config.get("debug") then
          vim.notify("Could not find custom model info for: " .. extracted_name, vim.log.levels.WARN)
        end
        -- Keep model_id and model_name as extracted_name
      end
    elseif provider_key == "OpenAI" then
      -- Check if this standard-looking line corresponds to a loaded custom model ID
      custom_model_info = custom_openai.custom_openai_models[extracted_name]
      if custom_model_info then
        provider_key = "Custom OpenAI"
        is_custom = true
        model_id = custom_model_info.model_id
        model_name = custom_model_info.model_name
        if config.get("debug") then
          vim.notify("Identified standard line as custom model: " .. model_name .. " (ID: " .. model_id .. ")",
            vim.log.levels.DEBUG)
        end
      end
    end

    -- Create the entry for this model
    local entry = {
      model_id = model_id,
      model_name = model_name,
      full_line = model.id, -- The original line from `llm models` or constructed for custom
      is_default = false,
      is_custom = is_custom,
      aliases = model_to_aliases[model_id] or {}, -- Check aliases ONLY by model_id
      provider = provider_key
    }

    -- Check if this model is the default ONLY by model_id
    if model_id == default_model then
      entry.is_default = true
    end

    -- Check for duplicates before adding to the provider list
    if is_custom then
      if processed_custom_model_ids[model_id] then
        if config.get("debug") then
          vim.notify("Skipping duplicate custom model entry for ID: " .. model_id, vim.log.levels.DEBUG)
        end
        goto next_model_line                        -- Skip adding this duplicate entry
      else
        processed_custom_model_ids[model_id] = true -- Mark this ID as processed
      end
    end

    if not providers[provider_key] then
        providers[provider_key] = {}
    end
    table.insert(providers[provider_key], entry)

    ::next_model_line::
  end

  local model_data = {}       -- Stores detailed info keyed by model_id
  local line_to_model_id = {} -- Maps buffer line number to model_id
  local current_line = #lines + 1
  -- Add content to buffer
  local provider_keys = {}
  for key, _ in pairs(providers) do
    table.insert(provider_keys, key)
  end
  table.sort(provider_keys)

  for _, provider in ipairs(provider_keys) do
    local provider_models = providers[provider]
    if #provider_models > 0 then
      table.insert(lines, provider)
      table.insert(lines, string.rep("─", #provider))
      current_line = current_line + 2
      -- Sort models within the provider group based on the display name (model_name)
      table.sort(provider_models, function(a, b) return a.model_name < b.model_name end)

      for _, model_entry in ipairs(provider_models) do
        local status = model_entry.is_default and "✓" or " "
        local alias_text = #model_entry.aliases > 0 and " (aliases: " .. table.concat(model_entry.aliases, ", ") .. ")" or
            ""
        -- Display model_name in the list
        local display_line_part = model_entry.full_line
        local provider_prefix = model_entry.provider .. ":"
        local line = string.format("[%s] %s %s%s", status, provider_prefix, display_line_part, alias_text)

        table.insert(lines, line)
        -- Store data keyed by model_id
        model_data[model_entry.model_id] = {
          line = current_line,
          is_default = model_entry.is_default,
          is_custom = model_entry.is_custom,
          full_line = model_entry.full_line,   -- Store original line for context if needed
          model_name = model_entry.model_name, -- Store model name
          aliases = model_entry.aliases
        }
        -- Map buffer line number to model_id
        line_to_model_id[current_line] = model_entry.model_id
        current_line = current_line + 1
      end
      table.insert(lines, "")
      current_line = current_line + 1
    end
  end
  table.insert(lines, "")

  return {
    lines = lines,
    line_to_model_id = line_to_model_id,
    model_data = model_data
  }
end

-- Populate the buffer with model management content
function M.populate_models_buffer(bufnr)
  local data = M.generate_models_list()

  api.nvim_buf_set_lines(bufnr, 0, -1, false, data.lines)
  styles.setup_buffer_syntax(bufnr) -- Use styles module

  -- Store lookup tables in buffer variables for keymaps
  vim.b[bufnr].line_to_model_id = data.line_to_model_id
  vim.b[bufnr].model_data = data.model_data

  return data.line_to_model_id, data.model_data -- Return for direct use if needed
end

-- Setup keymaps for the model management buffer
function M.setup_models_keymaps(bufnr, manager_module)
  manager_module = manager_module or M -- Allow passing self for testing/modularity

  local function set_keymap(mode, lhs, rhs)
    api.nvim_buf_set_keymap(bufnr, mode, lhs, rhs, { noremap = true, silent = true })
  end

  -- Set model under cursor as default
  set_keymap('n', 's',
    string.format([[<Cmd>lua require('%s').set_model_under_cursor(%d)<CR>]],
      manager_module.__name or 'llm.managers.models_manager', bufnr))

  -- Set alias for model under cursor
  set_keymap('n', 'a',
    string.format([[<Cmd>lua require('%s').set_alias_for_model_under_cursor(%d)<CR>]],
      manager_module.__name or 'llm.managers.models_manager', bufnr))

  -- Remove alias for model under cursor
  set_keymap('n', 'r',
    string.format([[<Cmd>lua require('%s').remove_alias_for_model_under_cursor(%d)<CR>]],
      manager_module.__name or 'llm.managers.models_manager', bufnr))

  set_keymap('n', 'c', -- New keymap for adding custom OpenAI model
    string.format([[<Cmd>lua require('%s').add_custom_openai_model_interactive(%d)<CR>]],
      manager_module.__name or 'llm.managers.models_manager', bufnr))
end

-- Action functions called by keymaps (now accept bufnr)

-- Function to add a new custom OpenAI model via interactive input
function M.add_custom_openai_model_interactive(bufnr)
  models_view.get_custom_model_details(function(details)
    local success, err_msg = custom_openai.add_custom_openai_model(details)
    if success then
      custom_openai.load_custom_openai_models() -- Reload models
      vim.notify("Custom OpenAI model '" .. (details.model_name or details.model_id) .. "' added successfully.",
        vim.log.levels.INFO)
      require('llm.ui.unified_manager').switch_view("Models")
    else
      vim.notify("Failed to add custom OpenAI model: " .. (err_msg or "Unknown error"), vim.log.levels.ERROR)
    end
    vim.cmd('stopinsert') -- Ensure normal mode
  end)
end

-- Sets the model under the cursor as the default LLM model.
function M.set_default_model_logic(model_id, model_info)
  if not model_id or not model_info then
    return { success = false, message = "No model info found" }
  end

  local display_name = model_info.model_name or model_id

  if model_info.is_default then
    return { success = false, message = "Model '" .. display_name .. "' is already the default" }
  end

  local check_identifier = model_info.is_custom and model_id or model_info.full_line
  if not M.is_model_available(check_identifier) then
    local provider = "unknown"
    if model_info.is_custom then
      provider = "Custom OpenAI/Azure"
    elseif model_info.full_line:match("OpenAI") then
      provider = "OpenAI"
    elseif model_info.full_line:match("Anthropic") then
      provider = "Anthropic"
    elseif model_info.full_line:match("Mistral") then
      provider = "Mistral"
    elseif model_info.full_line:match("Gemini") then
      provider = "Gemini"
    elseif model_info.full_line:match("Groq") then
      provider = "Groq"
    elseif model_info.full_line:match("ollama") then
      provider = "Ollama"
    end
    return { success = false, message = "Cannot set as default: " .. provider .. " requirements not met (API key/plugin/config)" }
  end

  if M.set_default_model(model_id) then
    config.options.model = model_id
    return { success = true, message = "Default model set to: " .. display_name }
  else
    return { success = false, message = "Failed to set default model via llm CLI" }
  end
end

-- Sets the model under the cursor as the default LLM model.
function M.set_model_under_cursor(bufnr)
  local ui = require('llm.core.utils.ui')
  local model_id, model_info = M.get_model_info_under_cursor(bufnr)
  local result = M.set_default_model_logic(model_id, model_info)

  if result.success then
    ui.notify(result.message, vim.log.levels.INFO)
    require('llm.ui.unified_manager').switch_view("Models") -- Refresh view
  else
    ui.notify(result.message, vim.log.levels.ERROR)
  end
end

-- Sets an alias for the model under the cursor.
function M.set_alias_for_model_under_cursor(bufnr)
  local model_id, model_info = M.get_model_info_under_cursor(bufnr)
  if not model_id or not model_info then return end

  local display_name = model_info.model_name or model_id

  models_view.get_alias(display_name, function(alias)
    if not alias or alias == "" then
      vim.notify("Alias cannot be empty", vim.log.levels.WARN)
      return
    end

    if M.set_model_alias(alias, model_id) then
      vim.notify("Alias set: " .. alias .. " -> " .. display_name .. " (ID: " .. model_id .. ")", vim.log.levels.INFO)
      vim.cmd('stopinsert')
      require('llm.ui.unified_manager').switch_view("Models")
    else
      vim.notify("Failed to set alias via llm CLI", vim.log.levels.ERROR)
      vim.cmd('stopinsert')
    end
  end)
end

-- Removes an alias associated with the model under the cursor.
function M.remove_alias_for_model_under_cursor(bufnr)
  local model_id, model_info = M.get_model_info_under_cursor(bufnr)
  if not model_id or not model_info then return end -- Exit if no model info

  local display_name = model_info.model_name or model_id

  if not model_info.aliases or #model_info.aliases == 0 then
    vim.notify("No aliases found for model '" .. display_name .. "'", vim.log.levels.WARN)
    return
  end

  models_view.select_alias_to_remove(model_info.aliases, function(alias)
      if not alias then return end
      models_view.confirm_remove_alias(alias, function()
        if M.remove_model_alias(alias) then
            vim.notify("Alias removed: " .. alias, vim.log.levels.INFO)
            require('llm.ui.unified_manager').switch_view("Models")
        else
            vim.notify("Failed to remove alias '" .. alias .. "'", vim.log.levels.ERROR)
        end
      end)
    end
  )
end

-- Helper to get model info (ID and data) from buffer variables (Duplicate of local function, keep for external calls if needed)
function M.get_model_info_under_cursor(bufnr)
  local current_line = api.nvim_win_get_cursor(0)[1]
  local line_to_model_id = vim.b[bufnr].line_to_model_id
  local model_data = vim.b[bufnr].model_data

  if not line_to_model_id or not model_data then
    if config.get("debug") then
      vim.notify(string.format("Buffer data missing for bufnr %d (line_to_model_id: %s, model_data: %s)",
        bufnr, tostring(line_to_model_id), tostring(model_data)), vim.log.levels.DEBUG)
    end
    return nil, nil -- Return nil for both model_id and model_info
  end

  local model_id = line_to_model_id[current_line]
  if model_id and model_data[model_id] then
    -- Return model_id and the corresponding data table
    return model_id, model_data[model_id]
  end

  -- Add debug log if no model info is found for the line
  if config.get("debug") then
    local line_content = api.nvim_buf_get_lines(bufnr, current_line - 1, current_line, false)[1]
    vim.notify(string.format("No model info found for line %d (content: '%s', mapped_id: %s) in bufnr %d",
      current_line, line_content or "nil", tostring(model_id), bufnr), vim.log.levels.DEBUG)
  end

  return nil, nil -- Return nil for both model_id and model_info
end

-- Main function to open the model manager (now delegates to unified manager)
function M.manage_models()
  require('llm.ui.unified_manager').open_specific_manager("Models")
end

-- Get custom OpenAI models
function M.get_custom_openai_models()
  if vim.tbl_isempty(custom_openai.custom_openai_models) then
    custom_openai.load_custom_openai_models()
  end
  return custom_openai.custom_openai_models
end

-- Force reload custom OpenAI models
function M.reload_custom_openai_models()
  -- Clear the cache and reload
  custom_openai.custom_openai_models = {}
  custom_openai.load_custom_openai_models()
  return custom_openai.custom_openai_models
end

-- Debug function for custom models (delegates to custom_openai module)
function M.debug_custom_openai_models()
  return custom_openai.debug_custom_openai_models()
end

-- Create sample YAML file (delegates to custom_openai module)
function M.create_sample_yaml_file()
  return custom_openai.create_sample_yaml_file()
end

-- Add module name for require path in keymaps
M.__name = 'llm.managers.models_manager'

return M
