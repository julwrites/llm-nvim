-- llm/models/custom_openai.lua - Custom OpenAI model management
-- License: Apache 2.0

local M = {}
local utils = require('llm.utils')
local config = require('llm.config')
local keys_manager = require('llm.keys.keys_manager')

-- Cache for custom OpenAI models
M.custom_openai_models = {}

-- Default values for model properties
local DEFAULT_MODEL_PROPERTIES = {
  needs_auth = true,
  supports_functions = false,
  supports_system_prompt = true,
  headers = nil,
  api_base = nil,
  api_key_name = nil,
}

-- Load custom OpenAI models from extra-openai-models.yaml
function M.load_custom_openai_models()
  M.custom_openai_models = {} -- Clear the cache

  local _, yaml_path = utils.get_config_path("extra-openai-models.yaml")
  if config.get("debug") then
    vim.notify("Looking for custom OpenAI models at: " .. (yaml_path or "path not found"), vim.log.levels.INFO)
  end

  if not yaml_path then
    vim.notify("Could not determine or create config directory for extra-openai-models.yaml", vim.log.levels.WARN)
    return {}
  end

  local file = io.open(yaml_path, "r")
  if not file then
    if config.get("debug") then
      vim.notify("extra-openai-models.yaml not found at: " .. yaml_path .. ". No custom models loaded.", vim.log.levels.INFO)
    end
    return {}
  end

  local content = file:read("*a")
  file:close()
  if not content or content == "" then
    if config.get("debug") then
      vim.notify("extra-openai-models.yaml is empty. No custom models loaded.", vim.log.levels.INFO)
    end
    return {}
  end

  local parsed_data = utils.parse_simple_yaml(yaml_path)
  if not parsed_data then
    if config.get("debug") then
      vim.notify("Failed to parse YAML file: " .. yaml_path .. ". Backing up and proceeding as if empty.", vim.log.levels.WARN)
    end
    local backup_path = yaml_path .. ".parse_failed_backup." .. os.time()
    os.rename(yaml_path, backup_path)
    vim.notify("Backed up unparsable YAML to: " .. backup_path, vim.log.levels.WARN)
    return {}
  end

  -- Check if parsed_data is a list
  local is_list = type(parsed_data) == 'table'
  if is_list then
    local count = 0
    for k, _ in pairs(parsed_data) do
      count = count + 1
      if type(k) ~= 'number' or k < 1 then is_list = false; break end
    end
    if count > 0 and not parsed_data[1] then is_list = false end
    if #parsed_data ~= count then is_list = false end
  end

  if not is_list then
    if config.get("debug") then
      vim.notify("YAML content in " .. yaml_path .. " is not a list. Backing up and proceeding as if empty.", vim.log.levels.WARN)
    end
    local backup_path = yaml_path .. ".non_list_backup." .. os.time()
    os.rename(yaml_path, backup_path)
    vim.notify("Backed up non-list YAML to: " .. backup_path, vim.log.levels.WARN)
    return {}
  end

  for i, model_def in ipairs(parsed_data) do
    if type(model_def) == 'table' then
      local primary_id = model_def.model_id
      if not primary_id or primary_id == "" then
        if config.get("debug") then
          vim.notify("Skipping model definition at index " .. i .. " due to missing 'model_id'", vim.log.levels.WARN)
        end
        goto next_model -- Skip this entry
      end

      local model_data = {
        model_id = primary_id,
        model_name = model_def.model_name or primary_id,
        api_base = model_def.api_base or DEFAULT_MODEL_PROPERTIES.api_base,
        api_key_name = model_def.api_key_name or DEFAULT_MODEL_PROPERTIES.api_key_name,
        headers = DEFAULT_MODEL_PROPERTIES.headers, -- Default to nil
        needs_auth = (model_def.needs_auth == nil) and DEFAULT_MODEL_PROPERTIES.needs_auth or model_def.needs_auth,
        supports_functions = (model_def.supports_functions == nil) and DEFAULT_MODEL_PROPERTIES.supports_functions or model_def.supports_functions,
        supports_system_prompt = (model_def.supports_system_prompt == nil) and DEFAULT_MODEL_PROPERTIES.supports_system_prompt or model_def.supports_system_prompt,
        is_valid = false -- Will be set by M.is_custom_openai_model_valid
      }

      -- Handle headers (string or table)
      if model_def.headers then
        if type(model_def.headers) == 'string' then
          local success, decoded_headers = pcall(vim.fn.json_decode, model_def.headers)
          if success then
            model_data.headers = decoded_headers
          else
            if config.get("debug") then
              vim.notify("Failed to parse JSON string for headers for model " .. primary_id .. ": " .. model_def.headers, vim.log.levels.WARN)
            end
          end
        elseif type(model_def.headers) == 'table' then
          model_data.headers = model_def.headers
        end
      end

      -- Validate the model (sets model_data.is_valid)
      M.is_custom_openai_model_valid(model_data) -- Pass the whole model_data for validation context

      M.custom_openai_models[primary_id] = model_data
      if config.get("debug") then
        vim.notify(string.format("Loaded custom model: ID=%s, Name=%s, Valid=%s, Auth=%s, Funcs=%s, SysPrompt=%s, Headers=%s",
          primary_id, model_data.model_name, tostring(model_data.is_valid), tostring(model_data.needs_auth),
          tostring(model_data.supports_functions), tostring(model_data.supports_system_prompt), vim.inspect(model_data.headers)), vim.log.levels.DEBUG)
      end
    else
      if config.get("debug") then
        vim.notify("Skipping non-table entry in parsed YAML data at index " .. i, vim.log.levels.WARN)
      end
    end
    ::next_model::
  end
  return M.custom_openai_models
end

-- Check if a custom OpenAI model identifier corresponds to a valid configuration
-- Can be called with a model_id string or directly with a model_data table
function M.is_custom_openai_model_valid(model_identifier_or_data)
  local model_info
  if type(model_identifier_or_data) == 'string' then
    if not model_identifier_or_data or model_identifier_or_data == "" then return false end
    -- Ensure models are loaded if called with just an ID
    if vim.tbl_isempty(M.custom_openai_models) then
      M.load_custom_openai_models()
    end
    model_info = M.custom_openai_models[model_identifier_or_data]
  elseif type(model_identifier_or_data) == 'table' then
    model_info = model_identifier_or_data -- model_data was passed directly
  else
    return false -- Invalid argument
  end

  if not model_info then return false end

  -- If needs_auth is explicitly false, model is valid (even without API key name or set key)
  if model_info.needs_auth == false then
    model_info.is_valid = true
    return true
  end

  -- If needs_auth is true (or default), api_key_name must exist and key must be set
  if model_info.api_key_name and model_info.api_key_name ~= "" then
    if keys_manager.is_key_set(model_info.api_key_name) then
      model_info.is_valid = true
      return true
    else
      if config.get("debug") then
        vim.notify("API key '" .. model_info.api_key_name .. "' not set for custom model: " .. model_info.model_id, vim.log.levels.DEBUG)
      end
      model_info.is_valid = false
      return false
    end
  else
    -- needs_auth is true but no api_key_name defined
    if config.get("debug") then
      vim.notify("Custom model '" .. model_info.model_id .. "' requires auth but no api_key_name is defined.", vim.log.levels.DEBUG)
    end
    model_info.is_valid = false
    return false
  end
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

  local sample_content = [[# Sample extra-openai-models.yaml
# This file allows defining custom OpenAI-compatible models or overriding properties.
# Models are defined as a YAML list.
#
# - model_id: (Required) The unique identifier for the model.
#   model_name: (Optional) A user-friendly display name. Defaults to model_id.
#   api_base: (Optional) The base URL for the API.
#               Example: https://api.example.com/v1
#   api_key_name: (Optional) The name of the key to use from keys.json.
#                 Required if 'needs_auth' is true or not specified.
#                 Example: my_custom_api_key
#   headers: (Optional) Custom headers to send with requests.
#            Can be a JSON string or a YAML map.
#            Example as JSON string: '{"X-My-Header": "value"}'
#            Example as YAML map:
#              X-My-Header: value
#              Authorization: Bearer your_static_token # If token is static and not from keys.json
#   needs_auth: (Optional) Whether this model requires an API key via 'api_key_name'.
#               Default: true
#   supports_functions: (Optional) Whether this model supports function calling.
#                       Default: false
#   supports_system_prompt: (Optional) Whether this model supports system prompts.
#                           Default: true

- model_id: my-custom-gpt4-turbo
  model_name: My Custom GPT-4 Turbo (Needs Auth)
  api_base: https://my.openai.proxy/v1
  api_key_name: my_proxy_key # Must be set in keys.json
  # headers: '{"X-Custom-Billing-ID": "project-123"}' # Example JSON string for headers
  # supports_functions: true # Uncomment if it supports functions

- model_id: anyscale-llama3-70b
  model_name: Anyscale Llama3 70B
  api_base: https://api.endpoints.anyscale.com/v1
  api_key_name: anyscale_token # Must be set in keys.json
  supports_functions: true
  supports_system_prompt: true

- model_id: local-model-no-auth
  model_name: Local Model (No Auth)
  api_base: http://localhost:1234/v1
  needs_auth: false # No API key needed
  supports_system_prompt: false
  # headers: # Example YAML map for headers
  #   X-Forwarded-To: "llm-nvim"

# - model_id: azure-deployment-id # Example for Azure
#   model_name: Azure GPT-4 Turbo
#   api_base: https://your-resource.openai.azure.com/openai/deployments/YOUR_DEPLOYMENT_ID
#   api_key_name: azure_openai_key # Key for your Azure OpenAI service in keys.json
#   # For Azure, 'api-version' is often required in headers or as a query param.
#   # If using headers:
#   # headers:
#   #   api-key: Will be overridden by keys.json if api_key_name is also set.
#   #            Prefer api_key_name for dynamic keys.
#   #   Api-Version: "2024-02-15-preview" # Or your desired API version
#   # If needs_auth is true (default), the key from api_key_name will be added
#   # to headers as 'Authorization: Bearer <key_value>'.
#   # If your Azure setup needs 'api-key' header instead, manage it through static headers
#   # and potentially set needs_auth: false if the key is only in the header.
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

-- Helper function to serialize a list of models to YAML
local function serialize_to_yaml(models_list)
  local yaml_lines = {}
  if not models_list or #models_list == 0 then
    return ""
  end

  for _, model in ipairs(models_list) do
    if model.model_id and model.model_id ~= "" then
      table.insert(yaml_lines, "- model_id: " .. model.model_id)

      if model.model_name and model.model_name ~= "" and model.model_name ~= model.model_id then
        table.insert(yaml_lines, "  model_name: " .. model.model_name)
      end
      if model.api_base and model.api_base ~= "" then
        table.insert(yaml_lines, "  api_base: " .. model.api_base)
      end
      if model.api_key_name and model.api_key_name ~= "" then
        table.insert(yaml_lines, "  api_key_name: " .. model.api_key_name)
      end

      -- Handle headers: serialize table to JSON string
      if model.headers then
        if type(model.headers) == 'table' and not vim.tbl_isempty(model.headers) then
          local success, json_str = pcall(vim.fn.json_encode, model.headers)
          if success then
            -- Represent JSON string as a YAML string literal (e.g., using single quotes)
            table.insert(yaml_lines, "  headers: '" .. json_str:gsub("'", "''") .. "'")
          elseif config.get("debug") then
            vim.notify("Failed to serialize headers table to JSON for model " .. model.model_id, vim.log.levels.WARN)
          end
        elseif type(model.headers) == 'string' and model.headers ~= "" then
           -- If it's already a string (presumably JSON), quote it properly for YAML
           table.insert(yaml_lines, "  headers: '" .. model.headers:gsub("'", "''") .. "'")
        end
      end

      if model.needs_auth == false then -- Only write if explicitly false (default is true)
        table.insert(yaml_lines, "  needs_auth: false")
      end
      if model.supports_functions == true then -- Only write if explicitly true (default is false)
        table.insert(yaml_lines, "  supports_functions: true")
      end
      if model.supports_system_prompt == false then -- Only write if explicitly false (default is true)
        table.insert(yaml_lines, "  supports_system_prompt: false")
      end
    else
      if config.get("debug") then
        vim.notify("Skipping serialization of model due to missing model_id: " .. vim.inspect(model), vim.log.levels.WARN)
      end
    end
  end
  return table.concat(yaml_lines, "\n") .. "\n"
end

-- Add a new custom OpenAI model to the extra-openai-models.yaml file
function M.add_custom_openai_model(model_details)
  if not model_details or not model_details.model_id or model_details.model_id == "" then
    return false, "model_id is required"
  end

  local _, yaml_path = utils.get_config_path("extra-openai-models.yaml")
  if not yaml_path then
    return false, "Could not determine or create config directory for extra-openai-models.yaml"
  end

  local models_list = {}
  local file = io.open(yaml_path, "r")
  if file then
    local content = file:read("*a")
    file:close()
    if content and content ~= "" then
      local parsed_data = utils.parse_simple_yaml(yaml_path)
      if type(parsed_data) == 'table' then
        local is_list = true
        local count = 0
        for k, _ in pairs(parsed_data) do count = count + 1; if type(k) ~= 'number' or k < 1 then is_list = false; break end end
        if count > 0 and not parsed_data[1] then is_list = false end
        if #parsed_data ~= count then is_list = false end

        if is_list then
          models_list = parsed_data
        else
          if config.get("debug") then vim.notify("YAML content in " .. yaml_path .. " is not a list. Backing up.", vim.log.levels.WARN) end
          local backup_path = yaml_path .. ".non_list_backup." .. os.time()
          os.rename(yaml_path, backup_path)
          vim.notify("Backed up non-list YAML to: " .. backup_path, vim.log.levels.WARN)
          models_list = {}
        end
      else
        if config.get("debug") then vim.notify("Failed to parse YAML in " .. yaml_path .. ". Backing up.", vim.log.levels.WARN) end
        local backup_path = yaml_path .. ".parse_failed_backup." .. os.time()
        os.rename(yaml_path, backup_path)
        vim.notify("Backed up unparsable YAML to: " .. backup_path, vim.log.levels.WARN)
        models_list = {}
      end
    end
  end

  -- Prepare the new model entry with defaults for new fields
  local new_model_entry = {
    model_id = model_details.model_id,
    model_name = (model_details.model_name and model_details.model_name ~= "") and model_details.model_name or model_details.model_id,
    api_base = (model_details.api_base and model_details.api_base ~= "") and model_details.api_base or DEFAULT_MODEL_PROPERTIES.api_base,
    api_key_name = (model_details.api_key_name and model_details.api_key_name ~= "") and model_details.api_key_name or DEFAULT_MODEL_PROPERTIES.api_key_name,
    needs_auth = (model_details.needs_auth == nil) and DEFAULT_MODEL_PROPERTIES.needs_auth or model_details.needs_auth,
    supports_functions = (model_details.supports_functions == nil) and DEFAULT_MODEL_PROPERTIES.supports_functions or model_details.supports_functions,
    supports_system_prompt = (model_details.supports_system_prompt == nil) and DEFAULT_MODEL_PROPERTIES.supports_system_prompt or model_details.supports_system_prompt,
    headers = DEFAULT_MODEL_PROPERTIES.headers,
  }

  if model_details.headers then
    if type(model_details.headers) == 'table' then
      new_model_entry.headers = model_details.headers
    elseif type(model_details.headers) == 'string' and model_details.headers ~= "" then
      local success, decoded = pcall(vim.fn.json_decode, model_details.headers)
      if success and type(decoded) == 'table' then
        new_model_entry.headers = decoded
      else
        if config.get("debug") then vim.notify("Could not parse headers JSON string when adding model: " .. model_details.headers, vim.log.levels.WARN) end
         -- Store as string if not parsable as table, serializer will handle it.
        new_model_entry.headers = model_details.headers
      end
    end
  end

  table.insert(models_list, new_model_entry)
  local yaml_content = serialize_to_yaml(models_list)

  local out_file = io.open(yaml_path, "w")
  if not out_file then
    return false, "Failed to open YAML file for writing: " .. yaml_path
  end

  out_file:write(yaml_content)
  out_file:close()

  -- Clear the cache so it reloads next time
  M.custom_openai_models = {}

  return true, nil -- Success, no error message
end

return M
