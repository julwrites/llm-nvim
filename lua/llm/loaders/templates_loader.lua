-- llm/loaders/templates_loader.lua - Template loading functionality for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local utils = require('llm.utils')
local config = require('llm.config')
local api = vim.api

-- Function to ensure templates directory exists and is properly set up
function M.ensure_templates_dir()
  -- This is handled automatically by the llm CLI
  -- Just check if llm is installed
  return utils.check_llm_installed()
end

-- Get all templates from llm CLI
function M.get_templates()
  if not utils.check_llm_installed() then
    return {}
  end

  -- Use a simpler command that's more likely to work
  local result = vim.fn.system("llm templates list")
  local success = vim.v.shell_error == 0

  if not success or not result or result == "" then
    if config.get("debug") then
      vim.notify("No templates found or error listing templates", vim.log.levels.WARN)
    end
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
            indentation = 2 -- Default indentation is 2 spaces
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

  -- Validate template name to avoid directory issues
  if name:match("[/\\]") then
    vim.notify("Template name cannot contain path separators (/ or \\)", vim.log.levels.ERROR)
    return false
  end

  -- Build the command - use the simplest possible approach
  local cmd = "llm --system \"" .. (system or "You are a helpful assistant") .. "\""
  
  if model and model ~= "" then
    cmd = cmd .. " --model " .. model
  end
  
  -- Add save command
  cmd = cmd .. " --save " .. name
  
  if config.get("debug") then
    vim.notify("Template creation command: " .. cmd, vim.log.levels.DEBUG)
  end

  -- Execute the command
  local result = vim.fn.system(cmd)
  local success = vim.v.shell_error == 0

  if config.get("debug") then
    vim.notify("Template creation output: " .. result, vim.log.levels.DEBUG)
    vim.notify("Template creation success: " .. tostring(success), vim.log.levels.DEBUG)
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

  -- Simplify the command to just the basics
  local cmd = string.format("cat %s | llm -t %s", temp_file, name)

  -- Use vim.fn.system for better compatibility
  local result = vim.fn.system(cmd)
  local success = vim.v.shell_error == 0

  -- Clean up the temporary file
  os.remove(temp_file)

  if not success then
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
