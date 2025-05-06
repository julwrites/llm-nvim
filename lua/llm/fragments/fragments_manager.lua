-- llm/fragments/fragments_manager.lua - Fragment management functionality for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local api = vim.api
local fn = vim.fn

-- Forward declarations
local utils = require('llm.utils')
local fragments_loader = require('llm.fragments.fragments_loader')
local plugins_manager = require('llm.plugins.plugins_manager')
local styles = require('llm.styles') -- Added

-- Populate the buffer with fragment management content
function M.populate_fragments_buffer(bufnr)
  -- Determine view mode from global state or default to showing all
  local show_all = _G.llm_fragments_show_all or false

  local fragments_with_aliases = fragments_loader.get_fragments()
  local all_fragments = fragments_loader.get_all_fragments()

  -- Create a list of fragments without aliases
  local fragments_without_aliases = {}
  for _, fragment in ipairs(all_fragments) do
    if #fragment.aliases == 0 then
      table.insert(fragments_without_aliases, fragment)
    end
  end

  -- Determine which fragments to show based on the toggle
  local fragments = show_all and all_fragments or fragments_with_aliases
  local show_mode = show_all and "all" or "with_aliases"

  -- Double-check that fragments_with_aliases only contains fragments with aliases
  if not show_all then
    fragments = {}
    for _, fragment in ipairs(fragments_with_aliases) do
      if #fragment.aliases > 0 then
        table.insert(fragments, fragment)
      end
    end
  end

  local lines = {
    "# Fragment Management",
    "",
    "Navigate: [M]odels [P]lugins [K]eys [T]emplates [S]chemas",
    "Actions: [v]iew [a]dd alias [r]emove alias [n]ew file [g]itHub [p]rompt [t]oggle view [q]uit",
    "──────────────────────────────────────────────────────────────",
    ""
  }

  -- Add toggle status and fragment list
  table.insert(lines, show_mode == "all" and "Showing: All fragments" or "Showing: Only fragments with aliases")
  table.insert(lines, "")
  if #fragments == 0 then
    table.insert(lines, "No fragments found.")
    table.insert(lines, "Use 'n' to add a new fragment from a file.")
  end

  local fragment_data = {}
  local line_to_fragment = {}
  local current_line = #lines + 1

  if #fragments == 0 then
    table.insert(lines, "No fragments found.")
    table.insert(lines, "Use 'n' to add a new fragment from a file.")
  else
    for i, fragment in ipairs(fragments) do
      local aliases = #fragment.aliases > 0 and table.concat(fragment.aliases, ", ") or "none"
      local source = fragment.source or "unknown"
      local first_line = fragment.content:match("^[^\r\n]*") or ""
      local content_preview = first_line
      if #content_preview > 50 then
        content_preview = content_preview:sub(1, 47) .. "..."
      elseif #fragment.content > #content_preview then
        content_preview = content_preview .. "..."
      end

      local entry_lines = {
        string.format("Fragment %d: %s", i, fragment.hash),
        string.format("  Source: %s", source),
        string.format("  Aliases: %s", aliases),
        string.format("  Date: %s", fragment.datetime or "unknown"),
        string.format("  Content: %s", content_preview),
        ""
      }
      for _, line in ipairs(entry_lines) do table.insert(lines, line) end

      -- Store data for lookup
      fragment_data[fragment.hash] = {
        index = i,
        aliases = fragment.aliases,
        source = fragment.source,
        content = fragment.content,
        datetime = fragment.datetime,
        start_line = current_line,
      }
      for j = 0, 5 do line_to_fragment[current_line + j] = fragment.hash end
      current_line = current_line + 6
    end
  end

  api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- Apply syntax highlighting
  styles.setup_buffer_syntax(bufnr) -- Use styles module

  -- Store lookup tables in buffer variables
  vim.b[bufnr].line_to_fragment = line_to_fragment
  vim.b[bufnr].fragment_data = fragment_data
  vim.b[bufnr].fragments = fragments     -- Store the displayed list

  return line_to_fragment, fragment_data -- Return for direct use if needed
end

-- Setup keymaps for the fragment management buffer
function M.setup_fragments_keymaps(bufnr, manager_module)
  manager_module = manager_module or M -- Allow passing self

  local function set_keymap(mode, lhs, rhs)
    api.nvim_buf_set_keymap(bufnr, mode, lhs, rhs, { noremap = true, silent = true })
  end

  -- Helper to get fragment info
  local function get_fragment_info_under_cursor()
    local current_line = api.nvim_win_get_cursor(0)[1]
    local line_to_fragment = vim.b[bufnr].line_to_fragment
    local fragment_data = vim.b[bufnr].fragment_data
    local fragment_hash = line_to_fragment and line_to_fragment[current_line]
    if fragment_hash and fragment_data and fragment_data[fragment_hash] then
      return fragment_hash, fragment_data[fragment_hash]
    end
    return nil, nil
  end

  -- View fragment content
  set_keymap('n', 'v',
    string.format([[<Cmd>lua require('%s').view_fragment_under_cursor(%d)<CR>]],
      manager_module.__name or 'llm.fragments.fragments_manager', bufnr))

  -- Set alias for fragment
  set_keymap('n', 'a',
    string.format([[<Cmd>lua require('%s').set_alias_for_fragment_under_cursor(%d)<CR>]],
      manager_module.__name or 'llm.fragments.fragments_manager', bufnr))

  -- Remove alias from fragment
  set_keymap('n', 'r',
    string.format([[<Cmd>lua require('%s').remove_alias_from_fragment_under_cursor(%d)<CR>]],
      manager_module.__name or 'llm.fragments.fragments_manager', bufnr))

  -- Toggle view
  set_keymap('n', 't',
    string.format([[<Cmd>lua require('%s').toggle_fragments_view(%d)<CR>]],
      manager_module.__name or 'llm.fragments.fragments_manager', bufnr))

  -- Add new file fragment
  set_keymap('n', 'n',
    string.format([[<Cmd>lua require('%s').add_file_fragment(%d)<CR>]],
      manager_module.__name or 'llm.fragments.fragments_manager', bufnr))

  -- Add new GitHub repository fragment
  set_keymap('n', 'g',
    string.format([[<Cmd>lua require('%s').add_github_fragment_from_manager(%d)<CR>]],
      manager_module.__name or 'llm.fragments.fragments_manager', bufnr))

  -- Prompt with fragment under cursor
  set_keymap('n', 'p',
    string.format([[<Cmd>lua require('%s').prompt_with_fragment_under_cursor(%d)<CR>]],
      manager_module.__name or 'llm.fragments.fragments_manager', bufnr))

  -- Debug key (if needed)
  -- set_keymap('n', '?', string.format([[<Cmd>lua require('%s').debug_line_mapping(%d)<CR>]], manager_module.__name or 'llm.fragments.fragments_manager', bufnr))
end

-- Action functions called by keymaps (now accept bufnr)
function M.view_fragment_under_cursor(bufnr)
  local fragment_hash, fragment_info = M.get_fragment_info_under_cursor(bufnr)
  if not fragment_hash then return end

  -- Create a new buffer for the fragment content
  local content_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(content_buf, 'buftype', 'nofile')
  api.nvim_buf_set_option(content_buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(content_buf, 'swapfile', false)
  api.nvim_buf_set_name(content_buf, 'Fragment: ' .. fragment_hash:sub(1, 8))

  -- Create a new window (could reuse unified window logic if desired)
  local content_win = utils.create_floating_window(content_buf, 'LLM Fragment Content')

  -- Set content
  local content_lines = {
    "# Fragment: " .. fragment_hash,
    "Source: " .. (fragment_info.source or "unknown"),
    "Aliases: " .. (#fragment_info.aliases > 0 and table.concat(fragment_info.aliases, ", ") or "none"),
    "Date: " .. (fragment_info.datetime or "unknown"),
    "",
    "## Content:",
    "",
  }
  for line in fragment_info.content:gmatch("[^\r\n]+") do table.insert(content_lines, line) end
  api.nvim_buf_set_lines(content_buf, 0, -1, false, content_lines)

  -- Set buffer options
  api.nvim_buf_set_option(content_buf, 'modifiable', false)

  -- Set filetype for syntax highlighting
  local filetype = "text"
  if fragment_info.source then
    local ext = fragment_info.source:match("%.([^%.]+)$")
    if ext then filetype = ext end
    if filetype == "js" then filetype = "javascript" end
    if filetype == "py" then filetype = "python" end
    if filetype == "md" then filetype = "markdown" end
  end
  api.nvim_buf_set_option(content_buf, 'filetype', filetype)

  -- Set keymap to close window
  api.nvim_buf_set_keymap(content_buf, 'n', 'q', [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]],
    { noremap = true, silent = true })
  api.nvim_buf_set_keymap(content_buf, 'n', '<Esc>', [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]],
    { noremap = true, silent = true })
end

function M.set_alias_for_fragment_under_cursor(bufnr)
  local fragment_hash, _ = M.get_fragment_info_under_cursor(bufnr)
  if not fragment_hash then return end

  utils.floating_input({ prompt = "Enter alias for fragment: " }, function(alias)
    if not alias or alias == "" then return end
    if fragments_loader.set_fragment_alias(fragment_hash, alias) then
      vim.notify("Alias set: " .. alias .. " -> " .. fragment_hash:sub(1, 8), vim.log.levels.INFO)
      require('llm.unified_manager').switch_view("Fragments")
      -- Return to normal mode after switching view
      vim.cmd('stopinsert')
      vim.cmd('normal! \27') -- Send ESC to ensure normal mode
    else
      vim.notify("Failed to set alias", vim.log.levels.ERROR)
    end
  end)
end

function M.remove_alias_from_fragment_under_cursor(bufnr)
  local fragment_hash, fragment_info = M.get_fragment_info_under_cursor(bufnr)
  if not fragment_hash then return end
  if #fragment_info.aliases == 0 then
    vim.notify("Fragment has no aliases", vim.log.levels.WARN)
    return
  end

  local alias_to_remove = fragment_info.aliases[1]
  if #fragment_info.aliases > 1 then
    vim.ui.select(fragment_info.aliases, { prompt = "Select alias to remove:" }, function(selected_alias)
      if not selected_alias then return end
      alias_to_remove = selected_alias
      M.confirm_and_remove_alias(alias_to_remove)
    end)
  else
    M.confirm_and_remove_alias(alias_to_remove)
  end
end

function M.confirm_and_remove_alias(alias)
  utils.floating_confirm({
    prompt = "Remove alias '" .. alias .. "'?",
    on_confirm = function(confirmed)
      if not confirmed then return end
      if fragments_loader.remove_fragment_alias(alias) then
        vim.notify("Alias removed: " .. alias, vim.log.levels.INFO)
        require('llm.unified_manager').switch_view("Fragments")
      else
        vim.notify("Failed to remove alias", vim.log.levels.ERROR)
      end
    end
  })
end

function M.toggle_fragments_view(bufnr)
  _G.llm_fragments_show_all = not (_G.llm_fragments_show_all or false)
  require('llm.unified_manager').switch_view("Fragments")
end

function M.add_file_fragment(bufnr)
  -- Use the loader function, providing a callback to refresh the view
  fragments_loader.select_file_as_fragment(function()
    require('llm.unified_manager').switch_view("Fragments")
  end, true) -- Force manual input
end

function M.add_github_fragment_from_manager(bufnr)
  -- Use the loader function, providing a callback to refresh the view
  fragments_loader.add_github_fragment(function()
    require('llm.unified_manager').switch_view("Fragments")
  end)
end

-- Helper to get fragment info from buffer variables
function M.get_fragment_info_under_cursor(bufnr)
  local current_line = api.nvim_win_get_cursor(0)[1]
  local line_to_fragment = vim.b[bufnr].line_to_fragment
  local fragment_data = vim.b[bufnr].fragment_data
  if not line_to_fragment or not fragment_data then
    vim.notify("Buffer data missing", vim.log.levels.ERROR)
    return nil, nil
  end
  local fragment_hash = line_to_fragment[current_line]
  if fragment_hash and fragment_data[fragment_hash] then
    return fragment_hash, fragment_data[fragment_hash]
  end
  return nil, nil
end

-- Main function to open the fragment manager (now delegates to unified manager)
function M.manage_fragments(show_all)
  -- Store the view mode preference globally for refresh/toggle
  _G.llm_fragments_show_all = show_all or false
  require('llm.unified_manager').open_specific_manager("Fragments")
end

-- Prompt with the fragment under cursor
function M.prompt_with_fragment_under_cursor(bufnr)
  local fragment_hash, fragment_info = M.get_fragment_info_under_cursor(bufnr)
  if not fragment_hash then
    vim.notify("No fragment selected", vim.log.levels.WARN)
    return
  end

  -- Determine the fragment identifier to use (prefer alias if available)
  local fragment_identifier = fragment_hash
  if fragment_info.aliases and #fragment_info.aliases > 0 then
    fragment_identifier = fragment_info.aliases[1]
  end

  -- Close the fragment manager window
  vim.api.nvim_win_close(0, true)

  -- Ask for the prompt
  utils.floating_input({
    prompt = "Enter prompt to use with fragment: "
  }, function(input_prompt)
    if not input_prompt or input_prompt == "" then
      vim.notify("Prompt cannot be empty", vim.log.levels.ERROR)
      return
    end

    -- Send the prompt with the fragment - use the main module
    require('llm').prompt(input_prompt, { fragment_identifier })
  end)
end

-- Add module name for require path in keymaps
M.__name = 'llm.fragments.fragments_manager'

return M
