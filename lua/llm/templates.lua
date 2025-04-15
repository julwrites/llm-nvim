-- llm/templates.lua - Template handling for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local api = vim.api
local fn = vim.fn

-- Get templates from llm CLI
function M.get_templates()
  local handle = io.popen("llm templates")
  local result = handle:read("*a")
  handle:close()
  
  local templates = {}
  
  for line in result:gmatch("[^\r\n]+") do
    if not line:match("^%-%-") and line ~= "" then
      local template_name = line:match("^%s*(.-)%s*$")
      if template_name then
        table.insert(templates, template_name)
      end
    end
  end
  
  return templates
end

-- Get template details
function M.get_template_details(template_name)
  local cmd = string.format('llm templates show %s', template_name)
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  handle:close()
  
  -- Parse YAML content
  local details = {
    name = template_name,
    prompt = "",
    system = "",
    schema = nil
  }
  
  local in_prompt = false
  local in_system = false
  local in_schema = false
  local schema_content = {}
  
  for line in result:gmatch("[^\r\n]+") do
    if line:match("^name:") then
      -- Already have the name
    elseif line:match("^prompt:") then
      in_prompt = true
      in_system = false
      in_schema = false
      details.prompt = line:match("^prompt:%s*(.*)$") or ""
    elseif line:match("^system:") then
      in_prompt = false
      in_system = true
      in_schema = false
      details.system = line:match("^system:%s*(.*)$") or ""
    elseif line:match("^schema_object:") or line:match("^schema:") then
      in_prompt = false
      in_system = false
      in_schema = true
    elseif in_prompt then
      details.prompt = details.prompt .. "\n" .. line
    elseif in_system then
      details.system = details.system .. "\n" .. line
    elseif in_schema then
      table.insert(schema_content, line)
    end
  end
  
  if #schema_content > 0 then
    details.schema = table.concat(schema_content, "\n")
  end
  
  -- Trim whitespace
  details.prompt = details.prompt:match("^%s*(.-)%s*$") or ""
  details.system = details.system:match("^%s*(.-)%s*$") or ""
  
  return details
end

-- Create a new template
function M.create_template(name, prompt, system, schema)
  -- Create a temporary file with the template content
  local temp_file = os.tmpname()
  local file = io.open(temp_file, "w")
  
  if not file then
    vim.notify("Failed to create temporary file", vim.log.levels.ERROR)
    return false
  end
  
  file:write("name: " .. name .. "\n")
  
  if prompt and prompt ~= "" then
    file:write("prompt: " .. prompt .. "\n")
  end
  
  if system and system ~= "" then
    file:write("system: " .. system .. "\n")
  end
  
  if schema and schema ~= "" then
    file:write("schema: " .. schema .. "\n")
  end
  
  file:close()
  
  -- Create the template using llm CLI
  local cmd = string.format('llm templates import "%s"', temp_file)
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
  if result and (result:match("Template saved") or result:match("saved successfully") or result:match("Imported template")) then
    vim.notify("Template created successfully: " .. name, vim.log.levels.INFO)
    return true
  else
    vim.notify("Failed to create template: " .. (result or "Unknown error"), vim.log.levels.ERROR)
    return false
  end
end

-- Delete a template
function M.delete_template(name)
  local cmd = string.format('llm templates delete %s -y', name)
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  local success = handle:close()
  
  return success
end

-- Run a template
function M.run_template(name, input)
  local cmd
  if input and input ~= "" then
    -- Create a temporary file with the input
    local temp_file = os.tmpname()
    local file = io.open(temp_file, "w")
    file:write(input)
    file:close()
    
    cmd = string.format('cat %s | llm -t %s', temp_file, name)
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    
    -- Clean up temp file
    os.remove(temp_file)
    
    return result
  else
    cmd = string.format('llm -t %s', name)
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    
    return result
  end
end

-- Select a template to use
function M.select_template()
  local templates = M.get_templates()
  
  if #templates == 0 then
    vim.notify("No templates found", vim.log.levels.WARN)
    return
  end
  
  vim.ui.select(templates, {
    prompt = "Select a template to use:"
  }, function(choice)
    if not choice then return end
    
    -- Ask for input
    vim.ui.input({
      prompt = "Enter input for template (optional):"
    }, function(input)
      -- Run the template
      local result = M.run_template(choice, input or "")
      
      -- Create a response buffer with the result
      require('llm').create_response_buffer(result)
    end)
  end)
end

-- Manage templates (view, create, edit, delete)
function M.manage_templates()
  local templates = M.get_templates()
  
  -- Create a new buffer for the template manager
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(buf, 'swapfile', false)
  api.nvim_buf_set_name(buf, 'LLM Templates')
  
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
    title = ' LLM Templates ',
    title_pos = 'center',
  }
  
  local win = api.nvim_open_win(buf, true, opts)
  api.nvim_win_set_option(win, 'cursorline', true)
  api.nvim_win_set_option(win, 'winblend', 0)
  
  -- Set buffer content
  local lines = {
    "# LLM Templates Manager",
    "",
    "Keyboard shortcuts:",
    "  v - View template details",
    "  e - Edit template",
    "  d - Delete template",
    "  c - Create new template",
    "  r - Run template",
    "  q - Quit",
    "──────────────────────────────────────────────────────────────",
    ""
  }
  
  -- Add templates to the buffer
  if #templates > 0 then
    table.insert(lines, "Available templates:")
    for i, template_name in ipairs(templates) do
      table.insert(lines, "  • " .. template_name)
    end
  else
    table.insert(lines, "No templates found. Press 'c' to create a new template.")
  end
  
  -- Add option to create a new template
  table.insert(lines, "")
  table.insert(lines, "[+] Create new template")
  
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  
  -- Set buffer options
  api.nvim_buf_set_option(buf, 'modifiable', false)
  
  -- Set up syntax highlighting
  require('llm').setup_buffer_highlighting(buf)
  
  -- Add template-specific highlighting
  vim.cmd([[
    highlight default LLMTemplateItem guifg=#61afef
    highlight default LLMTemplateCreate guifg=#98c379 gui=bold
    highlight default LLMTemplateKeyShortcut guifg=#c678dd
  ]])
  
  -- Apply syntax highlighting
  local syntax_cmds = {
    "syntax match LLMTemplateItem /^  • .\\+$/",
    "syntax match LLMTemplateCreate /^\\[+\\] Create new template$/",
    "syntax match LLMTemplateKeyShortcut /^  [a-z] - .\\+$/",
  }
  
  for _, cmd in ipairs(syntax_cmds) do
    vim.api.nvim_buf_call(buf, function()
      vim.cmd(cmd)
    end)
  end
  
  -- Map of line numbers to template names
  local line_to_template = {}
  local template_start_line = 12 -- Line where templates start
  if #templates > 0 then
    template_start_line = 13 -- Account for the "Available templates:" line
    for i, template_name in ipairs(templates) do
      local line_num = template_start_line + i - 1
      line_to_template[line_num] = template_name
    end
  end
  
  -- Set keymaps
  local function set_keymap(mode, lhs, rhs)
    api.nvim_buf_set_keymap(buf, mode, lhs, rhs, {noremap = true, silent = true})
  end
  
  -- View template
  set_keymap('n', 'v', [[<cmd>lua require('llm.template_manager').view_template_under_cursor()<CR>]])
  
  -- Edit template
  set_keymap('n', 'e', [[<cmd>lua require('llm.template_manager').edit_template_under_cursor()<CR>]])
  
  -- Delete template
  set_keymap('n', 'd', [[<cmd>lua require('llm.template_manager').delete_template_under_cursor()<CR>]])
  
  -- Create new template
  set_keymap('n', 'c', [[<cmd>lua require('llm.template_manager').create_new_template()<CR>]])
  
  -- Run template
  set_keymap('n', 'r', [[<cmd>lua require('llm.template_manager').run_template_under_cursor()<CR>]])
  
  -- Close window
  set_keymap('n', 'q', [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])
  set_keymap('n', '<Esc>', [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])
  
  -- Create template manager module for the helper functions
  local template_manager = {}
  
  function template_manager.view_template_under_cursor()
    local current_line = api.nvim_win_get_cursor(0)[1]
    local template_name = line_to_template[current_line]
    
    if not template_name then
      -- Check if we're on the "Create new template" line
      local line_content = api.nvim_buf_get_lines(buf, current_line - 1, current_line, false)[1]
      if line_content == "[+] Create new template" then
        template_manager.create_new_template()
      end
      return
    end
    
    -- Get template details
    local details = M.get_template_details(template_name)
    
    -- Create a new buffer for the template content
    local content_buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(content_buf, 'buftype', 'nofile')
    api.nvim_buf_set_option(content_buf, 'bufhidden', 'wipe')
    api.nvim_buf_set_option(content_buf, 'swapfile', false)
    
    -- Use a unique buffer name to avoid conflicts
    local buffer_name = 'LLM Template View: ' .. template_name .. ' ' .. os.time()
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
      title = ' Template: ' .. template_name .. ' ',
      title_pos = 'center',
    })
    
    -- Set content
    local content_lines = {}
    table.insert(content_lines, "# Template: " .. template_name)
    table.insert(content_lines, "")
    
    if details.prompt and details.prompt ~= "" then
      table.insert(content_lines, "## Prompt:")
      table.insert(content_lines, "")
      for line in details.prompt:gmatch("[^\r\n]+") do
        table.insert(content_lines, line)
      end
      table.insert(content_lines, "")
    end
    
    if details.system and details.system ~= "" then
      table.insert(content_lines, "## System:")
      table.insert(content_lines, "")
      for line in details.system:gmatch("[^\r\n]+") do
        table.insert(content_lines, line)
      end
      table.insert(content_lines, "")
    end
    
    if details.schema then
      table.insert(content_lines, "## Schema:")
      table.insert(content_lines, "")
      for line in details.schema:gmatch("[^\r\n]+") do
        table.insert(content_lines, line)
      end
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
  
  function template_manager.edit_template_under_cursor()
    local current_line = vim.api.nvim_win_get_cursor(0)[1]
    local template_name = line_to_template[current_line]
    
    if not template_name then return end
    
    -- Get template details
    local details = M.get_template_details(template_name)
    
    -- Create a new buffer for the template editor
    local edit_buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(edit_buf, 'buftype', 'acwrite')
    api.nvim_buf_set_option(edit_buf, 'bufhidden', 'wipe')
    api.nvim_buf_set_option(edit_buf, 'swapfile', false)
    
    -- Use a unique buffer name to avoid conflicts
    local buffer_name = 'LLM Template: ' .. template_name .. ' ' .. os.time()
    pcall(api.nvim_buf_set_name, edit_buf, buffer_name)
    
    -- Create a new window
    local width = math.floor(vim.o.columns * 0.8)
    local height = math.floor(vim.o.lines * 0.8)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)
    
    local edit_win = api.nvim_open_win(edit_buf, true, {
      relative = 'editor',
      width = width,
      height = height,
      row = row,
      col = col,
      style = 'minimal',
      border = 'rounded',
      title = ' Edit Template: ' .. template_name .. ' ',
      title_pos = 'center',
    })
    
    -- Set initial content
    local content_lines = {
      "name: " .. template_name,
      ""
    }
    
    if details.prompt and details.prompt ~= "" then
      table.insert(content_lines, "prompt: " .. details.prompt)
      table.insert(content_lines, "")
    end
    
    if details.system and details.system ~= "" then
      table.insert(content_lines, "system: " .. details.system)
      table.insert(content_lines, "")
    end
    
    if details.schema then
      table.insert(content_lines, "schema: " .. details.schema)
    end
    
    table.insert(content_lines, "")
    table.insert(content_lines, "# Press <leader>s to save the template")
    table.insert(content_lines, "# Press q to cancel")
    
    api.nvim_buf_set_lines(edit_buf, 0, -1, false, content_lines)
    
    -- Set buffer as modifiable
    api.nvim_buf_set_option(edit_buf, 'modifiable', true)
    
    -- Set filetype for syntax highlighting
    api.nvim_buf_set_option(edit_buf, 'filetype', 'yaml')
    
    -- Set keymaps
    api.nvim_buf_set_keymap(edit_buf, 'n', '<leader>s', [[<cmd>lua require('llm.template_manager').save_template_buffer()<CR>]], {noremap = true, silent = true})
    api.nvim_buf_set_keymap(edit_buf, 'n', 'q', [[<cmd>lua require('llm.template_manager').cancel_template_edit()<CR>]], {noremap = true, silent = true})
    
    -- Store buffer data for later use
    template_manager.current_edit_buffer = {
      buf = edit_buf,
      win = edit_win,
      name = template_name,
      is_new = false
    }
  end
  
  function template_manager.delete_template_under_cursor()
    local current_line = api.nvim_win_get_cursor(0)[1]
    local template_name = line_to_template[current_line]
    
    if not template_name then return end
    
    -- Confirm deletion
    vim.ui.select({"Yes", "No"}, {
      prompt = "Delete template '" .. template_name .. "'?"
    }, function(choice)
      if choice ~= "Yes" then return end
      
      if M.delete_template(template_name) then
        vim.notify("Template deleted: " .. template_name, vim.log.levels.INFO)
        
        -- Refresh the template manager
        vim.api.nvim_win_close(0, true)
        vim.schedule(function()
          M.manage_templates()
        end)
      else
        vim.notify("Failed to delete template", vim.log.levels.ERROR)
      end
    end)
  end
  
  function template_manager.create_new_template()
    -- Ask for template name
    vim.ui.input({
      prompt = "Enter template name: "
    }, function(name)
      if not name or name == "" then
        vim.notify("Template name cannot be empty", vim.log.levels.ERROR)
        return
      end
      
      -- Create a new buffer for the template editor
      local edit_buf = api.nvim_create_buf(false, true)
      api.nvim_buf_set_option(edit_buf, 'buftype', 'acwrite')
      api.nvim_buf_set_option(edit_buf, 'bufhidden', 'wipe')
      api.nvim_buf_set_option(edit_buf, 'swapfile', false)
      
      -- Use a unique buffer name to avoid conflicts
      local buffer_name = 'LLM Template: ' .. name .. ' ' .. os.time()
      pcall(api.nvim_buf_set_name, edit_buf, buffer_name)
      
      -- Create a new window
      local width = math.floor(vim.o.columns * 0.8)
      local height = math.floor(vim.o.lines * 0.8)
      local row = math.floor((vim.o.lines - height) / 2)
      local col = math.floor((vim.o.columns - width) / 2)
      
      local edit_win = api.nvim_open_win(edit_buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = row,
        col = col,
        style = 'minimal',
        border = 'rounded',
        title = ' New Template: ' .. name .. ' ',
        title_pos = 'center',
      })
      
      -- Set initial content
      local content_lines = {
        "name: " .. name,
        "",
        "# Add your template content below",
        "# Examples:",
        "prompt: Your prompt text here",
        "system: You are a helpful assistant.",
        "# For schema templates, use:",
        "# schema: name, age int, bio",
        "",
        "# Press <leader>s to save the template",
        "# Press q to cancel"
      }
      
      api.nvim_buf_set_lines(edit_buf, 0, -1, false, content_lines)
      
      -- Set buffer as modifiable
      api.nvim_buf_set_option(edit_buf, 'modifiable', true)
      
      -- Set filetype for syntax highlighting
      api.nvim_buf_set_option(edit_buf, 'filetype', 'yaml')
      
      -- Set keymaps
      api.nvim_buf_set_keymap(edit_buf, 'n', '<leader>s', [[<cmd>lua require('llm.template_manager').save_template_buffer()<CR>]], {noremap = true, silent = true})
      api.nvim_buf_set_keymap(edit_buf, 'n', 'q', [[<cmd>lua require('llm.template_manager').cancel_template_edit()<CR>]], {noremap = true, silent = true})
      
      -- Store buffer data for later use
      template_manager.current_edit_buffer = {
        buf = edit_buf,
        win = edit_win,
        name = name,
        is_new = true
      }
    end)
  end
  
  function template_manager.run_template_under_cursor()
    local current_line = api.nvim_win_get_cursor(0)[1]
    local template_name = line_to_template[current_line]
    
    if not template_name then return end
    
    -- Close the template manager window
    vim.api.nvim_win_close(0, true)
    
    -- Ask for input
    vim.ui.input({
      prompt = "Enter input for template (optional):"
    }, function(input)
      -- Run the template
      local result = M.run_template(template_name, input or "")
      
      -- Create a response buffer with the result
      require('llm').create_response_buffer(result)
    end)
  end
  
  -- Helper function to save the template from the edit buffer
  function template_manager.save_template_buffer()
    if not template_manager.current_edit_buffer then
      vim.notify("No template being edited", vim.log.levels.ERROR)
      return
    end
    
    local buf = template_manager.current_edit_buffer.buf
    local win = template_manager.current_edit_buffer.win
    local name = template_manager.current_edit_buffer.name
    local is_new = template_manager.current_edit_buffer.is_new
    
    -- Get buffer content
    local content = table.concat(api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    
    -- Create a temporary file with the template content
    local temp_file = os.tmpname()
    local file = io.open(temp_file, "w")
    
    if not file then
      vim.notify("Failed to create temporary file", vim.log.levels.ERROR)
      return
    end
    
    file:write(content)
    file:close()
    
    -- Import the template
    local cmd = string.format('llm templates import "%s"', temp_file)
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
    if result and (result:match("Template saved") or result:match("saved successfully") or result:match("Imported template")) then
      if is_new then
        vim.notify("Template created: " .. name, vim.log.levels.INFO)
      else
        vim.notify("Template updated: " .. name, vim.log.levels.INFO)
      end
      
      -- Close the edit window
      if api.nvim_win_is_valid(win) then
        api.nvim_win_close(win, true)
      end
      
      -- Refresh the template manager
      vim.schedule(function()
        M.manage_templates()
      end)
    else
      vim.notify("Failed to save template. Check your YAML syntax: " .. (result or "Unknown error"), vim.log.levels.ERROR)
    end
  end
  
  -- Helper function to cancel template editing
  function template_manager.cancel_template_edit()
    if not template_manager.current_edit_buffer then
      return
    end
    
    local win = template_manager.current_edit_buffer.win
    
    -- Close the edit window
    if api.nvim_win_is_valid(win) then
      api.nvim_win_close(win, true)
    end
    
    -- Refresh the template manager if it was closed
    vim.schedule(function()
      if not api.nvim_buf_is_valid(buf) then
        M.manage_templates()
      end
    end)
  end

  -- Helper function to save the template from the edit buffer
  function template_manager.save_template_buffer()
    if not template_manager.current_edit_buffer then
      vim.notify("No template being edited", vim.log.levels.ERROR)
      return
    end
    
    local buf = template_manager.current_edit_buffer.buf
    local win = template_manager.current_edit_buffer.win
    local name = template_manager.current_edit_buffer.name
    local is_new = template_manager.current_edit_buffer.is_new
    
    -- Get buffer content
    local content = table.concat(api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    
    -- Create a temporary file with the template content
    local temp_file = os.tmpname()
    local file = io.open(temp_file, "w")
    
    if not file then
      vim.notify("Failed to create temporary file", vim.log.levels.ERROR)
      return
    end
    
    file:write(content)
    file:close()
    
    -- Import the template
    local cmd = string.format('llm templates import "%s"', temp_file)
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
    if result and (result:match("Template saved") or result:match("saved successfully") or result:match("Imported template")) then
      if is_new then
        vim.notify("Template created: " .. name, vim.log.levels.INFO)
      else
        vim.notify("Template updated: " .. name, vim.log.levels.INFO)
      end
      
      -- Close the edit window
      if api.nvim_win_is_valid(win) then
        api.nvim_win_close(win, true)
      end
      
      -- Refresh the template manager
      vim.schedule(function()
        M.manage_templates()
      end)
    else
      vim.notify("Failed to save template. Check your YAML syntax: " .. (result or "Unknown error"), vim.log.levels.ERROR)
    end
  end
  
  -- Helper function to cancel template editing
  function template_manager.cancel_template_edit()
    if not template_manager.current_edit_buffer then
      return
    end
    
    local win = template_manager.current_edit_buffer.win
    
    -- Close the edit window
    if api.nvim_win_is_valid(win) then
      api.nvim_win_close(win, true)
    end
    
    -- Refresh the template manager if it was closed
    vim.schedule(function()
      if not api.nvim_buf_is_valid(buf) then
        M.manage_templates()
      end
    end)
  end

  -- Store the template manager module
  package.loaded['llm.template_manager'] = template_manager
end

return M
