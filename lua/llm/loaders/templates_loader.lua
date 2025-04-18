-- llm/loaders/templates_loader.lua - Template loading functionality for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local utils = require('llm.utils')
local config = require('llm.config')
local api = vim.api

-- Get all templates from llm CLI
function M.get_templates()
  if not utils.check_llm_installed() then
    return {}
  end

  -- Use vim.fn.system for better compatibility
  local result = vim.fn.system("llm templates list")
  local success = vim.v.shell_error == 0
  
  if not success then
    if config.get("debug") then
      vim.notify("Error executing 'llm templates list': " .. result, vim.log.levels.ERROR)
    end
    return {}
  end
  
  if not result or result == "" then
    return {}
  end

  local templates = {}
  for line in result:gmatch("[^\r\n]+") do
    -- Parse template name and description
    local name, description = line:match("^([^%s:]+)%s*:%s*(.+)$")
    if name and description then
      templates[name] = description
    end
  end

  -- Debug output
  if config.get("debug") then
    vim.notify("Found templates: " .. vim.inspect(templates), vim.log.levels.DEBUG)
  end

  return templates
end

-- Get template details from llm CLI
function M.get_template_details(template_name)
  if not utils.check_llm_installed() then
    return nil
  end

  -- Use vim.fn.system to get the template details directly
  local cmd = string.format("llm templates show %s", template_name)
  local result = vim.fn.system(cmd)
  local success = vim.v.shell_error == 0
  
  if not success then
    if config.get("debug") then
      vim.notify("Error getting template details: " .. result, vim.log.levels.ERROR)
    end
    return nil
  end
  
  if not result or result == "" then
    return nil
  end

  -- Parse the YAML (basic parsing, not full YAML)
  local template = {
    name = template_name,
    prompt = "",
    system = "",
    model = "",
    fragments = {},
    system_fragments = {},
    options = {},
    defaults = {},
    extract = false,
    schema = nil
  }

  -- Simple YAML parsing
  local in_multiline = false
  local current_key = nil
  local multiline_value = ""
  local indentation = 0
  
  for line in result:gmatch("[^\r\n]+") do
    -- Check if we're in a multiline string
    if in_multiline then
      -- Check if this line is still part of the multiline string
      -- It should be indented at least as much as our detected indentation
      local line_indent = line:match("^(%s*)")
      if line_indent and #line_indent >= indentation then
        -- Continue multiline string - remove the indentation
        local content = line:sub(indentation + 1)
        -- Unescape any escaped $ characters, but preserve $input
        content = content:gsub("\\%$", "$")
        multiline_value = multiline_value .. "\n" .. content
      else
        -- End of multiline string
        template[current_key] = multiline_value
        in_multiline = false
        current_key = nil
        multiline_value = ""
        indentation = 0
        
        -- Process this line as a potential new key
        local key, value = line:match("^([%w_]+):%s*(.*)$")
        if key and value ~= nil then
          if key == "prompt" or key == "system" then
            if value:match("^[>|]") then
              -- Start of multiline string
              in_multiline = true
              current_key = key
              multiline_value = ""
              -- Detect indentation from the next line
            else
              template[key] = value
            end
          elseif key == "model" then
            template.model = value
          elseif key == "extract" then
            template.extract = (value == "true")
          end
        end
      end
    else
      local key, value = line:match("^([%w_]+):%s*(.*)$")
      if key and value ~= nil then
        if key == "prompt" or key == "system" then
          if value:match("^[>|]") then
            -- Start of multiline string
            in_multiline = true
            current_key = key
            multiline_value = ""
            -- Detect indentation from the next line
            indentation = 2  -- Default indentation is 2 spaces
          else
            template[key] = value
          end
        elseif key == "model" then
          template.model = value
        elseif key == "extract" then
          template.extract = (value == "true")
        end
      elseif in_multiline and line:match("^%s+") then
        -- This is the first indented line of a multiline string
        -- Detect the indentation level
        indentation = #line:match("^(%s+)")
        -- Extract the content without indentation
        local content = line:sub(indentation + 1)
        -- Unescape any escaped $ characters, but preserve $input
        content = content:gsub("\\%$", "$")
        multiline_value = content
      end
    end
  end
  
  -- Handle any remaining multiline string
  if in_multiline and current_key then
    template[current_key] = multiline_value
  end

  return template
end

-- Create a template using llm CLI
function M.create_template(name, prompt, system, model, options, fragments, system_fragments, defaults, extract, schema)
  if not utils.check_llm_installed() then
    return false
  end

  -- Create a temporary file for the template definition
  local temp_file = os.tmpname()
  local file = io.open(temp_file, "w")
  if not file then
    vim.notify("Failed to create temporary file for template creation", vim.log.levels.ERROR)
    return false
  end

  -- Write YAML content to the file
  file:write("name: " .. name .. "\n")
  
  if prompt and prompt ~= "" then
    -- Use YAML multiline format for prompts to preserve special characters
    file:write("prompt: |\n")
    -- Indent each line of the prompt, preserving $input
    for line in prompt:gmatch("[^\r\n]+") do
      -- Escape any $ that isn't part of $input to prevent shell expansion
      local escaped_line = line:gsub("%$([^i])", "\\%$%1")
      escaped_line = escaped_line:gsub("%$$$", "\\%$")
      -- But make sure $input is preserved exactly
      escaped_line = escaped_line:gsub("\\%$input", "$input")
      file:write("  " .. escaped_line .. "\n")
    end
  end
  
  if system and system ~= "" then
    -- Use YAML multiline format for system prompts to preserve special characters
    file:write("system: |\n")
    -- Indent each line of the system prompt
    for line in system:gmatch("[^\r\n]+") do
      -- Escape any $ characters in system prompt
      local escaped_line = line:gsub("%$", "\\%$")
      file:write("  " .. escaped_line .. "\n")
    end
  end
  
  if model and model ~= "" then
    file:write("model: " .. model .. "\n")
  end
  
  -- Add options if provided
  if options and next(options) then
    file:write("options:\n")
    for k, v in pairs(options) do
      file:write("  " .. k .. ": " .. v .. "\n")
    end
  end
  
  -- Add fragments if provided
  if fragments and #fragments > 0 then
    file:write("fragments:\n")
    for _, fragment in ipairs(fragments) do
      file:write("- " .. fragment .. "\n")
    end
  end
  
  -- Add system fragments if provided
  if system_fragments and #system_fragments > 0 then
    file:write("system_fragments:\n")
    for _, fragment in ipairs(system_fragments) do
      file:write("- " .. fragment .. "\n")
    end
  end
  
  -- Add defaults if provided
  if defaults and next(defaults) then
    file:write("defaults:\n")
    for k, v in pairs(defaults) do
      file:write("  " .. k .. ": " .. v .. "\n")
    end
  end
  
  -- Add extract if enabled
  if extract then
    file:write("extract: true\n")
  end
  
  -- Add schema if provided
  if schema and schema ~= "" then
    file:write("schema: " .. schema .. "\n")
  end
  
  file:close()
  
  -- Use direct --save command instead of templates import
  local cmd
  
  -- Create a temporary file for the prompt content
  local prompt_file = os.tmpname()
  local prompt_handle = io.open(prompt_file, "w")
  if not prompt_handle then
    vim.notify("Failed to create temporary file for prompt", vim.log.levels.ERROR)
    os.remove(temp_file)
    return false
  end
  
  -- Write the prompt to the file
  if prompt and prompt ~= "" then
    prompt_handle:write(prompt)
  else
    prompt_handle:write("$input")
  end
  prompt_handle:close()
  
  -- Build the command
  cmd = string.format("cat %s | llm", prompt_file)
  
  if system and system ~= "" then
    cmd = cmd .. string.format(" --system \"%s\"", system:gsub('"', '\\"'))
  end
  
  if model and model ~= "" then
    cmd = cmd .. string.format(" --model %s", model)
  end
  
  -- Add options if provided
  if options and next(options) then
    for k, v in pairs(options) do
      cmd = cmd .. string.format(" -o %s %s", k, v)
    end
  end
  
  -- Add fragments if provided
  if fragments and #fragments > 0 then
    for _, fragment in ipairs(fragments) do
      cmd = cmd .. string.format(" -f \"%s\"", fragment:gsub('"', '\\"'))
    end
  end
  
  -- Add system fragments if provided
  if system_fragments and #system_fragments > 0 then
    for _, fragment in ipairs(system_fragments) do
      cmd = cmd .. string.format(" --system-fragment \"%s\"", fragment:gsub('"', '\\"'))
    end
  end
  
  -- Add extract if enabled
  if extract then
    cmd = cmd .. " --extract"
  end
  
  -- Add schema if provided
  if schema and schema ~= "" then
    cmd = cmd .. string.format(" --schema %s", schema)
  end
  
  -- Add save command
  cmd = cmd .. string.format(" --save %s", name)
  
  if config.get("debug") then
    vim.notify("Template creation command: " .. cmd, vim.log.levels.DEBUG)
  end
  
  -- Execute the command
  local result = vim.fn.system(cmd)
  local success = vim.v.shell_error == 0
  
  -- Clean up temporary files
  os.remove(prompt_file)
  os.remove(temp_file)
  
  -- Clean up the temporary file
  os.remove(temp_file)
  
  if config.get("debug") then
    vim.notify("Command result: " .. vim.fn.exepath("llm"), vim.log.levels.DEBUG)
    vim.notify("Template creation output: " .. result, vim.log.levels.DEBUG)
    vim.notify("Template creation success: " .. tostring(success) .. ", exit code: " .. tostring(vim.v.shell_error), vim.log.levels.DEBUG)
  end
  
  -- Check if the command was successful
  if not success then
    vim.notify("Template creation failed: " .. result, vim.log.levels.ERROR)
    return false
  end
  
  return true
end

-- Delete a template using llm CLI
function M.delete_template(name)
  if not utils.check_llm_installed() then
    return false
  end

  local cmd = string.format("llm templates delete %s", name)
  local result = vim.fn.system(cmd)
  local success = vim.v.shell_error == 0
  
  if not success and config.get("debug") then
    vim.notify("Error deleting template: " .. result, vim.log.levels.ERROR)
  end
  
  return success
end

-- Run a template with input
function M.run_template(name, input, params)
  if not utils.check_llm_installed() then
    return nil
  end

  -- Create a temporary file for the input
  local temp_file = os.tmpname()
  local file = io.open(temp_file, "w")
  if not file then
    vim.notify("Failed to create temporary file for template input", vim.log.levels.ERROR)
    return nil
  end
  
  file:write(input)
  file:close()

  local cmd = string.format("cat %s | llm -t %s", temp_file, name)
  
  -- Add parameters if provided
  if params then
    for k, v in pairs(params) do
      cmd = cmd .. string.format(" -p %s \"%s\"", k, v)
    end
  end

  -- Use vim.fn.system for better compatibility
  local result = vim.fn.system(cmd)
  local success = vim.v.shell_error == 0
  
  -- Clean up the temporary file
  os.remove(temp_file)
  
  if not success and config.get("debug") then
    vim.notify("Error running template: " .. result, vim.log.levels.ERROR)
  end
  
  return success and result or nil
end

-- Run a template with a URL
function M.run_template_with_url(name, url, params)
  if not utils.check_llm_installed() then
    return nil
  end

  local cmd = string.format("curl -sL \"%s\" | llm -t %s", url, name)
  
  -- Add parameters if provided
  if params then
    for k, v in pairs(params) do
      cmd = cmd .. string.format(" -p %s \"%s\"", k, v)
    end
  end

  -- Use vim.fn.system for better compatibility
  local result = vim.fn.system(cmd)
  local success = vim.v.shell_error == 0
  
  if not success and config.get("debug") then
    vim.notify("Error running template with URL: " .. result, vim.log.levels.ERROR)
  end
  
  return success and result or nil
end

-- Edit a template using the system editor
function M.edit_template(name)
  if not utils.check_llm_installed() then
    return false
  end

  local cmd = string.format("llm templates edit %s", name)
  local result = vim.fn.system(cmd)
  local success = vim.v.shell_error == 0
  
  if not success and config.get("debug") then
    vim.notify("Error editing template: " .. result, vim.log.levels.ERROR)
  end
  
  return success
end

-- Export a template to a file
function M.export_template(name, file_path)
  if not utils.check_llm_installed() then
    return false
  end

  local cmd = string.format("llm templates export %s > %s", name, file_path)
  local success = os.execute(cmd)
  return success == 0 or success == true
end

-- Import a template from a file
function M.import_template(name, file_path)
  if not utils.check_llm_installed() then
    return false
  end

  local cmd = string.format("llm templates import %s < %s", name, file_path)
  local success = os.execute(cmd)
  return success == 0 or success == true
end

return M
