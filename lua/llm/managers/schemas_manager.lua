-- llm/managers/schemas_manager.lua - Schema management for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local api = vim.api
local schemas_loader = require('llm.loaders.schemas_loader')
local utils = require('llm.utils')

-- Select and run a schema
function M.select_schema()
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

  local schemas = schemas_loader.get_schemas()
  local schema_ids = {}
  local schema_descriptions = {}
  
  for id, description in pairs(schemas) do
    table.insert(schema_ids, id)
    schema_descriptions[id] = description
  end
  
  if #schema_ids == 0 then
    vim.notify("No schemas found", vim.log.levels.INFO)
    return
  end
  
  table.sort(schema_ids)
  
  vim.ui.select(schema_ids, {
    prompt = "Select a schema to run:",
    format_item = function(item)
      return item .. " - " .. (schema_descriptions[item] or "")
    end
  }, function(choice)
    if not choice then return end
    
    -- If we have a selection, use it directly
    if has_selection then
      -- Ask if this is a multi-schema
      vim.ui.select({
        "Regular schema",
        "Multi schema (array of items)"
      }, {
        prompt = "Schema type:"
      }, function(schema_type)
        if not schema_type then return end
        
        local is_multi = schema_type == "Multi schema (array of items)"
        local result = schemas_loader.run_schema(choice, selection, is_multi)
        if result then
          utils.create_buffer_with_content(result, "Schema Result: " .. choice, "json")
        end
      end)
    else
      -- No selection, ask for input source
      M.run_schema_with_input_source(choice)
    end
  end)
end

-- Run a schema with input from various sources
function M.run_schema_with_input_source(schema_id)
  vim.ui.select({
    "Current buffer",
    "URL (will use curl)",
    "Enter text manually"
  }, {
    prompt = "Choose input source:"
  }, function(choice)
    if not choice then return end
    
    -- Ask if this is a multi-schema
    vim.ui.select({
      "Regular schema",
      "Multi schema (array of items)"
    }, {
      prompt = "Schema type:"
    }, function(schema_type)
      if not schema_type then return end
      
      local is_multi = schema_type == "Multi schema (array of items)"
      
      if choice == "Current buffer" then
        local lines = api.nvim_buf_get_lines(0, 0, -1, false)
        local content = table.concat(lines, "\n")
        
        -- Show a notification that we're processing
        vim.notify("Running schema on buffer content...", vim.log.levels.INFO)
        
        local result = schemas_loader.run_schema(schema_id, content, is_multi)
        if result then
          utils.create_buffer_with_content(result, "Schema Result: " .. schema_id, "json")
        else
          vim.notify("Failed to run schema on buffer content", vim.log.levels.ERROR)
        end
      elseif choice == "URL (will use curl)" then
        vim.ui.input({
          prompt = "Enter URL:"
        }, function(url)
          if not url or url == "" then return end
          
          -- Show a notification that we're processing
          vim.notify("Running schema on URL content...", vim.log.levels.INFO)
          
          -- Use the module-level schemas_loader variable
          local result = schemas_loader.run_schema_with_url(schema_id, url, is_multi)
          if result then
            utils.create_buffer_with_content(result, "Schema Result: " .. schema_id, "json")
          else
            vim.notify("Failed to run schema on URL content", vim.log.levels.ERROR)
          end
        end)
      elseif choice == "Enter text manually" then
        -- Create a buffer for text input
        local buf = api.nvim_create_buf(false, true)
        api.nvim_buf_set_option(buf, "buftype", "nofile")
        api.nvim_buf_set_option(buf, "bufhidden", "wipe")
        api.nvim_buf_set_option(buf, "swapfile", false)
        api.nvim_buf_set_name(buf, "Schema Input")
        
        -- Create a window for the buffer
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
          title = ' Enter text for schema ' .. schema_id .. ' ',
          title_pos = 'center',
        }

        local win = api.nvim_open_win(buf, true, opts)
        
        -- Add instructions
        api.nvim_buf_set_lines(buf, 0, -1, false, {
          "Enter text to process with the schema.",
          "Press <Esc> to cancel, <Ctrl-W> to submit.",
          "",
          ""
        })
        
        -- Set cursor position
        api.nvim_win_set_cursor(win, {4, 0})
        
        -- Set up keymaps
        local function set_keymap(mode, lhs, rhs)
          api.nvim_buf_set_keymap(buf, mode, lhs, rhs, { noremap = true, silent = true })
        end
        
        set_keymap("n", "<Esc>", [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])
        set_keymap("n", "<C-w>", string.format([[<cmd>lua require('llm.managers.schemas_manager').submit_schema_input('%s', %s, %s)<CR>]], schema_id, tostring(is_multi), buf))
        
        -- Start in insert mode
        api.nvim_command('startinsert')
      end
    end)
  end)
end

-- Submit schema input from buffer
function M.submit_schema_input(schema_id, is_multi, buf)
  local lines = api.nvim_buf_get_lines(buf, 3, -1, false)
  local content = table.concat(lines, "\n")
  
  -- Close the input window
  local win = api.nvim_get_current_win()
  api.nvim_win_close(win, true)
  
  -- Show a notification that we're processing
  vim.notify("Running schema on input text...", vim.log.levels.INFO)
  
  -- Run the schema
  local result = schemas_loader.run_schema(schema_id, content, is_multi == "true")
  if result then
    utils.create_buffer_with_content(result, "Schema Result: " .. schema_id, "json")
  else
    vim.notify("Failed to run schema on input text", vim.log.levels.ERROR)
  end
end

-- Create a new schema using a temporary file
function M.create_schema()
  if not utils.check_llm_installed() then
    return
  end
  
  -- Ask for schema name
  vim.ui.input({
    prompt = "Enter schema name:"
  }, function(name)
    if not name or name == "" then return end
    
    -- Ask for schema type
    vim.ui.select({
      "JSON Schema",
      "DSL (simplified schema syntax)"
    }, {
      prompt = "Schema format:"
    }, function(format_choice)
      if not format_choice then return end
      
      -- Generate temporary file path
      local temp_dir = vim.fn.stdpath('cache') .. "/llm_nvim_temp"
      os.execute("mkdir -p " .. temp_dir) -- Ensure temp dir exists
      local file_ext = (format_choice == "JSON Schema") and ".json" or ".dsl"
      -- Sanitize name for filename
      local safe_name = name:gsub("[^%w_-]", "_") 
      local temp_file_path = string.format("%s/schema_edit_%s_%s%s", temp_dir, safe_name, os.time(), file_ext)
      
      -- Write boilerplate content
      local boilerplate = ""
      if format_choice == "JSON Schema" then
        boilerplate = "{\n  \"type\": \"object\",\n  \"properties\": {\n    \"property_name\": {\n      \"type\": \"string\",\n      \"description\": \"Description of the property\"\n    }\n  },\n  \"required\": [\"property_name\"]\n}"
        -- Set filetype for syntax highlighting
        vim.defer_fn(function()
          local temp_buf = vim.fn.bufnr(temp_file_path)
          if temp_buf > 0 then
            api.nvim_buf_set_option(temp_buf, 'filetype', 'json')
          end
        end, 100)
      else -- DSL
        boilerplate = "# Define schema properties using DSL syntax\n# Example:\n# name: the person's name\n# age int: their age in years\n# bio: a short biography\n\n"
        -- Set filetype for syntax highlighting (assuming a 'dsl' or similar filetype exists or using 'markdown')
        vim.defer_fn(function()
          local temp_buf = vim.fn.bufnr(temp_file_path)
          if temp_buf > 0 then
            api.nvim_buf_set_option(temp_buf, 'filetype', 'markdown') -- Or 'dsl' if defined
          end
        end, 100)
      end
      
      local file = io.open(temp_file_path, "w")
      if not file then
        vim.notify("Failed to create temporary schema file: " .. temp_file_path, vim.log.levels.ERROR)
        return
      end
      file:write(boilerplate)
      file:close()
      
      -- Open the temporary file in a new split
      api.nvim_command("split " .. vim.fn.fnameescape(temp_file_path))
      
      -- Get the buffer number of the new buffer
      local bufnr = api.nvim_get_current_buf()
      
      -- Store necessary info in buffer variables
      api.nvim_buf_set_var(bufnr, "llm_schema_name", name)
      api.nvim_buf_set_var(bufnr, "llm_schema_format", format_choice)
      api.nvim_buf_set_var(bufnr, "llm_temp_schema_file_path", temp_file_path) -- Store path for potential cleanup
      
      -- Set up autocommand to trigger saving on write
      local group = api.nvim_create_augroup("LLMSchemaSave", { clear = true })
      api.nvim_create_autocmd("BufWritePost", {
        group = group,
        buffer = bufnr,
        -- Remove once = true to allow multiple saves until validation passes
        callback = function(args)
          -- Check if buffer is still valid before proceeding
          if api.nvim_buf_is_valid(args.buf) then
            require('llm.managers.schemas_manager').save_schema_from_temp_file(args.buf)
          end
        end,
      })
      
      -- Add a command to cancel and delete the buffer/file
      api.nvim_buf_create_user_command(bufnr, "LlmSchemaCancel", function()
        local temp_file = api.nvim_buf_get_var(bufnr, "llm_temp_schema_file_path")
        -- Force delete the buffer
        api.nvim_command(bufnr .. "bdelete!")
        -- Remove the temp file
        if temp_file then os.remove(temp_file) end
        vim.notify("Schema creation cancelled.", vim.log.levels.INFO)
      end, {})
      
      -- Instruct the user
      vim.notify("Edit the schema in this buffer. Save (:w) to validate and finalize. Use :LlmSchemaCancel to abort.", vim.log.levels.INFO)
      
    end) -- End vim.ui.select callback
  end) -- End vim.ui.input callback
end

-- Save schema from the temporary file buffer (triggered by BufWritePost)
function M.save_schema_from_temp_file(bufnr)
  -- Check if buffer is valid
  if not api.nvim_buf_is_valid(bufnr) then
    if require('llm.config').get("debug") then
      vim.notify("save_schema_from_temp_file called with invalid buffer: " .. bufnr, vim.log.levels.WARN)
    end
    return
  end

  -- Retrieve info from buffer variables
  local name = api.nvim_buf_get_var(bufnr, "llm_schema_name")
  local format_choice = api.nvim_buf_get_var(bufnr, "llm_schema_format")
  local temp_file_path = api.nvim_buf_get_var(bufnr, "llm_temp_schema_file_path")
  
  if not name or not format_choice then
     vim.notify("Could not retrieve schema info from temporary buffer.", vim.log.levels.ERROR)
     -- Attempt to clean up buffer anyway
     api.nvim_command(bufnr .. "bdelete!")
     return
  end

  -- Get content from the buffer
  local content_lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = table.concat(content_lines, "\n")
  content = content:gsub("^%s+", ""):gsub("%s+$", "") -- Trim whitespace

  local validated_content = content
  local is_valid = false
  local error_message = ""

  -- Process and validate the schema based on format
  if format_choice == "DSL (simplified schema syntax)" then
    -- Convert DSL to JSON Schema
    local json_schema, dsl_err = schemas_loader.create_schema_from_dsl(content)
    if dsl_err then
      is_valid = false
      error_message = "DSL Error: " .. dsl_err
    elseif json_schema then
      validated_content = json_schema
      -- Debug: Show content being passed to validator
      if require('llm.config').get("debug") then
        vim.notify("Validating generated JSON: " .. vim.inspect(validated_content), vim.log.levels.DEBUG)
      end
      -- Validate the generated JSON schema
      is_valid, error_message = schemas_loader.validate_json_schema(validated_content)
      if not is_valid then
         error_message = "Generated JSON invalid: " .. error_message
      end
    else
      is_valid = false
      error_message = "Unknown error converting DSL."
    end
  else -- JSON Schema
    -- Validate JSON format first
    local json_ok, decode_err = pcall(vim.fn.json_decode, content)
    if not json_ok then
      is_valid = false
      error_message = "Invalid JSON: " .. tostring(decode_err):sub(1, 100)
    else
      -- Debug: Show content being passed to validator
      if require('llm.config').get("debug") then
        vim.notify("Validating direct JSON: " .. vim.inspect(content), vim.log.levels.DEBUG)
      end
      -- Validate the JSON schema structure
      is_valid, error_message = schemas_loader.validate_json_schema(content)
      validated_content = content -- Already JSON
    end
  end

  -- If validation failed, notify user but keep the buffer open
  if not is_valid then
    vim.notify("Schema validation failed: " .. error_message, vim.log.levels.ERROR)
    vim.notify("Schema not saved. Please fix the content and save again (:w), or use :LlmSchemaCancel to abort.", vim.log.levels.WARN)
    -- Do NOT delete the buffer or temp file here
    return 
  end

  -- If validation succeeded, attempt to save
  vim.notify("Schema validated. Saving schema '" .. name .. "'...", vim.log.levels.INFO)
  
  -- Save the validated schema content
  local success = schemas_loader.save_schema(name, validated_content)
  if success then
    vim.notify("Schema '" .. name .. "' saved successfully", vim.log.levels.INFO)
    
    -- Reopen the schema manager after a longer delay to ensure the schema is fully saved
    vim.defer_fn(function()
      -- If we're creating a named schema, we might want to switch to named-only view
      if _G.llm_schemas_named_only == nil then
        -- Default to showing named schemas after creating one
        _G.llm_schemas_named_only = true
      end
      M.manage_schemas(_G.llm_schemas_named_only)
    end, 1500) -- Increased delay to 1.5 seconds
  else
    vim.notify("Failed to save schema '" .. name .. "'", vim.log.levels.ERROR)
  end
  
  -- Delete the temporary buffer only on successful save
  api.nvim_command(bufnr .. "bdelete!")
  -- Remove the temp file from disk only on successful save
  if temp_file_path then os.remove(temp_file_path) end
end

-- Manage schemas
function M.manage_schemas(show_named_only)
  if not utils.check_llm_installed() then
    return
  end
  
  -- Create a buffer for schema management
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(buf, "buftype", "nofile")
  api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  api.nvim_buf_set_option(buf, "swapfile", false)
  api.nvim_buf_set_name(buf, "LLM Schemas")
  
  -- Create a new floating window
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
  
  -- Function to refresh the schema list
  local function refresh_schema_list()
    local all_schemas = schemas_loader.get_schemas()
    local schema_ids = {}
    local named_schemas = {}
    local unnamed_schemas = {}
    
    -- Get schema config to identify named schemas
    local _, schema_config_file = utils.get_config_path("schemas.json")
    local schema_names_to_ids = {}
    local schema_ids_to_names = {}
    
    if schema_config_file then
      local config_file = io.open(schema_config_file, "r")
      if config_file then
        local content = config_file:read("*all")
        config_file:close()
        
        if content and content ~= "" then
          local success, parsed = pcall(vim.fn.json_decode, content)
          if success and parsed then
            schema_names_to_ids = parsed
            -- Create reverse mapping
            for name, id in pairs(parsed) do
              schema_ids_to_names[id] = name
            end
          end
        end
      end
    end
    
    -- Separate named and unnamed schemas
    for id, description in pairs(all_schemas) do
      if schema_ids_to_names[id] then
        table.insert(named_schemas, {id = id, name = schema_ids_to_names[id], description = description})
      else
        table.insert(unnamed_schemas, {id = id, description = description})
      end
    end
    
    -- Sort named schemas by name
    table.sort(named_schemas, function(a, b) return a.name < b.name end)
    
    -- Sort unnamed schemas by ID
    table.sort(unnamed_schemas, function(a, b) return a.id < b.id end)
    
    -- Determine which schemas to show
    local schemas_to_show = show_named_only and named_schemas or named_schemas
    if not show_named_only then
      for _, schema in ipairs(unnamed_schemas) do
        table.insert(schemas_to_show, schema)
      end
    end
    
    -- Add header
    local lines = {
      "# LLM Schemas Manager",
      "",
      "Press 'c' to create, 'r' to run, 'v' to view details, 'e' to edit, 'a' to set alias, 'd' to delete alias, 't' to toggle view, 'q' to quit",
      "──────────────────────────────────────────────────────────────",
      "",
    }
    
    -- Add toggle status
    if show_named_only then
      table.insert(lines, "Currently showing: Only named schemas")
    else
      table.insert(lines, "Currently showing: All schemas")
    end
    table.insert(lines, "")
    
    if #schemas_to_show == 0 then
      table.insert(lines, "No schemas found. Press 'c' to create one.")
    else
      table.insert(lines, "Schemas:")
      table.insert(lines, "----------")
      
      -- Add schemas with descriptions
      for _, schema in ipairs(schemas_to_show) do
        -- Replace newlines in descriptions with spaces to avoid nvim_buf_set_lines error
        local description = schema.description:gsub("\n", " ")
        
        -- Check if the description already starts with the schema name in brackets
        local has_name_prefix = false
        if schema.name then
          has_name_prefix = description:match("^%[" .. schema.name .. "%]")
        end
        
        if schema.name and not has_name_prefix then
          table.insert(lines, schema.id .. " : [" .. schema.name .. "] " .. description)
        else
          table.insert(lines, schema.id .. " : " .. description)
        end
      end
    end
    
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    
    -- Set up highlighting
    require('llm').setup_buffer_highlighting(buf)
    
    -- Add schema-specific highlighting
    vim.cmd([[
      highlight default LLMSchemasHeader guifg=#61afef
      highlight default LLMSchemasAction guifg=#98c379
      highlight default LLMSchemasSection guifg=#c678dd
      highlight default LLMSchemasName guifg=#e5c07b
      highlight default LLMSchemasToggle guifg=#56b6c2
    ]])

    -- Apply syntax highlighting
    local syntax_cmds = {
      "syntax match LLMSchemasHeader /^# LLM Schemas Manager$/",
      "syntax match LLMSchemasAction /Press.*$/",
      "syntax match LLMSchemasToggle /^Currently showing:.*$/",
      "syntax match LLMSchemasSection /^Schemas:$/",
      "syntax match LLMSchemasName /^[0-9a-f]\\+/",
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
  set_keymap("n", "c", ":lua require('llm.managers.schemas_manager').create_schema_from_manager()<CR>")
  set_keymap("n", "r", ":lua require('llm.managers.schemas_manager').run_schema_under_cursor()<CR>")
  set_keymap("n", "v", ":lua require('llm.managers.schemas_manager').view_schema_details_under_cursor()<CR>")
  set_keymap("n", "e", ":lua require('llm.managers.schemas_manager').edit_schema_under_cursor()<CR>")
  set_keymap("n", "a", ":lua require('llm.managers.schemas_manager').set_alias_for_schema_under_cursor()<CR>")
  set_keymap("n", "d", ":lua require('llm.managers.schemas_manager').delete_alias_for_schema_under_cursor()<CR>")
  set_keymap("n", "t", ":lua require('llm.managers.schemas_manager').toggle_schemas_view()<CR>")
  
  -- Initial refresh
  refresh_schema_list()
  
  -- Store the refresh function in the buffer
  api.nvim_buf_set_var(buf, "refresh_function", refresh_schema_list)
  
  -- Store the current view mode
  _G.llm_schemas_named_only = show_named_only
end -- Added missing end for M.manage_schemas

-- Run schema under cursor
function M.run_schema_under_cursor()
  local line = api.nvim_get_current_line()
  local schema_id = line:match("^([0-9a-f]+)")
  
  if schema_id and #schema_id > 0 then
    if require('llm.config').get("debug") then
      vim.notify("Found schema ID: " .. schema_id, vim.log.levels.DEBUG)
    end
    
    -- Close the schema manager window
    local current_win = api.nvim_get_current_win()
    api.nvim_win_close(current_win, true)
    
    -- Run the schema
    M.run_schema_with_input_source(schema_id)
  else
    vim.notify("No schema found under cursor", vim.log.levels.ERROR)
  end
end

-- View schema details under cursor
function M.view_schema_details_under_cursor()
  local line = api.nvim_get_current_line()
  local schema_id = line:match("^([0-9a-f]+)")
  
  if not schema_id then
    vim.notify("No schema found under cursor", vim.log.levels.ERROR)
    return
  end
  
  -- Close the schema manager window
  local current_win = api.nvim_get_current_win()
  api.nvim_win_close(current_win, true)
  
  -- Get schema details
  local schema = schemas_loader.get_schema(schema_id)
  if not schema then
    vim.notify("Failed to get schema details for '" .. schema_id .. "'", vim.log.levels.ERROR)
    return
  end
  
  -- Create a buffer for schema details
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(buf, "buftype", "nofile")
  api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  api.nvim_buf_set_option(buf, "swapfile", false)
  api.nvim_buf_set_name(buf, "Schema Details: " .. schema_id)
  
  -- Create a new floating window
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
    title = ' Schema Details: ' .. schema_id .. ' ',
    title_pos = 'center',
  }

  local win = api.nvim_open_win(buf, true, opts)
  api.nvim_win_set_option(win, 'cursorline', true)
  api.nvim_win_set_option(win, 'winblend', 0)
  
  -- Format schema details
  local lines = {
    "# Schema: " .. schema_id,
    ""
  }
  
  -- Add schema name if available
  if schema.name then
    table.insert(lines, "## Name: " .. schema.name)
    table.insert(lines, "")
  end
  
  table.insert(lines, "## Schema Definition:")
  table.insert(lines, "")
  
  -- Add schema content
  if schema.content then
    -- Format the JSON content for better readability
    local success, parsed = pcall(vim.fn.json_decode, schema.content)
    if success then
      local formatted_json = vim.fn.json_encode(parsed)
      -- Split the formatted JSON by lines and add each line
      for line in formatted_json:gmatch("[^\r\n]+") do
        table.insert(lines, line)
      end
    else
      -- If not valid JSON, just add the raw content line by line
      for line in schema.content:gmatch("[^\r\n]+") do
        table.insert(lines, line)
      end
    end
  else
    table.insert(lines, "No schema content available")
  end
  
  -- Add footer with instructions
  table.insert(lines, "")
  table.insert(lines, "Press 'q' to close, 'r' to run this schema, 'e' to edit this schema, 'a' to set alias for this schema, 'd' to delete alias")
  
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  
  -- Set up keymaps
  local function set_keymap(mode, lhs, rhs)
    api.nvim_buf_set_keymap(buf, mode, lhs, rhs, { noremap = true, silent = true })
  end
  
  set_keymap("n", "q", [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])
  set_keymap("n", "<Esc>", [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])
  set_keymap("n", "r", string.format([[<cmd>lua require('llm.managers.schemas_manager').run_schema_from_details('%s')<CR>]], schema_id))
  set_keymap("n", "e", string.format([[<cmd>lua require('llm.managers.schemas_manager').edit_schema_from_details('%s')<CR>]], schema_id))
  set_keymap("n", "a", string.format([[<cmd>lua require('llm.managers.schemas_manager').set_alias_from_details('%s')<CR>]], schema_id))
  set_keymap("n", "d", string.format([[<cmd>lua require('llm.managers.schemas_manager').delete_alias_from_details('%s')<CR>]], schema_id))
  
  -- Set up highlighting
  require('llm').setup_buffer_highlighting(buf)
  
  -- Add schema-specific highlighting
  vim.cmd([[
    highlight default LLMSchemaHeader guifg=#61afef
    highlight default LLMSchemaSection guifg=#c678dd
    highlight default LLMSchemaContent guifg=#98c379
    highlight default LLMSchemaFooter guifg=#e5c07b
  ]])

  -- Apply syntax highlighting
  local syntax_cmds = {
    "syntax match LLMSchemaHeader /^# Schema:/",
    "syntax match LLMSchemaSection /^## .*$/",
    "syntax match LLMSchemaFooter /^Press.*$/",
  }

  for _, cmd in ipairs(syntax_cmds) do
    vim.api.nvim_buf_call(buf, function()
      vim.cmd(cmd)
    end)
  end
end

-- Set alias for schema under cursor
function M.set_alias_for_schema_under_cursor()
  local line = api.nvim_get_current_line()
  local schema_id = line:match("^([0-9a-f]+)")
  
  if not schema_id then
    vim.notify("No schema found under cursor", vim.log.levels.ERROR)
    return
  end
  
  -- Check if schema already has an alias
  local current_alias = nil
  local _, schema_config_file = utils.get_config_path("schemas.json")
  if schema_config_file then
    local config_file = io.open(schema_config_file, "r")
    if config_file then
      local content = config_file:read("*all")
      config_file:close()
      
      if content and content ~= "" then
        local success, parsed = pcall(vim.fn.json_decode, content)
        if success and parsed then
          for name, id in pairs(parsed) do
            if id == schema_id then
              current_alias = name
              break
            end
          end
        end
      end
    end
  end
  
  -- Prompt for new alias
  local prompt_text = current_alias 
    and "Enter new alias for schema (current: " .. current_alias .. "):" 
    or "Enter alias for schema:"
  
  vim.ui.input({
    prompt = prompt_text,
    default = current_alias or "",
  }, function(new_alias)
    if not new_alias or new_alias == "" then return end
    
    -- Save the alias
    local success = schemas_loader.set_schema_alias(schema_id, new_alias)
    
    if success then
      vim.notify("Schema alias set to '" .. new_alias .. "'", vim.log.levels.INFO)
      -- Close and reopen the schema manager to refresh
      local win = api.nvim_get_current_win()
      api.nvim_win_close(win, true)
      vim.defer_fn(function()
        -- Keep the same view mode when refreshing
        M.manage_schemas(_G.llm_schemas_named_only)
      end, 100)
    else
      vim.notify("Failed to set schema alias", vim.log.levels.ERROR)
    end
  end)
end

-- Create schema from manager
function M.create_schema_from_manager()
  -- Store the current view mode
  local current_view_mode = _G.llm_schemas_named_only
  
  -- Close the current window (schema manager)
  local current_win = api.nvim_get_current_win()
  api.nvim_win_close(current_win, true)
  
  -- Create the schema without automatically reopening the manager
  -- The save_schema_from_buffer function will handle reopening the manager
  M.create_schema()
  
  -- Don't set up a callback to reopen the schema manager here
  -- We'll let save_schema_from_buffer handle that after the schema is actually saved
end

-- Run schema from details view
function M.run_schema_from_details(schema_id)
  -- Close the current window (schema details)
  local current_win = api.nvim_get_current_win()
  api.nvim_win_close(current_win, true)
  
  -- Run the schema
  M.run_schema_with_input_source(schema_id)
end

-- Set alias from details view
function M.set_alias_from_details(schema_id)
  -- Check if schema already has an alias
  local current_alias = nil
  local _, schema_config_file = utils.get_config_path("schemas.json")
  if schema_config_file then
    local config_file = io.open(schema_config_file, "r")
    if config_file then
      local content = config_file:read("*all")
      config_file:close()
      
      if content and content ~= "" then
        local success, parsed = pcall(vim.fn.json_decode, content)
        if success and parsed then
          for name, id in pairs(parsed) do
            if id == schema_id then
              current_alias = name
              break
            end
          end
        end
      end
    end
  end
  
  -- Prompt for new alias
  local prompt_text = current_alias 
    and "Enter new alias for schema (current: " .. current_alias .. "):" 
    or "Enter alias for schema:"
  
  vim.ui.input({
    prompt = prompt_text,
    default = current_alias or "",
  }, function(new_alias)
    if not new_alias or new_alias == "" then return end
    
    -- Save the alias
    local success = schemas_loader.set_schema_alias(schema_id, new_alias)
    
    if success then
      vim.notify("Schema alias set to '" .. new_alias .. "'", vim.log.levels.INFO)
      -- Close the details window
      local win = api.nvim_get_current_win()
      api.nvim_win_close(win, true)
      -- Reopen the schema manager
      vim.defer_fn(function()
        -- Keep the same view mode when refreshing
        M.manage_schemas(_G.llm_schemas_named_only)
      end, 100)
    else
      vim.notify("Failed to set schema alias", vim.log.levels.ERROR)
    end
  end)
end

-- Delete alias for schema under cursor
function M.delete_alias_for_schema_under_cursor()
  local line = api.nvim_get_current_line()
  local schema_id = line:match("^([0-9a-f]+)")
  
  if not schema_id then
    vim.notify("No schema found under cursor", vim.log.levels.ERROR)
    return
  end
  
  -- Get all aliases for this schema
  local result = schemas_loader.remove_schema_alias(schema_id)
  
  -- If result is a boolean, it means there was only one alias and it was already removed
  if type(result) == "boolean" then
    if result then
      vim.notify("Schema alias deleted", vim.log.levels.INFO)
      -- Close and reopen the schema manager to refresh
      local win = api.nvim_get_current_win()
      api.nvim_win_close(win, true)
      vim.defer_fn(function()
        -- Keep the same view mode when refreshing
        M.manage_schemas(_G.llm_schemas_named_only)
      end, 100)
    else
      vim.notify("Failed to delete schema alias", vim.log.levels.ERROR)
    end
    return
  end
  
  -- If result is a table, it contains multiple aliases to choose from
  if type(result) == "table" and #result > 0 then
    -- Let the user select which alias to delete
    vim.ui.select(result, {
      prompt = "Select alias to delete:"
    }, function(choice)
      if not choice then return end
      
      -- Confirm deletion
      vim.ui.select({
        "Yes",
        "No"
      }, {
        prompt = "Are you sure you want to delete the alias '" .. choice .. "'?"
      }, function(confirm)
        if confirm ~= "Yes" then return end
        
        -- Delete the specific alias
        local success = schemas_loader.remove_schema_alias(schema_id, choice)
        
        if success then
          vim.notify("Schema alias '" .. choice .. "' deleted", vim.log.levels.INFO)
          -- Close and reopen the schema manager to refresh
          local win = api.nvim_get_current_win()
          api.nvim_win_close(win, true)
          vim.defer_fn(function()
            -- Keep the same view mode when refreshing
            M.manage_schemas(_G.llm_schemas_named_only)
          end, 100)
        else
          vim.notify("Failed to delete schema alias", vim.log.levels.ERROR)
        end
      end)
    end)
  else
    vim.notify("This schema does not have any aliases to delete", vim.log.levels.WARN)
  end
end

-- Edit schema under cursor
function M.edit_schema_under_cursor()
  local line = api.nvim_get_current_line()
  local schema_id = line:match("^([0-9a-f]+)")
  
  if not schema_id then
    vim.notify("No schema found under cursor", vim.log.levels.ERROR)
    return
  end
  
  -- Get schema details
  local schema = schemas_loader.get_schema(schema_id)
  if not schema then
    vim.notify("Failed to get schema details for '" .. schema_id .. "'", vim.log.levels.ERROR)
    return
  end
  
  -- Close the schema manager window
  local current_win = api.nvim_get_current_win()
  api.nvim_win_close(current_win, true)
  
  -- Generate temporary file path
  local temp_dir = vim.fn.stdpath('cache') .. "/llm_nvim_temp"
  os.execute("mkdir -p " .. temp_dir) -- Ensure temp dir exists
  
  -- Determine file extension and format
  local format_choice = "JSON Schema" -- Default format
  local file_ext = ".json"
  
  -- Sanitize name for filename
  local safe_name = schema.name and schema.name:gsub("[^%w_-]", "_") or schema_id
  local temp_file_path = string.format("%s/schema_edit_%s_%s%s", temp_dir, safe_name, os.time(), file_ext)
  
  -- Write schema content to temp file
  local file = io.open(temp_file_path, "w")
  if not file then
    vim.notify("Failed to create temporary schema file: " .. temp_file_path, vim.log.levels.ERROR)
    return
  end
  
  -- Format the JSON content for better readability
  local content = schema.content
  
  -- Remove usage section completely
  content = content:gsub(',%s*"usage":%s*[^}]*', '')
  content = content:gsub('"usage":%s*[^,}]*,%s*', '')
  content = content:gsub('usage: %|[^}]*', '')
  
  -- Parse and format the JSON
  local success, parsed = pcall(vim.fn.json_decode, content)
  if success then
    -- Format the JSON with proper indentation
    content = vim.fn.json_encode(parsed)
    
    -- Try to pretty-print the JSON if possible
    local ok, formatted = pcall(function()
      return vim.json.encode(parsed, { indent = 2 })
    end)
    if ok then
      content = formatted
    end
  end
  
  file:write(content)
  file:close()
  
  -- Open the temporary file in a new split
  api.nvim_command("split " .. vim.fn.fnameescape(temp_file_path))
  
  -- Get the buffer number of the new buffer
  local bufnr = api.nvim_get_current_buf()
  
  -- Set filetype for syntax highlighting
  api.nvim_buf_set_option(bufnr, 'filetype', 'json')
  
  -- Store necessary info in buffer variables
  api.nvim_buf_set_var(bufnr, "llm_schema_name", schema.name or "")
  api.nvim_buf_set_var(bufnr, "llm_schema_id", schema_id)
  api.nvim_buf_set_var(bufnr, "llm_schema_format", format_choice)
  api.nvim_buf_set_var(bufnr, "llm_temp_schema_file_path", temp_file_path)
  
  -- Set up autocommand to trigger saving on write
  local group = api.nvim_create_augroup("LLMSchemaSave", { clear = true })
  api.nvim_create_autocmd("BufWritePost", {
    group = group,
    buffer = bufnr,
    callback = function(args)
      -- Check if buffer is still valid before proceeding
      if api.nvim_buf_is_valid(args.buf) then
        require('llm.managers.schemas_manager').save_edited_schema(args.buf)
      end
    end,
  })
  
  -- Add a command to cancel and delete the buffer/file
  api.nvim_buf_create_user_command(bufnr, "LlmSchemaCancel", function()
    local temp_file = api.nvim_buf_get_var(bufnr, "llm_temp_schema_file_path")
    -- Force delete the buffer
    api.nvim_command(bufnr .. "bdelete!")
    -- Remove the temp file
    if temp_file then os.remove(temp_file) end
    vim.notify("Schema editing cancelled.", vim.log.levels.INFO)
  end, {})
  
  -- Instruct the user
  vim.notify("Edit the schema in this buffer. Save (:w) to validate and update. Use :LlmSchemaCancel to abort.", vim.log.levels.INFO)
end

-- Save edited schema (triggered by BufWritePost)
function M.save_edited_schema(bufnr)
  -- Check if buffer is valid
  if not api.nvim_buf_is_valid(bufnr) then
    if require('llm.config').get("debug") then
      vim.notify("save_edited_schema called with invalid buffer: " .. bufnr, vim.log.levels.WARN)
    end
    return
  end

  -- Retrieve info from buffer variables
  local name = api.nvim_buf_get_var(bufnr, "llm_schema_name")
  local schema_id = api.nvim_buf_get_var(bufnr, "llm_schema_id")
  local format_choice = api.nvim_buf_get_var(bufnr, "llm_schema_format")
  local temp_file_path = api.nvim_buf_get_var(bufnr, "llm_temp_schema_file_path")
  
  -- Get content from the buffer
  local content_lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = table.concat(content_lines, "\n")
  content = content:gsub("^%s+", ""):gsub("%s+$", "") -- Trim whitespace

  -- Validate the schema JSON
  local is_valid, error_message = schemas_loader.validate_json_schema(content)
  
  -- If validation failed, notify user but keep the buffer open
  if not is_valid then
    vim.notify("Schema validation failed: " .. error_message, vim.log.levels.ERROR)
    vim.notify("Schema not updated. Please fix the content and save again (:w), or use :LlmSchemaCancel to abort.", vim.log.levels.WARN)
    return 
  end

  -- If validation succeeded, attempt to save
  vim.notify("Schema validated. Updating schema...", vim.log.levels.INFO)
  
  -- Save the validated schema content
  local success = schemas_loader.save_schema(name ~= "" and name or nil, content)
  if success then
    vim.notify("Schema updated successfully", vim.log.levels.INFO)
    
    -- Delete the temporary buffer
    api.nvim_command(bufnr .. "bdelete!")
    -- Remove the temp file from disk
    if temp_file_path then os.remove(temp_file_path) end
    
    -- Reopen the schema manager after a delay to ensure the schema is fully saved
    vim.defer_fn(function()
      M.manage_schemas(_G.llm_schemas_named_only)
    end, 1500)
  else
    vim.notify("Failed to update schema", vim.log.levels.ERROR)
  end
end

-- Edit schema from details view
function M.edit_schema_from_details(schema_id)
  -- Close the current window (schema details)
  local current_win = api.nvim_get_current_win()
  api.nvim_win_close(current_win, true)
  
  -- Get schema details
  local schema = schemas_loader.get_schema(schema_id)
  if not schema then
    vim.notify("Failed to get schema details for '" .. schema_id .. "'", vim.log.levels.ERROR)
    return
  end
  
  -- Generate temporary file path
  local temp_dir = vim.fn.stdpath('cache') .. "/llm_nvim_temp"
  os.execute("mkdir -p " .. temp_dir) -- Ensure temp dir exists
  
  -- Determine file extension and format
  local format_choice = "JSON Schema" -- Default format
  local file_ext = ".json"
  
  -- Sanitize name for filename
  local safe_name = schema.name and schema.name:gsub("[^%w_-]", "_") or schema_id
  local temp_file_path = string.format("%s/schema_edit_%s_%s%s", temp_dir, safe_name, os.time(), file_ext)
  
  -- Write schema content to temp file
  local file = io.open(temp_file_path, "w")
  if not file then
    vim.notify("Failed to create temporary schema file: " .. temp_file_path, vim.log.levels.ERROR)
    return
  end
  
  -- Format the JSON content for better readability
  local content = schema.content
  
  -- Remove usage section completely
  content = content:gsub(',%s*"usage":%s*[^}]*', '')
  content = content:gsub('"usage":%s*[^,}]*,%s*', '')
  content = content:gsub('usage: %|[^}]*', '')
  
  -- Parse and format the JSON
  local success, parsed = pcall(vim.fn.json_decode, content)
  if success then
    -- Format the JSON with proper indentation
    content = vim.fn.json_encode(parsed)
    
    -- Try to pretty-print the JSON if possible
    local ok, formatted = pcall(function()
      return vim.json.encode(parsed, { indent = 2 })
    end)
    if ok then
      content = formatted
    end
  end
  
  file:write(content)
  file:close()
  
  -- Open the temporary file in a new split
  api.nvim_command("split " .. vim.fn.fnameescape(temp_file_path))
  
  -- Get the buffer number of the new buffer
  local bufnr = api.nvim_get_current_buf()
  
  -- Set filetype for syntax highlighting
  api.nvim_buf_set_option(bufnr, 'filetype', 'json')
  
  -- Store necessary info in buffer variables
  api.nvim_buf_set_var(bufnr, "llm_schema_name", schema.name or "")
  api.nvim_buf_set_var(bufnr, "llm_schema_id", schema_id)
  api.nvim_buf_set_var(bufnr, "llm_schema_format", format_choice)
  api.nvim_buf_set_var(bufnr, "llm_temp_schema_file_path", temp_file_path)
  
  -- Set up autocommand to trigger saving on write
  local group = api.nvim_create_augroup("LLMSchemaSave", { clear = true })
  api.nvim_create_autocmd("BufWritePost", {
    group = group,
    buffer = bufnr,
    callback = function(args)
      -- Check if buffer is still valid before proceeding
      if api.nvim_buf_is_valid(args.buf) then
        require('llm.managers.schemas_manager').save_edited_schema(args.buf)
      end
    end,
  })
  
  -- Add a command to cancel and delete the buffer/file
  api.nvim_buf_create_user_command(bufnr, "LlmSchemaCancel", function()
    local temp_file = api.nvim_buf_get_var(bufnr, "llm_temp_schema_file_path")
    -- Force delete the buffer
    api.nvim_command(bufnr .. "bdelete!")
    -- Remove the temp file
    if temp_file then os.remove(temp_file) end
    vim.notify("Schema editing cancelled.", vim.log.levels.INFO)
  end, {})
  
  -- Instruct the user
  vim.notify("Edit the schema in this buffer. Save (:w) to validate and update. Use :LlmSchemaCancel to abort.", vim.log.levels.INFO)
end

-- Toggle between showing all schemas or only named schemas
function M.toggle_schemas_view()
  -- Store the current show_named_only state in a global variable
  _G.llm_schemas_named_only = not (_G.llm_schemas_named_only or false)
  
  -- Close the current window and reopen with the new state
  vim.api.nvim_win_close(0, true)
  vim.schedule(function()
    M.manage_schemas(_G.llm_schemas_named_only)
  end)
end

-- Delete alias from details view
function M.delete_alias_from_details(schema_id)
  -- Get all aliases for this schema
  local result = schemas_loader.remove_schema_alias(schema_id)
  
  -- If result is a boolean, it means there was only one alias and it was already removed
  if type(result) == "boolean" then
    if result then
      vim.notify("Schema alias deleted", vim.log.levels.INFO)
      -- Close the details window
      local win = api.nvim_get_current_win()
      api.nvim_win_close(win, true)
      -- Reopen the schema manager
      vim.defer_fn(function()
        -- Keep the same view mode when refreshing
        M.manage_schemas(_G.llm_schemas_named_only)
      end, 100)
    else
      vim.notify("Failed to delete schema alias", vim.log.levels.ERROR)
    end
    return
  end
  
  -- If result is a table, it contains multiple aliases to choose from
  if type(result) == "table" and #result > 0 then
    -- Let the user select which alias to delete
    vim.ui.select(result, {
      prompt = "Select alias to delete:"
    }, function(choice)
      if not choice then return end
      
      -- Confirm deletion
      vim.ui.select({
        "Yes",
        "No"
      }, {
        prompt = "Are you sure you want to delete the alias '" .. choice .. "'?"
      }, function(confirm)
        if confirm ~= "Yes" then return end
        
        -- Delete the specific alias
        local success = schemas_loader.remove_schema_alias(schema_id, choice)
        
        if success then
          vim.notify("Schema alias '" .. choice .. "' deleted", vim.log.levels.INFO)
          -- Close the details window
          local win = api.nvim_get_current_win()
          api.nvim_win_close(win, true)
          -- Reopen the schema manager
          vim.defer_fn(function()
            -- Keep the same view mode when refreshing
            M.manage_schemas(_G.llm_schemas_named_only)
          end, 100)
        else
          vim.notify("Failed to delete schema alias", vim.log.levels.ERROR)
        end
      end)
    end)
  else
    vim.notify("This schema does not have any aliases to delete", vim.log.levels.WARN)
  end
end

-- Re-export functions from schemas_loader
M.get_schemas = schemas_loader.get_schemas
M.get_schema = schemas_loader.get_schema
M.save_schema = schemas_loader.save_schema
M.run_schema = schemas_loader.run_schema

return M
