-- llm/managers/schemas_manager.lua - Schema management for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local api = vim.api
local llm_cli = require('llm.core.data.llm_cli')
local cache = require('llm.core.data.cache')
local schemas_view = require('llm.ui.views.schemas_view')
local styles = require('llm.ui.styles')

-- Get schemas from llm CLI
function M.get_schemas()
    local cached_schemas = cache.get('schemas')
    if cached_schemas then
        return cached_schemas
    end

    local schemas_json = llm_cli.run_llm_command('schemas list --json')
    local schemas = vim.fn.json_decode(schemas_json)
    cache.set('schemas', schemas)
    return schemas
end

-- Get a specific schema from llm CLI
function M.get_schema(schema_id)
    local schema_json = llm_cli.run_llm_command('schemas get ' .. schema_id .. ' --json')
    return vim.fn.json_decode(schema_json)
end

-- Save a schema
function M.save_schema(name, content, test_mode)
    local temp_file_path = vim.fn.tempname()
    if test_mode then
        return 'schemas save ' .. name .. ' ' .. temp_file_path
    end
    local file = io.open(temp_file_path, "w")
    if not file then
        return false
    end
    file:write(content)
    file:close()

    local result = llm_cli.run_llm_command('schemas save ' .. name .. ' ' .. temp_file_path)
    os.remove(temp_file_path)
    cache.invalidate('schemas')
    return result ~= nil
end

-- Run a schema
function M.run_schema(schema_id, input, is_multi, bufnr, test_mode)
    local temp_file_path = vim.fn.tempname()
    if test_mode then
        local multi_flag = is_multi and " --multi" or ""
        return 'schema ' .. schema_id .. ' ' .. temp_file_path .. multi_flag
    end
    local file = io.open(temp_file_path, "w")
    if not file then
        return nil
    end
    file:write(input)
    file:close()

    local multi_flag = is_multi and " --multi" or ""
    local command_str = 'schema ' .. schema_id .. ' ' .. temp_file_path .. multi_flag

    local target_bufnr = bufnr
    if not target_bufnr then
        vim.cmd('vnew')
        target_bufnr = vim.api.nvim_get_current_buf()
        local buffer_name = "LLM Schema Result - " .. os.time()
        vim.api.nvim_buf_set_name(target_bufnr, buffer_name)
        vim.api.nvim_buf_set_option(target_bufnr, 'filetype', 'json')
        vim.api.nvim_buf_set_lines(target_bufnr, 0, -1, false, { "Waiting for response..." })
    end

    local cmd_parts = { llm_cli.get_llm_executable_path(), command_str }

    local job_id = require('llm.api').run_llm_command_streamed(cmd_parts, target_bufnr, {
        on_exit = function()
            vim.defer_fn(function() os.remove(temp_file_path) end, 0)
        end,
    })
    return job_id
end

-- Select and run a schema
function M.select_schema()
  local schemas = M.get_schemas()
  schemas_view.select_schema(schemas, function(choice)
    if not choice then return end

    local has_selection = false
    local selection = ""
    local mode = api.nvim_get_mode().mode
    if mode == 'v' or mode == 'V' or mode == '' then
      selection = require('llm.core.utils.text').get_visual_selection()
      has_selection = selection ~= ""
    end

    if has_selection then
      schemas_view.get_schema_type(function(schema_type)
        if not schema_type then return end
        local is_multi = schema_type == "Multi schema (array of items)"
        M.run_schema(choice.id, selection, is_multi)
      end)
    else
      M.run_schema_with_input_source(choice.id)
    end
  end)
end

-- Run a schema with input from various sources
function M.run_schema_with_input_source(schema_id)
  if not schema_id or schema_id == "" then
    vim.notify("Schema ID cannot be empty", vim.log.levels.ERROR)
    return
  end

  schemas_view.get_input_source(function(choice)
    if not choice then return end

    schemas_view.get_schema_type(function(schema_type)
      if not schema_type then return end
      local is_multi = schema_type == "Multi schema (array of items)"

      if choice == "Current buffer" then
        local lines = api.nvim_buf_get_lines(0, 0, -1, false)
        local content = table.concat(lines, "\n")
        vim.notify("Running schema on buffer content...", vim.log.levels.INFO)
        M.run_schema(schema_id, content, is_multi, bufnr)
      elseif choice == "URL (will use curl)" then
        schemas_view.get_url(function(url)
          if not url or url == "" then
            vim.notify("URL cannot be empty", vim.log.levels.WARN)
            return
          end
          vim.notify("Running schema on URL content...", vim.log.levels.INFO)
          M.run_schema(schema_id, url, is_multi, bufnr)
        end)
      elseif choice == "Enter text manually" then
        M.handle_manual_text_input(schema_id, is_multi)
      end
    end)
  end)
end

function M.handle_manual_text_input(schema_id, is_multi)
  local temp_dir = vim.fn.stdpath('cache') .. "/llm_nvim_temp"
  os.execute("mkdir -p " .. temp_dir)
  local temp_file_path = string.format("%s/schema_input_%s_%s.txt", temp_dir, schema_id:sub(1, 8), os.time())

  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(buf, "buftype", "acwrite")
  api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  api.nvim_buf_set_option(buf, "swapfile", false)
  api.nvim_buf_set_name(buf, temp_file_path)

  api.nvim_buf_set_lines(buf, 0, -1, false, {
    "# Enter text to process with schema " .. schema_id,
    "# Press :w to save and submit, or :q! to cancel",
    "",
    ""
  })

  api.nvim_command("split")
  api.nvim_win_set_buf(0, buf)
  api.nvim_win_set_cursor(0, { 4, 0 })

  api.nvim_buf_set_var(buf, "llm_schema_id", schema_id)
  api.nvim_buf_set_var(buf, "llm_schema_is_multi", is_multi)
  api.nvim_buf_set_var(buf, "llm_temp_file_path", temp_file_path)

  local group = api.nvim_create_augroup("LLMSchemaInput", { clear = true })
  api.nvim_create_autocmd("BufWriteCmd", {
    group = group,
    buffer = buf,
    callback = function(args)
      if api.nvim_buf_is_valid(args.buf) then
        api.nvim_buf_set_option(args.buf, "modified", false)
        require('llm.managers.schemas_manager').submit_schema_input_from_buffer(args.buf)
        return true
      end
    end,
  })

  api.nvim_buf_create_user_command(buf, "LlmSchemaCancel", function()
    local temp_file = api.nvim_buf_get_var(buf, "llm_temp_file_path")
    api.nvim_command(buf .. "bdelete!")
    if temp_file and vim.fn.filereadable(temp_file) == 1 then
      os.remove(temp_file)
    end
    vim.notify("Schema input cancelled.", vim.log.levels.INFO)
  end, {})

  local function set_keymap(mode, lhs, rhs, opts)
    opts = opts or { noremap = true, silent = true }
    api.nvim_buf_set_keymap(buf, mode, lhs, rhs, opts)
  end

  set_keymap("n", "<Esc>", ":LlmSchemaCancel<CR>")
  vim.notify("Enter text in this buffer. Save (:w) to submit or quit (:q!) to cancel.", vim.log.levels.INFO)
  api.nvim_command('startinsert')
end

function M.submit_schema_input_from_buffer(buf)
  if not api.nvim_buf_is_valid(buf) then
    vim.notify("Invalid buffer for schema input", vim.log.levels.ERROR)
    return
  end

  local schema_id = api.nvim_buf_get_var(buf, "llm_schema_id")
  local is_multi = api.nvim_buf_get_var(buf, "llm_schema_is_multi")
  local lines = api.nvim_buf_get_lines(buf, 3, -1, false)
  local content = table.concat(lines, "\n")

  api.nvim_command(buf .. "bdelete!")
  vim.notify("Running schema on input text...", vim.log.levels.INFO)

  local result = M.run_schema(schema_id, content, is_multi)
  if result then
    require('llm.core.utils.ui').create_buffer_with_content(result, "Schema Result: " .. schema_id, "json")
  else
    vim.notify("Failed to run schema on input text", vim.log.levels.ERROR)
  end
end

function M.create_schema()
  schemas_view.get_schema_name(function(name)
    if not name or name == "" then
      vim.notify("Schema name cannot be empty", vim.log.levels.WARN)
      return
    end
    if name:match("[/\\]") then
      vim.notify("Schema name cannot contain path separators (/ or \\)", vim.log.levels.ERROR)
      return
    end

    schemas_view.get_schema_format(function(format_choice)
      if not format_choice then return end
      M.handle_schema_creation(name, format_choice)
    end)
  end)
end

function M.handle_schema_creation(name, format_choice)
  local temp_dir = vim.fn.stdpath('cache') .. "/llm_nvim_temp"
  os.execute("mkdir -p " .. temp_dir)
  local file_ext = (format_choice == "JSON Schema") and ".json" or ".dsl"
  local safe_name = name:gsub("[^%w_-]", "_")
  local temp_file_path = string.format("%s/schema_edit_%s_%s%s", temp_dir, safe_name, os.time(), file_ext)

  local boilerplate = ""
  if format_choice == "JSON Schema" then
    boilerplate = "{\n  \"type\": \"object\",\n  \"properties\": {\n    \"property_name\": {\n      \"type\": \"string\",\n      \"description\": \"Description of the property\"\n    }\n  },\n  \"required\": [\"property_name\"]\n}"
  else
    boilerplate = "# Define schema properties using DSL syntax\n# Example:\n# name: the person's name\n# age int: their age in years\n# bio: a short biography\n\n"
  end

  local file = io.open(temp_file_path, "w")
  if not file then
    vim.notify("Failed to create temporary schema file: " .. temp_file_path, vim.log.levels.ERROR)
    return
  end
  file:write(boilerplate)
  file:close()

  api.nvim_command("split " .. vim.fn.fnameescape(temp_file_path))
  local bufnr = api.nvim_get_current_buf()

  if format_choice == "JSON Schema" then
    api.nvim_buf_set_option(bufnr, 'filetype', 'json')
  else
    api.nvim_buf_set_option(bufnr, 'filetype', 'markdown')
  end

  api.nvim_buf_set_var(bufnr, "llm_schema_name", name)
  api.nvim_buf_set_var(bufnr, "llm_schema_format", format_choice)
  api.nvim_buf_set_var(bufnr, "llm_temp_schema_file_path", temp_file_path)

  local group = api.nvim_create_augroup("LLMSchemaSave", { clear = true })
  api.nvim_create_autocmd("BufWritePost", {
    group = group,
    buffer = bufnr,
    callback = function(args)
      if api.nvim_buf_is_valid(args.buf) then
        require('llm.managers.schemas_manager').save_schema_from_temp_file(args.buf)
      end
    end,
  })

  api.nvim_buf_create_user_command(bufnr, "LlmCancel", function()
    local temp_file = api.nvim_buf_get_var(bufnr, "llm_temp_schema_file_path")
    api.nvim_command(bufnr .. "bdelete!")
    if temp_file and vim.fn.filereadable(temp_file) == 1 then
      os.remove(temp_file)
    end
    vim.notify("Schema creation cancelled.", vim.log.levels.INFO)
  end, {})

  vim.notify("Edit the schema in this buffer. Save (:w) to validate and finalize. Use :LlmCancel to abort.", vim.log.levels.INFO)
end

function M.save_schema_from_temp_file(bufnr)
  if not api.nvim_buf_is_valid(bufnr) then
    return
  end

  local name = api.nvim_buf_get_var(bufnr, "llm_schema_name")
  local format_choice = api.nvim_buf_get_var(bufnr, "llm_schema_format")
  local temp_file_path = api.nvim_buf_get_var(bufnr, "llm_temp_schema_file_path")
  local content = table.concat(api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
  content = content:gsub("^%s+", ""):gsub("%s+$", "")

  local validated_content, is_valid, error_message = M.validate_schema(content, format_choice)

  if not is_valid then
    vim.notify("Schema validation failed: " .. error_message, vim.log.levels.ERROR)
    vim.notify("Schema not saved. Please fix the content and save again (:w), or use :LlmCancel to abort.", vim.log.levels.WARN)
    return
  end

  vim.notify("Schema validated. Saving schema '" .. name .. "'...", vim.log.levels.INFO)
  local success = M.save_schema(name, validated_content)
  if success then
    vim.notify("Schema '" .. name .. "' saved successfully", vim.log.levels.INFO)
    vim.defer_fn(function()
      M.manage_schemas()
    end, 1500)
    api.nvim_command(bufnr .. "bdelete!")
    if temp_file_path then os.remove(temp_file_path) end
  else
    vim.notify("Failed to save schema '" .. name .. "'", vim.log.levels.ERROR)
  end
end

function M.validate_schema(content, format)
    -- Validation is now handled by the llm-cli
    return content, true, nil
end

function M.populate_schemas_buffer(bufnr)
  if _G.llm_schemas_named_only == nil then
    _G.llm_schemas_named_only = true
  end
  local show_named_only = _G.llm_schemas_named_only

  local all_schemas = M.get_schemas()
  local named_schemas, unnamed_schemas = M.categorize_schemas(all_schemas)
  local schemas_to_show = show_named_only and named_schemas or vim.list_extend(vim.deepcopy(named_schemas), unnamed_schemas)

  local lines = M.build_buffer_lines(schemas_to_show, show_named_only)
  local schema_data, line_to_schema = M.build_schema_data(schemas_to_show, #lines + 1)

  api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  styles.setup_highlights()
  styles.setup_buffer_syntax(bufnr)
  vim.b[bufnr].line_to_schema = line_to_schema
  vim.b[bufnr].schema_data = schema_data
  vim.b[bufnr].schemas = schemas_to_show
end

function M.categorize_schemas(all_schemas)
  local named_schemas = {}
  local unnamed_schemas = {}

  for _, schema in ipairs(all_schemas) do
    if schema.name then
      table.insert(named_schemas, schema)
    else
      table.insert(unnamed_schemas, schema)
    end
  end

  table.sort(named_schemas, function(a, b) return a.name < b.name end)
  table.sort(unnamed_schemas, function(a, b) return a.id < b.id end)
  return named_schemas, unnamed_schemas
end

function M.build_buffer_lines(schemas, show_named_only)
  local lines = {
    "# Schema Management",
    "",
    "Navigate: [M]odels [P]lugins [K]eys [F]ragments [T]emplates",
    "Actions: [c]reate [r]un [v]iew [e]dit [a]lias [d]elete alias [t]oggle view [q]uit",
    "──────────────────────────────────────────────────────────────",
    "",
    show_named_only and "Showing: Only named schemas" or "Showing: All schemas",
    ""
  }
  if #schemas == 0 then
    table.insert(lines, "No schemas found. Press 'c' to create one.")
  else
    table.insert(lines, "Schemas:")
    table.insert(lines, "----------")
    for i, schema in ipairs(schemas) do
      local description = schema.description:gsub("\n", " ")
      local schema_details = M.get_schema(schema.id)
      local is_valid = schema_details and schema_details.content and pcall(vim.fn.json_decode, schema_details.content)
      table.insert(lines, string.format("Schema %d: %s", i, schema.id))
      if schema.name then
        table.insert(lines, string.format("  Name: %s", schema.name))
      end
      table.insert(lines, string.format("  Status: %s", is_valid and "Valid" or "Invalid"))
      table.insert(lines, string.format("  Description: %s", description))
      table.insert(lines, "")
    end
  end
  return lines
end

function M.build_schema_data(schemas, start_line)
  local schema_data = {}
  local line_to_schema = {}
  local current_line = start_line
  for i, schema in ipairs(schemas) do
    local entry_lines = 1
    if schema.name then entry_lines = entry_lines + 1 end
    entry_lines = entry_lines + 3

    schema_data[schema.id] = {
      index = i,
      name = schema.name,
      description = schema.description,
      is_valid = M.get_schema(schema.id) and true or false,
      start_line = current_line,
    }
    for j = 0, entry_lines - 1 do
      line_to_schema[current_line + j] = schema.id
    end
    current_line = current_line + entry_lines
  end
  return schema_data, line_to_schema
end


function M.setup_schemas_keymaps(bufnr, manager_module)
  manager_module = manager_module or M
  local function set_keymap(mode, lhs, rhs)
    api.nvim_buf_set_keymap(bufnr, mode, lhs, rhs, { noremap = true, silent = true })
  end
  set_keymap('n', 'c', string.format([[<Cmd>lua require('%s').create_schema_from_manager(%d)<CR>]], manager_module.__name, bufnr))
  set_keymap('n', 'r', string.format([[<Cmd>lua require('%s').run_schema_under_cursor(%d)<CR>]], manager_module.__name, bufnr))
  set_keymap('n', 'v', string.format([[<Cmd>lua require('%s').view_schema_details_under_cursor(%d)<CR>]], manager_module.__name, bufnr))
  set_keymap('n', 'e', string.format([[<Cmd>lua require('%s').edit_schema_under_cursor(%d)<CR>]], manager_module.__name, bufnr))
  set_keymap('n', 'a', string.format([[<Cmd>lua require('%s').set_alias_for_schema_under_cursor(%d)<CR>]], manager_module.__name, bufnr))
  set_keymap('n', 'd', string.format([[<Cmd>lua require('%s').delete_alias_for_schema_under_cursor(%d)<CR>]], manager_module.__name, bufnr))
  set_keymap('n', 't', string.format([[<Cmd>lua require('%s').toggle_schemas_view(%d)<CR>]], manager_module.__name, bufnr))
end

function M.run_schema_under_cursor(bufnr)
  local schema_id, _ = M.get_schema_info_under_cursor(bufnr)
  if not schema_id then
    vim.notify("No schema found under cursor", vim.log.levels.ERROR)
    return
  end
  require('llm.ui.unified_manager').close()
  vim.schedule(function()
    M.run_schema_with_input_source(schema_id)
  end)
end

function M.view_schema_details_under_cursor(bufnr)
  local schema_id, _ = M.get_schema_info_under_cursor(bufnr)
  if not schema_id then
    vim.notify("No schema found under cursor", vim.log.levels.ERROR)
    return
  end
  local schema = M.get_schema(schema_id)
  if not schema then
    vim.notify("Failed to get schema details for '" .. schema_id .. "'", vim.log.levels.ERROR)
    return
  end
  require('llm.ui.unified_manager').close()
  vim.schedule(function()
    schemas_view.show_details(schema_id, schema, M)
  end)
end

function M.set_alias_for_schema_under_cursor(bufnr)
  local schema_id, schema_info = M.get_schema_info_under_cursor(bufnr)
  if not schema_id then
    vim.notify("No schema found under cursor", vim.log.levels.ERROR)
    return
  end
  schemas_view.get_alias(schema_info.name, function(new_alias)
    if not new_alias or new_alias == "" then
      vim.notify("Alias cannot be empty", vim.log.levels.WARN)
      return
    end
    if new_alias:match("[/\\]") then
      vim.notify("Alias cannot contain path separators (/ or \\)", vim.log.levels.ERROR)
      return
    end
    if llm_cli.run_llm_command('schemas alias set ' .. schema_id .. ' ' .. new_alias) then
      vim.notify("Schema alias set to '" .. new_alias .. "'", vim.log.levels.INFO)
      cache.invalidate('schemas')
      require('llm.ui.unified_manager').switch_view("Schemas")
    else
      vim.notify("Failed to set schema alias", vim.log.levels.ERROR)
    end
  end)
end

function M.create_schema_from_manager(bufnr)
  require('llm.ui.unified_manager').close()
  vim.schedule(function()
    M.create_schema()
  end)
end

function M.run_schema_from_details(schema_id)
  api.nvim_win_close(0, true)
  vim.schedule(function()
    M.run_schema_with_input_source(schema_id)
  end)
end

function M.set_alias_from_details(schema_id)
  local schema = M.get_schema(schema_id)
  schemas_view.get_alias(schema and schema.name, function(new_alias)
    if not new_alias or new_alias == "" then
      vim.notify("Alias cannot be empty", vim.log.levels.WARN)
      return
    end
    if new_alias:match("[/\\]") then
      vim.notify("Alias cannot contain path separators (/ or \\)", vim.log.levels.ERROR)
      return
    end
    if llm_cli.run_llm_command('schemas alias set ' .. schema_id .. ' ' .. new_alias) then
      vim.notify("Schema alias set to '" .. new_alias .. "'", vim.log.levels.INFO)
      cache.invalidate('schemas')
      api.nvim_win_close(0, true)
      vim.schedule(function()
        require('llm.ui.unified_manager').open_specific_manager("Schemas")
      end)
    else
      vim.notify("Failed to set schema alias", vim.log.levels.ERROR)
    end
  end)
end

function M.delete_alias_for_schema_under_cursor(bufnr)
  local schema_id, schema_info = M.get_schema_info_under_cursor(bufnr)
  if not schema_id or not schema_info.name then
    vim.notify("No schema with an alias found under cursor", vim.log.levels.ERROR)
    return
  end
  schemas_view.confirm_delete_alias(schema_info.name, function(confirmed)
    if not confirmed then return end
    if llm_cli.run_llm_command('schemas alias remove ' .. schema_info.name) then
      vim.notify("Schema alias '" .. schema_info.name .. "' deleted", vim.log.levels.INFO)
      cache.invalidate('schemas')
      require('llm.ui.unified_manager').switch_view("Schemas")
    else
      vim.notify("Failed to delete schema alias", vim.log.levels.ERROR)
    end
  end)
end

function M.edit_schema_under_cursor(bufnr)
  local schema_id, _ = M.get_schema_info_under_cursor(bufnr)
  if not schema_id then
    vim.notify("No schema found under cursor", vim.log.levels.ERROR)
    return
  end
  require('llm.ui.unified_manager').close()
  vim.schedule(function()
    M.edit_schema_from_details(schema_id)
  end)
end

function M.toggle_schemas_view(bufnr)
  _G.llm_schemas_named_only = not (_G.llm_schemas_named_only == true)
  require('llm.ui.unified_manager').close()
  vim.schedule(function()
    require('llm.ui.unified_manager').open_specific_manager("Schemas")
  end)
end

function M.delete_alias_from_details(schema_id)
  local schema = M.get_schema(schema_id)
  if not schema or not schema.name then
    vim.notify("This schema does not have an alias to delete", vim.log.levels.WARN)
    return
  end
  schemas_view.confirm_delete_alias(schema.name, function(confirmed)
    if not confirmed then return end
    if llm_cli.run_llm_command('schemas alias remove ' .. schema.name) then
      vim.notify("Schema alias '" .. schema.name .. "' deleted", vim.log.levels.INFO)
      cache.invalidate('schemas')
      api.nvim_win_close(0, true)
      vim.schedule(function()
        require('llm.ui.unified_manager').open_specific_manager("Schemas")
      end)
    else
      vim.notify("Failed to delete schema alias", vim.log.levels.ERROR)
    end
  end)
end

function M.get_schema_info_under_cursor(bufnr)
  local current_line = api.nvim_win_get_cursor(0)[1]
  local line_to_schema = vim.b[bufnr].line_to_schema
  local schema_data = vim.b[bufnr].schema_data
  if not line_to_schema or not schema_data then
    vim.notify("Buffer data missing", vim.log.levels.ERROR)
    return nil, nil
  end
  local schema_id = line_to_schema[current_line]
  if schema_id and schema_data[schema_id] then
    return schema_id, schema_data[schema_id]
  end
  return nil, nil
end

function M.manage_schemas(show_named_only)
  _G.llm_schemas_named_only = show_named_only or true
  require('llm.ui.unified_manager').open_specific_manager("Schemas")
end

M.__name = 'llm.managers.schemas_manager'

return M
