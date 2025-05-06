-- llm/loaders/schemas_loader.lua - Schema loading functionality for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local utils = require('llm.utils')
local config = require('llm.config')
local api = vim.api

-- Get all schemas from llm CLI
function M.get_schemas()
  if not utils.check_llm_installed() then
    return {}
  end

  -- Use vim.fn.system for better compatibility
  local result = vim.fn.system("llm schemas")
  local success = vim.v.shell_error == 0

  if not success then
    if config.get("debug") then
      vim.notify("Error executing 'llm schemas': " .. result, vim.log.levels.ERROR)
    end
    return {}
  end

  if not result or result == "" then
    return {}
  end

  local schemas = {}
  local current_id = nil
  local current_summary = nil

  for line in result:gmatch("[^\r\n]+") do
    -- Parse schema ID and summary
    local id = line:match("^%s*%-%s+id:%s+([0-9a-f]+)")
    if id then
      current_id = id
      current_summary = ""
    elseif current_id and line:match("^%s+summary:%s+|") then
      -- Start of summary
      current_summary = ""
    elseif current_id and current_summary ~= nil and line:match("^%s+") then
      -- Continue summary
      local summary_line = line:gsub("^%s+", "")
      if current_summary == "" then
        current_summary = summary_line
      else
        current_summary = current_summary .. "\n" .. summary_line
      end
      schemas[current_id] = current_summary
    end
  end

  -- Load named schemas from configuration
  local _, schema_config_file = utils.get_config_path("schemas.json") -- Capture the second return value (full path)
  if not schema_config_file then
    vim.notify("Could not determine path for schemas.json", vim.log.levels.ERROR)
    return schemas -- Return potentially incomplete list if path fails
  end
  local schema_names_to_ids = {}

  -- The directory is now ensured by utils.get_config_path
  -- local config_dir = utils.get_config_path("") -- No longer needed here
  -- os.execute("mkdir -p " .. config_dir) -- No longer needed here

  local config_file = io.open(schema_config_file, "r")
  if config_file then
    local content = config_file:read("*all")
    config_file:close()

    if content and content ~= "" then
      local success, parsed = pcall(vim.fn.json_decode, content)
      if success and parsed then
        schema_names_to_ids = parsed

        -- Add named schemas to the result
        for name, id_val in pairs(parsed) do
          local schema_id_str -- To store the validated string ID

          -- Validate that id_val is a string and looks like a schema ID (hexadecimal)
          if type(id_val) ~= "string" or not id_val:match("^[0-9a-f]+$") then
            if config.get("debug") then
              vim.notify(
                "Skipping invalid schema entry in schemas.json: name=" .. name .. ", value=" .. vim.inspect(id_val),
                vim.log.levels.WARN)
            end
            goto continue -- Skip processing this entry
          end

          -- Use the validated string ID
          schema_id_str = id_val

          if schemas[schema_id_str] then
            -- Add the name to the description, ensuring the summary is a string
            if type(schemas[schema_id_str]) == "string" then
              schemas[schema_id_str] = "[" .. name .. "] " .. schemas[schema_id_str]
            else
              -- Handle case where schema summary wasn't parsed correctly or is missing
              schemas[schema_id_str] = "[" .. name .. "] Schema (summary error)"
              if config.get("debug") then
                vim.notify("Warning: Summary for schema " .. schema_id_str .. " was not a string.", vim.log.levels.WARN)
              end
            end
          else
            -- Schema exists in config but not in llm CLI output
            schemas[schema_id_str] = "[" .. name .. "] Schema from configuration"

            if config.get("debug") then
              -- Concatenation is safe now because schema_id_str is a validated string
              vim.notify("Found schema in config but not in llm CLI: " .. schema_id_str .. " (" .. name .. ")",
                vim.log.levels.DEBUG)
            end
          end
          ::continue:: -- Label for goto
        end
      else
        if config.get("debug") then
          vim.notify("Failed to parse schemas.json: " .. tostring(content), vim.log.levels.ERROR)
        end

        -- Try to recover the file if it's corrupted
        if content and content ~= "" then
          -- Backup the corrupted file (schema_config_file now holds the correct full path)
          local backup_file = schema_config_file .. ".bak"
          local backup = io.open(backup_file, "w")
          if backup then
            backup:write(content)
            backup:close()
            vim.notify("Backed up corrupted schemas.json to " .. backup_file, vim.log.levels.WARN)
          end

          -- Create a new empty file
          local new_file = io.open(schema_config_file, "w")
          if new_file then
            new_file:write("{}")
            new_file:close()
            vim.notify("Created new empty schemas.json file", vim.log.levels.INFO)
          end
        end
      end
    else
      -- Create an empty config file if it doesn't exist or is empty
      local new_file = io.open(schema_config_file, "w")
      if new_file then
        new_file:write("{}")
        new_file:close()

        if config.get("debug") then
          vim.notify("Created new empty schemas.json file", vim.log.levels.DEBUG)
        end
      end
    end
  else
    -- Create an empty config file if it doesn't exist
    local new_file = io.open(schema_config_file, "w")
    if new_file then
      new_file:write("{}")
      new_file:close()

      if config.get("debug") then
        vim.notify("Created new empty schemas.json file", vim.log.levels.DEBUG)
      end
    end
  end

  -- Debug output
  if config.get("debug") then
    vim.notify("Found schemas: " .. vim.inspect(schemas), vim.log.levels.DEBUG)
  end

  return schemas
end

-- Get schema ID by name
function M.get_schema_id_by_name(name)
  if not name or name == "" or name == "nil" then
    if require('llm.config').get("debug") then
      vim.notify("Invalid schema name: " .. tostring(name), vim.log.levels.DEBUG)
    end
    return nil
  end

  -- Check if the name is already a valid schema ID (hexadecimal)
  if type(name) == "string" and name:match("^[0-9a-f]+$") then
    return name
  end

  -- Load schema configuration
  local _, schema_config_file = utils.get_config_path("schemas.json") -- Capture the second return value
  if not schema_config_file then
    if require('llm.config').get("debug") then
      vim.notify("Could not get schema config file path", vim.log.levels.DEBUG)
    end
    return nil
  end

  local config_file = io.open(schema_config_file, "r")
  if not config_file then
    if require('llm.config').get("debug") then
      vim.notify("Could not open schema config file: " .. schema_config_file, vim.log.levels.DEBUG)
    end
    return nil
  end

  local content = config_file:read("*all")
  config_file:close()

  if not content or content == "" then
    if require('llm.config').get("debug") then
      vim.notify("Schema config file is empty", vim.log.levels.DEBUG)
    end
    return nil
  end

  local success, parsed = pcall(vim.fn.json_decode, content)
  if not success or not parsed then
    if require('llm.config').get("debug") then
      vim.notify("Failed to parse schema config JSON", vim.log.levels.DEBUG)
    end
    return nil
  end

  -- Return the schema ID for the given name
  local schema_id = parsed[name]

  if not schema_id then
    if require('llm.config').get("debug") then
      vim.notify("No schema ID found for name: " .. name, vim.log.levels.DEBUG)
    end
  end

  return schema_id
end

-- Get schema details from llm CLI
function M.get_schema(schema_id_or_name)
  if not utils.check_llm_installed() then
    return nil
  end

  -- Convert name to ID if needed
  local schema_id = M.get_schema_id_by_name(schema_id_or_name)
  if not schema_id then
    schema_id = schema_id_or_name
  end

  -- Get the schema name if available
  local schema_name = nil
  local _, schema_config_file = utils.get_config_path("schemas.json") -- Capture the second return value
  if schema_config_file then                                          -- Check if path was determined
    local config_file = io.open(schema_config_file, "r")
    if config_file then
      local content = config_file:read("*all")
      config_file:close()

      if content and content ~= "" then
        local success, parsed = pcall(vim.fn.json_decode, content)
        if success and parsed then
          for name, id in pairs(parsed) do
            if id == schema_id then
              schema_name = name
              break
            end
          end
        end
      end
    end
  end

  -- Always fetch the schema details from the llm CLI output
  -- Fetch the full output and parse it in Lua for robustness
  local schema_content = nil -- Initialize schema_content
  local cmd = "llm schemas --full"
  local result = vim.fn.system(cmd)
  local success = vim.v.shell_error == 0

  if not success then
    if config.get("debug") then
      vim.notify("Error getting schema details: " .. result, vim.log.levels.ERROR)
    end
    return nil
  end

  if not result or result == "" then
    return nil
  end

  -- Parse the full output to find the correct schema section
  local schema_text = ""
  local found_target_id = false
  local looking_for_schema_start = false
  local in_target_schema_section = false
  local schema_start_pattern = "^%s+schema:%s*"
  local id_pattern = "^%s*%-%s*id:%s+([0-9a-f]+)"
  local usage_pattern = "^%s+usage:%s*"

  -- Add more debug output
  if config.get("debug") then
    vim.notify("Searching for schema ID: " .. schema_id, vim.log.levels.DEBUG)
    vim.notify("First 100 chars of result: " .. result:sub(1, 100), vim.log.levels.DEBUG)
  end

  for line in result:gmatch("[^\r\n]+") do
    -- Debug each line if needed
    if config.get("debug") then
      vim.notify("Processing line: " .. line, vim.log.levels.DEBUG)
    end

    -- Check for ID line with more flexible pattern
    local id_match = line:match(id_pattern)
    if id_match and id_match == schema_id then
      if config.get("debug") then vim.notify("Found target ID line: " .. line, vim.log.levels.DEBUG) end
      found_target_id = true
      looking_for_schema_start = true
      in_target_schema_section = false
      schema_text = ""
      goto continue
    end

    if found_target_id and looking_for_schema_start then
      -- Look for the 'schema:' line with more flexible matching
      if line:match(schema_start_pattern) then
        if config.get("debug") then vim.notify("Found schema start line: " .. line, vim.log.levels.DEBUG) end
        looking_for_schema_start = false
        in_target_schema_section = true
        schema_text = "" -- Initialize schema text
      elseif line:match(id_pattern) then
        -- Found another ID before finding the schema start for the target ID
        if config.get("debug") then
          vim.notify("Found next ID before schema start for " .. schema_id, vim.log.levels
            .WARN)
        end
        found_target_id = false
        looking_for_schema_start = false
      end
    elseif in_target_schema_section then
      -- Check if we've reached the usage section or another schema
      if line:match(usage_pattern) or line:match(id_pattern) then
        if config.get("debug") then 
          vim.notify("End of schema section detected: " .. line, vim.log.levels.DEBUG) 
        end
        in_target_schema_section = false
        break -- We have collected the schema, break the loop
      end
      
      -- Collect indented lines belonging to the schema
      if line:match("^%s+") then
        -- This line is part of the schema content
        local schema_line = line:gsub("^%s+", "")
        if schema_text == "" then
          schema_text = schema_line
        else
          schema_text = schema_text .. "\n" .. schema_line
        end
      else
        -- Line is not indented, means the schema section ended
        if config.get("debug") then vim.notify("End of schema section detected: " .. line, vim.log.levels.DEBUG) end
        in_target_schema_section = false
        break -- We have collected the schema, break the loop
      end
    end

    ::continue::
  end -- End of loop through lines

  -- If we didn't find the schema but found the ID, try a more aggressive approach
  if found_target_id and schema_text == "" then
    if config.get("debug") then vim.notify("Trying alternative parsing approach", vim.log.levels.DEBUG) end

    -- Reset flags
    found_target_id = false
    in_target_schema_section = false

    -- Try to find the schema section with a different approach
    for line in result:gmatch("[^\r\n]+") do
      if not found_target_id then
        if line:match(".*" .. schema_id .. ".*") then
          found_target_id = true
          if config.get("debug") then vim.notify("Alt approach: Found ID in line: " .. line, vim.log.levels.DEBUG) end
        end
      elseif not in_target_schema_section then
        if line:match(".*schema:.*") then
          in_target_schema_section = true
          if config.get("debug") then
            vim.notify("Alt approach: Found schema marker in line: " .. line,
              vim.log.levels.DEBUG)
          end
        end
      elseif in_target_schema_section then
        if line:match("^%s+") then
          local schema_line = line:gsub("^%s+", "")
          if schema_text == "" then
            schema_text = schema_line
          else
            schema_text = schema_text .. "\n" .. schema_line
          end
        else
          break
        end
      end
    end
  end

  -- After the loop, check if we successfully extracted text
  if schema_text ~= "" then
    if config.get("debug") then vim.notify("Successfully parsed schema text for " .. schema_id, vim.log.levels.DEBUG) end
    
    -- Try more aggressive JSON fixing
    local fixed_text = schema_text
    
    -- First attempt: Try to fix truncated JSON by adding missing closing braces/brackets
    local open_braces = select(2, schema_text:gsub("{", ""))
    local close_braces = select(2, schema_text:gsub("}", ""))
    local open_brackets = select(2, schema_text:gsub("%[", ""))
    local close_brackets = select(2, schema_text:gsub("%]", ""))
    
    -- Add missing closing braces
    for i = 1, (open_braces - close_braces) do
      fixed_text = fixed_text .. "}"
    end
    
    -- Add missing closing brackets
    for i = 1, (open_brackets - close_brackets) do
      fixed_text = fixed_text .. "]"
    end
    
    -- Second attempt: Try to fix common JSON syntax errors
    -- Fix missing quotes around property names
    fixed_text = fixed_text:gsub("([{,]%s*)([%w_-]+)(%s*:)", '%1"%2"%3')
    
    -- Fix missing commas between properties
    fixed_text = fixed_text:gsub('(["]}])%s*\n%s*(["{[])', '%1,%2')
    
    -- Fix trailing commas
    fixed_text = fixed_text:gsub(',(%s*[}%]])', '%1')
    
    -- Try parsing the fixed text
    local is_valid_json, parsed_content = pcall(vim.fn.json_decode, fixed_text)
    if is_valid_json then
      if config.get("debug") then
        vim.notify("Successfully fixed JSON schema", vim.log.levels.INFO)
      end
      
      -- Format the fixed JSON
      local formatted_success, formatted = pcall(function()
        return vim.json.encode(parsed_content, { indent = 2 })
      end)
      
      if formatted_success and formatted then
        schema_content = formatted
      else
        schema_content = fixed_text
      end
    else
      -- If JSON parsing failed, try one more approach with a minimal schema
      if config.get("debug") then
        vim.notify("Could not parse JSON, creating minimal valid schema", vim.log.levels.WARN)
      end
      
      -- Create a minimal valid schema
      schema_content = [[{
  "type": "object",
  "properties": {
    "content": {
      "type": "string",
      "description": "Content extracted from schema"
    }
  },
  "required": ["content"]
}]]
    end
  else
    -- If schema_text is empty after parsing, we didn't find the schema content
    if config.get("debug") then
      vim.notify("Failed to parse schema content from llm output for ID: " .. schema_id, vim.log.levels.WARN)

      -- Print more detailed debug info
      vim.notify("Schema ID being searched for: " .. schema_id, vim.log.levels.DEBUG)

      -- Check if the ID exists in the output at all
      if result:find(schema_id) then
        vim.notify("Schema ID " .. schema_id .. " was found in the output but schema content couldn't be parsed",
          vim.log.levels.DEBUG)

        -- Try to extract the context around the ID
        local start_pos = result:find(schema_id)
        if start_pos then
          local context_start = math.max(1, start_pos - 50)
          local context_end = math.min(#result, start_pos + 150)
          local context = result:sub(context_start, context_end)
          vim.notify("Context around schema ID:\n" .. context, vim.log.levels.DEBUG)
        end
      else
        vim.notify("Schema ID " .. schema_id .. " was NOT found in the output at all", vim.log.levels.DEBUG)
      end

      -- Only log raw output if debug is enabled, as it can be large and spammy
      vim.notify("Raw llm output (first 500 chars):\n" .. result:sub(1, 500), vim.log.levels.DEBUG)
    end

    if not schema_content then
      return nil -- Explicitly return nil if parsing failed
    end
  end

  -- Save to local file if we have a name and schema content
  if schema_name and schema_content then
    local config_dir, _ = utils.get_config_path("schemas")        -- Get the base config directory
    if config_dir then
      local schema_dir_path = config_dir .. "/schemas"            -- Construct path to 'schemas' subdir
      -- Create the directory if it doesn't exist
      os.execute(string.format("mkdir -p '%s'", schema_dir_path)) -- Quote path for safety

      local schema_file = schema_dir_path .. "/" .. schema_name .. ".json"
      local file = io.open(schema_file, "w")
      if file then
        file:write(schema_content)
        file:close()
        if config.get("debug") then
          vim.notify("Saved schema to file: " .. schema_file, vim.log.levels.DEBUG)
        end
      else
        if config.get("debug") then
          vim.notify("Failed to open schema file for writing: " .. schema_file, vim.log.levels.WARN)
        end
      end
    end
  elseif schema_name and not schema_content then
    if config.get("debug") then
      vim.notify("Cannot save schema file: schema_content is nil", vim.log.levels.WARN)
    end
  end

  -- Return the successfully parsed schema details from CLI
  return {
    id = schema_id,
    name = schema_name, -- May be nil if no alias exists yet
    content = schema_content
  }
end

-- Save a schema using llm CLI by running a query to log it
function M.save_schema(name, schema_text)
  if not utils.check_llm_installed() then
    return false
  end

  -- Clean up the schema text to ensure it's valid JSON
  schema_text = schema_text:gsub("Press <Esc>.-$", "")
  schema_text = schema_text:gsub("\n+$", "")

  -- Validate the schema JSON
  local success, parsed_schema = pcall(vim.fn.json_decode, schema_text)
  if not success then
    vim.notify("Invalid JSON schema format. Please check your syntax.", vim.log.levels.ERROR)
    if config.get("debug") then
      vim.notify("JSON error: " .. tostring(parsed_schema), vim.log.levels.DEBUG)
      vim.notify("Schema text: " .. schema_text, vim.log.levels.DEBUG)
    end
    return false
  end

  -- Use fixed, valid temporary filenames
  local temp_dir = vim.fn.stdpath("cache") .. "/llm_nvim_temp"
  os.execute("mkdir -p " .. temp_dir) -- Ensure temp dir exists
  local temp_schema_file = temp_dir .. "/schema_to_save.json"
  local temp_input_file = temp_dir .. "/dummy_input.txt"

  -- Create a temporary file for the schema with proper JSON
  local file = io.open(temp_schema_file, "w")
  if not file then
    vim.notify("Failed to create temporary file for schema: " .. temp_schema_file, vim.log.levels.ERROR)
    vim.notify("Failed to create temporary file for schema", vim.log.levels.ERROR)
    return false
  end

  -- Write the validated JSON to the file
  local formatted_json = vim.fn.json_encode(parsed_schema)
  file:write(formatted_json)
  file:close()

  -- Create a temporary file for dummy input
  local input = io.open(temp_input_file, "w")
  if not input then
    vim.notify("Failed to create temporary file for input: " .. temp_input_file, vim.log.levels.ERROR)
    os.remove(temp_schema_file)
    return false
  end

  input:write("This is a dummy input to log the schema.")
  input:close()

  -- Get the schema ID from the logged schemas
  local schemas_before = M.get_schemas()
  local schemas_before_ids = {}
  for id, _ in pairs(schemas_before) do
    schemas_before_ids[id] = true
  end

  -- Run the command to save the schema using the fixed temp filenames
  local cmd = string.format("cat '%s' | llm --schema '%s'", temp_input_file, temp_schema_file)

  if config.get("debug") then
    vim.notify("Schema save command: " .. cmd, vim.log.levels.DEBUG)
    vim.notify("Schema JSON: " .. formatted_json, vim.log.levels.DEBUG)
  end

  -- Execute the command
  local result = vim.fn.system(cmd)
  local success = vim.v.shell_error == 0

  -- Clean up the temporary files
  os.remove(temp_schema_file)
  os.remove(temp_input_file)

  if not success then
    if config.get("debug") then
      vim.notify("Schema save output: " .. result, vim.log.levels.DEBUG)
      vim.notify("Schema save failed: " .. tostring(vim.v.shell_error), vim.log.levels.DEBUG)
    end
    vim.notify("Failed to save schema", vim.log.levels.ERROR)
    return false
  end

  -- Get the schemas again to find the new one
  local schemas_after = M.get_schemas()
  local newest_schema_id = nil

  -- Find the schema that wasn't in the before list
  for id, _ in pairs(schemas_after) do
    if not schemas_before_ids[id] then
      newest_schema_id = id
      if config.get("debug") then
        vim.notify("Found new schema ID: " .. id, vim.log.levels.DEBUG)
      end
      break
    end
  end

  -- If we couldn't find a new schema, try to get the most recent one
  if not newest_schema_id then
    for id, _ in pairs(schemas_after) do
      newest_schema_id = id
      if config.get("debug") then
        vim.notify("Using most recent schema ID as fallback: " .. id, vim.log.levels.DEBUG)
      end
      break
    end
  end

  if newest_schema_id then
    -- Save the schema name and ID mapping in a configuration file
    local config_dir, schema_config_file = utils.get_config_path("schemas.json") -- Capture both values
    if not schema_config_file then
      vim.notify("Failed to get path for schemas.json", vim.log.levels.ERROR)
      return false
    end

    -- Ensure the config directory exists
    utils.ensure_config_dir_exists(config_dir)

    local schema_config = {}

    -- Try to load existing config
    local config_file = io.open(schema_config_file, "r")
    if config_file then
      local content = config_file:read("*all")
      config_file:close()

      if content and content ~= "" then
        local success, parsed = pcall(vim.fn.json_decode, content)
        if success and parsed then
          schema_config = parsed
        end
      end
    end

    -- Add or update the schema mapping
    schema_config[name] = newest_schema_id

    -- Save the updated config
    config_file = io.open(schema_config_file, "w")
    if config_file then
      config_file:write(vim.fn.json_encode(schema_config))
      config_file:close()

      if require('llm.config').get("debug") then
        vim.notify("Saved schema alias '" .. name .. "' for ID: " .. newest_schema_id, vim.log.levels.DEBUG)
      end

      -- Create a local copy of the schema for faster access
      local config_dir, _ = utils.get_config_path("schemas")        -- Get base config dir
      if config_dir then
        local schema_dir_path = config_dir .. "/schemas"            -- Construct path to 'schemas' subdir
        -- Create the directory if it doesn't exist
        os.execute(string.format("mkdir -p '%s'", schema_dir_path)) -- Quote path

        local schema_file = schema_dir_path .. "/" .. name .. ".json"
        local schema_copy = io.open(schema_file, "w")
        if schema_copy then
          schema_copy:write(formatted_json)
          schema_copy:close()
        end
      end

      -- Verify the alias was set correctly
      local verify_file = io.open(schema_config_file, "r")
      if verify_file then
        local content = verify_file:read("*all")
        verify_file:close()

        if content and content ~= "" then
          local success, parsed = pcall(vim.fn.json_decode, content)
          if success and parsed and parsed[name] == newest_schema_id then
            if require('llm.config').get("debug") then
              vim.notify("Schema alias verified in config file", vim.log.levels.DEBUG)
            end
          else
            vim.notify("Schema alias may not have been saved correctly", vim.log.levels.WARN)
          end
        end
      end

      vim.notify("Schema '" .. name .. "' saved with ID: " .. newest_schema_id, vim.log.levels.INFO)
      return true
    else
      vim.notify("Failed to save schema configuration", vim.log.levels.ERROR)
    end
  else
    vim.notify("Failed to get schema ID after saving", vim.log.levels.ERROR)
  end

  return false
end

-- Set an alias for a schema
function M.set_schema_alias(schema_id, alias)
  if not utils.check_llm_installed() then
    return false
  end

  -- Get the schema to make sure it exists
  local schema = M.get_schema(schema_id)
  if not schema then
    vim.notify("Schema not found: " .. schema_id, vim.log.levels.ERROR)
    return false
  end

  -- Load existing schema configuration
  local config_dir, schema_config_file = utils.get_config_path("schemas.json") -- Capture both return values
  if not schema_config_file then
    vim.notify("Failed to get path for schemas.json", vim.log.levels.ERROR)
    return false
  end
  local schema_config = {}

  local config_file = io.open(schema_config_file, "r")
  if config_file then
    local content = config_file:read("*all")
    config_file:close()

    if content and content ~= "" then
      local success, parsed = pcall(vim.fn.json_decode, content)
      if success and parsed then
        schema_config = parsed
      end
    end
  end

  -- Check if the alias is already used for a different schema
  for name, id in pairs(schema_config) do
    if name == alias and id ~= schema_id then
      vim.notify("Alias '" .. alias .. "' is already used for another schema", vim.log.levels.WARN)
      -- Ask if the user wants to overwrite
      utils.floating_confirm({
        prompt = "Overwrite existing alias '" .. alias .. "'?",
        on_confirm = function(confirmed)
          if confirmed then
            M.set_schema_alias_internal(schema_id, alias, schema_config, schema)
          end
        end
      })
      return false
    end
  end

  -- Set the alias
  return M.set_schema_alias_internal(schema_id, alias, schema_config, schema)
end

-- Remove an alias for a schema
function M.remove_schema_alias(schema_id, specific_alias)
  if not utils.check_llm_installed() then
    return false
  end

  -- Load existing schema configuration
  local config_dir, schema_config_file = utils.get_config_path("schemas.json")
  if not schema_config_file then
    vim.notify("Failed to get path for schemas.json", vim.log.levels.ERROR)
    return false
  end

  -- Ensure the config directory exists
  utils.ensure_config_dir_exists(config_dir)

  local schema_config = {}
  local aliases_to_remove = {}

  -- Load existing config
  local config_file = io.open(schema_config_file, "r")
  if config_file then
    local content = config_file:read("*all")
    config_file:close()

    if content and content ~= "" then
      local success, parsed = pcall(vim.fn.json_decode, content)
      if success and parsed then
        schema_config = parsed

        -- Find all aliases for this schema ID
        for name, id in pairs(parsed) do
          if id == schema_id then
            table.insert(aliases_to_remove, name)
          end
        end
      end
    end
  end

  if #aliases_to_remove == 0 then
    vim.notify("No aliases found for schema ID: " .. schema_id, vim.log.levels.WARN)
    return false
  end

  -- If a specific alias was provided, use that one
  local alias_to_remove = nil
  if specific_alias then
    -- Check if the specific alias exists for this schema
    local found = false
    for _, alias in ipairs(aliases_to_remove) do
      if alias == specific_alias then
        found = true
        alias_to_remove = specific_alias
        break
      end
    end

    if not found then
      vim.notify("Specified alias '" .. specific_alias .. "' not found for this schema", vim.log.levels.WARN)
      return false
    end
  elseif #aliases_to_remove == 1 then
    -- If there's only one alias, use that
    alias_to_remove = aliases_to_remove[1]
  end

  -- If we have an alias to remove at this point, remove it
  if alias_to_remove then
    -- Remove the alias
    schema_config[alias_to_remove] = nil

    -- Save the updated config
    config_file = io.open(schema_config_file, "w")
    if not config_file then
      vim.notify("Failed to open schema config file for writing", vim.log.levels.ERROR)
      return false
    end

    -- Ensure we write valid JSON with proper formatting
    local json_str = vim.fn.json_encode(schema_config)
    config_file:write(json_str)
    config_file:close()

    if config.get("debug") then
      vim.notify("Removed schema alias: " .. alias_to_remove, vim.log.levels.DEBUG)
      vim.notify("Updated schema config: " .. json_str, vim.log.levels.DEBUG)
    end

    -- Remove the schema file if it exists
    local schema_dir_path = config_dir .. "/schemas"
    if alias_to_remove then
      local schema_file = schema_dir_path .. "/" .. alias_to_remove .. ".json"
      os.remove(schema_file)

      if config.get("debug") then
        vim.notify("Removed schema file: " .. schema_file, vim.log.levels.DEBUG)
      end
    end

    vim.notify("Removed alias '" .. alias_to_remove .. "' for schema", vim.log.levels.INFO)
    return true
  end

  -- Return the list of aliases for the UI to handle
  return aliases_to_remove
end

-- Internal function to set schema alias
function M.set_schema_alias_internal(schema_id, alias, schema_config, schema)
  local config_dir, schema_config_file = utils.get_config_path("schemas.json") -- Capture both return values
  if not schema_config_file then
    vim.notify("Failed to get path for schemas.json", vim.log.levels.ERROR)
    return false
  end

  -- Ensure the config directory exists
  utils.ensure_config_dir_exists(config_dir)

  -- Remove any existing aliases for this schema
  local old_alias = nil
  for name, id in pairs(schema_config) do
    if id == schema_id then
      old_alias = name
      schema_config[name] = nil
    end
  end

  -- Add the new alias
  schema_config[alias] = schema_id

  -- Save the updated config
  local config_file, err = io.open(schema_config_file, "w")
  if not config_file then
    vim.notify("Failed to open schema config file for writing: " .. schema_config_file, vim.log.levels.ERROR)
    if err then
      vim.notify("System error: " .. err, vim.log.levels.ERROR)
    end
    return false
  end
  -- Ensure we write valid JSON with proper formatting
  local json_str = vim.fn.json_encode(schema_config)
  config_file:write(json_str)
  config_file:close()

  if config.get("debug") then
    vim.notify("Saved schema config: " .. json_str, vim.log.levels.DEBUG)
  end

  -- If we have schema content, save it to the new alias file
  if schema and schema.content then
    local config_dir, _ = utils.get_config_path("schemas")        -- Get base config dir
    if config_dir then
      local schema_dir_path = config_dir .. "/schemas"            -- Construct path to 'schemas' subdir
      -- Create schemas directory if it doesn't exist
      os.execute(string.format("mkdir -p '%s'", schema_dir_path)) -- Quote path

      -- Save schema content to the new alias file
      local schema_file = schema_dir_path .. "/" .. alias .. ".json"
      local file = io.open(schema_file, "w")
      if file then
        file:write(schema.content)
        file:close()

        if config.get("debug") then
          vim.notify("Saved schema content to: " .. schema_file, vim.log.levels.DEBUG)
        end
      end

      -- Remove old alias file if it exists
      if old_alias then
        local old_file = schema_dir_path .. "/" .. old_alias .. ".json"
        os.remove(old_file)

        if config.get("debug") then
          vim.notify("Removed old schema file: " .. old_file, vim.log.levels.DEBUG)
        end
      end
    end
  end

  -- Verify the config was saved correctly by reading it back
  local verify_file = io.open(schema_config_file, "r")
  if verify_file then
    local content = verify_file:read("*all")
    verify_file:close()

    if content and content ~= "" then
      local success, parsed = pcall(vim.fn.json_decode, content)
      if success and parsed and parsed[alias] == schema_id then
        if config.get("debug") then
          vim.notify("Schema alias verified in config file", vim.log.levels.DEBUG)
        end
      else
        vim.notify("Schema alias may not have been saved correctly", vim.log.levels.WARN)
      end
    end
  end

  return true
end

-- Run a schema with input
function M.run_schema(schema_id_or_name, input, is_multi)
  if not utils.check_llm_installed() then
    return nil
  end

  -- Convert name to ID if needed
  local schema_id = M.get_schema_id_by_name(schema_id_or_name)
  local schema_name = nil

  -- If we didn't get an ID from the name, use the original input as the ID
  if not schema_id then
    schema_id = schema_id_or_name
  end

  -- Validate that we have a valid schema ID
  if not schema_id or schema_id == "" or schema_id == "nil" then
    vim.notify("Invalid schema ID: " .. tostring(schema_id), vim.log.levels.ERROR)
    return nil
  end

  -- Check if we have a name for this schema ID
  local _, schema_config_file = utils.get_config_path("schemas.json") -- Capture full path
  if schema_config_file then
    local config_file = io.open(schema_config_file, "r")
    if config_file then
      local content = config_file:read("*all")
      config_file:close()

      if content and content ~= "" then
        local success, parsed = pcall(vim.fn.json_decode, content)
        if success and parsed then
          for name, id in pairs(parsed) do
            if id == schema_id then
              schema_name = name
              break
            end
          end
        end
      end
    end
  end

  -- Create a temporary file for the input with a more reliable path
  local temp_dir = vim.fn.stdpath('cache') .. "/llm_nvim_temp"
  os.execute("mkdir -p " .. temp_dir) -- Ensure temp dir exists

  -- Use a consistent naming pattern that matches what's used in schemas_manager.lua
  local schema_id_prefix = schema_id:sub(1, 8)
  local timestamp = os.time()
  local temp_file = temp_dir .. "/schema_input_" .. schema_id_prefix .. "_" .. timestamp .. ".txt"

  local file = io.open(temp_file, "w")
  if not file then
    vim.notify("Failed to create temporary file for schema input: " .. temp_file, vim.log.levels.ERROR)
    return nil
  end

  file:write(input)
  file:close()

  -- Debug: Show the input being passed to the schema
  if config.get("debug") then
    vim.notify("Schema input content length: " .. #input, vim.log.levels.DEBUG)
    vim.notify("Schema input content (first 100 chars):\n" .. input:sub(1, 100), vim.log.levels.DEBUG)
    vim.notify("Schema ID: " .. schema_id, vim.log.levels.DEBUG)
    vim.notify("Is multi: " .. tostring(is_multi), vim.log.levels.DEBUG)
  end

  -- Get the schema details to use the actual schema content
  local schema_details = M.get_schema(schema_id)
  if not schema_details or not schema_details.content then
    vim.notify("Schema not found or invalid. Please check the schema ID.", vim.log.levels.ERROR)
    os.remove(temp_file)
    return nil
  end

  -- Create a temporary file for the schema definition
  local schema_temp_file = temp_dir .. "/schema_def_" .. timestamp .. ".json"
  local schema_temp = io.open(schema_temp_file, "w")
  if not schema_temp then
    vim.notify("Failed to create temporary file for schema definition", vim.log.levels.ERROR)
    os.remove(temp_file)
    return nil
  end

  -- Write the schema content to the file
  schema_temp:write(schema_details.content)
  schema_temp:close()

  local cmd
  local schema_flag = is_multi and "--schema-multi" or "--schema"

  -- Use the schema ID directly - this is the most reliable approach
  cmd = string.format("cat '%s' | llm %s %s", temp_file, schema_flag, schema_id)

  -- Debug output
  if config.get("debug") then
    vim.notify("Running schema command: " .. cmd, vim.log.levels.DEBUG)
  end

  -- Debug the command
  if config.get("debug") then
    vim.notify("Running schema command: " .. cmd, vim.log.levels.DEBUG)
    vim.notify("Temp file path: " .. temp_file, vim.log.levels.DEBUG)
    vim.notify("Schema file path: " .. schema_temp_file, vim.log.levels.DEBUG)

    -- Verify the temp files exist
    if vim.fn.filereadable(temp_file) == 1 then
      vim.notify("Input file exists and is readable", vim.log.levels.DEBUG)
      local file_size = vim.fn.getfsize(temp_file)
      vim.notify("Input file size: " .. file_size .. " bytes", vim.log.levels.DEBUG)
    else
      vim.notify("WARNING: Input file does not exist or is not readable!", vim.log.levels.WARN)
    end

    if vim.fn.filereadable(schema_temp_file) == 1 then
      vim.notify("Schema file exists and is readable", vim.log.levels.DEBUG)
      local file_size = vim.fn.getfsize(schema_temp_file)
      vim.notify("Schema file size: " .. file_size .. " bytes", vim.log.levels.DEBUG)
    else
      vim.notify("WARNING: Schema file does not exist or is not readable!", vim.log.levels.WARN)
    end
  end

  -- Use vim.fn.system for better compatibility
  local result = vim.fn.system(cmd)
  local success = vim.v.shell_error == 0

  -- Clean up the temporary files
  if vim.fn.filereadable(temp_file) == 1 then
    os.remove(temp_file)
    if config.get("debug") then
      vim.notify("Input file removed", vim.log.levels.DEBUG)
    end
  end

  if vim.fn.filereadable(schema_temp_file) == 1 then
    os.remove(schema_temp_file)
    if config.get("debug") then
      vim.notify("Schema file removed", vim.log.levels.DEBUG)
    end
  end

  if not success then
    -- Try the original command as fallback
    if config.get("debug") then
      vim.notify("Direct schema command failed, trying original command", vim.log.levels.DEBUG)
    end

    -- Recreate the input file since we deleted it
    local fallback_file = temp_dir .. "/schema_input_fallback_" .. timestamp .. ".txt"
    local fallback = io.open(fallback_file, "w")
    if fallback then
      fallback:write(input)
      fallback:close()

      -- Use the schema ID directly
      local fallback_cmd = string.format("cat '%s' | llm %s %s", fallback_file, schema_flag, schema_id)

      if config.get("debug") then
        vim.notify("Trying fallback command: " .. fallback_cmd, vim.log.levels.DEBUG)
      end

      result = vim.fn.system(fallback_cmd)
      success = vim.v.shell_error == 0

      os.remove(fallback_file)

      if not success then
        if config.get("debug") then
          vim.notify("Error running schema (both methods failed): " .. result, vim.log.levels.ERROR)
          vim.notify("Original command was: " .. cmd, vim.log.levels.DEBUG)
          vim.notify("Fallback command was: " .. fallback_cmd, vim.log.levels.DEBUG)
          vim.notify("Exit code: " .. tostring(vim.v.shell_error), vim.log.levels.DEBUG)
        end
        vim.notify("Failed to run schema. The schema may be invalid or incompatible with your input.",
          vim.log.levels.ERROR)
        return nil
      end
    else
      if config.get("debug") then
        vim.notify("Error running schema: " .. result, vim.log.levels.ERROR)
        vim.notify("Command was: " .. cmd, vim.log.levels.DEBUG)
        vim.notify("Exit code: " .. tostring(vim.v.shell_error), vim.log.levels.DEBUG)
      end
      vim.notify("Failed to run schema. Check your input and schema ID.", vim.log.levels.ERROR)
      return nil
    end
  end

  -- Check if result is empty
  if not result or result == "" then
    if config.get("debug") then
      vim.notify("Schema returned empty result", vim.log.levels.WARN)
    end
    vim.notify("Schema returned empty result. Check your input format.", vim.log.levels.WARN)
    return "{}"; -- Return empty JSON object instead of nil
  end

  -- Try to validate the result is proper JSON
  local is_valid_json = pcall(vim.fn.json_decode, result)
  if not is_valid_json then
    if config.get("debug") then
      vim.notify("Schema result is not valid JSON: " .. result:sub(1, 100), vim.log.levels.WARN)
    end
    vim.notify("Schema returned invalid JSON. The result will be shown as plain text.", vim.log.levels.WARN)
  end

  if config.get("debug") then
    vim.notify("Schema execution successful", vim.log.levels.DEBUG)
    vim.notify("Result length: " .. #result, vim.log.levels.DEBUG)
    vim.notify("Result (first 100 chars): " .. result:sub(1, 100), vim.log.levels.DEBUG)
  end

  return result
end

-- Run a schema with an existing file
function M.run_schema_with_file(schema_id_or_name, file_path, is_multi)
  if not utils.check_llm_installed() then
    return nil
  end

  -- Convert name to ID if needed
  local schema_id = M.get_schema_id_by_name(schema_id_or_name)
  local schema_name = nil

  -- If we didn't get an ID from the name, use the original input as the ID
  if not schema_id then
    schema_id = schema_id_or_name
  end

  -- Validate that we have a valid schema ID
  if not schema_id or schema_id == "" or schema_id == "nil" then
    vim.notify("Invalid schema ID: " .. tostring(schema_id), vim.log.levels.ERROR)
    return nil
  end

  -- Check if we have a name for this schema ID
  local _, schema_config_file = utils.get_config_path("schemas.json") -- Capture full path
  if schema_config_file then
    local config_file = io.open(schema_config_file, "r")
    if config_file then
      local content = config_file:read("*all")
      config_file:close()

      if content and content ~= "" then
        local success, parsed = pcall(vim.fn.json_decode, content)
        if success and parsed then
          for name, id in pairs(parsed) do
            if id == schema_id then
              schema_name = name
              break
            end
          end
        end
      end
    end
  end

  -- Verify the file exists
  if vim.fn.filereadable(file_path) ~= 1 then
    vim.notify("Input file does not exist or is not readable: " .. file_path, vim.log.levels.ERROR)
    return nil
  end

  -- Debug output
  if config.get("debug") then
    vim.notify("Using existing file for schema input: " .. file_path, vim.log.levels.DEBUG)
    local file_size = vim.fn.getfsize(file_path)
    vim.notify("File size: " .. file_size .. " bytes", vim.log.levels.DEBUG)
    vim.notify("Schema ID: " .. schema_id, vim.log.levels.DEBUG)
    vim.notify("Is multi: " .. tostring(is_multi), vim.log.levels.DEBUG)
  end

  local cmd
  local schema_flag = is_multi and "--schema-multi" or "--schema"

  -- Prioritize using the schema ID if it's valid
  if schema_id and type(schema_id) == "string" and schema_id:match("^[0-9a-f]+$") then
    -- Use the schema ID with the existing file
    cmd = string.format("cat '%s' | llm %s %s", file_path, schema_flag, schema_id)
  else
    -- If not a valid ID, treat the original input as a direct schema definition
    -- Create a temporary file for the schema definition with a more reliable path
    local temp_dir = vim.fn.stdpath('cache') .. "/llm_nvim_temp"
    os.execute("mkdir -p " .. temp_dir) -- Ensure temp dir exists
    local schema_temp_file = temp_dir .. "/schema_def_" .. os.time() .. ".json"
    local schema_temp = io.open(schema_temp_file, "w")
    if not schema_temp then
      vim.notify("Failed to create temporary file for schema definition: " .. schema_temp_file, vim.log.levels.ERROR)
      return nil
    end

    -- Write the original input (treated as schema definition) to the file
    schema_temp:write(schema_id_or_name)
    schema_temp:close()

    if config.get("debug") then
      vim.notify("Created schema definition temp file: " .. schema_temp_file, vim.log.levels.DEBUG)
      if vim.fn.filereadable(schema_temp_file) == 1 then
        vim.notify("Schema def file exists and is readable", vim.log.levels.DEBUG)
      else
        vim.notify("WARNING: Schema def file does not exist or is not readable!", vim.log.levels.WARN)
      end
    end

    -- Use the temporary schema file path with the existing input file
    cmd = string.format("cat '%s' | llm %s '%s'", file_path, schema_flag, schema_temp_file)

    -- Set up cleanup for the schema temp file
    vim.defer_fn(function()
      if vim.fn.filereadable(schema_temp_file) == 1 then
        os.remove(schema_temp_file)
        if config.get("debug") then
          vim.notify("Schema def temp file removed", vim.log.levels.DEBUG)
        end
      end
    end, 5000) -- Clean up after 5 seconds
  end

  -- Debug the command
  if config.get("debug") then
    vim.notify("Running schema command: " .. cmd, vim.log.levels.DEBUG)
  end

  -- Verify the schema exists and is valid
  local schema_exists = false
  local schemas = M.get_schemas()
  if schemas[schema_id] then
    schema_exists = true
  end
  
  if not schema_exists then
    vim.notify("Schema ID not found: " .. schema_id, vim.log.levels.ERROR)
    return nil
  end
  
  -- Get the schema details to ensure it's valid
  local schema_details = M.get_schema(schema_id)
  if not schema_details or not schema_details.content then
    vim.notify("Schema content could not be retrieved: " .. schema_id, vim.log.levels.ERROR)
    return nil
  end
  
  -- Validate the schema content
  local is_valid_json, _ = pcall(vim.fn.json_decode, schema_details.content)
  if not is_valid_json and config.get("debug") then
    vim.notify("Schema content is not valid JSON. Using schema ID directly.", vim.log.levels.WARN)
  end

  -- Use the schema ID directly - this is the most reliable approach according to the docs
  local cmd = string.format("cat '%s' | llm %s %s", file_path, schema_flag, schema_id)

  if config.get("debug") then
    vim.notify("Running schema command: " .. cmd, vim.log.levels.DEBUG)
  end

  -- Use vim.fn.system for better compatibility
  local result = vim.fn.system(cmd)
  local success = vim.v.shell_error == 0

  if not success then
    if config.get("debug") then
      vim.notify("Error running schema: " .. result, vim.log.levels.ERROR)
      vim.notify("Command was: " .. cmd, vim.log.levels.DEBUG)
      vim.notify("Exit code: " .. tostring(vim.v.shell_error), vim.log.levels.DEBUG)
    end
    vim.notify("Failed to run schema. Check your input and schema ID.", vim.log.levels.ERROR)
    return nil
  end

  -- Check if result is empty
  if not result or result == "" then
    if config.get("debug") then
      vim.notify("Schema returned empty result", vim.log.levels.WARN)
    end
    vim.notify("Schema returned empty result. Check your input format.", vim.log.levels.WARN)
    return "{}"; -- Return empty JSON object instead of nil
  end

  if config.get("debug") then
    vim.notify("Schema execution successful", vim.log.levels.DEBUG)
    vim.notify("Result length: " .. #result, vim.log.levels.DEBUG)
    vim.notify("Result (first 100 chars): " .. result:sub(1, 100), vim.log.levels.DEBUG)
  end

  return result
end

-- Run a schema with a URL
function M.run_schema_with_url(schema_id_or_name, url, is_multi)
  if not utils.check_llm_installed() then
    return nil
  end

  -- Convert name to ID if needed
  local schema_id = M.get_schema_id_by_name(schema_id_or_name)
  local schema_name = nil

  -- If we didn't get an ID from the name, use the original input as the ID
  if not schema_id then
    schema_id = schema_id_or_name
  end

  -- Validate that we have a valid schema ID
  if not schema_id or schema_id == "" or schema_id == "nil" then
    vim.notify("Invalid schema ID: " .. tostring(schema_id), vim.log.levels.ERROR)
    return nil
  end

  -- Check if we have a name for this schema ID
  local _, schema_config_file = utils.get_config_path("schemas.json") -- Capture full path
  if schema_config_file then
    local config_file = io.open(schema_config_file, "r")
    if config_file then
      local content = config_file:read("*all")
      config_file:close()

      if content and content ~= "" then
        local success, parsed = pcall(vim.fn.json_decode, content)
        if success and parsed then
          for name, id in pairs(parsed) do
            if id == schema_id then
              schema_name = name
              break
            end
          end
        end
      end
    end
  end

  -- Check if we have a local schema file
  local schema_file = nil
  if schema_name then
    local config_dir, _ = utils.get_config_path("schemas")                          -- Get base config dir
    if config_dir then
      local local_schema_file = config_dir .. "/schemas/" .. schema_name .. ".json" -- Construct path
      local f = io.open(local_schema_file, "r")
      if f then
        f:close()
        schema_file = local_schema_file
      end
    end
  end

  local cmd
  local schema_flag = is_multi and "--schema-multi" or "--schema"

  if schema_file then
    -- Use the local schema file with proper quoting
    cmd = string.format("curl -sL \"%s\" | llm %s '%s'", url, schema_flag, schema_file)
  elseif schema_id:match("^[0-9a-f]+$") then
    -- Use the schema ID (ensure it's not nil)
    if not schema_id or schema_id == "nil" then
      vim.notify("Invalid schema ID for URL command", vim.log.levels.ERROR)
      return nil
    end
    cmd = string.format("curl -sL \"%s\" | llm %s %s", url, schema_flag, schema_id)
  else
    -- Treat as a direct schema definition
    -- Create a temporary file for the schema
    local schema_temp_file = os.tmpname()
    local schema_temp = io.open(schema_temp_file, "w")
    if not schema_temp then
      vim.notify("Failed to create temporary file for schema definition", vim.log.levels.ERROR)
      return nil
    end

    -- Write the schema definition to the file
    schema_temp:write(schema_id)
    schema_temp:close()

    -- Use the schema file
    cmd = string.format("curl -sL \"%s\" | llm %s '%s'", url, schema_flag, schema_temp_file)

    -- Set up cleanup for the schema temp file
    vim.defer_fn(function()
      os.remove(schema_temp_file)
    end, 5000) -- Clean up after 5 seconds
  end

  -- Debug output
  if config.get("debug") then
    vim.notify("Running schema URL command: " .. cmd, vim.log.levels.DEBUG)
  end

  -- Use vim.fn.system for better compatibility
  local result = vim.fn.system(cmd)
  local success = vim.v.shell_error == 0

  if not success then
    if config.get("debug") then
      vim.notify("Error running schema with URL: " .. result, vim.log.levels.ERROR)
      vim.notify("Command was: " .. cmd, vim.log.levels.DEBUG)
      vim.notify("Exit code: " .. tostring(vim.v.shell_error), vim.log.levels.DEBUG)

      -- Try to get more detailed error information if possible
      if schema_file then
        local schema_content = nil
        local f = io.open(schema_file, "r")
        if f then
          schema_content = f:read("*all")
          f:close()
          if schema_content then
            local schema_json = pcall(function() return vim.fn.json_encode(vim.fn.json_decode(schema_content)) end)
            if schema_json then
              vim.notify("Schema content: " .. schema_json:sub(1, 200) .. "...", vim.log.levels.DEBUG)
            end
          end
        end
      end
    end
    vim.notify("Failed to run schema with URL content. Check your schema ID and URL.", vim.log.levels.ERROR)
    return nil
  end

  -- Check if result is empty
  if not result or result == "" then
    if config.get("debug") then
      vim.notify("Schema returned empty result", vim.log.levels.WARN)
    end
    vim.notify("Schema returned empty result. Check your URL and schema.", vim.log.levels.WARN)
    return "{}"; -- Return empty JSON object instead of nil
  end

  if config.get("debug") then
    vim.notify("Schema execution successful", vim.log.levels.DEBUG)
    vim.notify("Result length: " .. #result, vim.log.levels.DEBUG)
    vim.notify("Result (first 100 chars): " .. result:sub(1, 100), vim.log.levels.DEBUG)
  end

  return result
end

-- Create a schema from DSL syntax
function M.create_schema_from_dsl(dsl_text)
  if not utils.check_llm_installed() then
    return nil
  end

  -- Convert DSL to JSON schema manually
  -- This is a simple implementation that handles basic DSL syntax
  local properties = {}
  local required = {}

  for line in dsl_text:gmatch("[^\r\n]+") do
    -- Skip empty lines and comment lines
    if line:match("^%s*$") or line:match("^%s*#") or line:match("^Press <Esc>") then
      -- Skip
    else
      -- Parse property definition - Allow hyphens in name
      local name, type_desc = line:match("^([%w_-]+)%s*:%s*(.+)$")
      if not name then
        local name_type, desc = line:match("^([%w_-]+%s+%w+)%s*:%s*(.+)$")
        if name_type then
          name = name_type:match("^([%w_-]+)")
          type_desc = desc
        end
      end
      if not name then
        name = line:match("^([%w_-]+)$")
        type_desc = ""
      end

      if name then
        -- Validate property name length
        if #name < 1 or #name > 64 then
          return nil, "Invalid property name '" .. name .. "'. Must be 1-64 characters."
        end

        -- Validate property name characters (redundant with pattern but good practice)
        if not name:match("^[a-zA-Z0-9_-]+$") then
          return nil, "Invalid characters in property name '" .. name .. "'. Use letters, numbers, _, -."
        end

        -- Add to required fields
        table.insert(required, name)

        -- Determine type
        local prop_type = "string" -- Default type
        if line:match("%s+int%s*:") or line:match("%s+int$") then
          prop_type = "integer"
        elseif line:match("%s+float%s*:") or line:match("%s+float$") then
          prop_type = "number"
        elseif line:match("%s+bool%s*:") or line:match("%s+bool$") then
          prop_type = "boolean"
        end

        -- Create property definition
        local prop = {
          type = prop_type
        }

        -- Add description if available
        local description = line:match(":%s*(.+)$")
        if description then
          prop.description = description
        end

        properties[name] = prop
      end
    end
  end

  -- Create the JSON schema
  local schema = {
    type = "object",
    properties = properties,
    required = required
  }

  -- Convert to JSON string with proper formatting
  local json_schema = vim.fn.json_encode(schema)

  if config.get("debug") then
    vim.notify("Generated JSON schema: " .. json_schema, vim.log.levels.DEBUG)
  end

  return json_schema, nil -- Return schema and nil error on success
end

-- Validate JSON schema structure and property names
function M.validate_json_schema(schema_json_string)
  local success, schema = pcall(vim.fn.json_decode, schema_json_string)
  if not success then
    return false, "Invalid JSON format: " .. tostring(schema)
  end

  if type(schema) ~= "table" then
    return false, "Schema must be a JSON object."
  end

  -- Recommended: Top-level should be an object
  if schema.type ~= "object" then
    -- Allow non-object top-level for now, but maybe warn?
    -- return false, "Top-level schema 'type' must be 'object'."
  end

  local function validate_properties(props, path)
    if type(props) ~= "table" then return true, nil end -- Not a properties object

    for key, value in pairs(props) do
      -- More detailed debug output
      if require('llm.config').get("debug") then
        vim.notify(string.format("Validating key: %s (type: %s, len: %d) at path: %s",
            vim.inspect(key), type(key), type(key) == "string" and #key or -1, path),
          vim.log.levels.DEBUG)
      end

      -- Ensure key is a string before proceeding
      if type(key) ~= "string" then
        if require('llm.config').get("debug") then
          vim.notify("Validation FAILED: Key is not a string: " .. vim.inspect(key), vim.log.levels.DEBUG)
        end
        return false, string.format("Invalid property key (not a string): %s at path '%s'.", vim.inspect(key), path)
      end

      -- Trim whitespace just in case (although unlikely for JSON keys)
      local trimmed_key = key:gsub("^%s+", ""):gsub("%s+$", "")
      -- Also strip potential surrounding double quotes
      local stripped_key = trimmed_key:gsub('^"', ''):gsub('"$', '')

      -- Manual validation of property key format using the stripped key
      local key_valid = true
      local key_len = #stripped_key

      if key_len < 1 or key_len > 64 then
        key_valid = false
      else
        for i = 1, key_len do
          local byte = string.byte(stripped_key, i)
          local is_alnum = (byte >= string.byte('a') and byte <= string.byte('z')) or
              (byte >= string.byte('A') and byte <= string.byte('Z')) or
              (byte >= string.byte('0') and byte <= string.byte('9'))
          local is_special = (byte == string.byte('_') or byte == string.byte('-'))

          if not (is_alnum or is_special) then
            key_valid = false
            break -- Exit loop early if invalid character found
          end
        end
      end

      if not key_valid then
        if require('llm.config').get("debug") then
          vim.notify(
            string.format("Manual Validation FAILED for key: %s (stripped: %s, len: %d)", vim.inspect(key),
              vim.inspect(stripped_key), key_len), vim.log.levels.DEBUG)
        end
        -- Use the original key in the error message for clarity
        return false,
            string.format("Invalid property key '%s' at path '%s'. Keys must match ^[a-zA-Z0-9_-]{1,64}$.", key, path)
      end

      -- Recursively validate nested properties if they exist
      if type(value) == "table" then
        if value.properties then
          local valid, err = validate_properties(value.properties, path .. "." .. key .. ".properties")
          if not valid then return false, err end
        end
        -- Also check items for arrays
        if value.type == "array" and value.items and value.items.properties then
          local valid, err = validate_properties(value.items.properties, path .. "." .. key .. ".items.properties")
          if not valid then return false, err end
        end
      end
    end
    return true, nil
  end

  if schema.properties then
    local valid, err = validate_properties(schema.properties, "properties")
    if not valid then return false, err end
  end

  -- Also check top-level 'items' if the root is an array schema (less common but possible)
  if schema.type == "array" and schema.items and schema.items.properties then
    local valid, err = validate_properties(schema.items.properties, "items.properties")
    if not valid then return false, err end
  end

  return true, nil
end

return M
