-- llm/managers/templates_manager.lua - Template management for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local api = vim.api
local templates_loader = require('llm.loaders.templates_loader')
local utils = require('llm.utils')
local models_manager = require('llm.managers.models_manager')
local fragments_loader = require('llm.loaders.fragments_loader')
local schemas_loader = require('llm.loaders.schemas_loader')

-- Select and run a template
function M.select_template()
  if not utils.check_llm_installed() then
    return
  end

  -- Check if we have a visual selection
  local has_selection = false
  local selection = ""
  local mode = api.nvim_get_mode().mode
  if mode == 'v' or mode == 'V' or mode == '' then
    -- Get the visual selection
    selection = utils.get_visual_selection()
    has_selection = selection ~= ""
  end

  local templates = templates_loader.get_templates()
  local template_names = {}
  local template_descriptions = {}

  for name, description in pairs(templates) do
    table.insert(template_names, name)
    template_descriptions[name] = description
  end

  if #template_names == 0 then
    vim.notify("No templates found", vim.log.levels.INFO)
    return
  end

  table.sort(template_names)

  vim.ui.select(template_names, {
    prompt = "Select a template to run:",
    format_item = function(item)
      return item .. " - " .. (template_descriptions[item] or "")
    end
  }, function(choice)
    if not choice then return end

    -- If we have a selection, use it directly
    if has_selection then
      -- Ask for parameters first
      local template = templates_loader.get_template_details(choice)
      if not template then
        vim.notify("Failed to get template details", vim.log.levels.ERROR)
        return
      end

      -- Check if we need to collect parameters
      local params = {}
      local param_names = {}

      -- Extract parameter names from prompt and system
      local function extract_params(text)
        if not text then return end
        for param in text:gmatch("%$([%w_]+)") do
          if param ~= "input" and not vim.tbl_contains(param_names, param) then
            table.insert(param_names, param)
          end
        end
      end

      extract_params(template.prompt)
      extract_params(template.system)

      -- If we have parameters, collect them
      if #param_names > 0 then
        local function collect_next_param(index)
          if index > #param_names then
            -- All parameters collected, run the template with selection
            local result = templates_loader.run_template(choice, selection, params)
            if result then
              utils.create_buffer_with_content(result, "Template Result: " .. choice, "markdown")
            end
            return
          end

          local param = param_names[index]
          local default = template.defaults and template.defaults[param] or ""

          vim.ui.input({
            prompt = "Enter value for parameter '" .. param .. "':",
            default = default
          }, function(value)
            if value then
              params[param] = value
              collect_next_param(index + 1)
            end
          end)
        end

        collect_next_param(1)
      else
        -- No parameters needed, run the template with selection
        local result = templates_loader.run_template(choice, selection, {})
        if result then
          utils.create_buffer_with_content(result, "Template Result: " .. choice, "markdown")
        end
      end
    else
      -- No selection, ask for parameters and input source
      M.run_template_with_params(choice)
    end
  end)
end

-- Run a template with parameters
function M.run_template_with_params(template_name)
  -- Check if we're in the template manager window and close it if so
  local current_buf = api.nvim_get_current_buf()
  local buf_name = api.nvim_buf_get_name(current_buf)
  local is_template_manager = buf_name:match("LLM Templates$")
  local current_win = api.nvim_get_current_win()

  if is_template_manager then
    api.nvim_win_close(current_win, true)
  end

  local template = templates_loader.get_template_details(template_name)
  if not template then
    vim.notify("Failed to get template details", vim.log.levels.ERROR)
    return
  end

  -- Check if we need to collect parameters
  local params = {}
  local param_names = {}

  -- Extract parameter names from prompt and system
  local function extract_params(text)
    if not text then return end
    for param in text:gmatch("%$([%w_]+)") do
      if param ~= "input" and not vim.tbl_contains(param_names, param) then
        table.insert(param_names, param)
      end
    end
  end

  extract_params(template.prompt)
  extract_params(template.system)

  -- If we have parameters, collect them
  if #param_names > 0 then
    local function collect_next_param(index)
      if index > #param_names then
        -- All parameters collected, run the template
        M.run_template_with_input(template_name, params)
        return
      end

      local param = param_names[index]
      local default = template.defaults and template.defaults[param] or ""

      vim.ui.input({
        prompt = "Enter value for parameter '" .. param .. "':",
        default = default
      }, function(value)
        if value then
          params[param] = value
          collect_next_param(index + 1)
        end
      end)
    end

    collect_next_param(1)
  else
    -- No parameters needed, run the template
    M.run_template_with_input(template_name, params)
  end
end

-- Run a template with input (selection, buffer, or URL)
function M.run_template_with_input(template_name, params)
  vim.ui.select({
    "Current selection",
    "Current buffer",
    "URL (will use curl)"
  }, {
    prompt = "Choose input source:"
  }, function(choice)
    if not choice then return end

    if choice == "Current selection" then
      local selection = utils.get_visual_selection()
      if selection == "" then
        vim.notify("No text selected", vim.log.levels.ERROR)
        return
      end

      local result = templates_loader.run_template(template_name, selection, params)
      if result then
        utils.create_buffer_with_content(result, "Template Result: " .. template_name, "markdown")
      end
    elseif choice == "Current buffer" then
      local lines = api.nvim_buf_get_lines(0, 0, -1, false)
      local content = table.concat(lines, "\n")

      local result = templates_loader.run_template(template_name, content, params)
      if result then
        utils.create_buffer_with_content(result, "Template Result: " .. template_name, "markdown")
      end
    elseif choice == "URL (will use curl)" then
      vim.ui.input({
        prompt = "Enter URL:"
      }, function(url)
        if not url or url == "" then return end

        local result = templates_loader.run_template_with_url(template_name, url, params)
        if result then
          utils.create_buffer_with_content(result, "Template Result: " .. template_name, "markdown")
        end
      end)
    end
  end)
end

-- Create a template with guided flow
function M.create_template()
  if not utils.check_llm_installed() then
    return
  end

  -- Step 1: Get template name
  vim.ui.input({
    prompt = "Enter template name:"
  }, function(name)
    if not name or name == "" then return end

    -- Step 2: Choose template type
    vim.ui.select({
      "Regular prompt",
      "System prompt only",
      "Both system and regular prompt"
    }, {
      prompt = "Choose template type:"
    }, function(type_choice)
      if not type_choice then return end

      local template = {
        name = name,
        prompt = "",
        system = "",
        model = "",
        options = {},
        fragments = {},
        system_fragments = {},
        defaults = {},
        extract = false,
        schema = nil
      }

      -- Step 3: Set prompts based on type
      if type_choice == "Regular prompt" then
        vim.ui.input({
          prompt = "Enter prompt (use $input for user input):",
          default = "$input"
        }, function(prompt)
          if not prompt or prompt == "" then return end
          -- Ensure $input is preserved
          template.prompt = prompt
          M.continue_template_creation(template)
        end)
      elseif type_choice == "System prompt only" then
        vim.ui.input({
          prompt = "Enter system prompt:"
        }, function(system)
          if not system or system == "" then return end
          template.system = system
          M.continue_template_creation(template)
        end)
      else -- Both
        vim.ui.input({
          prompt = "Enter system prompt:"
        }, function(system)
          if not system or system == "" then return end
          template.system = system

          vim.ui.input({
            prompt = "Enter regular prompt (use $input for user input):",
            default = "$input"
          }, function(prompt)
            if not prompt or prompt == "" then return end
            template.prompt = prompt
            M.continue_template_creation(template)
          end)
        end)
      end
    end)
  end)
end

-- Continue template creation with model selection
function M.continue_template_creation(template)
  -- Step 4: Select model (optional)
  vim.ui.select({
    "Use default model",
    "Select specific model"
  }, {
    prompt = "Model selection:"
  }, function(model_choice)
    if not model_choice then return end

    if model_choice == "Select specific model" then
      local models = models_manager.get_available_models()

      vim.ui.select(models, {
        prompt = "Select model for this template:"
      }, function(model)
        if model then
          template.model = models_manager.extract_model_name(model)
        end
        M.continue_template_creation_fragments(template)
      end)
    else
      M.continue_template_creation_fragments(template)
    end
  end)
end

-- Continue template creation with fragments
function M.continue_template_creation_fragments(template)
  -- Step 5: Add fragments (optional)
  vim.ui.select({
    "No fragments",
    "Add fragments",
    "Add system fragments"
  }, {
    prompt = "Do you want to add fragments?"
  }, function(fragment_choice)
    if not fragment_choice then return end

    if fragment_choice == "Add fragments" then
      local function add_more_fragments()
        vim.ui.select({
          "Select from file browser",
          "Enter fragment path/URL",
          "Done adding fragments"
        }, {
          prompt = "Add fragment:"
        }, function(choice)
          if not choice then return end

          if choice == "Select from file browser" then
            fragments_loader.select_file_as_fragment(function(fragment_path)
              if fragment_path then
                table.insert(template.fragments, fragment_path)
              end
              add_more_fragments()
            end)
          elseif choice == "Enter fragment path/URL" then
            vim.ui.input({
              prompt = "Enter fragment path or URL:"
            }, function(path)
              if path and path ~= "" then
                table.insert(template.fragments, path)
              end
              add_more_fragments()
            end)
          else
            M.continue_template_creation_options(template)
          end
        end)
      end

      add_more_fragments()
    elseif fragment_choice == "Add system fragments" then
      local function add_more_system_fragments()
        vim.ui.select({
          "Select from file browser",
          "Enter fragment path/URL",
          "Done adding system fragments"
        }, {
          prompt = "Add system fragment:"
        }, function(choice)
          if not choice then return end

          if choice == "Select from file browser" then
            fragments_loader.select_file_as_fragment(function(fragment_path)
              if fragment_path then
                table.insert(template.system_fragments, fragment_path)
              end
              add_more_system_fragments()
            end)
          elseif choice == "Enter fragment path/URL" then
            vim.ui.input({
              prompt = "Enter system fragment path or URL:"
            }, function(path)
              if path and path ~= "" then
                table.insert(template.system_fragments, path)
              end
              add_more_system_fragments()
            end)
          else
            M.continue_template_creation_options(template)
          end
        end)
      end

      add_more_system_fragments()
    else
      M.continue_template_creation_options(template)
    end
  end)
end

-- Continue template creation with options
function M.continue_template_creation_options(template)
  -- Step 6: Add options (optional)
  vim.ui.select({
    "No options",
    "Add options"
  }, {
    prompt = "Do you want to add model options (like temperature)?"
  }, function(option_choice)
    if not option_choice then return end

    if option_choice == "Add options" then
      local function add_option()
        vim.ui.input({
          prompt = "Enter option name (or leave empty to finish):"
        }, function(name)
          if not name or name == "" then
            M.continue_template_creation_params(template)
            return
          end

          vim.ui.input({
            prompt = "Enter value for " .. name .. ":"
          }, function(value)
            if value and value ~= "" then
              template.options[name] = value
            end
            add_option()
          end)
        end)
      end

      add_option()
    else
      M.continue_template_creation_params(template)
    end
  end)
end

-- Continue template creation with parameters
function M.continue_template_creation_params(template)
  -- Step 7: Extract parameters from prompt and system
  local params = {}

  local function extract_params(text)
    if not text then return end
    for param in text:gmatch("%$([%w_]+)") do
      if param ~= "input" and not vim.tbl_contains(params, param) then
        table.insert(params, param)
      end
    end
  end

  extract_params(template.prompt)
  extract_params(template.system)

  -- If we have parameters, ask for defaults
  if #params > 0 then
    vim.notify("Found parameters: " .. table.concat(params, ", "), vim.log.levels.INFO)

    local function set_param_default(index)
      if index > #params then
        M.continue_template_creation_extract(template)
        return
      end

      local param = params[index]

      vim.ui.input({
        prompt = "Default value for parameter '" .. param .. "' (leave empty for no default):"
      }, function(value)
        if value and value ~= "" then
          template.defaults[param] = value
        end
        set_param_default(index + 1)
      end)
    end

    set_param_default(1)
  else
    M.continue_template_creation_extract(template)
  end
end

-- Continue template creation with extract option
function M.continue_template_creation_extract(template)
  -- Step 8: Extract code option
  vim.ui.select({
    "No",
    "Yes"
  }, {
    prompt = "Extract first code block from response?"
  }, function(extract_choice)
    if not extract_choice then return end

    template.extract = (extract_choice == "Yes")
    M.continue_template_creation_schema(template)
  end)
end

-- Continue template creation with schema
function M.continue_template_creation_schema(template)
  -- Step 9: Add schema (optional)
  vim.ui.select({
    "No schema",
    "Select existing schema"
  }, {
    prompt = "Do you want to add a schema?"
  }, function(schema_choice)
    if not schema_choice then return end

    if schema_choice == "Select existing schema" then
      local schemas = schemas_loader.get_schemas()
      local schema_names = {}

      for name, _ in pairs(schemas) do
        table.insert(schema_names, name)
      end

      if #schema_names == 0 then
        vim.notify("No schemas found", vim.log.levels.INFO)
        M.finalize_template_creation(template)
        return
      end

      table.sort(schema_names)

      vim.ui.select(schema_names, {
        prompt = "Select schema:"
      }, function(schema_name)
        if schema_name then
          template.schema = schema_name
        end
        M.finalize_template_creation(template)
      end)
    else
      M.finalize_template_creation(template)
    end
  end)
end

-- Finalize template creation
function M.finalize_template_creation(template)
  -- Step 10: Create the template
  vim.notify("Creating template '" .. template.name .. "'...", vim.log.levels.INFO)

  local success = templates_loader.create_template(
    template.name,
    template.prompt,
    template.system,
    template.model,
    template.options,
    template.fragments,
    template.system_fragments,
    template.defaults,
    template.extract,
    template.schema
  )

  if success then
    vim.notify("Template '" .. template.name .. "' created successfully", vim.log.levels.INFO)

    -- Wait a moment for the template to be available in the system
    vim.defer_fn(function()
      -- Verify the template was created by checking if it exists
      local templates = templates_loader.get_templates()
      if templates[template.name] then
        vim.notify("Template '" .. template.name .. "' is available for use", vim.log.levels.INFO)
      else
        vim.notify("Template was created but is not showing in the template list.", vim.log.levels.WARN)
      end

      -- Always reopen the template manager after creation/editing
      M.manage_templates()
    end, 500) -- 500ms delay to ensure the template is registered
  else
    vim.notify("Failed to create template '" .. template.name .. "'", vim.log.levels.ERROR)

    -- Provide more detailed error information
    vim.notify("Please check if the llm CLI is properly installed and configured.", vim.log.levels.INFO)
    vim.notify("You can try creating a template directly with: llm --system 'Test' --save " .. template.name,
      vim.log.levels.INFO)

    -- Reopen the template manager even on failure
    vim.defer_fn(function()
      M.manage_templates()
    end, 500)
  end
end

-- Manage templates
function M.manage_templates()
  if not utils.check_llm_installed() then
    return
  end

  -- Create a buffer for template management
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(buf, "buftype", "nofile")
  api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  api.nvim_buf_set_option(buf, "swapfile", false)
  api.nvim_buf_set_name(buf, "LLM Templates")

  -- Create a new floating window
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Use the centralized window creation function
  local win = utils.create_floating_window(buf, 'LLM Templates Manager')

  -- Function to refresh the template list
  local function refresh_template_list()
    local templates = templates_loader.get_templates()
    local template_names = {}

    for name, _ in pairs(templates) do
      table.insert(template_names, name)
    end

    table.sort(template_names)

    -- Add header
    local lines = {
      "# LLM Templates Manager",
      "",
      "Press [c]reate, [r]un, [e]dit, [d]elete, [v]iew details, [q]uit",
      "──────────────────────────────────────────────────────────────",
      "",
    }

    if #template_names == 0 then
      table.insert(lines, "No templates found. Press 'c' to create one.")
    else
      table.insert(lines, "Templates:")
      table.insert(lines, "----------")

      -- Add templates with descriptions
      for i, name in ipairs(template_names) do
        -- Format template entry similar to fragments manager
        table.insert(lines, string.format("Template %d: %s", i, name))
        table.insert(lines, string.format("  Description: %s", templates[name]))

        -- Add empty line between templates
        table.insert(lines, "")
      end
    end

    api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    -- Set up highlighting
    require('llm').setup_buffer_highlighting(buf)

    -- Apply syntax highlighting using the styles module
    local styles = require('llm.styles')

    -- Apply specific syntax highlighting for templates manager
    local syntax_cmds = {
      "syntax match LLMHeader /^# LLM Templates Manager$/",
      "syntax match LLMAction /Press.*$/",
      "syntax match LLMSection /^Templates:$/",
      "syntax match LLMTemplateName /^Template \\d\\+: .*$/",
      "syntax match LLMContent /^  Description: .*$/",
      "syntax match LLMKeybinding /\\[.\\]/",
    }

    for _, cmd in ipairs(syntax_cmds) do
      vim.api.nvim_buf_call(buf, function()
        vim.cmd(cmd)
      end)
    end
  end

  -- Set up keymaps
  local function set_keymap(mode, lhs, rhs)
    api.nvim_buf_set_keymap(buf, mode, lhs, rhs, { noremap = true, silent = true })
  end

  set_keymap("n", "q", [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])
  set_keymap("n", "<Esc>", [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])
  set_keymap("n", "c", ":lua require('llm.managers.templates_manager').create_template_from_manager()<CR>")
  set_keymap("n", "r", ":lua require('llm.managers.templates_manager').run_template_under_cursor()<CR>")
  set_keymap("n", "e", ":lua require('llm.managers.templates_manager').edit_template_under_cursor()<CR>")
  set_keymap("n", "d", ":lua require('llm.managers.templates_manager').delete_template_under_cursor()<CR>")
  set_keymap("n", "v", ":lua require('llm.managers.templates_manager').view_template_details_under_cursor()<CR>")

  -- Initial refresh with error handling
  local status, err = pcall(function()
    refresh_template_list()
  end)
  
  if not status then
    -- If refresh fails, show a basic error message in the buffer
    local error_lines = {
      "# LLM Templates Manager",
      "",
      "Error loading templates.",
      "",
      "Press [c]reate to create a new template, or [q]uit to exit.",
      "",
      "Error details: " .. tostring(err),
      "",
      "Make sure the llm CLI tool is installed and working correctly.",
      "Try running 'llm --help' in your terminal to verify.",
      "",
    }
    api.nvim_buf_set_lines(buf, 0, -1, false, error_lines)
    
    -- Set up basic highlighting
    require('llm').setup_buffer_highlighting(buf)
  end

  -- Store the refresh function in the buffer
  api.nvim_buf_set_var(buf, "refresh_function", refresh_template_list)
end

-- Run template under cursor
function M.run_template_under_cursor()
  local line = api.nvim_get_current_line()
  local template_name = line:match("^Template %d+: (.+)$")

  if template_name then
    M.run_template_with_params(template_name)
  else
    vim.notify("No template found under cursor", vim.log.levels.ERROR)
  end
end

-- Edit template under cursor
function M.edit_template_under_cursor()
  local line = api.nvim_get_current_line()
  local template_name = line:match("^Template %d+: (.+)$")

  if not template_name then
    vim.notify("No template found under cursor", vim.log.levels.ERROR)
    return
  end

  -- Close the template manager window
  api.nvim_win_close(0, true)

  -- Edit the template
  M.edit_template(template_name)
end

-- Delete template under cursor
function M.delete_template_under_cursor()
  local line = api.nvim_get_current_line()
  local template_name = line:match("^Template %d+: (.+)$")

  if not template_name then
    vim.notify("No template found under cursor", vim.log.levels.ERROR)
    return
  end

  vim.ui.select({
    "Yes",
    "No"
  }, {
    prompt = "Are you sure you want to delete template '" .. template_name .. "'?"
  }, function(choice)
    if choice == "Yes" then
      local success = templates_loader.delete_template(template_name)

      if success then
        vim.notify("Template '" .. template_name .. "' deleted", vim.log.levels.INFO)
        -- Close and reopen the template manager to refresh
        local win = api.nvim_get_current_win()
        api.nvim_win_close(win, true)
        vim.defer_fn(function()
          M.manage_templates()
        end, 100)
      else
        vim.notify("Failed to delete template", vim.log.levels.ERROR)
      end
    end
  end)
end

-- Refresh the template manager (for backward compatibility)
function M.refresh_template_manager()
  -- Close and reopen the template manager
  local win = api.nvim_get_current_win()
  api.nvim_win_close(win, true)
  vim.defer_fn(function()
    M.manage_templates()
  end, 100)
end

-- View template details under cursor
function M.view_template_details_under_cursor()
  local line = api.nvim_get_current_line()
  local template_name = line:match("^Template %d+: (.+)$")

  if not template_name then
    vim.notify("No template found under cursor", vim.log.levels.ERROR)
    return
  end

  -- Close the template manager window
  local current_win = api.nvim_get_current_win()
  api.nvim_win_close(current_win, true)

  -- Check if template exists first
  local templates = templates_loader.get_templates()
  if not templates[template_name] then
    vim.notify("Template '" .. template_name .. "' not found", vim.log.levels.ERROR)
    return
  end

  -- Get template details
  local template = templates_loader.get_template_details(template_name)
  if not template then
    vim.notify("Failed to get template details for '" .. template_name .. "'", vim.log.levels.ERROR)
    return
  end

  -- Create a buffer for template details
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(buf, "buftype", "nofile")
  api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  api.nvim_buf_set_option(buf, "swapfile", false)
  api.nvim_buf_set_name(buf, "Template Details: " .. template_name)

  -- Create a new floating window
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Use the centralized window creation function
  local win = utils.create_floating_window(buf, 'LLM Template Details: ' .. template_name)

  -- Format template details
  local lines = {
    "# Template: " .. template_name,
    "",
  }

  if template.system and template.system ~= "" then
    table.insert(lines, "## System Prompt:")
    table.insert(lines, "")
    table.insert(lines, template.system)
    table.insert(lines, "")
  end

  if template.prompt and template.prompt ~= "" then
    table.insert(lines, "## Prompt:")
    table.insert(lines, "")
    -- Don't escape the $ characters in the display
    table.insert(lines, template.prompt)
    table.insert(lines, "")
  end

  if template.model and template.model ~= "" then
    table.insert(lines, "## Model: " .. template.model)
    table.insert(lines, "")
  end

  if template.extract then
    table.insert(lines, "## Extract first code block: Yes")
    table.insert(lines, "")
  end

  if template.schema then
    table.insert(lines, "## Schema: " .. template.schema)
    table.insert(lines, "")
  end

  -- Add footer with instructions
  table.insert(lines, "")
  table.insert(lines, "Press [q]uit, [e]dit template, [r]un template")

  api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Set up keymaps
  local function set_keymap(mode, lhs, rhs)
    api.nvim_buf_set_keymap(buf, mode, lhs, rhs, { noremap = true, silent = true })
  end

  set_keymap("n", "q", [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])
  set_keymap("n", "<Esc>", [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])
  set_keymap("n", "e",
    ":lua require('llm.managers.templates_manager').edit_template_from_details('" .. template_name .. "')<CR>")
  set_keymap("n", "r",
    ":lua require('llm.managers.templates_manager').run_template_with_params('" .. template_name .. "')<CR>")

  -- Set up highlighting
  require('llm').setup_buffer_highlighting(buf)

  -- Use the styles module for highlighting
  local styles = require('llm.styles')

  -- Apply syntax highlighting using the styles module
  local styles = require('llm.styles')

  -- Apply specific syntax highlighting for template details
  local syntax_cmds = {
    "syntax match LLMHeader /^# Template:/",
    "syntax match LLMSubHeader /^## .*$/",
    "syntax match LLMAction /^Press.*$/",
    "syntax match LLMKeybinding /\\[.\\]/",
  }

  for _, cmd in ipairs(syntax_cmds) do
    vim.api.nvim_buf_call(buf, function()
      vim.cmd(cmd)
    end)
  end
end

-- Edit a template by name
function M.edit_template(template_name)
  -- Get the template details
  local template = templates_loader.get_template_details(template_name)
  if not template then
    vim.notify("Failed to get template details for '" .. template_name .. "'", vim.log.levels.ERROR)
    return
  end

  -- Start the template creation workflow with pre-filled values
  M.edit_template_with_details(template)
end

-- Edit a template with pre-filled details
function M.edit_template_with_details(template)
  if not utils.check_llm_installed() then
    return
  end

  -- Store the original name to reopen the template manager after editing
  local original_name = template.name

  -- Step 2: Choose template type based on existing template
  local type_choice
  if template.system ~= "" and template.prompt ~= "" then
    type_choice = "Both system and regular prompt"
  elseif template.system ~= "" then
    type_choice = "System prompt only"
  else
    type_choice = "Regular prompt"
  end

  -- Step 3: Set prompts based on type
  if type_choice == "Regular prompt" then
    -- Don't escape the $input variable in the UI prompt
    vim.ui.input({
      prompt = "Enter prompt (use $input for user input):",
      default = template.prompt
    }, function(prompt)
      if not prompt or prompt == "" then
        -- If canceled, reopen the template manager
        vim.defer_fn(function() M.manage_templates() end, 100)
        return
      end
      template.prompt = prompt
      M.continue_template_creation(template)
    end)
  elseif type_choice == "System prompt only" then
    vim.ui.input({
      prompt = "Enter system prompt:",
      default = template.system
    }, function(system)
      if not system or system == "" then
        -- If canceled, reopen the template manager
        vim.defer_fn(function() M.manage_templates() end, 100)
        return
      end
      template.system = system
      M.continue_template_creation(template)
    end)
  else -- Both
    vim.ui.input({
      prompt = "Enter system prompt:",
      default = template.system
    }, function(system)
      if not system or system == "" then
        -- If canceled, reopen the template manager
        vim.defer_fn(function() M.manage_templates() end, 100)
        return
      end
      template.system = system

      vim.ui.input({
        prompt = "Enter regular prompt (use $input for user input):",
        default = template.prompt
      }, function(prompt)
        if not prompt or prompt == "" then
          -- If canceled, reopen the template manager
          vim.defer_fn(function() M.manage_templates() end, 100)
          return
        end
        template.prompt = prompt
        M.continue_template_creation(template)
      end)
    end)
  end
end

-- Create template from manager
function M.create_template_from_manager()
  -- Store current buffer and window to return to after template creation
  local current_buf = api.nvim_get_current_buf()
  local current_win = api.nvim_get_current_win()

  -- Close the current window (template manager)
  api.nvim_win_close(current_win, true)

  -- Create the template
  M.create_template()

  -- Set up a callback to reopen the template manager after creation
  vim.defer_fn(function()
    -- Reopen the template manager
    M.manage_templates()
  end, 1000) -- 1 second delay to allow template creation to complete
end

-- Edit template from details view
function M.edit_template_from_details(template_name)
  -- Close the current window (template details)
  api.nvim_win_close(0, true)

  -- Edit the template
  M.edit_template(template_name)

  -- Set up a callback to reopen the template manager after editing
  vim.defer_fn(function()
    -- Reopen the template manager
    M.manage_templates()
  end, 1000) -- 1 second delay to allow template editing to complete
end

-- Run a template by name
function M.run_template_by_name(template_name)
  if not template_name or template_name == "" then
    vim.notify("No template name provided", vim.log.levels.ERROR)
    return
  end

  -- Check if template exists
  local templates = templates_loader.get_templates()
  if not templates[template_name] then
    vim.notify("Template '" .. template_name .. "' not found", vim.log.levels.ERROR)
    return
  end

  -- Run the template with parameters
  M.run_template_with_params(template_name)
end

-- This function has been removed as it's no longer needed

-- Re-export functions from templates_loader
M.get_templates = templates_loader.get_templates
M.get_template_details = templates_loader.get_template_details
M.delete_template = templates_loader.delete_template
M.run_template = templates_loader.run_template

return M
