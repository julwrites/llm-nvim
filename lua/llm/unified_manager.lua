-- llm/managers/unified_manager.lua - Unified management window for llm-nvim
-- License: Apache 2.0

local M = {}

local api = vim.api
local utils = require('llm.utils')
local styles = require('llm.styles')

-- Manager modules
local models_manager = require('llm.managers.models_manager')
local plugins_manager = require('llm.managers.plugins_manager')
local keys_manager = require('llm.managers.keys_manager')
local fragments_manager = require('llm.managers.fragments_manager')
local templates_manager = require('llm.managers.templates_manager')
local schemas_manager = require('llm.managers.schemas_manager')

-- State for the unified window
local state = {
  winid = nil,
  bufnr = nil,
  current_view = nil,
}

-- Available views and their corresponding manager functions
local views = {
  Models = {
    populate = models_manager.populate_models_buffer,
    setup_keymaps = models_manager.setup_models_keymaps,
    title = "Models",
    manager_module = models_manager,
  },
  Plugins = {
    populate = plugins_manager.populate_plugins_buffer,
    setup_keymaps = plugins_manager.setup_plugins_keymaps,
    title = "Plugins",
    manager_module = plugins_manager,
  },
  Keys = {
    populate = keys_manager.populate_keys_buffer,
    setup_keymaps = keys_manager.setup_keys_keymaps,
    title = "API Keys",
    manager_module = keys_manager,
  },
  Fragments = {
    populate = fragments_manager.populate_fragments_buffer,
    setup_keymaps = fragments_manager.setup_fragments_keymaps,
    title = "Fragments",
    manager_module = fragments_manager,
  },
  Templates = {
    populate = templates_manager.populate_templates_buffer,
    setup_keymaps = templates_manager.setup_templates_keymaps,
    title = "Templates",
    manager_module = templates_manager,
  },
  Schemas = {
    populate = schemas_manager.populate_schemas_buffer,
    setup_keymaps = schemas_manager.setup_schemas_keymaps,
    title = "Schemas",
    manager_module = schemas_manager,
  },
}

-- Close the unified window
local function close_window()
  if state.winid and api.nvim_win_is_valid(state.winid) then
    api.nvim_win_close(state.winid, true)
  end
  if state.bufnr and api.nvim_buf_is_valid(state.bufnr) then
    -- Check if buffer is listed before trying to delete
    if vim.fn.bufexists(state.bufnr) == 1 and vim.fn.buflisted(state.bufnr) == 1 then
       pcall(api.nvim_buf_delete, state.bufnr, { force = true })
    elseif vim.fn.bufexists(state.bufnr) == 1 then
       -- If buffer exists but is not listed (e.g., nofile), try deleting directly
       pcall(api.nvim_buf_delete, state.bufnr, { force = true })
    end
  end
  state.winid = nil
  state.bufnr = nil
  state.current_view = nil
end

-- Setup common keymaps for switching views
local function setup_common_keymaps(bufnr)
  local function set_keymap(mode, lhs, rhs)
    api.nvim_buf_set_keymap(bufnr, mode, lhs, rhs, { noremap = true, silent = true })
  end

  set_keymap('n', 'q', '<Cmd>lua require("llm.managers.unified_manager").close()<CR>')
  set_keymap('n', '<Esc>', '<Cmd>lua require("llm.managers.unified_manager").close()<CR>')

  -- Keymaps to switch views
  set_keymap('n', 'M', '<Cmd>lua require("llm.managers.unified_manager").switch_view("Models")<CR>')
  set_keymap('n', 'P', '<Cmd>lua require("llm.managers.unified_manager").switch_view("Plugins")<CR>')
  set_keymap('n', 'K', '<Cmd>lua require("llm.managers.unified_manager").switch_view("Keys")<CR>')
  set_keymap('n', 'F', '<Cmd>lua require("llm.managers.unified_manager").switch_view("Fragments")<CR>')
  set_keymap('n', 'T', '<Cmd>lua require("llm.managers.unified_manager").switch_view("Templates")<CR>')
  set_keymap('n', 'S', '<Cmd>lua require("llm.managers.unified_manager").switch_view("Schemas")<CR>')
end

-- Switch the view within the unified window
function M.switch_view(view_name)
  if not state.winid or not api.nvim_win_is_valid(state.winid) then
    M.open(view_name) -- Open if not already open
    return
  end

  if not views[view_name] then
    vim.notify("Invalid view: " .. view_name, vim.log.levels.ERROR)
    return
  end

  state.current_view = view_name
  local view_config = views[view_name]

  -- Clear the buffer
  api.nvim_buf_set_option(state.bufnr, 'modifiable', true)
  api.nvim_buf_set_lines(state.bufnr, 0, -1, false, {})

  -- Populate buffer with new view content
  local success, err = pcall(view_config.populate, state.bufnr)
  if not success then
     vim.notify("Error populating " .. view_name .. " view: " .. tostring(err), vim.log.levels.ERROR)
     -- Add error message to buffer
     api.nvim_buf_set_lines(state.bufnr, 0, -1, false, {
       "# Error loading " .. view_name .. " Manager",
       "",
       "Details: " .. tostring(err),
       "",
       "Press [q]uit or use navigation keys ([M]odels, [P]lugins, etc.)"
     })
  end

  -- Set buffer options
  api.nvim_buf_set_option(state.bufnr, 'modifiable', false)
  api.nvim_buf_set_name(state.bufnr, 'LLM Unified Manager (' .. view_config.title .. ')')
  api.nvim_win_set_config(state.winid, { title = ' LLM Unified Manager (' .. view_config.title .. ') ' })

  -- Setup syntax highlighting
  styles.setup_buffer_styling(state.bufnr)

  -- Setup keymaps (common + view-specific)
  -- Setting new keymaps below will overwrite any previous ones for the same keys.
  setup_common_keymaps(state.bufnr)
  if view_config.setup_keymaps then
    pcall(view_config.setup_keymaps, state.bufnr, view_config.manager_module) -- Pass manager module if needed
  end
end

-- Open the unified window with a specific view
function M.open(initial_view)
  initial_view = initial_view or "Models" -- Default view

  if not views[initial_view] then
    vim.notify("Invalid initial view: " .. initial_view, vim.log.levels.ERROR)
    return
  end

  -- Check if already open
  if state.winid and api.nvim_win_is_valid(state.winid) then
    -- If open but wrong view, switch view
    if state.current_view ~= initial_view then
      M.switch_view(initial_view)
    end
    -- Bring window to front if already open with correct view
    api.nvim_set_current_win(state.winid)
    return
  end

  -- Create buffer
  state.bufnr = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(state.bufnr, 'buftype', 'nofile')
  api.nvim_buf_set_option(state.bufnr, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(state.bufnr, 'swapfile', false)

  -- Create window using utils function
  state.winid = utils.create_floating_window(state.bufnr, 'LLM Unified Manager')

  -- Switch to the initial view
  M.switch_view(initial_view)
end

-- Toggle the unified window
function M.toggle(initial_view)
  if state.winid and api.nvim_win_is_valid(state.winid) then
    close_window()
  else
    M.open(initial_view)
  end
end

-- Close the unified window (public function)
function M.close()
  close_window()
end

-- Function for individual managers to call when opened directly
function M.open_specific_manager(view_name)
   M.open(view_name)
end


return M
