-- llm/models/models_manager.lua - Model management functionality
-- License: Apache 2.0

local errors = require('llm.errors')
local M = {}

-- Forward declarations
local api = vim.api
local fn = vim.fn
local utils = require('llm.utils')
local config = require('llm.config')
local styles = require('llm.styles') -- Added for highlighting
local commands = require('llm.commands')

local custom_openai = require('llm.models.custom_openai')

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
  local keys_manager = require('llm.keys.keys_manager')
  local plugins_manager = require('llm.plugins.plugins_manager')

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
  if not utils.check_llm_installed() then
    return {}
  end

  -- Load custom OpenAI models first
  custom_openai.load_custom_openai_models()

  local result, err = utils.safe_shell_command("llm models")
  if err then
    errors.handle(
      errors.categories.MODEL,
      "Failed to get available models",
      { error = err },
      errors.levels.ERROR
    )
    return {}
  end

  local models = {}
  local standard_openai_models = {}

  -- First pass: collect all models and identify standard OpenAI models
  for line in result:gmatch("[^\r\n]+") do
    -- Skip header lines and empty lines
    if not line:match("^%-%-") and line ~= "" and not line:match("^Models:") and not line:match("^Default:") then
      -- Check if this is a standard OpenAI model
      if line:match("^OpenAI:") then
        table.insert(standard_openai_models, line)
      else
        -- Non-OpenAI model, add it directly
        table.insert(models, line)
      end
    end
  end

  -- Ensure custom models are loaded
  if vim.tbl_isempty(custom_openai.custom_openai_models) then
    custom_openai.load_custom_openai_models()
  end

  if config.get("debug") then
    vim.notify(
      "Adding " .. vim.tbl_count(custom_openai.custom_openai_models) .. " custom OpenAI models to available models list",
      vim.log.levels.INFO)
  end

  -- Create a set of model IDs and names to filter out duplicates
  local custom_model_ids = {}

  -- Add all custom OpenAI models to the list
  for model_id, model_info in pairs(custom_openai.custom_openai_models) do
    -- Use model_id for duplicate detection
    custom_model_ids[model_id:lower()] = true

    -- Use model_name for display if available, otherwise model_id
    local display_name = model_info.model_name or model_id
    local provider_prefix = "Custom OpenAI: "
    -- Construct the line using the display name
    local model_line = provider_prefix .. display_name
    table.insert(models, model_line)

    if config.get("debug") then
      vim.notify("Added custom OpenAI model to list: " .. model_line .. " (ID: " .. model_id .. ")", vim.log.levels.INFO)
    end
  end

  -- Add standard OpenAI models that don't conflict (by model_id) with custom ones
  for _, line in ipairs(standard_openai_models) do
    local extracted_name = M.extract_model_name(line)
    -- Check against the set of custom model IDs
    if extracted_name and not custom_model_ids[extracted_name:lower()] then
      table.insert(models, line)
    elseif config.get("debug") and extracted_name then
      vim.notify("Skipping standard OpenAI model due to conflict with custom ID: " .. extracted_name,
        vim.log.levels.DEBUG)
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

  if not utils.check_llm_installed() then
    return false
  end

  local result, err = utils.safe_shell_command(
    string.format('llm models default %s', model_name)
  )

  if err then
    errors.handle(
      errors.categories.MODEL,
      "Failed to set default model",
      { model = model_name, error = err },
      errors.levels.ERROR
    )
  end

  return result ~= nil
end

-- Get model aliases from llm CLI
function M.get_model_aliases()
  if not utils.check_llm_installed() then
    return {}
  end

  local result, err = utils.safe_shell_command("llm aliases --json")
  if err then
    errors.handle(
      errors.categories.MODEL,
      "Failed to get model aliases",
      { error = err },
      errors.levels.ERROR
    )
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

  if not utils.check_llm_installed() then
    return false
  end

  local result, err = utils.safe_shell_command(
    string.format('llm aliases set %s %s', alias, model)
  )

  if err then
    errors.handle(
      errors.categories.MODEL,
      "Failed to set model alias",
      { alias = alias, model = model, error = err },
      errors.levels.ERROR
    )
  end

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

  if not utils.check_llm_installed() then
    return false
  end

  -- Try CLI command first with better error handling
  local escaped_alias = string.format("'%s'", alias:gsub("'", "'\\''"))
  local cmd = string.format("llm aliases remove %s", escaped_alias)

  local _, err = utils.safe_shell_command(cmd)

  if not err then
    vim.notify("Successfully removed alias: " .. alias, vim.log.levels.INFO)
    return true
  else
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
    default_model = default_model_output:match("Default model: ([^\r\n]+)") or default_model_output:match("([^\r\n]+)") or
        ""
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

  for _, model_line in ipairs(models) do
    local extracted_name = M.extract_model_name(model_line) -- This is the name/id part of the line
    local model_id = extracted_name                         -- Default model_id to extracted name
    local model_name = extracted_name                       -- Default model_name to extracted name
    local is_custom = false
    local custom_model_info = nil

    -- Determine provider and potentially find custom model info
    local provider_key = "Other"
    if model_line:match("^Custom OpenAI:") then
      provider_key = "Custom OpenAI"
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
    elseif model_line:match("OpenAI") then
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
      else
        provider_key = "OpenAI"
      end
    elseif model_line:match("Anthropic") then
      provider_key = "Anthropic"
    elseif model_line:match("Mistral") then
      provider_key = "Mistral"
    elseif model_line:match("Gemini") then
      provider_key = "Gemini"
    elseif model_line:match("Groq") then
      provider_key = "Groq"
    elseif model_line:match("gguf") or model_line:match("ollama") or model_line:match("local") then
      provider_key = "Local Models"
    end

    -- Create the entry for this model
    local entry = {
      model_id = model_id,
      model_name = model_name,
      full_line = model_line, -- The original line from `llm models` or constructed for custom
      is_default = false,
      is_custom = is_custom,
      aliases = model_to_aliases[model_id] or {} -- Check aliases ONLY by model_id
    }

    -- Check if this model is the default ONLY by model_id
    if model_id == default_model then
      entry.is_default = true
      default_found = true
      default_model_id = model_id -- Store the ID of the default model
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

    table.insert(providers[provider_key], entry)

    ::next_model_line::
  end

  local model_data = {}       -- Stores detailed info keyed by model_id
  local line_to_model_id = {} -- Maps buffer line number to model_id
  local current_line = #lines + 1
  -- Flexible default model matching (if exact match wasn't found)
  if not default_found and default_model ~= "" then
    for _, provider_models in pairs(providers) do
      for _, model_entry in ipairs(provider_models) do
        -- Check if default_model is a substring of model_id, or vice-versa (ONLY check model_id)
        if model_entry.model_id:find(default_model, 1, true) or default_model:find(model_entry.model_id, 1, true) then
          model_entry.is_default = true
          default_found = true
          default_model_id = model_entry.model_id -- Store the ID
          break
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
      -- Sort models within the provider group based on the display name (model_name)
      table.sort(provider_models, function(a, b) return a.model_name < b.model_name end)

      for _, model_entry in ipairs(provider_models) do
        local status = model_entry.is_default and "✓" or " "
        local alias_text = #model_entry.aliases > 0 and " (aliases: " .. table.concat(model_entry.aliases, ", ") .. ")" or
            ""
        -- Display model_name in the list
        local display_line_part = model_entry.full_line:match(":(.*)") or
            model_entry
            .model_name                                             -- Extract name part or use model_name
        display_line_part = display_line_part:match("^%s*(.-)%s*$") -- Trim whitespace
        local provider_prefix = model_entry.full_line:match("^[^:]+:") or
            ""                                                      -- Extract provider prefix
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
  -- REMOVED: table.insert(lines, "[+] Add custom OpenAI model")
  -- REMOVED: table.insert(lines, "[+] Add custom alias")
  api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- Apply syntax highlighting
  styles.setup_buffer_syntax(bufnr) -- Use styles module

  -- Store lookup tables in buffer variables for keymaps
  vim.b[bufnr].line_to_model_id = line_to_model_id
  vim.b[bufnr].model_data = model_data

  return line_to_model_id, model_data -- Return for direct use if needed
end

-- Setup keymaps for the model management buffer
function M.setup_models_keymaps(bufnr, manager_module)
  manager_module = manager_module or M -- Allow passing self for testing/modularity

  local function set_keymap(mode, lhs, rhs)
    api.nvim_buf_set_keymap(bufnr, mode, lhs, rhs, { noremap = true, silent = true })
  end

  -- Helper function to get model info (ID and data) from current line
  local function get_model_info_under_cursor()
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

  -- Set model under cursor as default
  set_keymap('n', 's',
    string.format([[<Cmd>lua require('%s').set_model_under_cursor(%d)<CR>]],
      manager_module.__name or 'llm.models.models_manager', bufnr))

  -- Set alias for model under cursor
  set_keymap('n', 'a',
    string.format([[<Cmd>lua require('%s').set_alias_for_model_under_cursor(%d)<CR>]],
      manager_module.__name or 'llm.models.models_manager', bufnr))

  -- Remove alias for model under cursor
  set_keymap('n', 'r',
    string.format([[<Cmd>lua require('%s').remove_alias_for_model_under_cursor(%d)<CR>]],
      manager_module.__name or 'llm.models.models_manager', bufnr))

  -- Add custom alias (when on the [+] line)
  set_keymap('n', '<CR>',
    string.format([[<Cmd>lua require('%s').handle_action_under_cursor(%d)<CR>]],
      manager_module.__name or 'llm.models.models_manager', bufnr))

  set_keymap('n', 'c', -- New keymap for adding custom OpenAI model
    string.format([[<Cmd>lua require('%s').add_custom_openai_model_interactive(%d)<CR>]],
      manager_module.__name or 'llm.models.models_manager', bufnr))

  -- REMOVED 'c' keymap for chat (this comment is now redundant as 'c' is reused)
end

-- Action functions called by keymaps (now accept bufnr)

-- Function to add a new custom OpenAI model via interactive input
function M.add_custom_openai_model_interactive(bufnr)
  local original_win = api.nvim_get_current_win() -- Store original window

  utils.floating_input({ prompt = "Enter Model ID (e.g., gpt-3.5-turbo-custom):" }, function(model_id)
    if api.nvim_win_is_valid(original_win) then api.nvim_set_current_win(original_win) end
    if not model_id or model_id == "" then
      vim.notify("Model ID cannot be empty. Aborted.", vim.log.levels.WARN)
      return
    end

    utils.floating_input({ prompt = "Enter Model Name (display name, optional):" }, function(model_name)
      if api.nvim_win_is_valid(original_win) then api.nvim_set_current_win(original_win) end
      local final_model_name = (model_name and model_name ~= "") and model_name or nil

      utils.floating_input({ prompt = "Enter API Base URL (optional):" }, function(api_base)
        if api.nvim_win_is_valid(original_win) then api.nvim_set_current_win(original_win) end
        local final_api_base = (api_base and api_base ~= "") and api_base or nil

        utils.floating_input({ prompt = "Enter API Key Name (optional, from keys.json):" }, function(api_key_name)
          if api.nvim_win_is_valid(original_win) then api.nvim_set_current_win(original_win) end
          local final_api_key_name = (api_key_name and api_key_name ~= "") and api_key_name or nil

          -- For now, we are not prompting for headers, needs_auth etc. in this interactive flow.
          -- Those can be added later if desired, or users can edit the YAML.
          -- Passing existing defaults from custom_openai.add_custom_openai_model
          local model_details = {
            model_id = model_id,
            model_name = final_model_name,
            api_base = final_api_base,
            api_key_name = final_api_key_name,
            -- headers, needs_auth, supports_functions, supports_system_prompt will use defaults in add_custom_openai_model
          }

          local success, err_msg = custom_openai.add_custom_openai_model(model_details)

          if success then
            custom_openai.load_custom_openai_models() -- Reload models
            vim.notify("Custom OpenAI model '" .. (final_model_name or model_id) .. "' added successfully.",
              vim.log.levels.INFO)
            require('llm.unified_manager').switch_view("Models")
          else
            vim.notify("Failed to add custom OpenAI model: " .. (err_msg or "Unknown error"), vim.log.levels.ERROR)
          end
          vim.cmd('stopinsert') -- Ensure normal mode
        end)
      end)
    end)
  end)
end

-- Sets the model under the cursor as the default LLM model.
function M.set_model_under_cursor(bufnr)
  local model_id, model_info = M.get_model_info_under_cursor(bufnr)
  if not model_id or not model_info then return end      -- Exit if no model info found

  local display_name = model_info.model_name or model_id -- Use model_name for messages if available

  if model_info.is_default then
    vim.notify("Model '" .. display_name .. "' is already the default", vim.log.levels.INFO)
    return
  end

  -- Check availability using the model_id for custom models or full_line for others
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
    vim.notify("Cannot set as default: " .. provider .. " requirements not met (API key/plugin/config)",
      vim.log.levels.ERROR)
    return
  end

  -- Use model_id when setting the default via CLI
  vim.notify("Setting default model to: " .. display_name .. " (ID: " .. model_id .. ")", vim.log.levels.INFO)
  if M.set_default_model(model_id) then
    config.options.model = model_id                      -- Update runtime config as well
    vim.notify("Default model set to: " .. display_name, vim.log.levels.INFO)
    require('llm.unified_manager').switch_view("Models") -- Refresh view
  else
    vim.notify("Failed to set default model via llm CLI", vim.log.levels.ERROR)
  end
end

-- Sets an alias for the model under the cursor.
function M.set_alias_for_model_under_cursor(bufnr)
  local model_id, model_info = M.get_model_info_under_cursor(bufnr)
  if not model_id or not model_info then return end

  local display_name = model_info.model_name or model_id
  local original_win = api.nvim_get_current_win()

  utils.floating_input({ prompt = "Enter alias for model '" .. display_name .. "': " }, function(alias)
    if api.nvim_win_is_valid(original_win) then api.nvim_set_current_win(original_win) end
    if not alias or alias == "" then
      vim.notify("Alias cannot be empty", vim.log.levels.WARN)
      return
    end

    -- Use model_id when setting the alias via CLI
    if M.set_model_alias(alias, model_id) then
      vim.notify("Alias set: " .. alias .. " -> " .. display_name .. " (ID: " .. model_id .. ")", vim.log.levels.INFO)
      vim.cmd('stopinsert')
      require('llm.unified_manager').switch_view("Models")
    else
      vim.notify("Failed to set alias via llm CLI", vim.log.levels.ERROR)
      vim.cmd('stopinsert')
    end
  end)
end

function M.handle_action_under_cursor(bufnr)
  -- local current_line = api.nvim_win_get_cursor(0)[1]
  -- local line_content = api.nvim_buf_get_lines(bufnr, current_line - 1, current_line, false)[1]
  -- local original_win = api.nvim_get_current_win() -- Store original window

  -- REMOVED logic for "[+] Add custom OpenAI model" as it's now in M.add_custom_openai_model_interactive
  -- REMOVED logic for "[+] Add custom alias" as 'a' keymap is used directly on a model

  -- If <CR> is pressed on a model line, it currently does nothing specific beyond
  -- what other plugins might do for a an enter key in a nofile buffer.
  -- Could potentially make it an alias for 's' (set default) or another action if desired.
  -- For now, it does nothing if not on a previously active [+] line.
  if config.get("debug") then
    local line_content = api.nvim_buf_get_lines(bufnr, api.nvim_win_get_cursor(0)[1] - 1, api.nvim_win_get_cursor(0)[1],
      false)[1]
    vim.notify("Enter pressed on line: " .. (line_content or "empty") .. ". No specific action for <CR> on this line.",
      vim.log.levels.DEBUG)
  end
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

  vim.ui.select(model_info.aliases, {
    prompt = "Select alias to remove:",
    format_item = function(item) return item end
  }, function(alias)
    if not alias then return end

    utils.floating_confirm({
      prompt = "Remove alias '" .. alias .. "'?",
      options = { "Yes", "No" }
    }, function(choice)
      if choice == "Yes" then
        if M.remove_model_alias(alias) then
          vim.notify("Alias removed: " .. alias, vim.log.levels.INFO)
          require('llm.unified_manager').switch_view("Models")
        else
          vim.notify("Failed to remove alias '" .. alias .. "'", vim.log.levels.ERROR)
        end
      end
    end)
  end)
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
  require('llm.unified_manager').open_specific_manager("Models")
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
M.__name = 'llm.models.models_manager'

return M
