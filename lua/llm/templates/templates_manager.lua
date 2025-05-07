-- llm/templates/templates_manager.lua - Template management for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local api = vim.api
local templates_loader = require('llm.templates.templates_loader')
local utils = require('llm.utils')
local models_manager = require('llm.models.models_manager')
local fragments_loader = require('llm.fragments.fragments_loader')
local schemas_loader = require('llm.schemas.schemas_loader')
local styles = require('llm.styles') -- Added

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

          utils.floating_input({
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
  if not template_name or template_name == "" then
    vim.notify("Template name cannot be empty", vim.log.levels.ERROR)
    return
  end

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
    vim.notify("Found parameters: " .. table.concat(param_names, ", "), vim.log.levels.INFO)

    local function collect_next_param(index)
      if index > #param_names then
        -- All parameters collected, run the template
        M.run_template_with_input(template_name, params)
        return
      end

      local param = param_names[index]
      local default = template.defaults and template.defaults[param] or ""

      utils.floating_input({
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
  if not template_name or template_name == "" then
    vim.notify("Template name cannot be empty", vim.log.levels.ERROR)
    return
  end

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
      utils.floating_input({
        prompt = "Enter URL:"
      }, function(url)
        if not url or url == "" then
          vim.notify("URL cannot be empty", vim.log.levels.WARN)
          return
        end

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
  utils.floating_input({
    prompt = "Enter template name:"
  }, function(name)
    if not name or name == "" then
      vim.notify("Template name cannot be empty", vim.log.levels.WARN)
      return
    end
    if name:match("[/\\]") then
      vim.notify("Template name cannot contain path separators (/ or \\)", vim.log.levels.ERROR)
      return
    end

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
        utils.floating_input({
          prompt = "Enter prompt (use $input for user input):",
          default = "$input"
        }, function(prompt)
          if not prompt or prompt == "" then
            vim.notify("Prompt cannot be empty", vim.log.levels.WARN)
            return
          end
          -- Ensure $input is preserved
          template.prompt = prompt
          M.continue_template_creation(template)
        end)
      elseif type_choice == "System prompt only" then
        utils.floating_input({
          prompt = "Enter system prompt:"
        }, function(system)
          if not system or system == "" then
            vim.notify("System prompt cannot be empty", vim.log.levels.WARN)
            return
          end
          template.system = system
          M.continue_template_creation(template)
        end)
      else -- Both
        vim.ui.input({
          prompt = "Enter system prompt:"
        }, function(system)
          if not system or system == "" then
            vim.notify("System prompt cannot be empty", vim.log.levels.WARN)
            return
          end
          template.system = system

          utils.floating_input({
            prompt = "Enter regular prompt (use $input for user input):",
            default = "$input"
          }, function(prompt)
            if not prompt or prompt == "" then
              vim.notify("Prompt cannot be empty", vim.log.levels.WARN)
              return
            end
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
              else
                vim.notify("Fragment path/URL cannot be empty", vim.log.levels.WARN)
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
              else
                vim.notify("Fragment path/URL cannot be empty", vim.log.levels.WARN)
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
        utils.floating_input({
          prompt = "Enter option name (or leave empty to finish):"
        }, function(name)
          if not name or name == "" then
            M.continue_template_creation_params(template)
            return
          end

          utils.floating_input({
            prompt = "Enter value for " .. name .. ":"
          }, function(value)
            if value and value ~= "" then
              template.options[name] = value
            else
              vim.notify("Option value cannot be empty", vim.log.levels.WARN)
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

      utils.floating_input({
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
  utils.floating_confirm({
    prompt = "Extract first code block from response?",
    options = { "Yes", "No" }
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

-- Populate the buffer with template management content
function M.populate_templates_buffer(bufnr)
  local templates = templates_loader.get_templates()
  local template_names = {}
  for name, _ in pairs(templates) do table.insert(template_names, name) end
  table.sort(template_names)

  local lines = {
    "# Template Management",
    "",
    "Navigate: [M]odels [P]lugins [K]eys [F]ragments [S]chemas",
    "Actions: [c]reate [r]un [e]dit [d]elete [v]iew details [q]uit",
    "──────────────────────────────────────────────────────────────",
    ""
  }

  local template_data = {}
  local line_to_template = {}
  local current_line = #lines + 1

  if #template_names == 0 then
    table.insert(lines, "No templates found. Press 'c' to create one.")
  else
    -- Show all templates in a single list
    for i, name in ipairs(template_names) do
      local is_loader = name:match("^loader:")
      local prefix = is_loader and name:match("^loader:(.+)$")
      local description = templates[name] or ""
      
      local entry_lines = {}
      if is_loader then
        table.insert(entry_lines, string.format("Loader %d: %s", i, prefix))
        table.insert(entry_lines, string.format("  Description: %s", description))
        table.insert(entry_lines, string.format("  Usage: llm -t %s:owner/repo/template", prefix))
      else
        table.insert(entry_lines, string.format("Template %d: %s", i, name))
        table.insert(entry_lines, string.format("  Description: %s", description))
      end
      table.insert(entry_lines, "")

      -- Store the line numbers that belong to this template
      local start_line = current_line
      local end_line = current_line + #entry_lines - 1
      
      -- Add all lines from start to end to the mapping
      for line_num = start_line, end_line do
        line_to_template[line_num] = name
      end

      template_data[name] = {
        index = i,
        description = description,
        start_line = start_line,
        end_line = end_line,
        is_loader = is_loader,
        prefix = prefix
      }

      -- Add the entry lines to the buffer
      for _, line in ipairs(entry_lines) do 
        table.insert(lines, line) 
      end
      
      current_line = current_line + #entry_lines
    end
  end

  api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- Apply syntax highlighting
  styles.setup_buffer_syntax(bufnr) -- Use styles module

  -- Store lookup tables in buffer variables
  vim.b[bufnr].line_to_template = line_to_template
  vim.b[bufnr].template_data = template_data
  vim.b[bufnr].templates = templates     -- Store the displayed list

  return line_to_template, template_data -- Return for direct use if needed
end

-- Setup keymaps for the template management buffer
function M.setup_templates_keymaps(bufnr, manager_module)
  manager_module = manager_module or M -- Allow passing self

  local function set_keymap(mode, lhs, rhs)
    api.nvim_buf_set_keymap(bufnr, mode, lhs, rhs, { noremap = true, silent = true })
  end

  -- Helper to get template info
  local function get_template_info_under_cursor()
    local current_line = api.nvim_win_get_cursor(0)[1]
    local line_to_template = vim.b[bufnr].line_to_template
    local template_data = vim.b[bufnr].template_data
    local template_name = line_to_template and line_to_template[current_line]
    if template_name and template_data and template_data[template_name] then
      return template_name, template_data[template_name]
    end
    return nil, nil
  end

  -- Create template
  set_keymap('n', 'c',
    string.format([[<Cmd>lua require('%s').create_template_from_manager(%d)<CR>]],
      manager_module.__name or 'llm.templates.templates_manager', bufnr))

  -- Run template
  set_keymap('n', 'r',
    string.format([[<Cmd>lua require('%s').run_template_under_cursor(%d)<CR>]],
      manager_module.__name or 'llm.templates.templates_manager', bufnr))

  -- Edit template
  set_keymap('n', 'e',
    string.format([[<Cmd>lua require('%s').edit_template_under_cursor(%d)<CR>]],
      manager_module.__name or 'llm.templates.templates_manager', bufnr))

  -- Delete template
  set_keymap('n', 'd',
    string.format([[<Cmd>lua require('%s').delete_template_under_cursor(%d)<CR>]],
      manager_module.__name or 'llm.templates.templates_manager', bufnr))

  -- View details
  set_keymap('n', 'v',
    string.format([[<Cmd>lua require('%s').view_template_details_under_cursor(%d)<CR>]],
      manager_module.__name or 'llm.templates.templates_manager', bufnr))
end

-- Action functions called by keymaps (now accept bufnr)
function M.create_template_from_manager(bufnr)
  require('llm.unified_manager').close() -- Close manager before starting creation flow
  vim.schedule(function()
    M.create_template()                  -- This function handles reopening the manager on completion/failure
  end)
end

function M.run_template_under_cursor(bufnr)
  local template_name, template_info = M.get_template_info_under_cursor(bufnr)
  if not template_name then
    vim.notify("No template found under cursor", vim.log.levels.ERROR)
    return
  end

  if template_info and template_info.is_loader then
    -- For template loaders, prompt for the full template path
    utils.floating_input({
      prompt = string.format("Enter template path for %s (e.g. owner/repo/template):", template_info.prefix),
    }, function(path)
      if not path or path == "" then return end
      
      -- Construct full template name with prefix
      local full_template = template_info.prefix .. ":" .. path
      
      -- Verify the template exists by trying to get its details
      local template_details = templates_loader.get_template_details(full_template)
      if not template_details then
        vim.notify(string.format("Template '%s' not found", full_template), vim.log.levels.ERROR)
        return
      end

      -- Close manager and proceed with regular template flow
      require('llm.unified_manager').close()
      vim.schedule(function()
        -- First check if we need parameters
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

        extract_params(template_details.prompt)
        extract_params(template_details.system)

        -- If we have parameters, collect them
        if #param_names > 0 then
          local function collect_next_param(index)
            if index > #param_names then
              -- All parameters collected, ask for input source
              M.run_template_with_input(full_template, params)
              return
            end

            local param = param_names[index]
            local default = template_details.defaults and template_details.defaults[param] or ""

            utils.floating_input({
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
          -- No parameters needed, ask for input source directly
          M.run_template_with_input(full_template, params)
        end
      end)
    end)
  else
    -- Regular template
    require('llm.unified_manager').close()
    vim.schedule(function()
      M.run_template_with_params(template_name)
    end)
  end
end

function M.edit_template_under_cursor(bufnr)
  local template_name, _ = M.get_template_info_under_cursor(bufnr)
  if not template_name then
    vim.notify("No template found under cursor", vim.log.levels.ERROR)
    return
  end
  require('llm.unified_manager').close() -- Close manager before editing
  vim.schedule(function()
    M.edit_template(template_name)       -- This function handles reopening the manager
  end)
end

function M.delete_template_under_cursor(bufnr)
  local template_name, _ = M.get_template_info_under_cursor(bufnr)
  if not template_name then
    vim.notify("No template found under cursor", vim.log.levels.ERROR)
    return
  end

  -- Use floating confirm dialog
  utils.floating_confirm({
    prompt = "Delete template '" .. template_name .. "'?",
    on_confirm = function(confirmed)
      if not confirmed then return end

      -- Perform deletion in a scheduled callback to ensure UI updates properly
      vim.schedule(function()
        local success, err = templates_loader.delete_template(template_name)
        if success then
          vim.notify("Template '" .. template_name .. "' deleted", vim.log.levels.INFO)
          require('llm.unified_manager').switch_view("Templates")
        else
          vim.notify("Failed to delete template: " .. (err or "unknown error"), vim.log.levels.ERROR)
        end
      end)
    end
  })
end

function M.view_template_details_under_cursor(bufnr)
  local template_name, _ = M.get_template_info_under_cursor(bufnr)
  if not template_name then
    vim.notify("No template found under cursor", vim.log.levels.ERROR)
    return
  end

  local template = templates_loader.get_template_details(template_name)
  if not template then
    vim.notify("Failed to get template details for '" .. template_name .. "'", vim.log.levels.ERROR)
    return
  end

  -- Close the unified manager before showing details
  require('llm.unified_manager').close()

  vim.schedule(function()
    -- Create a buffer for template details
    local detail_buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(detail_buf, "buftype", "nofile")
    api.nvim_buf_set_option(detail_buf, "bufhidden", "wipe")
    api.nvim_buf_set_option(detail_buf, "swapfile", false)
    api.nvim_buf_set_name(detail_buf, "Template Details: " .. template_name)

    -- Create a new floating window
    local detail_win = utils.create_floating_window(detail_buf, 'LLM Template Details: ' .. template_name)

    -- Format template details
    local lines = { "# Template: " .. template_name, "" }
    if template.system and template.system ~= "" then
      table.insert(lines, "## System Prompt:"); table.insert(lines, ""); table.insert(lines, template.system); table
          .insert(lines, "")
    end
    if template.prompt and template.prompt ~= "" then
      table.insert(lines, "## Prompt:"); table.insert(lines, ""); table.insert(lines, template.prompt); table.insert(
        lines, "")
    end
    if template.model and template.model ~= "" then
      table.insert(lines, "## Model: " .. template.model); table.insert(lines, "")
    end
    if template.extract then
      table.insert(lines, "## Extract first code block: Yes"); table.insert(lines, "")
    end
    if template.schema then
      table.insert(lines, "## Schema: " .. template.schema); table.insert(lines, "")
    end
    table.insert(lines, ""); table.insert(lines, "Press [q]uit, [e]dit template, [r]un template")
    api.nvim_buf_set_lines(detail_buf, 0, -1, false, lines)

    -- Set up keymaps for the detail view
    local function set_detail_keymap(mode, lhs, rhs)
      api.nvim_buf_set_keymap(detail_buf, mode, lhs, rhs,
        { noremap = true, silent = true })
    end
    set_detail_keymap("n", "q", [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])
    set_detail_keymap("n", "<Esc>", [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])
    set_detail_keymap("n", "e",
      string.format([[<Cmd>lua require('llm.templates.templates_manager').edit_template_from_details('%s')<CR>]],
        template_name))
    set_detail_keymap("n", "r",
      string.format([[<Cmd>lua require('llm.templates.templates_manager').run_template_with_params('%s')<CR>]],
        template_name))

    -- Set up highlighting
    styles.setup_buffer_styling(detail_buf)
  end)
end

-- Helper to get template info from buffer variables
function M.get_template_info_under_cursor(bufnr)
  local current_line = api.nvim_win_get_cursor(0)[1]
  local line_to_template = vim.b[bufnr].line_to_template
  local template_data = vim.b[bufnr].template_data
  if not line_to_template or not template_data then
    vim.notify("Buffer data missing", vim.log.levels.ERROR)
    return nil, nil
  end

  -- Find the template that includes the current line
  for template_name, data in pairs(template_data) do
    if current_line >= data.start_line and current_line <= data.end_line then
      return template_name, data
    end
  end

  return nil, nil
end

-- Main function to open the template manager (now delegates to unified manager)
function M.manage_templates()
  require('llm.unified_manager').open_specific_manager("Templates")
end

-- Add module name for require path in keymaps
M.__name = 'llm.templates.templates_manager'

-- Run template by name (ensure it closes manager first)
function M.run_template_by_name(template_name)
  if not template_name or template_name == "" then
    vim.notify("No template name provided", vim.log.levels.ERROR)
    return
  end
  local templates = templates_loader.get_templates()
  if not templates[template_name] then
    vim.notify("Template '" .. template_name .. "' not found", vim.log.levels.ERROR)
    return
  end
  require('llm.unified_manager').close() -- Close manager if open
  vim.schedule(function()
    M.run_template_with_params(template_name)
  end)
end

-- Edit template from details view (ensure it closes details view first)
function M.edit_template_from_details(template_name)
  -- Close the current window (template details)
  api.nvim_win_close(0, true)
  vim.schedule(function()
    M.edit_template(template_name) -- This handles reopening manager
  end)
end

-- Re-export functions from templates_loader
M.get_templates = templates_loader.get_templates
M.get_template_details = templates_loader.get_template_details
M.delete_template = templates_loader.delete_template
M.run_template = templates_loader.run_template

return M
