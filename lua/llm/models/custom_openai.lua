-- llm/models/custom_openai.lua - Custom OpenAI model management
-- License: Apache 2.0

local M = {}
local utils = require('llm.utils')
local config = require('llm.config')
local keys_manager = require('llm.keys.keys_manager')

-- Cache for custom OpenAI models
M.custom_openai_models = {}

-- Load custom OpenAI models from extra-openai-models.yaml
function M.load_custom_openai_models()
  -- Clear the cache
  M.custom_openai_models = {}

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

  -- Use the new YAML parser from utils
  local parsed_data = utils.parse_simple_yaml(yaml_path)

  if not parsed_data then
    if config.get("debug") then
      vim.notify("Failed to parse YAML file or file is empty: " .. yaml_path, vim.log.levels.WARN)
    end
    return {}
  end

  -- Process the parsed data
  -- Assuming the parser returns a list of tables for the user's format
  if type(parsed_data) ~= 'table' then
     if config.get("debug") then
        vim.notify("Parsed YAML data is not a table: " .. vim.inspect(parsed_data), vim.log.levels.WARN)
     end
     return {}
  end

  -- Iterate through the list of model definitions
  for i, model_def in ipairs(parsed_data) do
    if type(model_def) == 'table' then
      -- Extract data, providing defaults
      local model_data = {
        yaml_key = "list_item_" .. i, -- Store original index/key if needed
        model_id = model_def.model_id,
        model_name = model_def.model_name,
        api_base = model_def.api_base,
        api_key_name = model_def.api_key_name,
        has_api_base = model_def.api_base ~= nil and model_def.api_base ~= "",
        is_valid = false -- Will be set during validation
      }

      -- Determine the primary identifier (key for the cache)
      local primary_id = model_data.model_id
      if not primary_id or primary_id == "" then
         if config.get("debug") then
            vim.notify("Skipping model definition at index " .. i .. " due to missing 'model_id'", vim.log.levels.WARN)
         end
         goto next_model -- Skip this entry if model_id is missing
      end

      -- Default model_name if not provided
      if not model_data.model_name or model_data.model_name == "" then
        model_data.model_name = primary_id
      end

      -- Validate based on API key presence
      if model_data.has_api_base and model_data.api_key_name then
        local key_is_set = keys_manager.is_key_set(model_data.api_key_name)
        model_data.is_valid = key_is_set

        if not key_is_set and config.get("debug") then
          vim.notify("API key '" .. model_data.api_key_name .. "' not set for custom model: " .. primary_id,
            vim.log.levels.DEBUG)
        end
      else
        -- If api_base or api_key_name is missing, it's invalid
        model_data.is_valid = false
        if config.get("debug") then
          vim.notify("Custom model '" .. primary_id .. "' is missing api_base or api_key_name.", vim.log.levels.DEBUG)
        end
      end

      -- Add the validated model data to the cache using the primary_id
      M.custom_openai_models[primary_id] = model_data

      if config.get("debug") then
        vim.notify(string.format("Loaded custom model: ID=%s, Name=%s, Valid=%s",
          primary_id, model_data.model_name, tostring(model_data.is_valid)), vim.log.levels.DEBUG)
      end
    else
       if config.get("debug") then
          vim.notify("Skipping non-table entry in parsed YAML data at index " .. i, vim.log.levels.WARN)
       end
    end
    ::next_model:: -- Label for goto statement
  end

  return M.custom_openai_models
end

-- Check if a custom OpenAI model identifier corresponds to a valid configuration
function M.is_custom_openai_model_valid(model_identifier)
  if not model_identifier or model_identifier == "" then return false end

  -- Ensure models are loaded
  if vim.tbl_isempty(M.custom_openai_models) then
    M.load_custom_openai_models()
  end

  -- Check if the identifier directly matches a model_id (primary key in the cache)
  local model_info = M.custom_openai_models[model_identifier]
  if model_info then
    return model_info.is_valid
  end

  -- No fallback checks are performed. Only model_id is used.
  return false
end


-- Debug function for custom models
function M.debug_custom_openai_models()
  local config_dir, yaml_path = utils.get_config_path("extra-openai-models.yaml")

  vim.notify("Debug information for custom OpenAI models:", vim.log.levels.INFO)
  vim.notify("Config directory: " .. (config_dir or "not found"), vim.log.levels.INFO)
  vim.notify("YAML path: " .. (yaml_path or "not found"), vim.log.levels.INFO)

  -- Check file existence and content
  if yaml_path then
    local file = io.open(yaml_path, "r")
    if file then
      local content = file:read("*a")
      file:close()
      vim.notify("File exists with " .. #content .. " bytes", vim.log.levels.INFO)
    end
  end

  -- Load and show models
  M.load_custom_openai_models()
  vim.notify("Found " .. vim.tbl_count(M.custom_openai_models) .. " custom OpenAI models", vim.log.levels.INFO)

  for name, model in pairs(M.custom_openai_models) do
    local status = model.is_valid and "valid" or "invalid"
    vim.notify(string.format("Model: %s, Status: %s, API Key: %s, Has API Base: %s",
      name, status, model.api_key_name or "not set", model.has_api_base and "yes" or "no"), vim.log.levels.INFO)
  end

  return M.custom_openai_models
end

-- Create sample YAML file
function M.create_sample_yaml_file()
  local config_dir, yaml_path = utils.get_config_path("extra-openai-models.yaml.sample")

  if not config_dir then
    vim.notify("Could not find config directory", vim.log.levels.ERROR)
    return false
  end

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

  local file = io.open(yaml_path, "w")
  if not file then
    vim.notify("Could not create sample YAML file: " .. yaml_path, vim.log.levels.ERROR)
    return false
  end

  file:write(sample_content)
  file:close()

  vim.notify("Created sample YAML file at: " .. yaml_path, vim.log.levels.INFO)
  return true
end

return M
