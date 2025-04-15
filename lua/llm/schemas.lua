-- llm/schemas.lua - Schema handling for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local api = vim.api
local fn = vim.fn

-- Get schemas from llm CLI
function M.get_schemas()
  local handle = io.popen("llm schemas")
  local result = handle:read("*a")
  handle:close()
  
  local schemas = {}
  
  for line in result:gmatch("[^\r\n]+") do
    if line:match("^%- id:") then
      local id = line:match("^%- id:%s+([0-9a-f]+)")
      if id then
        table.insert(schemas, {
          id = id,
          summary = "",
          usage = ""
        })
      end
    elseif line:match("^%s+summary:") then
      -- Skip the summary line itself
    elseif line:match("^%s+usage:") then
      -- Skip the usage line itself
    elseif #schemas > 0 then
      local last_schema = schemas[#schemas]
      if line:match("^%s+%|") then
        -- This is a continuation of summary or usage
        local content = line:match("^%s+%|%s+(.*)")
        if content then
          if last_schema.summary == "" then
            last_schema.summary = content
          else
            last_schema.usage = content
          end
        end
      end
    end
  end
  
  return schemas
end

-- Get schema details
function M.get_schema_details(schema_id)
  local cmd = string.format('llm schemas --full | grep -A 100 "id: %s"', schema_id)
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  handle:close()
  
  local details = {
    id = schema_id,
    schema = ""
  }
  
  local in_schema = false
  
  for line in result:gmatch("[^\r\n]+") do
    if line:match("^%s+schema:") then
      in_schema = true
    elseif line:match("^%-") and in_schema then
      -- Start of a new schema, stop parsing
      break
    elseif in_schema then
      if line:match("^%s+%|") then
        -- This is a continuation of the schema
        local content = line:match("^%s+%|%s+(.*)")
        if content then
          details.schema = details.schema .. content .. "\n"
        end
      end
    end
  end
  
  -- Trim whitespace
  details.schema = details.schema:match("^%s*(.-)%s*$") or ""
  
  return details
end

-- Create a new schema
function M.create_schema(name, schema_content)
  -- Create a temporary file with the schema content
  local temp_file = os.tmpname()
  local file = io.open(temp_file, "w")
  
  if not file then
    vim.notify("Failed to create temporary file", vim.log.levels.ERROR)
    return false
  end
  
  file:write(schema_content)
  file:close()
  
  -- Create the schema using llm CLI
  local cmd = string.format('llm schemas save "%s" "%s"', name, temp_file)
  local handle = io.popen(cmd)
  if not handle then
    vim.notify("Failed to execute command", vim.log.levels.ERROR)
    os.remove(temp_file)
    return false
  end
  
  local result = handle:read("*a")
  local success, exit_type, exit_code = handle:close()
  
  -- Clean up temp file
  os.remove(temp_file)
  
  -- In Lua, popen:close() returns true only if the command exited with status 0
  -- For llm CLI, we need to check the output for success indicators
  if result and (result:match("Schema saved") or result:match("saved successfully")) then
    vim.notify("Schema created successfully: " .. name, vim.log.levels.INFO)
    return true
  else
    vim.notify("Failed to create schema: " .. (result or "Unknown error"), vim.log.levels.ERROR)
    return false
  end
end

-- Delete a schema
function M.delete_schema(schema_id)
  local cmd = string.format('llm schemas delete %s -y', schema_id)
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  local success = handle:close()
  
  return success
end

-- Run a schema
function M.run_schema(schema_id, input, is_multi)
  local cmd
  local schema_option = is_multi and "--schema-multi" or "--schema"
  
  if input and input ~= "" then
    -- Create a temporary file with the input
    local temp_file = os.tmpname()
    local file = io.open(temp_file, "w")
    file:write(input)
    file:close()
    
    cmd = string.format('cat %s | llm %s %s', temp_file, schema_option, schema_id)
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    
    -- Clean up temp file
    os.remove(temp_file)
    
    return result
  else
    cmd = string.format('llm %s %s "Generate data that matches this schema"', schema_option, schema_id)
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    
    return result
  end
end

-- Convert Concise LLM Schema Syntax to JSON schema
function M.concise_to_schema(concise_syntax)
  local cmd = string.format('llm schemas dsl "%s"', concise_syntax:gsub('"', '\\"'))
  local handle = io.popen(cmd)
  if not handle then
    vim.notify("Failed to execute command", vim.log.levels.ERROR)
    return "{}"
  end
  
  local result = handle:read("*a")
  handle:close()
  
  if not result or result == "" then
    vim.notify("Failed to convert schema syntax", vim.log.levels.ERROR)
    return "{}"
  end
  
  return result
end

-- Select a schema to use
function M.select_schema()
  local schemas = M.get_schemas()
  
  if #schemas == 0 then
    vim.notify("No schemas found", vim.log.levels.WARN)
    return
  end
  
  -- Format schemas for selection
  local items = {}
  for _, schema in ipairs(schemas) do
    table.insert(items, schema.id .. " - " .. schema.summary)
  end
  
  vim.ui.select(items, {
    prompt = "Select a schema to use:"
  }, function(choice, idx)
    if not choice then return end
    
    local schema_id = schemas[idx].id
    
    -- Ask if this is a multi-schema
    vim.ui.select({"Single object", "Multiple objects (array)"}, {
      prompt = "Schema type:"
    }, function(schema_type)
      if not schema_type then return end
      
      local is_multi = schema_type == "Multiple objects (array)"
      
      -- Ask for input
      vim.ui.input({
        prompt = "Enter input for schema (optional):"
      }, function(input)
        -- Run the schema
        local result = M.run_schema(schema_id, input or "", is_multi)
        
        -- Create a response buffer with the result
        require('llm').create_response_buffer(result)
      end)
    end)
  end)
end

-- Manage schemas (view, create, edit, delete)
function M.manage_schemas()
  local schemas = M.get_schemas()
  
  -- Create a new buffer for the schema manager
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(buf, 'swapfile', false)
  api.nvim_buf_set_name(buf, 'LLM Schemas')
  
  -- Create a new window
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  local opts = {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' LLM Schemas ',
    title_pos = 'center',
  }
  
  local win = api.nvim_open_win(buf, true, opts)
  api.nvim_win_set_option(win, 'cursorline', true)
  api.nvim_win_set_option(win, 'winblend', 0)
  
  -- Set buffer content
  local lines = {
    "# LLM Schemas Manager",
    "",
    "Press 'v' to view schema, 'e' to edit schema, 'd' to delete schema, 'c' to create new schema, 'r' to run schema, 'q' to quit",
    "──────────────────────────────────────────────────────────────",
    ""
  }
  
  -- Add schemas to the buffer
  for i, schema in ipairs(schemas) do
    table.insert(lines, schema.id .. " - " .. schema.summary)
    table.insert(lines, "  Usage: " .. schema.usage)
    table.insert(lines, "")
  end
  
  -- Add option to create a new schema
  table.insert(lines, "")
  table.insert(lines, "[+] Create new schema")
  
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  
  -- Set buffer options
  api.nvim_buf_set_option(buf, 'modifiable', false)
  
  -- Set up syntax highlighting
  require('llm').setup_buffer_highlighting(buf)
  
  -- Add schema-specific highlighting
  vim.cmd([[
    highlight default LLMSchemaItem guifg=#61afef
    highlight default LLMSchemaUsage guifg=#98c379
    highlight default LLMSchemaCreate guifg=#c678dd gui=bold
  ]])
  
  -- Apply syntax highlighting
  local syntax_cmds = {
    "syntax match LLMSchemaItem /^[0-9a-f]\\+ - .*$/",
    "syntax match LLMSchemaUsage /^  Usage: .*$/",
    "syntax match LLMSchemaCreate /^\\[+\\] Create new schema$/",
  }
  
  for _, cmd in ipairs(syntax_cmds) do
    vim.api.nvim_buf_call(buf, function()
      vim.cmd(cmd)
    end)
  end
  
  -- Map of line numbers to schema IDs
  local line_to_schema = {}
  local schema_start_line = 6 -- Line where schemas start
  for i, schema in ipairs(schemas) do
    local line_num = schema_start_line + (i - 1) * 3
    line_to_schema[line_num] = schema.id
    line_to_schema[line_num + 1] = schema.id
  end
  
  -- Set keymaps
  local function set_keymap(mode, lhs, rhs)
    api.nvim_buf_set_keymap(buf, mode, lhs, rhs, {noremap = true, silent = true})
  end
  
  -- View schema
  set_keymap('n', 'v', [[<cmd>lua require('llm.schema_manager').view_schema_under_cursor()<CR>]])
  
  -- Edit schema
  set_keymap('n', 'e', [[<cmd>lua require('llm.schema_manager').edit_schema_under_cursor()<CR>]])
  
  -- Delete schema
  set_keymap('n', 'd', [[<cmd>lua require('llm.schema_manager').delete_schema_under_cursor()<CR>]])
  
  -- Create new schema
  set_keymap('n', 'c', [[<cmd>lua require('llm.schema_manager').create_new_schema()<CR>]])
  
  -- Run schema
  set_keymap('n', 'r', [[<cmd>lua require('llm.schema_manager').run_schema_under_cursor()<CR>]])
  
  -- Close window
  set_keymap('n', 'q', [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])
  set_keymap('n', '<Esc>', [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])
  
  -- Create schema manager module for the helper functions
  local schema_manager = {}
  
  function schema_manager.view_schema_under_cursor()
    local current_line = api.nvim_win_get_cursor(0)[1]
    local schema_id = line_to_schema[current_line]
    
    if not schema_id then
      -- Check if we're on the "Create new schema" line
      local line_content = api.nvim_buf_get_lines(buf, current_line - 1, current_line, false)[1]
      if line_content == "[+] Create new schema" then
        schema_manager.create_new_schema()
      end
      return
    end
    
    -- Get schema details
    local details = M.get_schema_details(schema_id)
    
    -- Create a new buffer for the schema content
    local content_buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(content_buf, 'buftype', 'nofile')
    api.nvim_buf_set_option(content_buf, 'bufhidden', 'wipe')
    api.nvim_buf_set_option(content_buf, 'swapfile', false)
    
    -- Use a unique buffer name to avoid conflicts
    local buffer_name = 'LLM Schema View: ' .. schema_id .. ' ' .. os.time()
    pcall(api.nvim_buf_set_name, content_buf, buffer_name)
    
    -- Create a new window
    local content_win = api.nvim_open_win(content_buf, true, {
      relative = 'editor',
      width = width,
      height = height,
      row = row,
      col = col,
      style = 'minimal',
      border = 'rounded',
      title = ' Schema: ' .. schema_id .. ' ',
      title_pos = 'center',
    })
    
    -- Set content
    local content_lines = {}
    table.insert(content_lines, "# Schema: " .. schema_id)
    table.insert(content_lines, "")
    
    if details.schema and details.schema ~= "" then
      table.insert(content_lines, "```json")
      for line in details.schema:gmatch("[^\r\n]+") do
        table.insert(content_lines, line)
      end
      table.insert(content_lines, "```")
    else
      table.insert(content_lines, "No schema content found.")
    end
    
    api.nvim_buf_set_lines(content_buf, 0, -1, false, content_lines)
    
    -- Set buffer options
    api.nvim_buf_set_option(content_buf, 'modifiable', false)
    
    -- Set filetype for syntax highlighting
    api.nvim_buf_set_option(content_buf, 'filetype', 'markdown')
    
    -- Set keymap to close window
    api.nvim_buf_set_keymap(content_buf, 'n', 'q', [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]], {noremap = true, silent = true})
    api.nvim_buf_set_keymap(content_buf, 'n', '<Esc>', [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]], {noremap = true, silent = true})
  end
  
  function schema_manager.edit_schema_under_cursor()
    local current_line = vim.api.nvim_win_get_cursor(0)[1]
    local schema_id = line_to_schema[current_line]
    
    if not schema_id then return end
    
    -- Get schema details
    local details = M.get_schema_details(schema_id)
    
    -- Get the current window
    local current_win = api.nvim_get_current_win()
    
    -- Create a new buffer for schema editing
    local edit_buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(edit_buf, 'buftype', 'nofile')
    api.nvim_buf_set_option(edit_buf, 'bufhidden', 'wipe')
    api.nvim_buf_set_option(edit_buf, 'swapfile', false)
    
    -- Use a unique buffer name to avoid conflicts
    local buffer_name = 'LLM Edit Schema: ' .. schema_id .. ' ' .. os.time()
    pcall(api.nvim_buf_set_name, edit_buf, buffer_name)
    
    -- Create a new window
    local edit_win = api.nvim_open_win(edit_buf, true, {
      relative = 'editor',
      width = width,
      height = height,
      row = row,
      col = col,
      style = 'minimal',
      border = 'rounded',
      title = ' Edit Schema: ' .. schema_id .. ' ',
      title_pos = 'center',
    })
    
    -- Set content
    local content_lines = {
      "# Edit Schema: " .. schema_id,
      "",
      "Schema Content:",
      "```json",
    }
    
    -- Add schema content
    if details.schema and details.schema ~= "" then
      for line in details.schema:gmatch("[^\r\n]+") do
        table.insert(content_lines, line)
      end
    else
      table.insert(content_lines, "{\n  \"type\": \"object\",\n  \"properties\": {\n    \n  }\n}")
    end
    
    table.insert(content_lines, "```")
    table.insert(content_lines, "")
    table.insert(content_lines, "Press <Ctrl-S> to save changes")
    table.insert(content_lines, "Press <Esc> to cancel")
    
    api.nvim_buf_set_lines(edit_buf, 0, -1, false, content_lines)
    api.nvim_buf_set_option(edit_buf, 'modifiable', true)
    
    -- Set up syntax highlighting
    require('llm').setup_buffer_highlighting(edit_buf)
    
    -- Apply syntax highlighting
    local syntax_cmds = {
      "syntax match LLMSchemaHeader /^# Edit Schema: .*$/",
      "syntax match LLMSchemaField /^Schema Content:$/",
      "syntax match LLMSchemaHelp /^Press.*$/",
      "syntax region LLMSchemaContent start=/^```json$/ end=/^```$/ contains=ALL"
    }
    
    for _, cmd in ipairs(syntax_cmds) do
      vim.api.nvim_buf_call(edit_buf, function()
        vim.cmd(cmd)
      end)
    end
    
    -- Set highlighting
    vim.cmd([[
      highlight default LLMSchemaHeader guifg=#61afef gui=bold
      highlight default LLMSchemaField guifg=#c678dd gui=bold
      highlight default LLMSchemaHelp guifg=#5c6370 gui=italic
      highlight default LLMSchemaContent guifg=#abb2bf
    ]])
    
    -- Set keymaps
    local function set_keymap(mode, lhs, rhs)
      api.nvim_buf_set_keymap(edit_buf, mode, lhs, rhs, {noremap = true, silent = true})
    end
    
    -- Save schema
    set_keymap('n', '<C-s>', [[<cmd>lua require('llm.schema_manager').save_edited_schema()<CR>]])
    
    -- Cancel
    set_keymap('n', '<Esc>', [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])
    
    -- Add save function to schema_manager
    schema_manager.edit_buf = edit_buf
    schema_manager.edit_win = edit_win
    schema_manager.current_schema_id = schema_id
    schema_manager.current_win = current_win
    
    schema_manager.save_edited_schema = function()
      -- Get content from buffer
      local start_line = 4 -- After ```json
      local end_line
      
      -- Find the closing ```
      local lines = api.nvim_buf_get_lines(schema_manager.edit_buf, 0, -1, false)
      for i, line in ipairs(lines) do
        if i > start_line and line == "```" then
          end_line = i
          break
        end
      end
      
      if not end_line then
        vim.notify("Invalid schema format", vim.log.levels.ERROR)
        return
      end
      
      local content_lines = api.nvim_buf_get_lines(schema_manager.edit_buf, start_line, end_line, false)
      local content = table.concat(content_lines, "\n")
      
      -- Create a temporary file with the schema content
      local temp_file = os.tmpname()
      local file = io.open(temp_file, "w")
      
      if not file then
        vim.notify("Failed to create temporary file", vim.log.levels.ERROR)
        return
      end
      
      file:write(content)
      file:close()
      
      -- Save the schema
      local cmd = string.format('llm schemas save "%s" "%s"', schema_manager.current_schema_id, temp_file)
      local handle = io.popen(cmd)
      
      if not handle then
        vim.notify("Failed to execute command", vim.log.levels.ERROR)
        os.remove(temp_file)
        return
      end
      
      local result = handle:read("*a")
      local success, exit_type, exit_code = handle:close()
      
      -- Clean up temp file
      os.remove(temp_file)
      
      -- In Lua, popen:close() returns true only if the command exited with status 0
      -- For llm CLI, we need to check the output for success indicators
      if result and (result:match("Schema saved") or result:match("saved successfully")) then
        vim.notify("Schema saved: " .. schema_manager.current_schema_id, vim.log.levels.INFO)
        
        -- Close the edit window
        api.nvim_win_close(schema_manager.edit_win, true)
        
        -- Close the schema manager window
        api.nvim_win_close(schema_manager.current_win, true)
        
        -- Reopen the schema manager
        vim.schedule(function()
          M.manage_schemas()
        end)
      else
        vim.notify("Failed to save schema: " .. (result or "Unknown error"), vim.log.levels.ERROR)
      end
    end
    
    -- Position cursor at the beginning of the schema content
    vim.api.nvim_win_set_cursor(edit_win, {5, 0})
  end
  
  function schema_manager.delete_schema_under_cursor()
    local current_line = api.nvim_win_get_cursor(0)[1]
    local schema_id = line_to_schema[current_line]
    
    if not schema_id then return end
    
    -- Confirm deletion
    vim.ui.select({"Yes", "No"}, {
      prompt = "Delete schema '" .. schema_id .. "'?"
    }, function(choice)
      if choice ~= "Yes" then return end
      
      if M.delete_schema(schema_id) then
        vim.notify("Schema deleted: " .. schema_id, vim.log.levels.INFO)
        
        -- Refresh the schema manager
        vim.api.nvim_win_close(0, true)
        vim.schedule(function()
          M.manage_schemas()
        end)
      else
        vim.notify("Failed to delete schema", vim.log.levels.ERROR)
      end
    end)
  end
  
  function schema_manager.create_new_schema()
    -- Get the current window and buffer
    local current_win = api.nvim_get_current_win()
    local current_buf = api.nvim_get_current_buf()
    
    -- Create a new buffer for schema creation
    local create_buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(create_buf, 'buftype', 'nofile')
    api.nvim_buf_set_option(create_buf, 'bufhidden', 'wipe')
    api.nvim_buf_set_option(create_buf, 'swapfile', false)
    
    -- Use a unique buffer name to avoid conflicts
    local buffer_name = 'LLM Create Schema ' .. os.time()
    pcall(api.nvim_buf_set_name, create_buf, buffer_name)
    
    -- Create a new window
    local create_win = api.nvim_open_win(create_buf, true, {
      relative = 'editor',
      width = width,
      height = height,
      row = row,
      col = col,
      style = 'minimal',
      border = 'rounded',
      title = ' Create New Schema ',
      title_pos = 'center',
    })
    
    -- Set content
    local content_lines = {
      "# Create New Schema",
      "",
      "Schema Name: ",
      "",
      "Schema Format:",
      "[ ] JSON Schema",
      "[ ] Concise LLM Schema Syntax",
      "",
      "Schema Content:",
      "```",
      "",
      "```",
      "",
      "Press <Enter> on a format option to select it",
      "Press <Tab> to navigate between fields",
      "Press <Ctrl-S> to save the schema",
      "Press <Esc> to cancel"
    }
    
    api.nvim_buf_set_lines(create_buf, 0, -1, false, content_lines)
    api.nvim_buf_set_option(create_buf, 'modifiable', true)
    
    -- Set up syntax highlighting
    require('llm').setup_buffer_highlighting(create_buf)
    
    -- Apply syntax highlighting
    local syntax_cmds = {
      "syntax match LLMSchemaHeader /^# Create New Schema$/",
      "syntax match LLMSchemaField /^Schema Name: \\|^Schema Format:\\|^Schema Content:$/",
      "syntax match LLMSchemaOption /^\\[[ x]\\] .*$/",
      "syntax match LLMSchemaHelp /^Press.*$/",
      "syntax region LLMSchemaContent start=/^```$/ end=/^```$/ contains=ALL"
    }
    
    for _, cmd in ipairs(syntax_cmds) do
      vim.api.nvim_buf_call(create_buf, function()
        vim.cmd(cmd)
      end)
    end
    
    -- Set highlighting
    vim.cmd([[
      highlight default LLMSchemaHeader guifg=#61afef gui=bold
      highlight default LLMSchemaField guifg=#c678dd gui=bold
      highlight default LLMSchemaOption guifg=#98c379
      highlight default LLMSchemaHelp guifg=#5c6370 gui=italic
      highlight default LLMSchemaContent guifg=#abb2bf
    ]])
    
    -- State variables
    local schema_name = ""
    local selected_format = nil
    local current_section = "name" -- name, format, content
    
    -- Helper functions
    local function update_name(name)
      schema_name = name
      api.nvim_buf_set_lines(create_buf, 2, 3, false, {"Schema Name: " .. name})
    end
    
    local function update_format(format)
      selected_format = format
      local json_line = "[ ] JSON Schema"
      local concise_line = "[ ] Concise LLM Schema Syntax"
      
      if format == "json" then
        json_line = "[x] JSON Schema"
      elseif format == "concise" then
        concise_line = "[x] Concise LLM Schema Syntax"
      end
      
      api.nvim_buf_set_lines(create_buf, 5, 7, false, {json_line, concise_line})
      
      -- Update content template based on format
      if format == "json" then
        api.nvim_buf_set_lines(create_buf, 10, 11, false, {"{\n  \"type\": \"object\",\n  \"properties\": {\n    \n  }\n}"})
      elseif format == "concise" then
        api.nvim_buf_set_lines(create_buf, 10, 11, false, {"name, age int, bio"})
      end
    end
    
    local function get_content()
      local lines = api.nvim_buf_get_lines(create_buf, 10, -6, false)
      return table.concat(lines, "\n")
    end
    
    local function save_schema()
      if schema_name == "" then
        vim.notify("Schema name cannot be empty", vim.log.levels.ERROR)
        return
      end
      
      if not selected_format then
        vim.notify("Please select a schema format", vim.log.levels.ERROR)
        return
      end
      
      local content = get_content()
      if content == "" then
        vim.notify("Schema content cannot be empty", vim.log.levels.ERROR)
        return
      end
      
      local schema_content = content
      if selected_format == "concise" then
        schema_content = M.concise_to_schema(content)
      end
      
      if M.create_schema(schema_name, schema_content) then
        -- Close the create window
        api.nvim_win_close(create_win, true)
        
        -- Close the schema manager window
        api.nvim_win_close(current_win, true)
        
        -- Reopen the schema manager with the new schema
        vim.schedule(function()
          M.manage_schemas()
        end)
      end
    end
    
    -- Set keymaps
    local function set_keymap(mode, lhs, rhs)
      api.nvim_buf_set_keymap(create_buf, mode, lhs, rhs, {noremap = true, silent = true})
    end
    
    -- Tab to navigate between sections
    set_keymap('n', '<Tab>', [[<cmd>lua require('llm.schema_manager').navigate_next_section()<CR>]])
    set_keymap('n', '<S-Tab>', [[<cmd>lua require('llm.schema_manager').navigate_prev_section()<CR>]])
    
    -- Enter to select format
    set_keymap('n', '<CR>', [[<cmd>lua require('llm.schema_manager').handle_enter()<CR>]])
    
    -- Save schema
    set_keymap('n', '<C-s>', [[<cmd>lua require('llm.schema_manager').save_schema()<CR>]])
    
    -- Cancel
    set_keymap('n', '<Esc>', [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])
    
    -- Add navigation functions to schema_manager
    schema_manager.current_section = current_section
    schema_manager.schema_name = schema_name
    schema_manager.selected_format = selected_format
    schema_manager.create_buf = create_buf
    schema_manager.create_win = create_win
    schema_manager.current_win = current_win
    
    schema_manager.navigate_next_section = function()
      if schema_manager.current_section == "name" then
        schema_manager.current_section = "format"
        vim.api.nvim_win_set_cursor(schema_manager.create_win, {6, 1})
      elseif schema_manager.current_section == "format" then
        schema_manager.current_section = "content"
        vim.api.nvim_win_set_cursor(schema_manager.create_win, {11, 1})
      else
        schema_manager.current_section = "name"
        vim.api.nvim_win_set_cursor(schema_manager.create_win, {3, 13})
      end
    end
    
    schema_manager.navigate_prev_section = function()
      if schema_manager.current_section == "content" then
        schema_manager.current_section = "format"
        vim.api.nvim_win_set_cursor(schema_manager.create_win, {6, 1})
      elseif schema_manager.current_section == "format" then
        schema_manager.current_section = "name"
        vim.api.nvim_win_set_cursor(schema_manager.create_win, {3, 13})
      else
        schema_manager.current_section = "content"
        vim.api.nvim_win_set_cursor(schema_manager.create_win, {11, 1})
      end
    end
    
    schema_manager.handle_enter = function()
      local current_line = vim.api.nvim_win_get_cursor(schema_manager.create_win)[1]
      local line_content = api.nvim_buf_get_lines(schema_manager.create_buf, current_line - 1, current_line, false)[1]
      
      if current_line == 3 then
        -- Name section
        vim.ui.input({
          prompt = "Enter schema name: ",
          default = schema_manager.schema_name
        }, function(input)
          if input and input ~= "" then
            update_name(input)
            schema_manager.schema_name = input
          end
        end)
      elseif current_line == 6 then
        -- JSON Schema option
        update_format("json")
        schema_manager.selected_format = "json"
      elseif current_line == 7 then
        -- Concise LLM Schema Syntax option
        update_format("concise")
        schema_manager.selected_format = "concise"
      end
    end
    
    schema_manager.save_schema = function()
      save_schema()
    end
    
    -- Position cursor at name field
    vim.api.nvim_win_set_cursor(create_win, {3, 13})
    
    -- Enter insert mode
    vim.cmd("startinsert!")
  end
  
  function schema_manager.run_schema_under_cursor()
    local current_line = api.nvim_win_get_cursor(0)[1]
    local schema_id = line_to_schema[current_line]
    
    if not schema_id then return end
    
    -- Close the schema manager window
    vim.api.nvim_win_close(0, true)
    
    -- Ask if this is a multi-schema
    vim.ui.select({"Single object", "Multiple objects (array)"}, {
      prompt = "Schema type:"
    }, function(schema_type)
      if not schema_type then return end
      
      local is_multi = schema_type == "Multiple objects (array)"
      
      -- Ask for input
      vim.ui.input({
        prompt = "Enter input for schema (optional):"
      }, function(input)
        -- Run the schema
        local result = M.run_schema(schema_id, input or "", is_multi)
        
        -- Create a response buffer with the result
        require('llm').create_response_buffer(result)
      end)
    end)
  end
  
  -- Store the schema manager module
  package.loaded['llm.schema_manager'] = schema_manager
end

return M
