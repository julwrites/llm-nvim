-- llm/managers/fragments_manager.lua - Fragment management functionality for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local api = vim.api
local fn = vim.fn
local llm_cli = require('llm.core.data.llm_cli')
local cache = require('llm.core.data.cache')
local fragments_view = require('llm.ui.views.fragments_view')
local styles = require('llm.ui.styles')

-- Get fragments from llm CLI
function M.get_fragments()
    local cached_fragments = cache.get('fragments')
    if cached_fragments then
        return cached_fragments
    end

    local fragments_json = llm_cli.run_llm_command('fragments list --json')
    local fragments = vim.fn.json_decode(fragments_json)
    cache.set('fragments', fragments)
    return fragments
end

-- Populate the buffer with fragment management content
function M.populate_fragments_buffer(bufnr)
  local show_all = _G.llm_fragments_show_all or false
  local fragments = M.get_fragments()
  local show_mode = show_all and "all" or "with_aliases"

  local lines = {
    "# Fragment Management",
    "",
    "Navigate: [M]odels [P]lugins [K]eys [T]emplates [S]chemas",
    "Actions: [v]iew [a]dd alias [r]emove alias [n]ew file [g]itHub [p]rompt [t]oggle view [q]uit",
    "──────────────────────────────────────────────────────────────",
    "",
    "Showing: " .. (show_mode == "all" and "All fragments" or "Only fragments with aliases"),
    ""
  }

  local fragment_data = {}
  local line_to_fragment = {}
  local current_line = #lines + 1

  if #fragments == 0 then
    table.insert(lines, "No fragments found.")
    table.insert(lines, "Use 'n' to add a new fragment from a file.")
  else
    for i, fragment in ipairs(fragments) do
        if not show_all and (#fragment.aliases == 0) then
            goto continue
        end
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
      ::continue::
    end
  end

  api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  styles.setup_buffer_syntax(bufnr)
  vim.b[bufnr].line_to_fragment = line_to_fragment
  vim.b[bufnr].fragment_data = fragment_data
  vim.b[bufnr].fragments = fragments
end

-- Setup keymaps for the fragment management buffer
function M.setup_fragments_keymaps(bufnr, manager_module)
  manager_module = manager_module or M

  local function set_keymap(mode, lhs, rhs)
    api.nvim_buf_set_keymap(bufnr, mode, lhs, rhs, { noremap = true, silent = true })
  end

  set_keymap('n', 'v', string.format([[<Cmd>lua require('%s').view_fragment_under_cursor(%d)<CR>]], manager_module.__name, bufnr))
  set_keymap('n', 'a', string.format([[<Cmd>lua require('%s').set_alias_for_fragment_under_cursor(%d)<CR>]], manager_module.__name, bufnr))
  set_keymap('n', 'r', string.format([[<Cmd>lua require('%s').remove_alias_from_fragment_under_cursor(%d)<CR>]], manager_module.__name, bufnr))
  set_keymap('n', 't', string.format([[<Cmd>lua require('%s').toggle_fragments_view(%d)<CR>]], manager_module.__name, bufnr))
  set_keymap('n', 'n', string.format([[<Cmd>lua require('%s').add_file_fragment(%d)<CR>]], manager_module.__name, bufnr))
  set_keymap('n', 'g', string.format([[<Cmd>lua require('%s').add_github_fragment_from_manager(%d)<CR>]], manager_module.__name, bufnr))
  set_keymap('n', 'p', string.format([[<Cmd>lua require('%s').prompt_with_fragment_under_cursor(%d)<CR>]], manager_module.__name, bufnr))
end

-- Action functions called by keymaps (now accept bufnr)
function M.view_fragment_under_cursor(bufnr)
  local fragment_hash, fragment_info = M.get_fragment_info_under_cursor(bufnr)
  if not fragment_hash then return end
  fragments_view.view_fragment(fragment_hash, fragment_info)
end

function M.set_alias_for_fragment_under_cursor(bufnr)
  local fragment_hash, _ = M.get_fragment_info_under_cursor(bufnr)
  if not fragment_hash then return end

  fragments_view.get_alias(function(alias)
    if not alias or alias == "" then return end
    if llm_cli.run_llm_command('fragments alias set ' .. fragment_hash .. ' ' .. alias) then
      vim.notify("Alias set: " .. alias .. " -> " .. fragment_hash:sub(1, 8), vim.log.levels.INFO)
      cache.invalidate('fragments')
      require('llm.ui.unified_manager').switch_view("Fragments")
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
    fragments_view.select_alias_to_remove(fragment_info.aliases, function(selected_alias)
      if not selected_alias then return end
      M.confirm_and_remove_alias(selected_alias)
    end)
  else
    M.confirm_and_remove_alias(alias_to_remove)
  end
end

function M.confirm_and_remove_alias(alias)
  fragments_view.confirm_remove_alias(alias, function(confirmed)
    if not confirmed then return end
    if llm_cli.run_llm_command('fragments alias remove ' .. alias) then
      vim.notify("Alias removed: " .. alias, vim.log.levels.INFO)
      cache.invalidate('fragments')
      require('llm.ui.unified_manager').switch_view("Fragments")
    else
      vim.notify("Failed to remove alias", vim.log.levels.ERROR)
    end
  end)
end

function M.toggle_fragments_view(bufnr)
  _G.llm_fragments_show_all = not (_G.llm_fragments_show_all or false)
  require('llm.ui.unified_manager').switch_view("Fragments")
end

function M.add_file_fragment(bufnr)
    fragments_view.select_file(function(file_path)
        if not file_path then return end
        llm_cli.run_llm_command('fragments store ' .. file_path)
        cache.invalidate('fragments')
        require('llm.ui.unified_manager').switch_view("Fragments")
    end)
end

function M.add_github_fragment_from_manager(bufnr)
    fragments_view.get_github_url(function(url)
        if not url then return end
        llm_cli.run_llm_command('fragments store ' .. url)
        cache.invalidate('fragments')
        require('llm.ui.unified_manager').switch_view("Fragments")
    end)
end

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

function M.manage_fragments(show_all)
  _G.llm_fragments_show_all = show_all or false
  require('llm.ui.unified_manager').open_specific_manager("Fragments")
end

function M.prompt_with_fragment_under_cursor(bufnr)
  local fragment_hash, fragment_info = M.get_fragment_info_under_cursor(bufnr)
  if not fragment_hash then
    vim.notify("No fragment selected", vim.log.levels.WARN)
    return
  end

  local fragment_identifier = fragment_hash
  if fragment_info.aliases and #fragment_info.aliases > 0 then
    fragment_identifier = fragment_info.aliases[1]
  end

  api.nvim_win_close(0, true)

  fragments_view.get_prompt(function(input_prompt)
    if not input_prompt or input_prompt == "" then
      vim.notify("Prompt cannot be empty", vim.log.levels.ERROR)
      return
    end
    require('llm').prompt(input_prompt, { fragment_identifier })
  end)
end

M.__name = 'llm.managers.fragments_manager'

return M
