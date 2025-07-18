-- llm/managers/plugins_manager.lua - Plugin management for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local api = vim.api
local llm_cli = require('llm.core.data.llm_cli')
local cache = require('llm.core.data.cache')
local plugins_view = require('llm.ui.views.plugins_view')
local styles = require('llm.ui.styles')

-- Get available plugins from the plugin directory
function M.get_available_plugins()
    local cached_plugins = cache.get('available_plugins')
    if cached_plugins then
        return cached_plugins
    end

    local plugins_json = llm_cli.run_llm_command('plugins --all --json')
    local plugins = vim.fn.json_decode(plugins_json)
    cache.set('available_plugins', plugins)
    return plugins
end

-- Get installed plugins from llm CLI
function M.get_installed_plugins()
    local cached_plugins = cache.get('installed_plugins')
    if cached_plugins then
        return cached_plugins
    end

    local plugins_json = llm_cli.run_llm_command('plugins --json')
    local plugins = vim.fn.json_decode(plugins_json)
    cache.set('installed_plugins', plugins)
    return plugins
end

-- Check if a plugin is installed
function M.is_plugin_installed(plugin_name)
  local installed_plugins = M.get_installed_plugins()
  for _, plugin in ipairs(installed_plugins) do
    if plugin.name == plugin_name then
      return true
    end
  end
  return false
end

-- Install a plugin using llm CLI
function M.install_plugin(plugin_name)
    local result = llm_cli.run_llm_command('install ' .. plugin_name)
    cache.invalidate('installed_plugins')
    return result ~= nil
end

-- Uninstall a plugin using llm CLI
function M.uninstall_plugin(plugin_name)
    local result = llm_cli.run_llm_command('uninstall ' .. plugin_name .. ' -y')
    cache.invalidate('installed_plugins')
    return result ~= nil
end

-- Populate the buffer with plugin management content
function M.populate_plugins_buffer(bufnr)
  local available_plugins = M.get_available_plugins()
  if not available_plugins or #available_plugins == 0 then
    api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      "# Plugin Management - Error",
      "",
      "No plugins found. Make sure llm is properly configured and plugin cache is up-to-date.",
      "Try running :LLMRefreshPlugins",
      "",
      "Press [q]uit or use navigation keys ([M]odels, [K]eys, etc.)"
    })
    return {}, {} -- Return empty lookup tables
  end

  local installed_plugins = M.get_installed_plugins()
  local installed_set = {}
  for _, plugin in ipairs(installed_plugins) do installed_set[plugin.name] = true end

  local lines = {
    "# Plugin Management",
    "",
    "Navigate: [M]odels [K]eys [F]ragments [T]emplates [S]chemas",
    "Actions: [i]nstall [x]uninstall [r]efresh [q]uit",
    "──────────────────────────────────────────────────────────────",
    ""
  }

  local plugin_data = {}
  local line_to_plugin = {}
  local current_line = #lines + 1
  -- Add content to buffer
  for _, plugin in ipairs(available_plugins) do
    local desc = plugin.description or ""
    if #desc > 50 then desc = desc:sub(1, 47) .. "..." end
    local status = installed_set[plugin.name] and "✓" or " "
    local line = string.format("[%s] %-20s - %s", status, plugin.name, desc)
    table.insert(lines, line)
    plugin_data[plugin.name] = { line = current_line, installed = installed_set[plugin.name] or false }
    line_to_plugin[current_line] = plugin.name
    current_line = current_line + 1
  end
  api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- Apply syntax highlighting
  styles.setup_buffer_syntax(bufnr) -- Use styles module

  -- Store lookup tables in buffer variables
  vim.b[bufnr].line_to_plugin = line_to_plugin
  vim.b[bufnr].plugin_data = plugin_data

  return line_to_plugin, plugin_data -- Return for direct use if needed
end

-- Setup keymaps for the plugin management buffer
function M.setup_plugins_keymaps(bufnr, manager_module)
  manager_module = manager_module or M -- Allow passing self

  local function set_keymap(mode, lhs, rhs)
    api.nvim_buf_set_keymap(bufnr, mode, lhs, rhs, { noremap = true, silent = true })
  end

  -- Install plugin under cursor
  set_keymap('n', 'i',
    string.format([[<Cmd>lua require('%s').install_plugin_under_cursor(%d)<CR>]],
      manager_module.__name or 'llm.managers.plugins_manager', bufnr))

  -- Uninstall plugin under cursor
  set_keymap('n', 'x',
    string.format([[<Cmd>lua require('%s').uninstall_plugin_under_cursor(%d)<CR>]],
      manager_module.__name or 'llm.managers.plugins_manager', bufnr))

  -- Refresh plugin list
  set_keymap('n', 'r',
    string.format([[<Cmd>lua require('%s').refresh_plugin_list(%d)<CR>]],
      manager_module.__name or 'llm.managers.plugins_manager', bufnr))
end

-- Action functions called by keymaps (now accept bufnr)
function M.install_plugin_under_cursor(bufnr)
  local plugin_name, plugin_info = M.get_plugin_info_under_cursor(bufnr)
  if not plugin_name then return end
  if plugin_info.installed then
    vim.notify("Plugin " .. plugin_name .. " is already installed", vim.log.levels.INFO)
    return
  end
  vim.notify("Installing plugin: " .. plugin_name .. "...", vim.log.levels.INFO)
  vim.schedule(function()
    if M.install_plugin(plugin_name) then
      vim.notify("Plugin installed: " .. plugin_name, vim.log.levels.INFO)
      require('llm.ui.unified_manager').switch_view("Plugins")
    else
      vim.notify("Failed to install plugin: " .. plugin_name, vim.log.levels.ERROR)
    end
  end)
end

function M.uninstall_plugin_under_cursor(bufnr)
  local plugin_name, plugin_info = M.get_plugin_info_under_cursor(bufnr)
  if not plugin_name then
    vim.notify("No plugin selected", vim.log.levels.WARN)
    return
  end
  if not plugin_info.installed then
    vim.notify("Plugin " .. plugin_name .. " is not installed", vim.log.levels.INFO)
    return
  end

  plugins_view.confirm_uninstall(plugin_name, function(confirmed)
    if not confirmed then return end
    vim.notify("Uninstalling plugin: " .. plugin_name .. "...", vim.log.levels.INFO)

    -- Run in schedule to avoid blocking UI
    vim.schedule(function()
      local success = M.uninstall_plugin(plugin_name)
      if success then
        vim.notify("Successfully uninstalled: " .. plugin_name, vim.log.levels.INFO)
        require('llm.ui.unified_manager').switch_view("Plugins")
      else
        vim.notify("Failed to uninstall " .. plugin_name, vim.log.levels.ERROR)
      end
    end)
  end)
end

function M.refresh_plugin_list(bufnr)
    cache.invalidate('available_plugins')
    cache.invalidate('installed_plugins')
    require('llm.ui.unified_manager').switch_view("Plugins")
end

-- Helper to get plugin info from buffer variables
function M.get_plugin_info_under_cursor(bufnr)
  local current_line = api.nvim_win_get_cursor(0)[1]
  local line_to_plugin = vim.b[bufnr].line_to_plugin
  local plugin_data = vim.b[bufnr].plugin_data
  if not line_to_plugin or not plugin_data then
    vim.notify("Buffer data missing", vim.log.levels.ERROR)
    return nil, nil
  end
  local plugin_name = line_to_plugin[current_line]
  if plugin_name and plugin_data[plugin_name] then
    return plugin_name, plugin_data[plugin_name]
  end
  return nil, nil
end

-- Main function to open the plugin manager (now delegates to unified manager)
function M.manage_plugins()
  require('llm.ui.unified_manager').open_specific_manager("Plugins")
end

-- Add module name for require path in keymaps
M.__name = 'llm.managers.plugins_manager'

return M
