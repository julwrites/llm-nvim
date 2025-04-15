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
  
  file:write(schema_content)
  file:close()
  
  -- Create the schema using llm CLI
  local cmd = string.format('llm schemas save %s %s', name, temp_file)
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  local success = handle:close()
  
  -- Clean up temp file
  os.remove(temp_file)
  
  return success
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

-- Convert DSL to JSON schema
function M.dsl_to_schema(dsl)
  local cmd = string.format('llm schemas dsl "%s"', dsl:gsub('"', '\\"'))
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  handle:close()
  
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
    api.nvim_buf_set_name(content_buf, 'Schema: ' .. schema_id)
    
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
    
    -- Create a temporary file with the schema content
    local temp_file = os.tmpname()
    local file = io.open(temp_file, "w")
    
    if details.schema and details.schema ~= "" then
      file:write(details.schema)
    else
      file:write("{\n  \"type\": \"object\",\n  \"properties\": {\n    \n  }\n}")
    end
    
    file:close()
    
    -- Close the schema manager window
    vim.api.nvim_win_close(0, true)
    
    -- Open the temporary file in a new buffer
    vim.cmd("edit " .. temp_file)
    
    -- Set up autocmd to save the schema when the buffer is written
    local augroup = api.nvim_create_augroup("LLMSchemaEdit", { clear = true })
    api.nvim_create_autocmd("BufWritePost", {
      group = augroup,
      buffer = api.nvim_get_current_buf(),
      callback = function()
        -- Save the schema
        local cmd = string.format('llm schemas save %s %s', schema_id, temp_file)
        local handle = io.popen(cmd)
        local result = handle:read("*a")
        local success = handle:close()
        
        if success then
          vim.notify("Schema saved: " .. schema_id, vim.log.levels.INFO)
        else
          vim.notify("Failed to save schema", vim.log.levels.ERROR)
        end
      end
    })
    
    -- Set up autocmd to clean up the temporary file when the buffer is closed
    api.nvim_create_autocmd("BufUnload", {
      group = augroup,
      buffer = api.nvim_get_current_buf(),
      callback = function()
        os.remove(temp_file)
      end
    })
    
    vim.notify("Edit the schema and save to update it.", vim.log.levels.INFO)
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
    -- Close the schema manager window
    vim.api.nvim_win_close(0, true)
    
    -- Ask for schema name
    vim.ui.input({
      prompt = "Enter schema name: "
    }, function(name)
      if not name or name == "" then
        vim.notify("Schema name cannot be empty", vim.log.levels.ERROR)
        return
      end
      
      -- Ask for schema type
      vim.ui.select({"JSON Schema", "DSL (Simple Schema Language)"}, {
        prompt = "Select schema format:"
      }, function(format_type)
        if not format_type then return end
        
        if format_type == "DSL (Simple Schema Language)" then
          -- Ask for DSL schema
          vim.ui.input({
            prompt = "Enter schema in DSL format (e.g., 'name, age int, bio'): "
          }, function(dsl)
            if not dsl or dsl == "" then
              vim.notify("Schema cannot be empty", vim.log.levels.ERROR)
              return
            end
            
            -- Convert DSL to JSON schema
            local json_schema = M.dsl_to_schema(dsl)
            
            -- Create a temporary file with the schema content
            local temp_file = os.tmpname()
            local file = io.open(temp_file, "w")
            file:write(json_schema)
            file:close()
            
            -- Save the schema
            local cmd = string.format('llm schemas save %s %s', name, temp_file)
            local handle = io.popen(cmd)
            local result = handle:read("*a")
            local success = handle:close()
            
            -- Clean up temp file
            os.remove(temp_file)
            
            if success then
              vim.notify("Schema created: " .. name, vim.log.levels.INFO)
              
              -- Open the schema manager
              vim.schedule(function()
                M.manage_schemas()
              end)
            else
              vim.notify("Failed to create schema", vim.log.levels.ERROR)
            end
          end)
        else
          -- Create a temporary file for the schema
          local temp_file = os.tmpname()
          local file = io.open(temp_file, "w")
          
          file:write("{\n  \"type\": \"object\",\n  \"properties\": {\n    \n  }\n}")
          
          file:close()
          
          -- Open the temporary file in a new buffer
          vim.cmd("edit " .. temp_file)
          
          -- Set up autocmd to save the schema when the buffer is written
          local augroup = api.nvim_create_augroup("LLMSchemaCreate", { clear = true })
          api.nvim_create_autocmd("BufWritePost", {
            group = augroup,
            buffer = api.nvim_get_current_buf(),
            callback = function()
              -- Save the schema
              local cmd = string.format('llm schemas save %s %s', name, temp_file)
              local handle = io.popen(cmd)
              local result = handle:read("*a")
              local success = handle:close()
              
              if success then
                vim.notify("Schema created: " .. name, vim.log.levels.INFO)
              else
                vim.notify("Failed to create schema", vim.log.levels.ERROR)
              end
            end
          })
          
          -- Set up autocmd to clean up the temporary file when the buffer is closed
          api.nvim_create_autocmd("BufUnload", {
            group = augroup,
            buffer = api.nvim_get_current_buf(),
            callback = function()
              os.remove(temp_file)
            end
          })
          
          vim.notify("Edit the schema and save to create it.", vim.log.levels.INFO)
        end
      end)
    end)
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
