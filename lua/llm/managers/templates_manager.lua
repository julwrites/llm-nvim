-- llm/managers/templates_manager.lua - Template management for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local api = require('llm.api')
local llm_cli = require('llm.core.data.llm_cli')
local cache = require('llm.core.data.cache')
local templates_view = require('llm.ui.views.templates_view')
local styles = require('llm.ui.styles')
local models_manager = require('llm.managers.models_manager')

-- Get templates from llm CLI
function M.get_templates()
    local cached_templates = cache.get('templates')
    if cached_templates then
        return cached_templates
    end

    local templates_json = llm_cli.run_llm_command('templates list --json')
    local templates = vim.fn.json_decode(templates_json)
    cache.set('templates', templates)
    return templates
end

-- Get a specific template from llm CLI
function M.get_template_details(template_name)
    local template_json = llm_cli.run_llm_command('templates show ' .. template_name)
    return vim.fn.json_decode(template_json)
end

-- Create a template
-- Save a template
function M.save_template(name, prompt, system, model, options, fragments, system_fragments, defaults, extract, schema)
    local cmd = 'templates save ' .. name
    if prompt then
        cmd = cmd .. ' --prompt ' .. vim.fn.shellescape(prompt)
    end
    if system then
        cmd = cmd .. ' --system ' .. vim.fn.shellescape(system)
    end
    if model then
        cmd = cmd .. ' --model ' .. model
    end
    for k, v in pairs(options) do
        cmd = cmd .. ' -o ' .. k .. ' ' .. vim.fn.shellescape(v)
    end
    for _, f in ipairs(fragments) do
        cmd = cmd .. ' -f ' .. f
    end
    for _, f in ipairs(system_fragments) do
        cmd = cmd .. ' -sf ' .. f
    end
    for k, v in pairs(defaults) do
        cmd = cmd .. ' -d ' .. k .. ' ' .. vim.fn.shellescape(v)
    end
    if extract then
        cmd = cmd .. ' --extract'
    end
    if schema then
        cmd = cmd .. ' --schema ' .. schema
    end

    local result = llm_cli.run_llm_command(cmd)
    cache.invalidate('templates')
    return result ~= nil
end

-- Delete a template
function M.delete_template(template_name)
    local result = llm_cli.run_llm_command('templates delete ' .. template_name .. ' -y')
    cache.invalidate('templates')
    return result ~= nil
end

-- Run a template
function M.run_template(template_name, input, params)
    local cmd = { llm_cli.get_llm_executable_path(), "-t", template_name }
    if input then
        table.insert(cmd, vim.fn.shellescape(input))
    end
    for k, v in pairs(params) do
        table.insert(cmd, "-p")
        table.insert(cmd, k)
        table.insert(cmd, vim.fn.shellescape(v))
    end
    return cmd
end

-- Select and run a template
function M.select_template()
  local templates = M.get_templates()
  templates_view.select_template(templates, function(choice)
    if not choice then return end

    -- If we have a selection, use it directly
    local has_selection = false
    local selection = ""
    local mode = api.nvim_get_mode().mode
    if mode == 'v' or mode == 'V' or mode == '' then
      -- Get the visual selection
      selection = require('llm.core.utils.text').get_visual_selection()
      has_selection = selection ~= ""
    end

    if has_selection then
      M.run_template_with_selection(choice.name, selection)
    else
      M.run_template_with_params(choice.name)
    end
  end)
end

function M.run_template_with_selection(template_name, selection)
  local template = M.get_template_details(template_name)
  if not template then
    vim.notify("Failed to get template details", vim.log.levels.ERROR)
    return
  end

  local params = {}
  local param_names = M.extract_params(template)

  if #param_names > 0 then
    M.collect_params_and_run(template_name, selection, param_names, template.defaults, function(final_params)
      local cmd_parts = M.run_template(template_name, selection, final_params)
      local response_buf = api.nvim_create_buf(false, true)
      api.nvim_buf_set_option(response_buf, "buftype", "nofile")
      api.nvim_buf_set_option(response_buf, "bufhidden", "wipe")
      api.nvim_buf_set_option(response_buf, "swapfile", false)
      api.nvim_buf_set_name(response_buf, "Template Result: " .. template_name)
      require('llm.core.utils.ui').create_floating_window(response_buf, "Template Result: " .. template_name)
      api.run_llm_command_streamed(cmd_parts, response_buf)
    end)
  else
    local cmd_parts = M.run_template(template_name, selection, {})
    local response_buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(response_buf, "buftype", "nofile")
    api.nvim_buf_set_option(response_buf, "bufhidden", "wipe")
    api.nvim_buf_set_option(response_buf, "swapfile", false)
    api.nvim_buf_set_name(response_buf, "Template Result: " .. template_name)
    require('llm.core.utils.ui').create_floating_window(response_buf, "Template Result: " .. template_name)
    api.run_llm_command_streamed(cmd_parts, response_buf)
  end
end

function M.extract_params(template)
  local param_names = {}
  local function extract(text)
    if not text then return end
    for param in text:gmatch("%$([%w_]+)") do
      if param ~= "input" and not vim.tbl_contains(param_names, param) then
        table.insert(param_names, param)
      end
    end
  end
  extract(template.prompt)
  extract(template.system)
  return param_names
end

function M.collect_params_and_run(template_name, selection, param_names, defaults, callback)
  local params = {}
  local function collect_next_param(index)
    if index > #param_names then
      callback(params)
      return
    end

    local param = param_names[index]
    local default = defaults and defaults[param] or ""

    templates_view.get_user_input("Enter value for parameter '" .. param .. "':", default, function(value)
      if value then
        params[param] = value
        collect_next_param(index + 1)
      end
    end)
  end
  collect_next_param(1)
end

-- Run a template with parameters
function M.run_template_with_params(template_name)
  if not template_name or template_name == "" then
    vim.notify("Template name cannot be empty", vim.log.levels.ERROR)
    return
  end

  local template = M.get_template_details(template_name)
  if not template then
    vim.notify("Failed to get template details", vim.log.levels.ERROR)
    return
  end

  local param_names = M.extract_params(template)

  if #param_names > 0 then
    M.collect_params_and_run(template_name, nil, param_names, template.defaults, function(final_params)
      M.run_template_with_input(template_name, final_params)
    end)
  else
    M.run_template_with_input(template_name, {})
  end
end

-- Run a template with input (selection, buffer, or URL)
function M.run_template_with_input(template_name, params)
  if not template_name or template_name == "" then
    vim.notify("Template name cannot be empty", vim.log.levels.ERROR)
    return
  end

  templates_view.get_input_source(function(choice)
    if not choice then return end

    if choice == "Current selection" then
      local selection = require('llm.core.utils.text').get_visual_selection()
      if selection == "" then
        vim.notify("No text selected", vim.log.levels.ERROR)
        return
      end
      local cmd_parts = M.run_template(template_name, selection, params)
      local response_buf = api.nvim_create_buf(false, true)
      api.nvim_buf_set_option(response_buf, "buftype", "nofile")
      api.nvim_buf_set_option(response_buf, "bufhidden", "wipe")
      api.nvim_buf_set_option(response_buf, "swapfile", false)
      api.nvim_buf_set_name(response_buf, "Template Result: " .. template_name)
      require('llm.core.utils.ui').create_floating_window(response_buf, "Template Result: " .. template_name)
      api.run_llm_command_streamed(cmd_parts, response_buf)
    elseif choice == "Current buffer" then
      local lines = api.nvim_buf_get_lines(0, 0, -1, false)
      local content = table.concat(lines, "\n")
      local cmd_parts = M.run_template(template_name, content, params)
      local response_buf = api.nvim_create_buf(false, true)
      api.nvim_buf_set_option(response_buf, "buftype", "nofile")
      api.nvim_buf_set_option(response_buf, "bufhidden", "wipe")
      api.nvim_buf_set_option(response_buf, "swapfile", false)
      api.nvim_buf_set_name(response_buf, "Template Result: " .. template_name)
      require('llm.core.utils.ui').create_floating_window(response_buf, "Template Result: " .. template_name)
      api.run_llm_command_streamed(cmd_parts, response_buf)
    elseif choice == "URL (will use curl)" then
      templates_view.get_user_input("Enter URL:", nil, function(url)
        if not url or url == "" then
          vim.notify("URL cannot be empty", vim.log.levels.WARN)
          return
        end
        local result = M.run_template(template_name, url, params)
        if result then
          require('llm.core.utils.ui').create_buffer_with_content(result, "Template Result: " .. template_name, "markdown")
        end
      end)
    end
  end)
end

-- Create a template with guided flow
function M.create_template_guided()
  templates_view.get_user_input("Enter template name:", nil, function(name)
    if not name or name == "" then
      vim.notify("Template name cannot be empty", vim.log.levels.WARN)
      return
    end
    if name:match("[/\\]") then
      vim.notify("Template name cannot contain path separators (/ or \\)", vim.log.levels.ERROR)
      return
    end

    local template = { name = name, defaults = {}, options = {}, fragments = {}, system_fragments = {} }
    M.continue_template_creation_type(template)
  end)
end

function M.continue_template_creation_type(template)
  templates_view.get_template_type(function(type_choice)
    if not type_choice then return end

    if type_choice == "Regular prompt" then
      templates_view.get_user_input("Enter prompt (use $input for user input):", "$input", function(prompt)
        if not prompt or prompt == "" then
          vim.notify("Prompt cannot be empty", vim.log.levels.WARN)
          return
        end
        template.prompt = prompt
        M.continue_template_creation_model(template)
      end)
    elseif type_choice == "System prompt only" then
      templates_view.get_user_input("Enter system prompt:", nil, function(system)
        if not system or system == "" then
          vim.notify("System prompt cannot be empty", vim.log.levels.WARN)
          return
        end
        template.system = system
        M.continue_template_creation_model(template)
      end)
    else -- Both
      templates_view.get_user_input("Enter system prompt:", nil, function(system)
        if not system or system == "" then
          vim.notify("System prompt cannot be empty", vim.log.levels.WARN)
          return
        end
        template.system = system
        templates_view.get_user_input("Enter regular prompt (use $input for user input):", "$input", function(prompt)
          if not prompt or prompt == "" then
            vim.notify("Prompt cannot be empty", vim.log.levels.WARN)
            return
          end
          template.prompt = prompt
          M.continue_template_creation_model(template)
        end)
      end)
    end
  end)
end

function M.continue_template_creation_model(template)
  templates_view.get_model_choice(function(model_choice)
    if not model_choice then return end
    if model_choice == "Select specific model" then
      local models = models_manager.get_available_models()
      templates_view.select_model(models, function(model)
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

function M.continue_template_creation_fragments(template)
  templates_view.get_fragment_choice(function(fragment_choice)
    if not fragment_choice then return end
    if fragment_choice == "Add fragments" then
      M.add_fragments_loop(template, "fragments", function()
        M.continue_template_creation_options(template)
      end)
    elseif fragment_choice == "Add system fragments" then
      M.add_fragments_loop(template, "system_fragments", function()
        M.continue_template_creation_options(template)
      end)
    else
      M.continue_template_creation_options(template)
    end
  end)
end

function M.add_fragments_loop(template, fragment_type, on_done)
  templates_view.get_add_fragment_choice(function(choice)
    if not choice or choice == "Done adding fragments" then
      on_done()
      return
    end

    if choice == "Select from file browser" then
      require('llm.managers.fragments_manager').select_file_as_fragment(function(fragment_path)
        if fragment_path then
          table.insert(template[fragment_type], fragment_path)
        end
        M.add_fragments_loop(template, fragment_type, on_done)
      end)
    elseif choice == "Enter fragment path/URL" then
      templates_view.get_user_input("Enter fragment path or URL:", nil, function(path)
        if path and path ~= "" then
          table.insert(template[fragment_type], path)
        else
          vim.notify("Fragment path/URL cannot be empty", vim.log.levels.WARN)
        end
        M.add_fragments_loop(template, fragment_type, on_done)
      end)
    end
  end)
end

function M.continue_template_creation_options(template)
  templates_view.get_option_choice(function(option_choice)
    if not option_choice or option_choice == "No options" then
      M.continue_template_creation_params(template)
      return
    end

    M.add_options_loop(template, function()
      M.continue_template_creation_params(template)
    end)
  end)
end

function M.add_options_loop(template, on_done)
  templates_view.get_user_input("Enter option name (or leave empty to finish):", nil, function(name)
    if not name or name == "" then
      on_done()
      return
    end
    templates_view.get_user_input("Enter value for " .. name .. ":", nil, function(value)
      if value and value ~= "" then
        template.options[name] = value
      else
        vim.notify("Option value cannot be empty", vim.log.levels.WARN)
      end
      M.add_options_loop(template, on_done)
    end)
  end)
end

function M.continue_template_creation_params(template)
  local params = M.extract_params(template)
  if #params > 0 then
    vim.notify("Found parameters: " .. table.concat(params, ", "), vim.log.levels.INFO)
    M.set_param_defaults_loop(template, params, 1, function()
      M.continue_template_creation_extract(template)
    end)
  else
    M.continue_template_creation_extract(template)
  end
end

function M.set_param_defaults_loop(template, params, index, on_done)
  if index > #params then
    on_done()
    return
  end
  local param = params[index]
  templates_view.get_user_input("Default value for parameter '" .. param .. "' (leave empty for no default):", nil, function(value)
    if value and value ~= "" then
      template.defaults[param] = value
    end
    M.set_param_defaults_loop(template, params, index + 1, on_done)
  end)
end

function M.continue_template_creation_extract(template)
  templates_view.confirm_extract(function(extract)
    template.extract = extract
    M.continue_template_creation_schema(template)
  end)
end

function M.continue_template_creation_schema(template)
  templates_view.get_schema_choice(function(schema_choice)
    if not schema_choice or schema_choice == "No schema" then
      M.finalize_template_creation(template)
      return
    end

    local schemas = require('llm.managers.schemas_manager').get_schemas()
    templates_view.select_schema(schemas, function(schema_name)
      if schema_name then
        template.schema = schema_name
      end
      M.finalize_template_creation(template)
    end)
  end)
end

function M.finalize_template_creation(template)
  vim.notify("Creating template '" .. template.name .. "'...", vim.log.levels.INFO)
  local success = M.save_template(
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
    vim.defer_fn(function()
      M.manage_templates()
    end, 500)
  else
    vim.notify("Failed to create template '" .. template.name .. "'", vim.log.levels.ERROR)
    vim.defer_fn(function()
      M.manage_templates()
    end, 500)
  end
end

-- Populate the buffer with template management content
function M.populate_templates_buffer(bufnr)
  local templates = M.get_templates()

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

  if #templates == 0 then
    table.insert(lines, "No templates found. Press 'c' to create one.")
  else
    for i, template in ipairs(templates) do
      local description = template.description or ""

      local entry_lines = {
        string.format("Template %d: %s", i, template.name),
        string.format("  Description: %s", description)
      }
      table.insert(entry_lines, "")

      local start_line = current_line
      local end_line = current_line + #entry_lines - 1

      for line_num = start_line, end_line do
        line_to_template[line_num] = template.name
      end

      template_data[template.name] = {
        index = i,
        description = description,
        start_line = start_line,
        end_line = end_line,
      }

      for _, line in ipairs(entry_lines) do
        table.insert(lines, line)
      end

      current_line = current_line + #entry_lines
    end
  end

  api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  styles.setup_highlights()
  styles.setup_buffer_syntax(bufnr)
  vim.b[bufnr].line_to_template = line_to_template
  vim.b[bufnr].template_data = template_data
  vim.b[bufnr].templates = templates
end

-- Setup keymaps for the template management buffer
function M.setup_templates_keymaps(bufnr, manager_module)
  manager_module = manager_module or M

  local function set_keymap(mode, lhs, rhs)
    api.nvim_buf_set_keymap(bufnr, mode, lhs, rhs, { noremap = true, silent = true })
  end

  set_keymap('n', 'c', string.format([[<Cmd>lua require('%s').create_template_from_manager(%d)<CR>]], manager_module.__name or 'llm.managers.templates_manager', bufnr))
  set_keymap('n', 'r', string.format([[<Cmd>lua require('%s').run_template_under_cursor(%d)<CR>]], manager_module.__name or 'llm.managers.templates_manager', bufnr))
  set_keymap('n', 'e', string.format([[<Cmd>lua require('%s').edit_template_under_cursor(%d)<CR>]], manager_module.__name or 'llm.managers.templates_manager', bufnr))
  set_keymap('n', 'd', string.format([[<Cmd>lua require('%s').delete_template_under_cursor(%d)<CR>]], manager_module.__name or 'llm.managers.templates_manager', bufnr))
  set_keymap('n', 'v', string.format([[<Cmd>lua require('%s').view_template_details_under_cursor(%d)<CR>]], manager_module.__name or 'llm.managers.templates_manager', bufnr))
end

function M.create_template_from_manager(bufnr)
  require('llm.ui.unified_manager').close()
  vim.schedule(function()
    M.create_template()
  end)
end

function M.run_template_under_cursor(bufnr)
  local template_name, template_info = M.get_template_info_under_cursor(bufnr)
  if not template_name then
    vim.notify("No template found under cursor", vim.log.levels.ERROR)
    return
  end

    require('llm.ui.unified_manager').close()
    vim.schedule(function()
      M.run_template_with_params(template_name)
    end)
end

function M.edit_template_under_cursor(bufnr)
  local template_name, _ = M.get_template_info_under_cursor(bufnr)
  if not template_name then
    vim.notify("No template found under cursor", vim.log.levels.ERROR)
    return
  end
  require('llm.ui.unified_manager').close()
  vim.schedule(function()
    M.edit_template(template_name)
  end)
end

function M.delete_template_under_cursor(bufnr)
  local template_name, _ = M.get_template_info_under_cursor(bufnr)
  if not template_name then
    vim.notify("No template found under cursor", vim.log.levels.ERROR)
    return
  end

  templates_view.confirm_delete(template_name, function(confirmed)
    if not confirmed then return end
    vim.schedule(function()
      local success = M.delete_template(template_name)
      if success then
        vim.notify("Template '" .. template_name .. "' deleted", vim.log.levels.INFO)
        require('llm.ui.unified_manager').switch_view("Templates")
      else
        vim.notify("Failed to delete template", vim.log.levels.ERROR)
      end
    end)
  end)
end

function M.view_template_details_under_cursor(bufnr)
  local template_name, _ = M.get_template_info_under_cursor(bufnr)
  if not template_name then
    vim.notify("No template found under cursor", vim.log.levels.ERROR)
    return
  end

  local template = M.get_template_details(template_name)
  if not template then
    vim.notify("Failed to get template details for '" .. template_name .. "'", vim.log.levels.ERROR)
    return
  end

  require('llm.ui.unified_manager').close()
  vim.schedule(function()
    M.show_template_details(template_name, template)
  end)
end

function M.show_template_details(template_name, template)
  local detail_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(detail_buf, "buftype", "nofile")
  api.nvim_buf_set_option(detail_buf, "bufhidden", "wipe")
  api.nvim_buf_set_option(detail_buf, "swapfile", false)
  api.nvim_buf_set_name(detail_buf, "Template Details: " .. template_name)

  local detail_win = require('llm.core.utils.ui').create_floating_window(detail_buf, 'LLM Template Details: ' .. template_name)

  local lines = { "# Template: " .. template_name, "" }
  if template.system and template.system ~= "" then
    table.insert(lines, "## System Prompt:"); table.insert(lines, ""); table.insert(lines, template.system); table.insert(lines, "")
  end
  if template.prompt and template.prompt ~= "" then
    table.insert(lines, "## Prompt:"); table.insert(lines, ""); table.insert(lines, template.prompt); table.insert(lines, "")
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

  local function set_detail_keymap(mode, lhs, rhs)
    api.nvim_buf_set_keymap(detail_buf, mode, lhs, rhs, { noremap = true, silent = true })
  end

  set_detail_keymap("n", "q", [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])
  set_detail_keymap("n", "<Esc>", [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])
  set_detail_keymap("n", "e", string.format([[<Cmd>lua require('llm.managers.templates_manager').edit_template_from_details('%s')<CR>]], template_name))
  set_detail_keymap("n", "r", string.format([[<Cmd>lua require('llm.managers.templates_manager').run_template_with_params('%s')<CR>]], template_name))

  styles.setup_buffer_styling(detail_buf)
end

function M.get_template_info_under_cursor(bufnr)
  local current_line = api.nvim_win_get_cursor(0)[1]
  local line_to_template = vim.b[bufnr].line_to_template
  local template_data = vim.b[bufnr].template_data
  if not line_to_template or not template_data then
    vim.notify("Buffer data missing", vim.log.levels.ERROR)
    return nil, nil
  end

  for template_name, data in pairs(template_data) do
    if current_line >= data.start_line and current_line <= data.end_line then
      return template_name, data
    end
  end

  return nil, nil
end

function M.manage_templates()
  require('llm.ui.unified_manager').open_specific_manager("Templates")
end

M.__name = 'llm.managers.templates_manager'

function M.run_template_by_name(template_name)
  if not template_name or template_name == "" then
    vim.notify("No template name provided", vim.log.levels.ERROR)
    return
  end
  local templates = M.get_templates()
  local found = false
  for _, t in ipairs(templates) do
    if t.name == template_name then
      found = true
      break
    end
  end
  if not found then
    vim.notify("Template '" .. template_name .. "' not found", vim.log.levels.ERROR)
    return
  end
  require('llm.ui.unified_manager').close()
  vim.schedule(function()
    M.run_template_with_params(template_name)
  end)
end

function M.edit_template_from_details(template_name)
  api.nvim_win_close(0, true)
  vim.schedule(function()
    M.edit_template(template_name)
  end)
end

return M
