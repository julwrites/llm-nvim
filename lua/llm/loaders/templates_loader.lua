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
  local cmd = "llm templates list"
  local result = vim.fn.system(cmd)
  local shell_error = vim.v.shell_error

  if shell_error ~= 0 then
    if config.get("debug") then
      vim.notify("Error executing '" .. cmd .. "': " .. result .. " (Exit code: " .. tostring(shell_error) .. ")", vim.log.levels.ERROR)
    end
    return {}
  end

  if not result or result == "" then
    if config.get("debug") then
      vim.notify("No templates found or empty output from '" .. cmd .. "'", vim.log.levels.WARN)
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
  if not template_name or template_name == "" then
    if config.get("debug") then
      vim.notify("Template name cannot be empty", vim.log.levels.DEBUG)
    end
    return nil
  end

  if not utils.check_llm_installed() then
    return nil
  end

  -- Use vim.fn.system to get the template details directly
  local cmd = string.format("llm templates show %s", template_name)
  local result = vim.fn.system(cmd)
  local shell_error = vim.v.shell_error

  if shell_error ~= 0 then
    if config.get("debug") then
      vim.notify("Error getting template details: " .. result .. " (Exit code: " .. tostring(shell_error) .. ")", vim.log.levels.ERROR)
    end
    return nil
  end

  if not result or result == "" then
    if config.get("debug") then
      vim.notify("Empty output from '" .. cmd .. "'", vim.log.levels.WARN)
    end
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
  if not name or name == "" then
    vim.notify("Template name cannot be empty", vim.log.levels.ERROR)
    return false
  end
  if name:match("[/\\]") then
    vim.notify("Template name cannot contain path separators (/ or \\)", vim.log.levels.ERROR)
    return false
  end

  if not utils.check_llm_installed() then
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
  local shell_error = vim.v.shell_error

  if config.get("debug") then
    vim.notify("Template creation output: " .. result, vim.log.levels.DEBUG)
    vim.notify("Template creation success: " .. tostring(shell_error == 0), vim.log.levels.DEBUG)
  end

  -- Check if the command was successful
  if shell_error ~= 0 then
    vim.notify("Template creation failed: " .. result, vim.log.levels.ERROR)
    return false
  end

  return true
end

-- Delete a template by removing its file from the templates directory
function M.delete_template(name)
  if not name or name == "" then
    return false, "Template name cannot be empty"
  end
  if name:match("[/\\]") then
    return false, "Template name cannot contain path separators (/ or \\)"
  end

  -- First check if template exists
  local templates = M.get_templates()
  if not templates[name] then
    return false, "Template '"..name.."' does not exist"
  end

  -- Get the full path to the template file
  local config_dir, template_file = utils.get_config_path("templates/" .. name .. ".yaml")
  if not config_dir or not template_file then
    return false, "Could not determine LLM templates directory"
  end

  -- Check if file exists
  if vim.fn.filereadable(template_file) ~= 1 then
    return false, "Template file not found at: " .. template_file
  end

  -- Delete the file
  local success, err = os.remove(template_file)
  if not success then
    return false, "Failed to delete template file: " .. (err or "unknown error")
  end

  -- Verify deletion
  if vim.fn.filereadable(template_file) == 1 then
    return false, "Template file still exists after deletion attempt"
  end

  return true, nil
end

-- Run a template with input
function M.run_template(name, input, params)
  if not name or name == "" then
    vim.notify("Template name cannot be empty", vim.log.levels.ERROR)
    return nil
  end
  if not input or input == "" then
    vim.notify("Input content cannot be empty", vim.log.levels.ERROR)
    return nil
  end

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
  local shell_error = vim.v.shell_error

  -- Clean up the temporary file
  os.remove(temp_file)

  if shell_error ~= 0 then
    vim.notify("Error running template: " .. result, vim.log.levels.ERROR)
  end

  return shell_error == 0 and result or nil
end

-- Run a template with a URL
function M.run_template_with_url(name, url, params)
  if not name or name == "" then
    vim.notify("Template name cannot be empty", vim.log.levels.ERROR)
    return nil
  end
  if not url or url == "" then
    vim.notify("URL cannot be empty", vim.log.levels.ERROR)
    return nil
  end

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
  local shell_error = vim.v.shell_error

  if shell_error ~= 0 and config.get("debug") then
    vim.notify("Error running template with URL: " .. result .. " (Exit code: " .. tostring(shell_error) .. ")", vim.log.levels.ERROR)
  end

  return shell_error == 0 and result or nil
end

-- Edit a template using the system editor
function M.edit_template(name)
  if not name or name == "" then
    vim.notify("Template name cannot be empty", vim.log.levels.ERROR)
    return false
  end

  if not utils.check_llm_installed() then
    return false
  end

  local cmd = string.format("llm templates edit %s", name)
  local result = vim.fn.system(cmd)
  local shell_error = vim.v.shell_error

  if shell_error ~= 0 and config.get("debug") then
    vim.notify("Error editing template: " .. result .. " (Exit code: " .. tostring(shell_error) .. ")", vim.log.levels.ERROR)
  end

  return shell_error == 0
end

-- Export a template to a file
function M.export_template(name, file_path)
  if not name or name == "" then
    vim.notify("Template name cannot be empty", vim.log.levels.ERROR)
    return false
  end
  if not file_path or file_path == "" then
    vim.notify("File path cannot be empty", vim.log.levels.ERROR)
    return false
  end

  if not utils.check_llm_installed() then
    return false
  end

  local cmd = string.format("llm templates export %s > %s", name, file_path)
  local success = os.execute(cmd)
  return success == 0 or success == true
end

-- Import a template from a file
function M.import_template(name, file_path)
  if not name or name == "" then
    vim.notify("Template name cannot be empty", vim.log.levels.ERROR)
    return false
  end
  if not file_path or file_path == "" then
    vim.notify("File path cannot be empty", vim.log.levels.ERROR)
    return false
  end

  if not utils.check_llm_installed() then
    return false
  end

  local cmd = string.format("llm templates import %s < %s", name, file_path)
  local success = os.execute(cmd)
  return success == 0 or success == true
end

return M
