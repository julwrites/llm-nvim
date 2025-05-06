-- llm/managers/models/custom_openai.lua - Custom OpenAI model management
-- License: Apache 2.0

local M = {}
local utils = require('llm.utils')
local config = require('llm.config')
local keys_manager = require('llm.managers.keys_manager')

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

  local content = file:read("*a")
  file:close()

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

  for i, line in ipairs(lines) do
    -- Skip comment lines and empty lines
    if not line:match("^%s*#") and line:match("%S") then
      -- Check for model section start (no indentation, ends with colon)
      if line:match("^[^%s#][^:]*:") then
        current_model = line:match("^([^:]+)"):gsub("%s+$", "")
        in_list_item = false
        current_section = current_model

        -- Initialize model data
        models[current_model] = {
          name = current_model,
          model_id = current_model,
          model_name = current_model,
          has_api_base = false,
          api_base = nil,
          api_key_name = nil,
          is_valid = false,
        }
      elseif line:match("^%s*-%s") then
        -- Handle list items
        in_list_item = true
        list_indent = line:match("^(%s*)"):len()
        local list_item_content = line:match("^%s*-%s*(.+)")
        if list_item_content then
          local prop, value = list_item_content:match("([^:]+):%s*(.+)")
          if prop and value then
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
          else
            local list_model_name = list_item_content:match("^%s*(.-)%s*$") or ("model_" .. i)
            current_model = list_model_name
            models[current_model] = {
              name = current_model,
              model_id = current_model,
              model_name = current_model,
              has_api_base = false,
              api_base = nil,
              api_key_name = nil,
              is_valid = false,
            }
          end
        end
      elseif current_model and line:match("^%s+") then
        -- Handle nested properties
        if in_list_item then
          local indent = line:match("^(%s*)"):len()
          if indent <= list_indent and not line:match("^%s*-%s") then
            in_list_item = false
            goto continue
          end
        end

        if not current_model then goto continue end

        -- Handle regular properties
        if line:match("api_base%s*:") then
          local api_base = line:match("api_base%s*:%s*(.+)")
          if api_base then
            models[current_model].has_api_base = true
            models[current_model].api_base = api_base:gsub("^%s*(.-)%s*$", "%1"):gsub("%s*#.*$", "")
          end
        elseif line:match("api_key_name%s*:") then
          local key_name = line:match("api_key_name%s*:%s*(.+)")
          if key_name then
            models[current_model].api_key_name = key_name:gsub("^%s*(.-)%s*$", "%1"):gsub("%s*#.*$", "")
          end
        elseif line:match("model_id%s*:") then
          local model_id = line:match("model_id%s*:%s*(.+)")
          if model_id then
            models[current_model].model_id = model_id:gsub("^%s*(.-)%s*$", "%1"):gsub("%s*#.*$", "")
          end
        elseif line:match("model_name%s*:") then
          local model_name = line:match("model_name%s*:%s*(.+)")
          if model_name then
            models[current_model].model_name = model_name:gsub("^%s*(.-)%s*$", "%1"):gsub("%s*#.*$", "")
          end
        end
      end
    end
    ::continue::
  end

  -- Clean up invalid models
  local models_to_remove = {}
  for name, model in pairs(models) do
    if not model.model_id and not model.model_name then
      table.insert(models_to_remove, name)
    end
  end
  for _, name in ipairs(models_to_remove) do
    models[name] = nil
  end

  -- Validate models and add to cache
  for name, model in pairs(models) do
    M.custom_openai_models[name] = model

    if model.has_api_base and model.api_key_name then
      local key_is_set = keys_manager.is_key_set(model.api_key_name)
      model.is_valid = key_is_set

      if not key_is_set then
        vim.notify("To use model '" .. name .. "', set the API key with: llm keys set " ..
          model.api_key_name .. " YOUR_API_KEY", vim.log.levels.WARN)
      end
    else
      model.is_valid = false
    end

    if not model.model_name or model.model_name == "" then
      model.model_name = model.model_id or name
    end
  end

  return M.custom_openai_models
end

-- Check if a custom OpenAI model is valid
function M.is_custom_openai_model_valid(model_line)
  local model_name
  if model_line:match("^Custom OpenAI:") then
    model_name = model_line:match("^Custom OpenAI:%s*(.+)")
  elseif model_line:match("^Azure OpenAI:") then
    model_name = model_line:match("^Azure OpenAI:%s*([^%(]+)")
  else
    model_name = model_line:match(": ([^%(]+)")
  end

  if not model_name then return false end
  model_name = model_name:match("^%s*(.-)%s*$")

  -- Ensure models are loaded
  if vim.tbl_isempty(M.custom_openai_models) then
    M.load_custom_openai_models()
  end

  -- Check for matches
  for name, model_info in pairs(M.custom_openai_models) do
    local model_id = model_info.model_id or name
    local info_model_name = model_info.model_name or name

    if model_name == model_id or model_name == info_model_name or
        model_name:lower() == model_id:lower() or model_name:lower() == info_model_name:lower() or
        model_name:lower():find(model_id:lower(), 1, true) or
        model_id:lower():find(model_name:lower(), 1, true) or
        model_name:lower():find(info_model_name:lower(), 1, true) or
        info_model_name:lower():find(model_name:lower(), 1, true) then
      return model_info.is_valid
    end
  end

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
