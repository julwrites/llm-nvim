-- llm/managers/models_manager.lua - Model management functionality
-- License: Apache 2.0

local M = {}

-- Forward declarations
local api = vim.api
local fn = vim.fn
local utils = require('llm.utils')
local config = require('llm.config')
local styles = require('llm.styles') -- Added for highlighting

-- Cache for custom OpenAI models
local custom_openai_models = {}

-- Add pattern escape function to vim namespace if it doesn't exist
if not vim.pesc then
  vim.pesc = function(s)
    return string.gsub(s, "[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1")
  end
end

-- Load custom OpenAI models from extra-openai-models.yaml
local function load_custom_openai_models()
  local utils = require('llm.utils')
  local keys_manager = require('llm.managers.keys_manager')
  local config = require('llm.config')

  -- Clear the cache
  custom_openai_models = {}

  -- Get the config directory
  local config_dir, yaml_path = utils.get_config_path("extra-openai-models.yaml")

  if config.get("debug") then
    vim.notify("Looking for custom OpenAI models at: " .. (yaml_path or "path not found"), vim.log.levels.INFO)
  end

  if not config_dir then
    vim.notify("Could not find config directory for extra-openai-models.yaml", vim.log.levels.WARN)
    return {}
  end

  -- Try to read the extra-openai-models.yaml file
  local file = io.open(yaml_path, "r")
  if not file then
    vim.notify("Could not open extra-openai-models.yaml at: " .. yaml_path, vim.log.levels.WARN)
    return {}
  end

  local content = file:read("*a")
  file:close()

  if config.get("debug") then
    vim.notify("Found extra-openai-models.yaml with content length: " .. #content, vim.log.levels.DEBUG)
  end

  -- Process the YAML content line by line
  local lines = {}
  for line in content:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end

  -- Parse YAML to extract model definitions
  local models = {}
  local current_model = nil
  local in_list_item = false
  local list_indent = 0
  local current_section = nil

  if config.get("debug") then
    vim.notify("Starting YAML parsing with " .. #lines .. " lines", vim.log.levels.DEBUG)
  end

  for i, line in ipairs(lines) do
    -- Skip comment lines and empty lines
    if not line:match("^%s*#") and line:match("%S") then
      -- Check for model section start (no indentation, ends with colon)
      if line:match("^[^%s#][^:]*:") then
        -- Extract model name
        current_model = line:match("^([^:]+)"):gsub("%s+$", "")
        in_list_item = false
        current_section = current_model

        if config.get("debug") then
          vim.notify("Found model section: " .. current_model, vim.log.levels.DEBUG)
        end

        -- Initialize model data
        models[current_model] = {
          name = current_model,
          model_id = current_model,   -- Default to using the key as model_id
          model_name = current_model, -- Default to using the key as model_name
          has_api_base = false,
          api_base = nil,
          api_key_name = nil,
          is_valid = false,
        }
        -- Check for list items (models in a list)
      elseif line:match("^%s*-%s") then
        -- This is a list item, could be a model in a list format
        in_list_item = true
        list_indent = line:match("^(%s*)"):len()

        -- Extract the model name or property from the list item
        local list_item_content = line:match("^%s*-%s*(.+)")
        if list_item_content then
          -- Check if this is a property: value pair
          local prop, value = list_item_content:match("([^:]+):%s*(.+)")

          if prop and value then
            -- This is a property in list format
            if current_model then
              -- Trim whitespace and any trailing comments
              value = value:gsub("^%s*(.-)%s*$", "%1"):gsub("%s*#.*$", "")

              if prop:match("model_id") then
                models[current_model].model_id = value
              elseif prop:match("model_name") then
                models[current_model].model_name = value
              elseif prop:match("api_base") then
                models[current_model].has_api_base = true
                models[current_model].api_base = value
              elseif prop:match("api_key_name") then
                models[current_model].api_key_name = value
              end
            end
          else
            -- This is a new model in list format
            -- Generate a unique name for this list item model
            local list_model_name = list_item_content:match("^%s*(.-)%s*$") or ("model_" .. i)
            current_model = list_model_name

            if config.get("debug") then
              vim.notify("Found list item model at line " .. i .. ": " .. list_model_name, vim.log.levels.DEBUG)
            end

            -- Initialize model data for this list item
            models[current_model] = {
              name = current_model,
              model_id = current_model,   -- Default to using the item content as model_id
              model_name = current_model, -- Default to using the item content as model_name
              has_api_base = false,
              api_base = nil,
              api_key_name = nil,
              is_valid = false,
            }
          end
        else
          -- Empty list item, create a placeholder
          local list_model_name = "model_" .. i
          current_model = list_model_name

          if config.get("debug") then
            vim.notify("Found empty list item at line " .. i, vim.log.levels.DEBUG)
          end

          -- Initialize model data for this list item
          models[current_model] = {
            name = current_model,
            model_id = nil,
            model_name = nil,
            has_api_base = false,
            api_base = nil,
            api_key_name = nil,
            is_valid = false,
          }
        end
        -- Check for properties within the current model section or list item
      elseif current_model and line:match("^%s+") then
        -- If we're in a list item, check if this line is part of the same item
        if in_list_item then
          local indent = line:match("^(%s*)"):len()
          -- If indent is less than or equal to list_indent, we've exited this list item
          if indent <= list_indent and not line:match("^%s*-%s") then
            in_list_item = false
            -- Don't reset current_model here, as we might be processing nested properties
            goto continue
          end
        end

        -- Only process if we have a current model
        if not current_model then goto continue end

        -- Check if this is a nested property in YAML list format
        if line:match("^%s+-%s") then
          -- This is a nested list item under the current model
          local nested_prop = line:match("^%s+-%s*(.+)")
          if nested_prop then
            -- Check if this is a property: value pair
            local prop, value = nested_prop:match("([^:]+):%s*(.+)")

            if prop and value then
              -- Trim whitespace and any trailing comments
              value = value:gsub("^%s*(.-)%s*$", "%1"):gsub("%s*#.*$", "")

              if prop:match("model_id") then
                models[current_model].model_id = value
              elseif prop:match("model_name") then
                models[current_model].model_name = value
              elseif prop:match("api_base") then
                models[current_model].has_api_base = true
                models[current_model].api_base = value
              elseif prop:match("api_key_name") then
                models[current_model].api_key_name = value
              end
            end
          end
        else
          -- Regular property format (not in list)
          -- Check for api_base
          if line:match("api_base%s*:") then
            local api_base = line:match("api_base%s*:%s*(.+)")
            if api_base then
              models[current_model].has_api_base = true
              models[current_model].api_base = api_base:gsub("^%s*(.-)%s*$", "%1"):gsub("%s*#.*$", "") -- Trim
            end
          end

          -- Check for api_key_name
          if line:match("api_key_name%s*:") then
            local key_name = line:match("api_key_name%s*:%s*(.+)")
            if key_name then
              -- Trim whitespace and any trailing comments
              key_name = key_name:gsub("^%s*(.-)%s*$", "%1"):gsub("%s*#.*$", "")
              models[current_model].api_key_name = key_name
            end
          end

          -- Check for model_id
          if line:match("model_id%s*:") then
            local model_id = line:match("model_id%s*:%s*(.+)")
            if model_id then
              -- Trim whitespace and any trailing comments
              model_id = model_id:gsub("^%s*(.-)%s*$", "%1"):gsub("%s*#.*$", "")
              models[current_model].model_id = model_id
            end
          end

          -- Check for model_name
          if line:match("model_name%s*:") then
            local model_name = line:match("model_name%s*:%s*(.+)")
            if model_name then
              -- Trim whitespace and any trailing comments
              model_name = model_name:gsub("^%s*(.-)%s*$", "%1"):gsub("%s*#.*$", "")
              models[current_model].model_name = model_name
            end
          end
        end
      end
    end
    ::continue::
  end

  -- Clean up models that don't have required fields
  local models_to_remove = {}
  for name, model in pairs(models) do
    -- If model doesn't have a model_id or model_name, it's probably not a valid model
    if not model.model_id and not model.model_name then
      table.insert(models_to_remove, name)
    end
  end

  for _, name in ipairs(models_to_remove) do
    models[name] = nil
  end

  -- Add debug output for each model found
  if config.get("debug") then
    for name, model in pairs(models) do
      vim.notify(string.format("Found model: %s (model_id: %s, model_name: %s, api_key_name: %s, api_base: %s)",
        name,
        model.model_id or "nil",
        model.model_name or "nil",
        model.api_key_name or "nil",
        model.api_base or "nil"
      ), vim.log.levels.DEBUG)
    end
  end

  if config.get("debug") then
    vim.notify("Found " .. vim.tbl_count(models) .. " potential models in YAML", vim.log.levels.INFO)
  end

  -- Validate models and add to cache
  for name, model in pairs(models) do
    -- Always add the model to the cache
    custom_openai_models[name] = model

    -- Check if the model has the required fields
    if model.has_api_base and model.api_key_name then
      -- Check if the API key is set
      local key_is_set = keys_manager.is_key_set(model.api_key_name)
      model.is_valid = key_is_set

      if config.get("debug") then
        local status = key_is_set and "valid" or "invalid (missing API key: " .. model.api_key_name .. ")"
        vim.notify("Found custom OpenAI model: " .. name .. " - " .. status, vim.log.levels.INFO)
      end

      -- If the key isn't set, show a helpful message
      if not key_is_set then
        vim.notify("To use model '" .. name .. "', set the API key with: llm keys set " ..
          model.api_key_name .. " YOUR_API_KEY", vim.log.levels.WARN)
      end
    else
      local missing = {}
      if not model.has_api_base then table.insert(missing, "api_base") end
      if not model.api_key_name then table.insert(missing, "api_key_name") end

      -- Mark as invalid
      model.is_valid = false

      if config.get("debug") then
        vim.notify("Incomplete model definition '" .. name .. "': missing " ..
          table.concat(missing, ", "), vim.log.levels.WARN)
      end
    end

    -- Ensure model has display name
    if not model.model_name or model.model_name == "" then
      model.model_name = model.model_id or name
    end
  end

  if config.get("debug") then
    vim.notify("Loaded " .. vim.tbl_count(custom_openai_models) .. " custom OpenAI models", vim.log.levels.INFO)
  end
  return custom_openai_models
end

-- Check if a custom OpenAI model is valid
local function is_custom_openai_model_valid(model_line)
  local config = require('llm.config')

  -- Extract model name from the line based on different possible formats
  local model_name
  if model_line:match("^Custom OpenAI:") then
    model_name = model_line:match("^Custom OpenAI:%s*(.+)")
  elseif model_line:match("^Azure OpenAI:") then
    model_name = model_line:match("^Azure OpenAI:%s*([^%(]+)")
  else
    model_name = model_line:match(": ([^%(]+)")
  end

  if not model_name then
    if config.get("debug") then
      vim.notify("Could not extract model name from: " .. model_line, vim.log.levels.INFO)
    end
    return false
  end

  -- Trim whitespace
  model_name = model_name:match("^%s*(.-)%s*$")

  if config.get("debug") then
    vim.notify("Checking if custom model is valid: " .. model_name, vim.log.levels.INFO)
  end

  -- Ensure custom models are loaded
  if vim.tbl_isempty(custom_openai_models) then
    load_custom_openai_models()
  end

  -- First check for direct match by name
  if custom_openai_models[model_name] then
    return custom_openai_models[model_name].is_valid
  end

  -- Then check for match by model_id or model_name
  for name, model_info in pairs(custom_openai_models) do
    local model_id = model_info.model_id or name
    local info_model_name = model_info.model_name or name

    -- Check for exact matches first
    if model_name == model_id or model_name == info_model_name then
      return model_info.is_valid
    end

    -- Then check for case-insensitive matches
    if model_name:lower() == model_id:lower() or model_name:lower() == info_model_name:lower() then
      return model_info.is_valid
    end

    -- Try more flexible matching for all custom models
    -- This helps with Azure deployments and other variations
    if model_name:lower():find(model_id:lower(), 1, true) or
        model_id:lower():find(model_name:lower(), 1, true) or
        model_name:lower():find(info_model_name:lower(), 1, true) or
        info_model_name:lower():find(model_name:lower(), 1, true) then
      if config.get("debug") then
        vim.notify("Found matching custom model: " .. name .. " for " .. model_name, vim.log.levels.INFO)
      end
      return model_info.is_valid
    end
  end

  return false
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
    -- For custom models, we need to check if the model definition is valid
    return is_custom_openai_model_valid(model_line)
  elseif model_line:match("OpenAI") then
    -- Check if this is actually a custom model that wasn't marked as such
    -- First check by model_name with more flexible matching
    for name, model_info in pairs(custom_openai_models) do
      local model_id = model_info.model_id or name
      local info_model_name = model_info.model_name or name

      -- More flexible matching - check if either contains the other
      if model_name:find(model_id, 1, true) or model_id:find(model_name, 1, true) or
          model_name:find(info_model_name, 1, true) or info_model_name:find(model_name, 1, true) then
        if config.get("debug") then
          vim.notify("Found unmarked custom OpenAI model: " .. model_name ..
            " (matches " .. name .. ", model_id: " .. model_id ..
            ", model_name: " .. info_model_name .. ")", vim.log.levels.INFO)
        end
        return model_info.is_valid
      end
    end

    -- Regular OpenAI only requires the API key, not a plugin
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
  load_custom_openai_models()

  local result = utils.safe_shell_command("llm models", "Failed to get available models")
  if not result then
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
  if vim.tbl_isempty(custom_openai_models) then
    load_custom_openai_models()
  end

  if config.get("debug") then
    vim.notify("Adding " .. vim.tbl_count(custom_openai_models) .. " custom OpenAI models to available models list",
      vim.log.levels.INFO)
  end

  -- Create a set of model IDs and names to filter out duplicates
  local custom_model_identifiers = {}

  -- Add all custom OpenAI models to the list
  for name, model_info in pairs(custom_openai_models) do
    local model_id = model_info.model_id or name
    local model_name = model_info.model_name or name

    -- Add identifiers to our set for duplicate detection
    custom_model_identifiers[model_id:lower()] = true
    custom_model_identifiers[model_name:lower()] = true

    -- Add the custom model with a special marker
    local display_name = model_name or name
    local provider_prefix = "Custom OpenAI: "
    local model_line = provider_prefix .. display_name
    table.insert(models, model_line)

    if config.get("debug") then
      vim.notify("Added custom OpenAI model to list: " .. model_line, vim.log.levels.INFO)
    end
  end

  -- Add standard OpenAI models that don't conflict with custom ones
  for _, line in ipairs(standard_openai_models) do
    local model_name = M.extract_model_name(line)
    if model_name and not custom_model_identifiers[model_name:lower()] then
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
    default_model = default_model_output:match("Default model: ([^\r\n]+)") or default_model_output:match("([^\r\n]+)") or
        ""
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
    ["Custom OpenAI"] = {},
    ["Anthropic"] = {},
    ["Mistral"] = {},
    ["Gemini"] = {},
    ["Groq"] = {},
    ["Local Models"] = {},
    ["Other"] = {}
  }

  -- Pre-load custom OpenAI models if not already loaded
  if vim.tbl_isempty(custom_openai_models) then
    load_custom_openai_models()
  end
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
    -- Check for custom OpenAI models first - more specific check
    if model_line:match("OpenAI") and model_line:match("%(custom%)") then
      provider_key = "Custom OpenAI"
      vim.notify("Grouping as Custom OpenAI: " .. model_line, vim.log.levels.DEBUG)
      -- Check for model names that match our loaded custom models
    elseif model_line:match("OpenAI") then
      -- Extract model name to check if it's in our custom models list
      local model_name = M.extract_model_name(model_line)
      if custom_openai_models[model_name] then
        provider_key = "Custom OpenAI"
        vim.notify("Identified existing custom model: " .. model_name, vim.log.levels.DEBUG)
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
    table.insert(providers[provider_key], entry)
  end

  local model_data = {}
  local line_to_model = {}
  local current_line = #lines + 1
  -- Flexible default model matching
  local default_found = false
  for _, provider_models in pairs(providers) do
    for _, model in ipairs(provider_models) do
      if model.is_default then
        default_found = true; break
      end
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
        -- Remove any existing alias text from the full_line to avoid duplicates
        model.full_line = model.full_line:gsub("%s*%(aliases: [^%)]+%)", "")
        local line = string.format("[%s] %s%s", status, model.full_line, alias_text)
        table.insert(lines, line)
        model_data[model.model_name] = {
          line = current_line,
          is_default = model.is_default,
          full_line = model.full_line,
          aliases =
              model.aliases
        }
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

  -- Chat with model under cursor
  set_keymap('n', 'c',
    string.format([[<Cmd>lua require('%s').chat_with_model_under_cursor(%d)<CR>]],
      manager_module.__name or 'llm.managers.models_manager', bufnr))

  -- Add custom alias (when on the [+] line)
  set_keymap('n', '<CR>',
    string.format([[<Cmd>lua require('%s').handle_action_under_cursor(%d)<CR>]],
      manager_module.__name or 'llm.managers.models_manager', bufnr))
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
    local is_custom_openai = false

    if model_info.full_line:match("OpenAI") and model_info.full_line:match("%(custom%)") then
      provider = "Custom OpenAI"
      is_custom_openai = true
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

    local error_message
    if is_custom_openai then
      error_message = "Cannot set as default: " ..
          provider .. " model configuration is invalid or required API key not configured"
    elseif provider == "OpenAI" then
      error_message = "Cannot set as default: " .. provider .. " API key not configured"
    else
      error_message = "Cannot set as default: " .. provider .. " API key or plugin not configured"
    end

    vim.notify(error_message, vim.log.levels.ERROR)
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

  -- Store original window before showing floating input
  local original_win = api.nvim_get_current_win()

  utils.floating_input({ prompt = "Enter alias for model " .. model_name .. ": " }, function(alias)
    -- Return focus to original window first
    if api.nvim_win_is_valid(original_win) then
      api.nvim_set_current_win(original_win)
    end

    if not alias or alias == "" then
      vim.notify("Alias cannot be empty", vim.log.levels.WARN)
      return
    end

    if M.set_model_alias(alias, model_name) then
      vim.notify("Alias set: " .. alias .. " -> " .. model_name, vim.log.levels.INFO)
      vim.cmd('stopinsert') -- Force normal mode
      require('llm.managers.unified_manager').switch_view("Models")
    else
      vim.notify("Failed to set alias", vim.log.levels.ERROR)
      vim.cmd('stopinsert') -- Force normal mode even on error
    end
  end)
end

function M.chat_with_model_under_cursor(bufnr)
  local model_name, model_info = M.get_model_info_under_cursor(bufnr)
  if not model_name then return end

  -- Check if the model is available before starting chat
  if not M.is_model_available(model_info.full_line) then
    local provider = "unknown"
    local is_custom_openai = false

    if model_info.full_line:match("OpenAI") and model_info.full_line:match("%(custom%)") then
      provider = "Custom OpenAI"
      is_custom_openai = true
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

    local error_message
    if is_custom_openai then
      error_message = "Cannot chat with model: " ..
          provider .. " model configuration is invalid or required API key not configured"
    elseif provider == "OpenAI" then
      error_message = "Cannot chat with model: " .. provider .. " API key not configured"
    else
      error_message = "Cannot chat with model: " .. provider .. " API key or plugin not configured"
    end

    vim.notify(error_message, vim.log.levels.ERROR)
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
    -- Store original window before showing floating inputs
    local original_win = api.nvim_get_current_win()

    utils.floating_input({ prompt = "Enter alias name: " }, function(alias)
      -- Return focus to original window between inputs
      if api.nvim_win_is_valid(original_win) then
        api.nvim_set_current_win(original_win)
      end

      if not alias or alias == "" then
        vim.notify("Alias name cannot be empty", vim.log.levels.WARN)
        return
      end

      utils.floating_input({ prompt = "Enter model name: " }, function(model)
        -- Return focus to original window before processing
        if api.nvim_win_is_valid(original_win) then
          api.nvim_set_current_win(original_win)
        end

        if not model or model == "" then
          vim.notify("Model name cannot be empty", vim.log.levels.WARN)
          return
        end

        if M.set_model_alias(alias, model) then
          vim.notify("Alias set: " .. alias .. " -> " .. model, vim.log.levels.INFO)
          vim.cmd('stopinsert') -- Force normal mode
          require('llm.managers.unified_manager').switch_view("Models")
        else
          vim.notify("Failed to set alias", vim.log.levels.ERROR)
          vim.cmd('stopinsert') -- Force normal mode even on error
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

  vim.ui.select(model_info.aliases, {
    prompt = "Select alias to remove:",
    format_item = function(item) return item end
  }, function(alias)
    if not alias then return end

    local _, aliases_file = utils.get_config_path("aliases.json")
    local is_system_alias = false
    if aliases_file then
      local file = io.open(aliases_file, "r")
      if file then
        local content = file:read("*a")
        file:close()
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

    -- Additional check for alias existence
    local current_aliases = M.get_model_aliases()
    if not current_aliases[alias] then
      vim.notify("Alias '" .. alias .. "' not found in current aliases", vim.log.levels.ERROR)
      return
    end

    utils.floating_confirm({
      prompt = "Remove alias '" .. alias .. "'?",
      options = { "Yes", "No" }
    }, function(choice)
      if choice == "Yes" then
        if M.remove_model_alias(alias) then
          vim.notify("Alias removed: " .. alias, vim.log.levels.INFO)
          require('llm.managers.unified_manager').switch_view("Models")
        else
          vim.notify("Failed to remove alias '" .. alias .. "'", vim.log.levels.ERROR)
        end
      end
    end)
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

-- Get custom OpenAI models
function M.get_custom_openai_models()
  if vim.tbl_isempty(custom_openai_models) then
    load_custom_openai_models()
  end
  return custom_openai_models
end

-- Force reload custom OpenAI models
function M.reload_custom_openai_models()
  -- Clear the cache and reload
  custom_openai_models = {}
  load_custom_openai_models()
  return custom_openai_models
end

-- Debug function to help diagnose issues with custom OpenAI models
function M.debug_custom_openai_models()
  local utils = require('llm.utils')
  local config_dir, yaml_path = utils.get_config_path("extra-openai-models.yaml")

  vim.notify("Debug information for custom OpenAI models:", vim.log.levels.INFO)
  vim.notify("Config directory: " .. (config_dir or "not found"), vim.log.levels.INFO)
  vim.notify("YAML path: " .. (yaml_path or "not found"), vim.log.levels.INFO)

  -- Check if file exists
  local file_exists = false
  if yaml_path then
    local file = io.open(yaml_path, "r")
    if file then
      file_exists = true
      local content = file:read("*a")
      file:close()
      vim.notify("File exists with " .. #content .. " bytes", vim.log.levels.INFO)

      -- Show first few lines
      local lines = {}
      local count = 0
      for line in content:gmatch("[^\r\n]+") do
        if count < 10 then
          table.insert(lines, line)
          count = count + 1
        else
          break
        end
      end

      if #lines > 0 then
        vim.notify("First " .. #lines .. " lines of file:", vim.log.levels.INFO)
        vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
      else
        vim.notify("File appears to be empty", vim.log.levels.WARN)
      end
    else
      vim.notify("File does not exist or cannot be opened", vim.log.levels.WARN)
    end
  end

  -- Add a function to validate YAML structure
  M.validate_yaml_file(yaml_path)

  -- Load models and show what was found
  load_custom_openai_models()

  vim.notify("Found " .. vim.tbl_count(custom_openai_models) .. " custom OpenAI models", vim.log.levels.INFO)
  for name, model in pairs(custom_openai_models) do
    local status = model.is_valid and "valid" or "invalid"
    local key_name = model.api_key_name or "not set"
    local has_base = model.has_api_base and "yes" or "no"
    local model_id = model.model_id or "not set"
    local model_name = model.model_name or "not set"

    vim.notify(string.format("Model: %s, Status: %s, API Key: %s, Has API Base: %s, Model ID: %s, Model Name: %s",
      name, status, key_name, has_base, model_id, model_name), vim.log.levels.INFO)
  end

  -- Check if models are being added to the available models list
  local available_models = M.get_available_models()

  vim.notify("All available models:", vim.log.levels.INFO)
  for i, model_line in ipairs(available_models) do
    vim.notify(i .. ": " .. model_line, vim.log.levels.INFO)

    -- For each model, check if it matches any custom model
    for name, model_info in pairs(custom_openai_models) do
      local model_id = model_info.model_id or name
      local info_model_name = model_info.model_name or name

      -- Extract model name from the line
      local line_model_name = M.extract_model_name(model_line)

      -- Check for matches
      if line_model_name:find(model_id, 1, true) or model_id:find(line_model_name, 1, true) or
          line_model_name:find(info_model_name, 1, true) or info_model_name:find(line_model_name, 1, true) then
        vim.notify("  - Matches custom model: " .. name ..
          " (model_id: " .. model_id .. ", model_name: " .. info_model_name .. ")",
          vim.log.levels.INFO)
      end
    end
  end

  local custom_found = 0
  for _, model_line in ipairs(available_models) do
    if model_line:match("%(custom%)") then
      custom_found = custom_found + 1
      vim.notify("Found in available models with custom marker: " .. model_line, vim.log.levels.INFO)
    end
  end

  vim.notify("Found " .. custom_found .. " custom models in available models list", vim.log.levels.INFO)

  return custom_openai_models
end

-- Function to validate YAML file structure
function M.validate_yaml_file(yaml_path)
  if not yaml_path then
    vim.notify("No YAML path provided for validation", vim.log.levels.ERROR)
    return false
  end

  local file = io.open(yaml_path, "r")
  if not file then
    vim.notify("Could not open YAML file for validation: " .. yaml_path, vim.log.levels.ERROR)
    return false
  end

  local content = file:read("*a")
  file:close()

  vim.notify("Validating YAML file structure...", vim.log.levels.INFO)

  -- Parse the file line by line to check structure
  local lines = {}
  for line in content:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end

  local indent_stack = {}
  local current_indent = 0
  local line_num = 0
  local errors = {}

  for i, line in ipairs(lines) do
    line_num = i

    -- Skip empty lines and comments
    if line:match("%S") and not line:match("^%s*#") then
      local indent = line:match("^(%s*)"):len()
      local content = line:match("^%s*(.+)")

      -- Check for list items
      if content:match("^-%s") then
        -- This is a list item
        vim.notify(string.format("Line %d: List item at indent %d: %s", i, indent, content), vim.log.levels.DEBUG)

        -- Check if this is a property in a list item
        local prop_value = content:match("^-%s*([^:]+):%s*(.+)")
        if prop_value then
          vim.notify(string.format("Line %d: List item with property: %s", i, content), vim.log.levels.DEBUG)
        end
      elseif content:match(":") then
        -- This is a key-value pair
        local key = content:match("^([^:]+):")
        if key then
          vim.notify(string.format("Line %d: Key-value pair at indent %d: %s", i, indent, key), vim.log.levels.DEBUG)
        end
      end
    end
  end

  -- Create a sample YAML file if requested
  if #errors > 0 then
    vim.notify("YAML validation found " .. #errors .. " issues:", vim.log.levels.WARN)
    for _, err in ipairs(errors) do
      vim.notify(err, vim.log.levels.WARN)
    end

    -- Offer to create a sample file
    vim.ui.select({ "Yes", "No" }, {
      prompt = "Would you like to create a sample YAML file?"
    }, function(choice)
      if choice == "Yes" then
        M.create_sample_yaml_file()
      end
    end)

    return false
  else
    vim.notify("YAML validation completed with no structural issues detected", vim.log.levels.INFO)
    return true
  end
end

-- Function to create a sample YAML file
function M.create_sample_yaml_file()
  local utils = require('llm.utils')
  local config_dir, yaml_path = utils.get_config_path("extra-openai-models.yaml.sample")

  if not config_dir then
    vim.notify("Could not find config directory", vim.log.levels.ERROR)
    return false
  end

  -- Create sample content
  local sample_content = [[# Sample extra-openai-models.yaml file
# This file defines custom OpenAI models and Azure OpenAI deployments

# Example of a custom OpenAI model with direct properties
my-custom-gpt4:
  model_id: gpt-4-turbo-preview
  model_name: My Custom GPT-4
  api_base: https://api.openai.com/v1
  api_key_name: openai

# Example of an Azure OpenAI deployment
azure-gpt4:
  model_id: deployment-name
  model_name: Azure GPT-4
  api_base: https://your-resource.openai.azure.com/
  api_key_name: azure_openai
  is_azure: true

# Example of models defined in list format
models:
  - model_id: gpt-3.5-turbo
    model_name: GPT-3.5 Turbo
    api_base: https://api.openai.com/v1
    api_key_name: openai

  - model_id: gpt-4
    model_name: GPT-4
    api_base: https://api.openai.com/v1
    api_key_name: openai
]]

  -- Write the sample file
  local file = io.open(yaml_path, "w")
  if not file then
    vim.notify("Could not create sample YAML file: " .. yaml_path, vim.log.levels.ERROR)
    return false
  end

  file:write(sample_content)
  file:close()

  vim.notify("Created sample YAML file at: " .. yaml_path, vim.log.levels.INFO)
  vim.notify("You can copy this to extra-openai-models.yaml and modify it for your needs", vim.log.levels.INFO)

  return true
end

-- Add module name for require path in keymaps
M.__name = 'llm.managers.models_manager'

return M
