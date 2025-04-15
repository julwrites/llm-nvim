-- llm/fragments.lua - Fragment handling for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local api = vim.api
local fn = vim.fn

-- Get fragments from llm CLI
function M.get_fragments()
  local handle = io.popen("llm fragments")
  local result = handle:read("*a")
  handle:close()
  
  local fragments = {}
  local current_fragment = nil
  
  for line in result:gmatch("[^\r\n]+") do
    if line:match("^%s*-%s+hash:%s+") then
      -- Start of a new fragment
      if current_fragment then
        table.insert(fragments, current_fragment)
      end
      
      local hash = line:match("hash:%s+([0-9a-f]+)")
      current_fragment = {
        hash = hash,
        aliases = {},
        source = "",
        content = "",
        datetime = ""
      }
    elseif current_fragment and line:match("^%s+aliases:") then
      local aliases_str = line:match("aliases:%s+(.+)")
      if aliases_str and aliases_str ~= "[]" then
        -- Parse aliases from the string
        for alias in aliases_str:gmatch('"([^"]+)"') do
          table.insert(current_fragment.aliases, alias)
        end
      end
    elseif current_fragment and line:match("^%s+datetime_utc:") then
      current_fragment.datetime = line:match("datetime_utc:%s+'([^']+)'")
    elseif current_fragment and line:match("^%s+source:") then
      current_fragment.source = line:match("source:%s+(.+)")
    elseif current_fragment and line:match("^%s+content:") then
      -- Start of content
      current_fragment.content = line:match("content:%s+(.+)")
      if current_fragment.content:match("^%|-$") then
        current_fragment.content = ""
      end
    elseif current_fragment and current_fragment.content ~= "" then
      -- Continuation of content
      current_fragment.content = current_fragment.content .. "\n" .. line:gsub("^%s+", "")
    end
  end
  
  -- Add the last fragment
  if current_fragment then
    table.insert(fragments, current_fragment)
  end
  
  return fragments
end

-- Set an alias for a fragment
function M.set_fragment_alias(path, alias)
  local cmd = string.format('llm fragments set %s "%s"', alias, path)
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  local success = handle:close()
  
  return success
end

-- Remove a fragment alias
function M.remove_fragment_alias(alias)
  local cmd = string.format('llm fragments remove %s', alias)
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  local success = handle:close()
  
  return success
end

-- Show a specific fragment
function M.show_fragment(hash_or_alias)
  local cmd = string.format('llm fragments show %s', hash_or_alias)
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  handle:close()
  
  return result
end

-- Get a list of files from NvimTree if available
function M.get_files_from_nvimtree()
  -- Check if NvimTree is available
  local has_nvimtree = pcall(require, "nvim-tree.api")
  if not has_nvimtree then
    return {}
  end
  
  local nvimtree_api = require("nvim-tree.api")
  local nodes = nvimtree_api.tree.get_nodes()
  
  if not nodes then
    return {}
  end
  
  local files = {}
  
  -- Helper function to recursively collect files
  local function collect_files(node, path_prefix)
    if not node then return end
    
    local path = path_prefix and (path_prefix .. "/" .. node.name) or node.name
    
    if node.type == "file" then
      table.insert(files, {
        name = node.name,
        path = path,
        absolute_path = fn.fnamemodify(path, ":p")
      })
    elseif node.type == "directory" and node.nodes then
      for _, child in ipairs(node.nodes) do
        collect_files(child, path)
      end
    end
  end
  
  -- Start collecting from root nodes
  if nodes.nodes then
    for _, node in ipairs(nodes.nodes) do
      collect_files(node, "")
    end
  end
  
  return files
end

-- Select a file to use as a fragment
function M.select_file_as_fragment()
  local files = M.get_files_from_nvimtree()
  
  if #files == 0 then
    -- If NvimTree is not available or has no files, use vim.ui.input
    vim.ui.input({
      prompt = "Enter file path to use as fragment: "
    }, function(input)
      if not input or input == "" then return end
      
      -- Check if file exists
      if fn.filereadable(input) == 0 then
        vim.notify("File not found: " .. input, vim.log.levels.ERROR)
        return
      end
      
      -- Ask for an optional alias
      vim.ui.input({
        prompt = "Set an alias for this fragment (optional): "
      }, function(alias)
        if alias and alias ~= "" then
          if M.set_fragment_alias(input, alias) then
            vim.notify("Fragment alias set: " .. alias .. " -> " .. input, vim.log.levels.INFO)
          else
            vim.notify("Failed to set fragment alias", vim.log.levels.ERROR)
          end
        end
        
        vim.notify("File added as fragment: " .. input, vim.log.levels.INFO)
      end)
    end)
    return
  end
  
  -- Format files for selection
  local items = {}
  for _, file in ipairs(files) do
    table.insert(items, file.path)
  end
  
  -- Use vim.ui.select to choose a file
  vim.ui.select(items, {
    prompt = "Select a file to use as fragment:",
    format_item = function(item)
      return item
    end
  }, function(choice, idx)
    if not choice then return end
    
    local selected_file = files[idx]
    if not selected_file then return end
    
    -- Ask for an optional alias
    vim.ui.input({
      prompt = "Set an alias for this fragment (optional): "
    }, function(alias)
      if alias and alias ~= "" then
        if M.set_fragment_alias(selected_file.absolute_path, alias) then
          vim.notify("Fragment alias set: " .. alias .. " -> " .. selected_file.path, vim.log.levels.INFO)
        else
          vim.notify("Failed to set fragment alias", vim.log.levels.ERROR)
        end
      end
      
      vim.notify("File added as fragment: " .. selected_file.path, vim.log.levels.INFO)
    end)
  end)
end

-- Manage fragments (view, set aliases, remove aliases)
function M.manage_fragments()
  local fragments = M.get_fragments()
  if #fragments == 0 then
    vim.notify("No fragments found", vim.log.levels.INFO)
    return
  end
  
  -- Create a new buffer for the fragment manager
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(buf, 'swapfile', false)
  api.nvim_buf_set_name(buf, 'LLM Fragments')
  
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
    title = ' LLM Fragments ',
    title_pos = 'center',
  }
  
  local win = api.nvim_open_win(buf, true, opts)
  api.nvim_win_set_option(win, 'cursorline', true)
  api.nvim_win_set_option(win, 'winblend', 0)
  
  -- Set buffer content
  local lines = {
    "# LLM Fragments Manager",
    "",
    "Press 'v' to view fragment, 'a' to set alias, 'r' to remove alias, 'q' to quit",
    "──────────────────────────────────────────────────────────────",
    ""
  }
  
  -- Add fragments to the buffer
  for i, fragment in ipairs(fragments) do
    local aliases = table.concat(fragment.aliases, ", ")
    if aliases == "" then aliases = "none" end
    
    local source = fragment.source or "unknown"
    local content_preview = fragment.content:sub(1, 50)
    if #fragment.content > 50 then
      content_preview = content_preview .. "..."
    end
    
    table.insert(lines, string.format("Fragment %d: %s", i, fragment.hash))
    table.insert(lines, string.format("  Source: %s", source))
    table.insert(lines, string.format("  Aliases: %s", aliases))
    table.insert(lines, string.format("  Date: %s", fragment.datetime or "unknown"))
    table.insert(lines, string.format("  Content: %s", content_preview))
    table.insert(lines, "")
  end
  
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  
  -- Set buffer options
  api.nvim_buf_set_option(buf, 'modifiable', false)
  
  -- Set up syntax highlighting
  require('llm').setup_buffer_highlighting(buf)
  
  -- Add fragment-specific highlighting
  vim.cmd([[
    highlight default LLMFragmentHash guifg=#61afef
    highlight default LLMFragmentSource guifg=#98c379
    highlight default LLMFragmentAliases guifg=#c678dd
    highlight default LLMFragmentDate guifg=#56b6c2
    highlight default LLMFragmentContent guifg=#e5c07b
  ]])
  
  -- Apply syntax highlighting
  local syntax_cmds = {
    "syntax match LLMFragmentHash /^Fragment \\d\\+: [0-9a-f]\\+$/",
    "syntax match LLMFragmentSource /^  Source: .*$/",
    "syntax match LLMFragmentAliases /^  Aliases: .*$/",
    "syntax match LLMFragmentDate /^  Date: .*$/",
    "syntax match LLMFragmentContent /^  Content: .*$/",
  }
  
  for _, cmd in ipairs(syntax_cmds) do
    vim.api.nvim_buf_call(buf, function()
      vim.cmd(cmd)
    end)
  end
  
  -- Map of line numbers to fragment indices
  local line_to_fragment = {}
  for i, fragment in ipairs(fragments) do
    local line_num = 5 + (i - 1) * 6 + 1
    line_to_fragment[line_num] = i
    line_to_fragment[line_num + 1] = i
    line_to_fragment[line_num + 2] = i
    line_to_fragment[line_num + 3] = i
    line_to_fragment[line_num + 4] = i
  end
  
  -- Set keymaps
  local function set_keymap(mode, lhs, rhs)
    api.nvim_buf_set_keymap(buf, mode, lhs, rhs, {noremap = true, silent = true})
  end
  
  -- View fragment content
  set_keymap('n', 'v', [[<cmd>lua require('llm.fragment_manager').view_fragment_under_cursor()<CR>]])
  
  -- Set alias for fragment
  set_keymap('n', 'a', [[<cmd>lua require('llm.fragment_manager').set_alias_for_fragment_under_cursor()<CR>]])
  
  -- Remove alias from fragment
  set_keymap('n', 'r', [[<cmd>lua require('llm.fragment_manager').remove_alias_from_fragment_under_cursor()<CR>]])
  
  -- Close window
  set_keymap('n', 'q', [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])
  set_keymap('n', '<Esc>', [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])
  
  -- Create fragment manager module for the helper functions
  local fragment_manager = {}
  
  function fragment_manager.view_fragment_under_cursor()
    local current_line = api.nvim_win_get_cursor(0)[1]
    local fragment_idx = line_to_fragment[current_line]
    
    if not fragment_idx then return end
    
    local fragment = fragments[fragment_idx]
    if not fragment then return end
    
    -- Create a new buffer for the fragment content
    local content_buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(content_buf, 'buftype', 'nofile')
    api.nvim_buf_set_option(content_buf, 'bufhidden', 'wipe')
    api.nvim_buf_set_option(content_buf, 'swapfile', false)
    api.nvim_buf_set_name(content_buf, 'Fragment: ' .. fragment.hash:sub(1, 8))
    
    -- Create a new window
    local content_win = api.nvim_open_win(content_buf, true, {
      relative = 'editor',
      width = width,
      height = height,
      row = row,
      col = col,
      style = 'minimal',
      border = 'rounded',
      title = ' Fragment Content ',
      title_pos = 'center',
    })
    
    -- Set content
    local content_lines = {}
    table.insert(content_lines, "# Fragment: " .. fragment.hash)
    table.insert(content_lines, "Source: " .. (fragment.source or "unknown"))
    
    local aliases = table.concat(fragment.aliases, ", ")
    if aliases == "" then aliases = "none" end
    table.insert(content_lines, "Aliases: " .. aliases)
    
    table.insert(content_lines, "Date: " .. (fragment.datetime or "unknown"))
    table.insert(content_lines, "")
    table.insert(content_lines, "## Content:")
    table.insert(content_lines, "")
    
    -- Split content into lines
    for line in fragment.content:gmatch("[^\r\n]+") do
      table.insert(content_lines, line)
    end
    
    api.nvim_buf_set_lines(content_buf, 0, -1, false, content_lines)
    
    -- Set buffer options
    api.nvim_buf_set_option(content_buf, 'modifiable', false)
    
    -- Set filetype for syntax highlighting based on source
    local filetype = "text"
    if fragment.source then
      if fragment.source:match("%.py$") then
        filetype = "python"
      elseif fragment.source:match("%.js$") then
        filetype = "javascript"
      elseif fragment.source:match("%.lua$") then
        filetype = "lua"
      elseif fragment.source:match("%.md$") then
        filetype = "markdown"
      elseif fragment.source:match("%.json$") then
        filetype = "json"
      elseif fragment.source:match("%.html$") then
        filetype = "html"
      elseif fragment.source:match("%.css$") then
        filetype = "css"
      elseif fragment.source:match("%.sh$") then
        filetype = "sh"
      end
    end
    
    api.nvim_buf_set_option(content_buf, 'filetype', filetype)
    
    -- Set keymap to close window
    api.nvim_buf_set_keymap(content_buf, 'n', 'q', [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]], {noremap = true, silent = true})
    api.nvim_buf_set_keymap(content_buf, 'n', '<Esc>', [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]], {noremap = true, silent = true})
  end
  
  function fragment_manager.set_alias_for_fragment_under_cursor()
    local current_line = api.nvim_win_get_cursor(0)[1]
    local fragment_idx = line_to_fragment[current_line]
    
    if not fragment_idx then return end
    
    local fragment = fragments[fragment_idx]
    if not fragment then return end
    
    -- Prompt for alias
    vim.ui.input({
      prompt = "Enter alias for fragment: "
    }, function(alias)
      if not alias or alias == "" then return end
      
      -- Set alias
      if M.set_fragment_alias(fragment.hash, alias) then
        vim.notify("Alias set: " .. alias .. " -> " .. fragment.hash:sub(1, 8), vim.log.levels.INFO)
        
        -- Refresh the fragment manager
        vim.api.nvim_win_close(0, true)
        vim.schedule(function()
          M.manage_fragments()
        end)
      else
        vim.notify("Failed to set alias", vim.log.levels.ERROR)
      end
    end)
  end
  
  function fragment_manager.remove_alias_from_fragment_under_cursor()
    local current_line = api.nvim_win_get_cursor(0)[1]
    local fragment_idx = line_to_fragment[current_line]
    
    if not fragment_idx then return end
    
    local fragment = fragments[fragment_idx]
    if not fragment then return end
    
    if #fragment.aliases == 0 then
      vim.notify("Fragment has no aliases", vim.log.levels.WARN)
      return
    end
    
    -- If there's only one alias, remove it directly
    if #fragment.aliases == 1 then
      local alias = fragment.aliases[1]
      
      -- Confirm removal
      vim.ui.select({"Yes", "No"}, {
        prompt = "Remove alias '" .. alias .. "'?"
      }, function(choice)
        if choice ~= "Yes" then return end
        
        if M.remove_fragment_alias(alias) then
          vim.notify("Alias removed: " .. alias, vim.log.levels.INFO)
          
          -- Refresh the fragment manager
          vim.api.nvim_win_close(0, true)
          vim.schedule(function()
            M.manage_fragments()
          end)
        else
          vim.notify("Failed to remove alias", vim.log.levels.ERROR)
        end
      end)
      return
    end
    
    -- If there are multiple aliases, let the user select which one to remove
    vim.ui.select(fragment.aliases, {
      prompt = "Select alias to remove:"
    }, function(alias)
      if not alias then return end
      
      if M.remove_fragment_alias(alias) then
        vim.notify("Alias removed: " .. alias, vim.log.levels.INFO)
        
        -- Refresh the fragment manager
        vim.api.nvim_win_close(0, true)
        vim.schedule(function()
          M.manage_fragments()
        end)
      else
        vim.notify("Failed to remove alias", vim.log.levels.ERROR)
      end
    end)
  end
  
  -- Store the fragment manager module
  package.loaded['llm.fragment_manager'] = fragment_manager
end

return M
