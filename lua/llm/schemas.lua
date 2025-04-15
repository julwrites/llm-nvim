-- llm/schemas.lua - Simple schema handling for llm-nvim
-- License: Apache 2.0

local M = {}
local config = require('llm.config')

-- Forward declarations
local api = vim.api
local fn = vim.fn

-- Initialize schemas in config if not already present
local function ensure_schemas_config()
  if not config.get('schemas') then
    config.setup({ schemas = {} })
  end
end

-- Get all stored schemas
function M.get_schemas()
  ensure_schemas_config()
  return config.get('schemas') or {}
end

-- Get a specific schema by name
function M.get_schema(name)
  local schemas = M.get_schemas()
  return schemas[name]
end

-- Save a schema
function M.save_schema(name, schema_text)
  ensure_schemas_config()
  local schemas = M.get_schemas()
  
  -- Store the schema with its original text
  schemas[name] = {
    text = schema_text,
    created_at = os.date("%Y-%m-%d %H:%M:%S")
  }
  
  -- Update config
  config.setup({ schemas = schemas })
  
  return true
end

-- Delete a schema
function M.delete_schema(name)
  ensure_schemas_config()
  local schemas = M.get_schemas()
  
  if not schemas[name] then
    return false
  end
  
  schemas[name] = nil
  config.setup({ schemas = schemas })
  
  return true
end

-- Run a schema with LLM
function M.run_schema(name, input, is_multi)
  local schema = M.get_schema(name)
  if not schema then
    vim.notify("Schema not found: " .. name, vim.log.levels.ERROR)
    return nil
  end
  
  local schema_option = is_multi and "--schema-multi" or "--schema"
  local cmd
  
  if input and input ~= "" then
    -- Create a temporary file with the input
    local temp_file = os.tmpname()
    local file = io.open(temp_file, "w")
    file:write(input)
    file:close()
    
    cmd = string.format('cat %s | llm %s "%s"', temp_file, schema_option, schema.text:gsub('"', '\\"'))
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    
    -- Clean up temp file
    os.remove(temp_file)
    
    return result
  else
    cmd = string.format('llm %s "%s" "Generate data that matches this schema"', schema_option, schema.text:gsub('"', '\\"'))
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    
    return result
  end
end

-- Select a schema to use
function M.select_schema()
  local schemas = M.get_schemas()
  local schema_names = {}
  
  for name, _ in pairs(schemas) do
    table.insert(schema_names, name)
  end
  
  if #schema_names == 0 then
    vim.notify("No schemas found", vim.log.levels.WARN)
    return
  end
  
  -- Sort schema names alphabetically
  table.sort(schema_names)
  
  vim.ui.select(schema_names, {
    prompt = "Select a schema to use:"
  }, function(choice)
    if not choice then return end
    
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
        local result = M.run_schema(choice, input or "", is_multi)
        
        -- Create a response buffer with the result
        require('llm').create_response_buffer(result)
      end)
    end)
  end)
end

-- Manage schemas (view, create, edit, delete)
function M.manage_schemas()
  local schemas = M.get_schemas()
  local schema_names = {}
  
  for name, _ in pairs(schemas) do
    table.insert(schema_names, name)
  end
  
  -- Sort schema names alphabetically
  table.sort(schema_names)
  
  -- Create a new buffer for the schema manager
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(buf, 'swapfile', false)
  api.nvim_buf_set_name(buf, 'LLM Simple Schemas')
  
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
    title = ' LLM Simple Schemas ',
    title_pos = 'center',
  }
  
  local win = api.nvim_open_win(buf, true, opts)
  api.nvim_win_set_option(win, 'cursorline', true)
  api.nvim_win_set_option(win, 'winblend', 0)
  
  -- Set buffer content
  local lines = {
    "# LLM Simple Schemas Manager",
    "",
    "Press 'v' to view schema, 'e' to edit schema, 'd' to delete schema, 'c' to create new schema, 'r' to run schema, 'q' to quit",
    "──────────────────────────────────────────────────────────────",
    ""
  }
  
  -- Add schemas to the buffer
  for _, name in ipairs(schema_names) do
    local schema = schemas[name]
    local preview = schema.text:gsub("\n", " "):sub(1, 50)
    if #schema.text > 50 then
      preview = preview .. "..."
    end
    
    table.insert(lines, name)
    table.insert(lines, "  Created: " .. (schema.created_at or "unknown"))
    table.insert(lines, "  Schema: " .. preview)
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
    highlight default LLMSchemaName guifg=#61afef
    highlight default LLMSchemaCreated guifg=#98c379
    highlight default LLMSchemaContent guifg=#e5c07b
    highlight default LLMSchemaCreate guifg=#c678dd gui=bold
  ]])
  
  -- Apply syntax highlighting
  local syntax_cmds = {
    "syntax match LLMSchemaName /^[A-Za-z0-9_-]\\+$/",
    "syntax match LLMSchemaCreated /^  Created: .*$/",
    "syntax match LLMSchemaContent /^  Schema: .*$/",
    "syntax match LLMSchemaCreate /^\\[+\\] Create new schema$/",
  }
  
  for _, cmd in ipairs(syntax_cmds) do
    vim.api.nvim_buf_call(buf, function()
      vim.cmd(cmd)
    end)
  end
  
  -- Map of line numbers to schema names
  local line_to_schema = {}
  local schema_start_line = 6 -- Line where schemas start
  local line_num = schema_start_line
  
  for _, name in ipairs(schema_names) do
    line_to_schema[line_num] = name
    line_to_schema[line_num + 1] = name
    line_to_schema[line_num + 2] = name
    line_num = line_num + 4 -- Each schema takes 4 lines (name, created, schema, blank)
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
    local schema_name = line_to_schema[current_line]
    
    if not schema_name then
      -- Check if we're on the "Create new schema" line
      local line_content = api.nvim_buf_get_lines(buf, current_line - 1, current_line, false)[1]
      if line_content == "[+] Create new schema" then
        schema_manager.create_new_schema()
      end
      return
    end
    
    -- Get schema details
    local schema = M.get_schema(schema_name)
    
    -- Create a new buffer for the schema content
    local content_buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(content_buf, 'buftype', 'nofile')
    api.nvim_buf_set_option(content_buf, 'bufhidden', 'wipe')
    api.nvim_buf_set_option(content_buf, 'swapfile', false)
    
    -- Use a unique buffer name to avoid conflicts
    local buffer_name = 'LLM Schema View: ' .. schema_name
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
      title = ' Schema: ' .. schema_name .. ' ',
      title_pos = 'center',
    })
    
    -- Set content
    local content_lines = {
      "# Schema: " .. schema_name,
      "Created: " .. (schema.created_at or "unknown"),
      "",
      "```",
    }
    
    -- Add schema content
    for line in schema.text:gmatch("[^\r\n]+") do
      table.insert(content_lines, line)
    end
    
    table.insert(content_lines, "```")
    
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
    local schema_name = line_to_schema[current_line]
    
    if not schema_name then return end
    
    -- Get schema details
    local schema = M.get_schema(schema_name)
    
    -- Get the current window
    local current_win = api.nvim_get_current_win()
    
    -- Create a new buffer for schema editing
    local edit_buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(edit_buf, 'buftype', 'nofile')
    api.nvim_buf_set_option(edit_buf, 'bufhidden', 'wipe')
    api.nvim_buf_set_option(edit_buf, 'swapfile', false)
    
    -- Use a unique buffer name to avoid conflicts
    local buffer_name = 'LLM Edit Schema: ' .. schema_name
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
      title = ' Edit Schema: ' .. schema_name .. ' ',
      title_pos = 'center',
    })
    
    -- Set content
    local content_lines = {
      "# Edit Schema: " .. schema_name,
      "",
      "Schema Content (use the concise LLM schema syntax):",
      "",
    }
    
    -- Add schema content
    for line in schema.text:gmatch("[^\r\n]+") do
      table.insert(content_lines, line)
    end
    
    table.insert(content_lines, "")
    if vim.fn.has('mac') == 1 then
      table.insert(content_lines, "Press <Cmd-S> to save changes")
    else
      table.insert(content_lines, "Press <Ctrl-S> to save changes")
    end
    table.insert(content_lines, "Press <Esc> to cancel")
    
    api.nvim_buf_set_lines(edit_buf, 0, -1, false, content_lines)
    api.nvim_buf_set_option(edit_buf, 'modifiable', true)
    
    -- Set up syntax highlighting
    require('llm').setup_buffer_highlighting(edit_buf)
    
    -- Apply syntax highlighting
    local syntax_cmds = {
      "syntax match LLMSchemaHeader /^# Edit Schema: .*$/",
      "syntax match LLMSchemaField /^Schema Content.*$/",
      "syntax match LLMSchemaHelp /^Press.*$/",
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
    ]])
    
    -- Set keymaps
    local function set_keymap(mode, lhs, rhs)
      api.nvim_buf_set_keymap(edit_buf, mode, lhs, rhs, {noremap = true, silent = true})
    end
    
    -- Save schema (use Cmd+S on macOS, Ctrl+S otherwise)
    if vim.fn.has('mac') == 1 then
      set_keymap('n', '<D-s>', [[<cmd>lua require('llm.schema_manager').save_edited_schema()<CR>]])
    else
      set_keymap('n', '<C-s>', [[<cmd>lua require('llm.schema_manager').save_edited_schema()<CR>]])
    end
    
    -- Cancel
    set_keymap('n', '<Esc>', [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])
    
    -- Add save function to schema_manager
    schema_manager.edit_buf = edit_buf
    schema_manager.edit_win = edit_win
    schema_manager.current_schema_name = schema_name
    schema_manager.current_win = current_win
    
    schema_manager.save_edited_schema = function()
      -- Get content from buffer
      local start_line = 4 -- After the header lines
      local end_line = -3  -- Before the help text
      
      local content_lines = api.nvim_buf_get_lines(schema_manager.edit_buf, start_line, end_line, false)
      local content = table.concat(content_lines, "\n")
      
      -- Save the schema
      if M.save_schema(schema_manager.current_schema_name, content) then
        vim.notify("Schema saved: " .. schema_manager.current_schema_name, vim.log.levels.INFO)
        
        -- Close the edit window
        api.nvim_win_close(schema_manager.edit_win, true)
        
        -- Close the schema manager window
        api.nvim_win_close(schema_manager.current_win, true)
        
        -- Reopen the schema manager
        vim.schedule(function()
          M.manage_schemas()
        end)
      else
        vim.notify("Failed to save schema", vim.log.levels.ERROR)
      end
    end
    
    -- Position cursor at the beginning of the schema content
    vim.api.nvim_win_set_cursor(edit_win, {5, 0})
  end
  
  function schema_manager.delete_schema_under_cursor()
    local current_line = api.nvim_win_get_cursor(0)[1]
    local schema_name = line_to_schema[current_line]
    
    if not schema_name then return end
    
    -- Confirm deletion
    vim.ui.select({"Yes", "No"}, {
      prompt = "Delete schema '" .. schema_name .. "'?"
    }, function(choice)
      if choice ~= "Yes" then return end
      
      if M.delete_schema(schema_name) then
        vim.notify("Schema deleted: " .. schema_name, vim.log.levels.INFO)
        
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
    -- Get the current window
    local current_win = api.nvim_get_current_win()
    
    -- Create a new buffer for schema creation
    local create_buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(create_buf, 'buftype', 'nofile')
    api.nvim_buf_set_option(create_buf, 'bufhidden', 'wipe')
    api.nvim_buf_set_option(create_buf, 'swapfile', false)
    
    -- Use a unique buffer name to avoid conflicts
    local buffer_name = 'LLM Create Schema'
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
      "Schema Content (use the concise LLM schema syntax):",
      "name: the person's name",
      "age int: their age",
      "bio: a short bio, no more than three sentences",
      "",
      if vim.fn.has('mac') == 1 then
        table.insert(content_lines, "Press <Cmd-S> to save the schema")
      else
        table.insert(content_lines, "Press <Ctrl-S> to save the schema")
      end
      "Press <Esc> to cancel"
    }
    
    api.nvim_buf_set_lines(create_buf, 0, -1, false, content_lines)
    api.nvim_buf_set_option(create_buf, 'modifiable', true)
    
    -- Set up syntax highlighting
    require('llm').setup_buffer_highlighting(create_buf)
    
    -- Apply syntax highlighting
    local syntax_cmds = {
      "syntax match LLMSchemaHeader /^# Create New Schema$/",
      "syntax match LLMSchemaField /^Schema Name: \\|^Schema Content.*$/",
      "syntax match LLMSchemaHelp /^Press.*$/",
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
      highlight default LLMSchemaHelp guifg=#5c6370 gui=italic
    ]])
    
    -- Set keymaps
    local function set_keymap(mode, lhs, rhs)
      api.nvim_buf_set_keymap(create_buf, mode, lhs, rhs, {noremap = true, silent = true})
    end
    
    -- Save schema (use Cmd+S on macOS, Ctrl+S otherwise)
    if vim.fn.has('mac') == 1 then
      set_keymap('n', '<D-s>', [[<cmd>lua require('llm.schema_manager').save_new_schema()<CR>]])
    else
      set_keymap('n', '<C-s>', [[<cmd>lua require('llm.schema_manager').save_new_schema()<CR>]])
    end
    
    -- Cancel
    set_keymap('n', '<Esc>', [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])
    
    -- Add save function to schema_manager
    schema_manager.create_buf = create_buf
    schema_manager.create_win = create_win
    schema_manager.current_win = current_win
    
    schema_manager.save_new_schema = function()
      -- Get schema name
      local name_line = api.nvim_buf_get_lines(schema_manager.create_buf, 2, 3, false)[1]
      local schema_name = name_line:match("Schema Name: (.+)")
      
      if not schema_name or schema_name == "" then
        vim.notify("Please enter a schema name", vim.log.levels.ERROR)
        return
      end
      
      -- Get schema content
      local start_line = 5 -- After the header lines
      local end_line = -3  -- Before the help text
      
      local content_lines = api.nvim_buf_get_lines(schema_manager.create_buf, start_line, end_line, false)
      local content = table.concat(content_lines, "\n")
      
      if content == "" then
        vim.notify("Schema content cannot be empty", vim.log.levels.ERROR)
        return
      end
      
      -- Save the schema
      if M.save_schema(schema_name, content) then
        vim.notify("Schema saved: " .. schema_name, vim.log.levels.INFO)
        
        -- Close the create window
        api.nvim_win_close(schema_manager.create_win, true)
        
        -- Close the schema manager window
        api.nvim_win_close(schema_manager.current_win, true)
        
        -- Reopen the schema manager
        vim.schedule(function()
          M.manage_schemas()
        end)
      else
        vim.notify("Failed to save schema", vim.log.levels.ERROR)
      end
    end
    
    -- Position cursor at the schema name field
    vim.api.nvim_win_set_cursor(create_win, {3, 13})
    
    -- Enter insert mode
    vim.cmd("startinsert!")
  end
  
  function schema_manager.run_schema_under_cursor()
    local current_line = api.nvim_win_get_cursor(0)[1]
    local schema_name = line_to_schema[current_line]
    
    if not schema_name then return end
    
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
        local result = M.run_schema(schema_name, input or "", is_multi)
        
        -- Create a response buffer with the result
        require('llm').create_response_buffer(result)
      end)
    end)
  end
  
  -- Store the schema manager module
  package.loaded['llm.schema_manager'] = schema_manager
end

return M
-- llm/schemas.lua - Simple schema handling for llm-nvim
-- License: Apache 2.0

local M = {}

-- Disabled functionality
function M.select_schema()
  vim.notify("Schemas functionality is currently disabled", vim.log.levels.INFO)
end

function M.manage_schemas()
  vim.notify("Schemas functionality is currently disabled", vim.log.levels.INFO)
end

-- Placeholder functions to maintain API compatibility
function M.get_schemas()
  return {}
end

function M.get_schema(name)
  return nil
end

function M.save_schema(name, schema_text)
  vim.notify("Schemas functionality is currently disabled", vim.log.levels.INFO)
  return false
end

function M.delete_schema(name)
  vim.notify("Schemas functionality is currently disabled", vim.log.levels.INFO)
  return false
end

function M.run_schema(name, input, is_multi)
  vim.notify("Schemas functionality is currently disabled", vim.log.levels.INFO)
  return nil
end

return M
