-- llm/schemas/schemas_manager.lua - Schema management for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local api = vim.api
local schemas_loader = require('llm.schemas.schemas_loader')
local utils = require('llm.utils')
local styles = require('llm.styles') -- Added

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
  if not schema_id or schema_id == "" then
    vim.notify("Schema ID cannot be empty", vim.log.levels.ERROR)
    return
  end

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
        utils.floating_input({
          prompt = "Enter URL:",
          on_confirm = function(url)
            if not url or url == "" then
              vim.notify("URL cannot be empty", vim.log.levels.WARN)
              return
            end

            -- Show a notification that we're processing
            vim.notify("Running schema on URL content...", vim.log.levels.INFO)

            -- Use the module-level schemas_loader variable
            local result = schemas_loader.run_schema_with_url(schema_id, url, is_multi)
            if result then
              utils.create_buffer_with_content(result, "Schema Result: " .. schema_id, "json")
            else
              vim.notify("Failed to run schema on URL content", vim.log.levels.ERROR)
            end
          end
        })
      elseif choice == "Enter text manually" then
        -- Generate temporary file path
        local temp_dir = vim.fn.stdpath('cache') .. "/llm_nvim_temp"
        os.execute("mkdir -p " .. temp_dir) -- Ensure temp dir exists
        local temp_file_path = string.format("%s/schema_input_%s_%s.txt", temp_dir, schema_id:sub(1, 8), os.time())

        -- Create a new buffer for the input
        local buf = api.nvim_create_buf(false, true)
        api.nvim_buf_set_option(buf, "buftype", "acwrite")
        api.nvim_buf_set_option(buf, "bufhidden", "wipe")
        api.nvim_buf_set_option(buf, "swapfile", false)
        api.nvim_buf_set_name(buf, temp_file_path)

        -- Add instructions
        api.nvim_buf_set_lines(buf, 0, -1, false, {
          "# Enter text to process with schema " .. schema_id,
          "# Press :w to save and submit, or :q! to cancel",
          "",
          ""
        })

        -- Open the buffer in a split
        api.nvim_command("split")
        api.nvim_win_set_buf(0, buf)

        -- Set cursor position after instructions
        api.nvim_win_set_cursor(0, { 4, 0 })

        -- Store schema info in buffer variables
        api.nvim_buf_set_var(buf, "llm_schema_id", schema_id)
        api.nvim_buf_set_var(buf, "llm_schema_is_multi", is_multi)
        api.nvim_buf_set_var(buf, "llm_temp_file_path", temp_file_path)

        -- Set up autocommand to trigger submission on write
        local group = api.nvim_create_augroup("LLMSchemaInput", { clear = true })
        api.nvim_create_autocmd("BufWriteCmd", {
          group = group,
          buffer = buf,
          callback = function(args)
            -- Check if buffer is still valid before proceeding
            if api.nvim_buf_is_valid(args.buf) then
              -- Mark the buffer as 'saved' to avoid "No write since last change" message
              api.nvim_buf_set_option(args.buf, "modified", false)
              -- Submit the schema input
              require('llm.schemas.schemas_manager').submit_schema_input_from_buffer(args.buf)
              return true -- Indicate the write was handled
            end
          end,
        })

        -- Add a command to cancel
        api.nvim_buf_create_user_command(buf, "LlmSchemaCancel", function()
          local temp_file = api.nvim_buf_get_var(buf, "llm_temp_file_path")
          -- Force delete the buffer
          api.nvim_command(buf .. "bdelete!")
          -- Remove the temp file if it exists
          if temp_file and vim.fn.filereadable(temp_file) == 1 then
            os.remove(temp_file)
          end
          vim.notify("Schema input cancelled.", vim.log.levels.INFO)
        end, {})

        -- Set up keymaps
        local function set_keymap(mode, lhs, rhs, opts)
          opts = opts or { noremap = true, silent = true }
          api.nvim_buf_set_keymap(buf, mode, lhs, rhs, opts)
        end

        -- Add Escape key mapping for quick cancel in normal mode
        set_keymap("n", "<Esc>", ":LlmSchemaCancel<CR>")

        -- Instruct the user
        vim.notify("Enter text in this buffer. Save (:w) to submit or quit (:q!) to cancel.", vim.log.levels.INFO)

        -- Start in insert mode
        api.nvim_command('startinsert')
      end
    end)
  end)
end

-- Submit schema input from buffer (new version)
function M.submit_schema_input_from_buffer(buf)
  -- Check if buffer is valid
  if not api.nvim_buf_is_valid(buf) then
    vim.notify("Invalid buffer for schema input", vim.log.levels.ERROR)
    return
  end

  -- Get schema info from buffer variables
  local schema_id = api.nvim_buf_get_var(buf, "llm_schema_id")
  local is_multi = api.nvim_buf_get_var(buf, "llm_schema_is_multi")
  local temp_file_path = api.nvim_buf_get_var(buf, "llm_temp_file_path")

  -- Get the content from the buffer, skipping the instruction lines
  local lines = api.nvim_buf_get_lines(buf, 3, -1, false)
  local content = table.concat(lines, "\n")

  -- Debug output
  if self.config.get("debug") then
    vim.notify("Schema ID: " .. schema_id, vim.log.levels.DEBUG)
    vim.notify("Is multi: " .. tostring(is_multi), vim.log.levels.DEBUG)
    vim.notify("Input content length: " .. #content, vim.log.levels.DEBUG)
    vim.notify("Input content (first 100 chars): " .. content:sub(1, 100), vim.log.levels.DEBUG)
  end

  -- Save the content to the temp file first to ensure it exists
  if temp_file_path then
    local file = io.open(temp_file_path, "w")
    if file then
      file:write(content)
      file:close()

      if self.config.get("debug") then
        vim.notify("Saved input to temp file: " .. temp_file_path, vim.log.levels.DEBUG)
        if vim.fn.filereadable(temp_file_path) == 1 then
          vim.notify("Temp file exists and is readable", vim.log.levels.DEBUG)
          local file_size = vim.fn.getfsize(temp_file_path)
          vim.notify("Temp file size: " .. file_size .. " bytes", vim.log.levels.DEBUG)
        else
          vim.notify("WARNING: Temp file does not exist after writing!", vim.log.levels.WARN)
        end
      end
    else
      vim.notify("Failed to write to temp file: " .. temp_file_path, vim.log.levels.ERROR)
    end
  end

  -- Close the input buffer
  api.nvim_command(buf .. "bdelete!")

  -- Show a notification that we're processing
  vim.notify("Running schema on input text...", vim.log.levels.INFO)

  -- Verify the schema exists before running
  local schema_details = schemas_loader.get_schema(schema_id)
  if not schema_details then
    vim.notify("Schema not found. Please check the schema ID.", vim.log.levels.ERROR)
    return
  end

  -- Debug output
  if self.config.get("debug") then
    vim.notify("Using schema ID: " .. schema_id, vim.log.levels.DEBUG)
    vim.notify("Schema content length: " .. (schema_details.content and #schema_details.content or 0),
      vim.log.levels.DEBUG)
  end

  -- Show a notification that we're processing
  vim.notify("Running schema on input text...", vim.log.levels.INFO)

  -- Create a temporary file for the input
  local temp_dir = vim.fn.stdpath('cache') .. "/llm_nvim_temp"
  os.execute("mkdir -p " .. temp_dir) -- Ensure temp dir exists
  local temp_file = temp_dir .. "/schema_input_" .. os.time() .. ".txt"

  local file = io.open(temp_file, "w")
  if not file then
    vim.notify("Failed to create temporary file for schema input", vim.log.levels.ERROR)
    return
  end

  file:write(content)
  file:close()

  -- Run the schema using the llm CLI directly
  local cmd = string.format("cat '%s' | llm %s %s", temp_file,
    is_multi and "--schema-multi" or "--schema",
    schema_id)

  if self.config.get("debug") then
    vim.notify("Running schema command: " .. cmd, vim.log.levels.DEBUG)
  end

  local result = vim.fn.system(cmd)
  local shell_error = vim.v.shell_error

  -- Clean up the temporary file
  os.remove(temp_file)

  if shell_error ~= 0 then
    vim.notify("Failed to run schema: " .. result, vim.log.levels.ERROR)
    return
  end

  if result then
    if self.config.get("debug") then
      vim.notify("Schema result received (length: " .. #result .. ")", vim.log.levels.DEBUG)
      vim.notify("Result (first 100 chars): " .. result:sub(1, 100), vim.log.levels.DEBUG)
    end

    -- Try to parse the result as JSON to validate it
    local success, parsed = pcall(vim.fn.json_decode, result)
    if success then
      -- Format the JSON for better readability
      local formatted_json
      pcall(function()
        formatted_json = vim.json.encode(parsed, { indent = 2 })
      end)

      -- Use the formatted JSON if available, otherwise use the original result
      utils.create_buffer_with_content(formatted_json or result, "Schema Result: " .. schema_id, "json")
    else
      -- If not valid JSON, show as plain text
      utils.create_buffer_with_content(result, "Schema Result: " .. schema_id, "text")
      vim.notify("Warning: Schema result is not valid JSON", vim.log.levels.WARN)
    end
  else
    vim.notify("Failed to run schema on input text. Try a different schema or input.", vim.log.levels.ERROR)

    -- Create a buffer with the error message
    utils.create_buffer_with_content(
      "Failed to run schema " .. schema_id .. " on the provided input.\n\n" ..
      "Possible reasons:\n" ..
      "1. The schema definition may be invalid\n" ..
      "2. The input format doesn't match what the schema expects\n" ..
      "3. There might be an issue with the LLM CLI tool\n\n" ..
      "Try using a different schema or modifying your input.",
      "Schema Error: " .. schema_id,
      "text"
    )
  end
end

-- Keep the old function for backward compatibility
function M.submit_schema_input(schema_id, is_multi, buf)
  -- Get the content from the buffer, skipping the instruction lines
  local lines = api.nvim_buf_get_lines(buf, 3, -1, false)
  local content = table.concat(lines, "\n")

  -- Debug output
  if self.config.get("debug") then
    vim.notify("Schema ID: " .. schema_id, vim.log.levels.DEBUG)
    vim.notify("Is multi: " .. is_multi, vim.log.levels.DEBUG)
    vim.notify("Input content: " .. content, vim.log.levels.DEBUG)
  end

  -- Close the input window
  local win = api.nvim_get_current_win()
  api.nvim_win_close(win, true)

  -- Show a notification that we're processing
  vim.notify("Running schema on input text...", vim.log.levels.INFO)

  -- Run the schema
  local result = schemas_loader.run_schema(schema_id, content, is_multi == "true")

  if result then
    if self.config.get("debug") then
      vim.notify("Schema result: " .. result, vim.log.levels.DEBUG)
    end
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

  -- Ask for schema name with floating input
  utils.floating_input({
    prompt = "Enter schema name:",
    on_confirm = function(name)
      if not name or name == "" then
        vim.notify("Schema name cannot be empty", vim.log.levels.WARN)
        return
      end
      if name:match("[/\\]") then
        vim.notify("Schema name cannot contain path separators (/ or \\)", vim.log.levels.ERROR)
        return
      end

      -- Ask for schema type in a new floating input
      utils.floating_confirm({
        prompt = "Select schema format:",
        options = { "JSON Schema", "DSL (simplified schema syntax)" },
        on_confirm = function(format_choice)
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
            boilerplate =
            "{\n  \"type\": \"object\",\n  \"properties\": {\n    \"property_name\": {\n      \"type\": \"string\",\n      \"description\": \"Description of the property\"\n    }\n  },\n  \"required\": [\"property_name\"]\n}"
            -- Set filetype for syntax highlighting
            vim.defer_fn(function()
              local temp_buf = vim.fn.bufnr(temp_file_path)
              if temp_buf > 0 then
                api.nvim_buf_set_option(temp_buf, 'filetype', 'json')
              end
            end, 100)
          else -- DSL
            boilerplate =
            "# Define schema properties using DSL syntax\n# Example:\n# name: the person's name\n# age int: their age in years\n# bio: a short biography\n\n"
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
            callback = function(args)
              -- Check if buffer is still valid before proceeding
              if api.nvim_buf_is_valid(args.buf) then
                require('llm.schemas.schemas_manager').save_schema_from_temp_file(args.buf)
              end
            end,
          })

          -- Add a command to cancel and delete the buffer/file
          api.nvim_buf_create_user_command(bufnr, "LlmCancel", function()
            local temp_file = api.nvim_buf_get_var(bufnr, "llm_temp_schema_file_path")
            -- Force delete the buffer
            api.nvim_command(bufnr .. "bdelete!")
            -- Remove the temp file
            if temp_file and vim.fn.filereadable(temp_file) == 1 then
              os.remove(temp_file)
            end
            vim.notify("Schema creation cancelled.", vim.log.levels.INFO)
          end, {})

          -- Instruct the user
          vim.notify("Edit the schema in this buffer. Save (:w) to validate and finalize. Use :LlmCancel to abort.",
            vim.log.levels.INFO)
        end
      })
    end
  })
end

-- Save schema from the temporary file buffer (triggered by BufWritePost)
function M.save_schema_from_temp_file(bufnr)
  -- Check if buffer is valid
  if not api.nvim_buf_is_valid(bufnr) then
    if self.config.get("debug") then
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
      if self.config.get("debug") then
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
      if self.config.get("debug") then
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
    vim.notify("Schema not saved. Please fix the content and save again (:w), or use :LlmCancel to abort.",
      vim.log.levels.WARN)
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

-- Populate the buffer with schema management content
function M.populate_schemas_buffer(bufnr)
  -- Initialize view mode if not set (default to showing named only)
  if _G.llm_schemas_named_only == nil then
    _G.llm_schemas_named_only = true
  end
  local show_named_only = _G.llm_schemas_named_only

  local all_schemas = schemas_loader.get_schemas()
  local named_schemas = {}
  local unnamed_schemas = {}

  -- Get schema config to identify named schemas
  local _, schema_config_file = utils.get_config_path("schemas.json")
  local schema_ids_to_names = {}
  if schema_config_file then
    local config_file = io.open(schema_config_file, "r")
    if config_file then
      local content = config_file:read("*all"); config_file:close()
      if content and content ~= "" then
        local success, parsed = pcall(vim.fn.json_decode, content)
        if success and parsed then
          for name, id in pairs(parsed) do schema_ids_to_names[id] = name end
        end
      end
    end
  end

  -- Separate named and unnamed schemas
  for id, description in pairs(all_schemas) do
    if schema_ids_to_names[id] then
      table.insert(named_schemas, { id = id, name = schema_ids_to_names[id], description = description })
    else
      table.insert(unnamed_schemas, { id = id, description = description })
    end
  end

  -- Sort schemas
  table.sort(named_schemas, function(a, b) return a.name < b.name end)
  table.sort(unnamed_schemas, function(a, b) return a.id < b.id end)

  -- Determine which schemas to show
  local schemas_to_show = show_named_only and named_schemas or
      vim.list_extend(vim.deepcopy(named_schemas), unnamed_schemas)

  local lines = {
    "# Schema Management",
    "",
    "Navigate: [M]odels [P]lugins [K]eys [F]ragments [T]emplates",
    "Actions: [c]reate [r]un [v]iew [e]dit [a]lias [d]elete alias [t]oggle view [q]uit",
    "──────────────────────────────────────────────────────────────",
    ""
  }
  table.insert(lines, show_named_only and "Showing: Only named schemas" or "Showing: All schemas")
  table.insert(lines, "")

  local schema_data = {}
  local line_to_schema = {}
  local current_line = #lines + 1

  if #schemas_to_show == 0 then
    table.insert(lines, "No schemas found. Press 'c' to create one.")
  else
    table.insert(lines, "Schemas:")
    table.insert(lines, "----------")
    for i, schema in ipairs(schemas_to_show) do
      local description = schema.description:gsub("\n", " ") -- Avoid newline issues
      local schema_details = schemas_loader.get_schema(schema.id)
      local is_valid = schema_details and schema_details.content and pcall(vim.fn.json_decode, schema_details.content)

      local entry_lines = {
        string.format("Schema %d: %s", i, schema.id),
        schema.name and string.format("  Name: %s", schema.name) or nil,
        string.format("  Status: %s", is_valid and "Valid" or "Invalid"),
        string.format("  Description: %s", description),
        ""
      }
      -- Filter out nil lines (like missing name)
      local filtered_lines = {}
      for _, line in ipairs(entry_lines) do if line then table.insert(filtered_lines, line) end end
      for _, line in ipairs(filtered_lines) do table.insert(lines, line) end

      -- Store data for lookup
      schema_data[schema.id] = {
        index = i,
        name = schema.name,
        description = description,
        is_valid = is_valid,
        start_line = current_line,
      }
      for j = 0, #filtered_lines - 1 do line_to_schema[current_line + j] = schema.id end
      current_line = current_line + #filtered_lines
    end
  end

  api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- Apply syntax highlighting
  styles.setup_buffer_syntax(bufnr) -- Use styles module

  -- Store lookup tables in buffer variables
  vim.b[bufnr].line_to_schema = line_to_schema
  vim.b[bufnr].schema_data = schema_data
  vim.b[bufnr].schemas = schemas_to_show -- Store the displayed list

  return line_to_schema, schema_data     -- Return for direct use if needed
end

-- Setup keymaps for the schema management buffer
function M.setup_schemas_keymaps(bufnr, manager_module)
  manager_module = manager_module or M -- Allow passing self

  local function set_keymap(mode, lhs, rhs)
    api.nvim_buf_set_keymap(bufnr, mode, lhs, rhs, { noremap = true, silent = true })
  end

  -- Helper to get schema info
  local function get_schema_info_under_cursor()
    local current_line = api.nvim_win_get_cursor(0)[1]
    local line_to_schema = vim.b[bufnr].line_to_schema
    local schema_data = vim.b[bufnr].schema_data
    local schema_id = line_to_schema and line_to_schema[current_line]
    if schema_id and schema_data and schema_data[schema_id] then
      return schema_id, schema_data[schema_id]
    end
    return nil, nil
  end

  -- Create schema
  set_keymap('n', 'c',
    string.format([[<Cmd>lua require('%s').create_schema_from_manager(%d)<CR>]],
      manager_module.__name or 'llm.schemas.schemas_manager', bufnr))

  -- Run schema
  set_keymap('n', 'r',
    string.format([[<Cmd>lua require('%s').run_schema_under_cursor(%d)<CR>]],
      manager_module.__name or 'llm.schemas.schemas_manager', bufnr))

  -- View details
  set_keymap('n', 'v',
    string.format([[<Cmd>lua require('%s').view_schema_details_under_cursor(%d)<CR>]],
      manager_module.__name or 'llm.schemas.schemas_manager', bufnr))

  -- Edit schema
  set_keymap('n', 'e',
    string.format([[<Cmd>lua require('%s').edit_schema_under_cursor(%d)<CR>]],
      manager_module.__name or 'llm.schemas.schemas_manager', bufnr))

  -- Add/Set alias
  set_keymap('n', 'a',
    string.format([[<Cmd>lua require('%s').set_alias_for_schema_under_cursor(%d)<CR>]],
      manager_module.__name or 'llm.schemas.schemas_manager', bufnr))

  -- Delete alias
  set_keymap('n', 'd',
    string.format([[<Cmd>lua require('%s').delete_alias_for_schema_under_cursor(%d)<CR>]],
      manager_module.__name or 'llm.schemas.schemas_manager', bufnr))

  -- Toggle view
  set_keymap('n', 't',
    string.format([[<Cmd>lua require('%s').toggle_schemas_view(%d)<CR>]],
      manager_module.__name or 'llm.schemas.schemas_manager', bufnr))
end

-- Action functions called by keymaps (now accept bufnr)
function M.run_schema_under_cursor(bufnr)
  local schema_id, _ = M.get_schema_info_under_cursor(bufnr)
  if not schema_id then
    vim.notify("No schema found under cursor", vim.log.levels.ERROR)
    return
  end
  require('llm.unified_manager').close() -- Close manager before running
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

  local schema = schemas_loader.get_schema(schema_id)
  if not schema then
    vim.notify("Failed to get schema details for '" .. schema_id .. "'", vim.log.levels.ERROR)
    return
  end

  -- Close the unified manager before showing details
  require('llm.unified_manager').close()

  vim.schedule(function()
    -- Create a buffer for schema details
    local detail_buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(detail_buf, "buftype", "nofile")
    api.nvim_buf_set_option(detail_buf, "bufhidden", "wipe")
    api.nvim_buf_set_option(detail_buf, "swapfile", false)
    api.nvim_buf_set_name(detail_buf, "Schema Details: " .. schema_id)

    -- Create a new floating window
    local detail_win = utils.create_floating_window(detail_buf, 'LLM Schema Details: ' .. schema_id)

    -- Format schema details
    local lines = { "# Schema: " .. schema_id, "" }
    if schema.name then
      table.insert(lines, "## Name: " .. schema.name); table.insert(lines, "")
    end
    table.insert(lines, "## Schema Definition:"); table.insert(lines, "")
    if schema.content then
      local success, parsed = pcall(vim.fn.json_decode, schema.content)
      if success then
        local formatted_json = vim.fn.json_encode(parsed)
        if formatted_json then
          -- Split into lines with proper indentation
          local indent = "  "
          local current_indent = 0
          local formatted_lines = {}
          for line in formatted_json:gmatch("[^\r\n]+") do
            -- Simple indentation handling (basic but works for display)
            if line:match("}") or line:match("]") then
              current_indent = math.max(0, current_indent - 1)
            end
            table.insert(formatted_lines, string.rep(indent, current_indent) .. line)
            if line:match("{") or line:match("%[") then
              current_indent = current_indent + 1
            end
          end
          vim.list_extend(lines, formatted_lines)
        else
          for line in schema.content:gmatch("[^\r\n]+") do table.insert(lines, line) end
        end
      else
        for line in schema.content:gmatch("[^\r\n]+") do table.insert(lines, line) end
      end
    else
      table.insert(lines, "No schema content available")
    end
    table.insert(lines, ""); table.insert(lines, "Press [q]uit, [r]un schema, [e]dit schema, [a]dd alias, [d]elete alias")
    api.nvim_buf_set_lines(detail_buf, 0, -1, false, lines)

    -- Set up keymaps for the detail view
    local function set_detail_keymap(mode, lhs, rhs)
      api.nvim_buf_set_keymap(detail_buf, mode, lhs, rhs,
        { noremap = true, silent = true })
    end
    set_detail_keymap("n", "q", [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])
    set_detail_keymap("n", "<Esc>", [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])
    set_detail_keymap("n", "r",
      string.format([[<Cmd>lua require('llm.schemas.schemas_manager').run_schema_from_details('%s')<CR>]], schema_id))
    set_detail_keymap("n", "e",
      string.format([[<Cmd>lua require('llm.schemas.schemas_manager').edit_schema_from_details('%s')<CR>]], schema_id))
    set_detail_keymap("n", "a",
      string.format([[<Cmd>lua require('llm.schemas.schemas_manager').set_alias_from_details('%s')<CR>]], schema_id))
    set_detail_keymap("n", "d",
      string.format([[<Cmd>lua require('llm.schemas.schemas_manager').delete_alias_from_details('%s')<CR>]], schema_id))

    -- Set up highlighting
    styles.setup_buffer_styling(detail_buf)
  end)
end

function M.set_alias_for_schema_under_cursor(bufnr)
  local schema_id, schema_info = M.get_schema_info_under_cursor(bufnr)
  if not schema_id then
    vim.notify("No schema found under cursor", vim.log.levels.ERROR)
    return
  end

  local current_alias = schema_info.name
  local prompt_text = current_alias and "Enter new alias (current: " .. current_alias .. "): " or
      "Enter alias for schema: "

  -- Store the callback directly in the buffer
  local on_confirm = function(new_alias)
    if not new_alias or new_alias == "" then
      vim.notify("Alias cannot be empty", vim.log.levels.WARN)
      return
    end
    if new_alias:match("[/\\]") then
      vim.notify("Alias cannot contain path separators (/ or \\)", vim.log.levels.ERROR)
      return
    end
    if schemas_loader.set_schema_alias(schema_id, new_alias) then
      vim.notify("Schema alias set to '" .. new_alias .. "'", vim.log.levels.INFO)
      require('llm.unified_manager').switch_view("Schemas")
    else
      vim.notify("Failed to set schema alias", vim.log.levels.ERROR)
    end
  end

  -- Create the input buffer
  local input_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(input_buf, "buftype", "prompt")
  api.nvim_buf_set_option(input_buf, "bufhidden", "wipe")

  -- Set up the prompt
  vim.fn.prompt_setprompt(input_buf, prompt_text)
  if current_alias then
    vim.fn.prompt_settext(input_buf, current_alias)
  end

  -- Create the floating window
  local width = math.floor(vim.o.columns * 0.6)
  local height = 1
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win_opts = {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = 'Set Schema Alias',
    title_pos = 'center'
  }

  local win = api.nvim_open_win(input_buf, true, win_opts)

  -- Set up keymaps
  local function set_keymap(mode, lhs, rhs)
    api.nvim_buf_set_keymap(input_buf, mode, lhs, rhs, { noremap = true, silent = true })
  end

  set_keymap('i', '<CR>', '<Cmd>lua vim.api.nvim_win_close(0, true)<CR>')
  set_keymap('n', '<CR>', '<Cmd>lua vim.api.nvim_win_close(0, true)<CR>')
  set_keymap('', '<Esc>', '<Cmd>lua vim.api.nvim_win_close(0, true)<CR>')

  -- Start insert mode
  api.nvim_command('startinsert')

  -- Set up callback when window closes
  vim.api.nvim_create_autocmd('BufUnload', {
    buffer = input_buf,
    callback = function()
      local lines = api.nvim_buf_get_lines(input_buf, 0, -1, false)
      local input = table.concat(lines, '\n')
      -- Remove the prompt text if it was included in the input
      input = input:gsub("^Enter alias for schema: ", "")
      input = input:gsub("^Enter new alias %(current: .+%): ", "")
      on_confirm(input)
    end
  })
end

function M.create_schema_from_manager(bufnr)
  require('llm.unified_manager').close() -- Close manager before starting creation flow
  vim.schedule(function()
    M.create_schema()                    -- This function handles reopening the manager on completion/failure
  end)
end

function M.run_schema_from_details(schema_id)
  -- This function is called from the details view, which is separate from the unified manager
  api.nvim_win_close(0, true) -- Close the details view
  vim.schedule(function()
    M.run_schema_with_input_source(schema_id)
  end)
end

function M.set_alias_from_details(schema_id)
  -- This function is called from the details view
  local schema = schemas_loader.get_schema(schema_id)
  local current_alias = schema and schema.name
  local prompt_text = current_alias and "Enter new alias (current: " .. current_alias .. "): " or
      "Enter alias for schema: "

  utils.floating_input({
    prompt = prompt_text,
    default = current_alias or "",
    on_confirm = function(new_alias)
      if not new_alias or new_alias == "" then
        vim.notify("Alias cannot be empty", vim.log.levels.WARN)
        return
      end
      if new_alias:match("[/\\]") then
        vim.notify("Alias cannot contain path separators (/ or \\)", vim.log.levels.ERROR)
        return
      end
      if schemas_loader.set_schema_alias(schema_id, new_alias) then
        vim.notify("Schema alias set to '" .. new_alias .. "'", vim.log.levels.INFO)
        api.nvim_win_close(0, true) -- Close details view
        -- Reopen the unified manager to the Schemas view
        vim.schedule(function()
          require('llm.unified_manager').open_specific_manager("Schemas")
        end)
      else
        vim.notify("Failed to set schema alias", vim.log.levels.ERROR)
      end
    end
  })
end

function M.delete_alias_for_schema_under_cursor(bufnr)
  local schema_id, schema_info = M.get_schema_info_under_cursor(bufnr)
  if not schema_id then
    vim.notify("No schema found under cursor", vim.log.levels.ERROR)
    return
  end

  local alias_to_remove = schema_info.name
  if not alias_to_remove then
    vim.notify("This schema does not have an alias to delete", vim.log.levels.WARN)
    return
  end

  utils.floating_confirm({
    prompt = "Delete alias '" .. alias_to_remove .. "'?",
    on_confirm = function(confirmed)
      if not confirmed then return end
      if schemas_loader.remove_schema_alias(schema_id, alias_to_remove) then
        vim.notify("Schema alias '" .. alias_to_remove .. "' deleted", vim.log.levels.INFO)
        require('llm.unified_manager').switch_view("Schemas")
      else
        vim.notify("Failed to delete schema alias", vim.log.levels.ERROR)
      end
    end
  })
end

function M.edit_schema_under_cursor(bufnr)
  local schema_id, _ = M.get_schema_info_under_cursor(bufnr)
  if not schema_id then
    vim.notify("No schema found under cursor", vim.log.levels.ERROR)
    return
  end
  require('llm.unified_manager').close()  -- Close manager before editing
  vim.schedule(function()
    M.edit_schema_from_details(schema_id) -- Use the existing edit flow
  end)
end

function M.toggle_schemas_view(bufnr)
  -- Initialize if not set (default to showing named only)
  if _G.llm_schemas_named_only == nil then
    _G.llm_schemas_named_only = true
  end

  -- Toggle the preference
  _G.llm_schemas_named_only = not _G.llm_schemas_named_only

  -- Close and reopen the manager to force a full refresh
  require('llm.unified_manager').close()
  vim.schedule(function()
    require('llm.unified_manager').open_specific_manager("Schemas")
  end)
end

function M.delete_alias_from_details(schema_id)
  -- This function is called from the details view
  local schema = schemas_loader.get_schema(schema_id)
  local alias_to_remove = schema and schema.name
  if not alias_to_remove then
    vim.notify("This schema does not have an alias to delete", vim.log.levels.WARN)
    return
  end

  utils.floating_confirm({
    prompt = "Delete alias '" .. alias_to_remove .. "'?",
    on_confirm = function(confirmed)
      if not confirmed then return end
      if schemas_loader.remove_schema_alias(schema_id, alias_to_remove) then
        vim.notify("Schema alias '" .. alias_to_remove .. "' deleted", vim.log.levels.INFO)
        api.nvim_win_close(0, true) -- Close details view
        -- Reopen the unified manager to the Schemas view
        vim.schedule(function()
          require('llm.unified_manager').open_specific_manager("Schemas")
        end)
      else
        vim.notify("Failed to delete schema alias", vim.log.levels.ERROR)
      end
    end
  })
end

-- Helper to get schema info from buffer variables
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

-- Main function to open the schema manager (now delegates to unified manager)
function M.manage_schemas(show_named_only)
  -- Store the view mode preference globally for refresh/toggle
  _G.llm_schemas_named_only = show_named_only or true -- Default to named only
  require('llm.unified_manager').open_specific_manager("Schemas")
end

-- Add module name for require path in keymaps
M.__name = 'llm.schemas.schemas_manager'

-- Re-export functions from schemas_loader needed by other modules
M.get_schemas = schemas_loader.get_schemas
M.get_schema = schemas_loader.get_schema
M.save_schema = schemas_loader.save_schema
M.run_schema = schemas_loader.run_schema

return M
