-- llm/managers/plugins_manager.lua - Plugin management for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local api = vim.api
local llm_cli = require('llm.core.data.llm_cli')
local cache = require('llm.core.data.cache')
local plugins_view = require('llm.ui.views.plugins_view')
local styles = require('llm.ui.styles')

local function parse_plugins_html(html)
  local plugins = {}
  vim.notify("Parsing HTML content of length: " .. #html, vim.log.levels.INFO)
  local sections = html:gmatch('<section id="([%w-]+)">(.-)</section>')

  for id, content in sections do
    local h2 = content:match('<h2>(.-)</h2>')
    if h2 then
      -- vim.notify("Found section: " .. h2, vim.log.levels.INFO) -- Removed per-section log
      local list_items = content:gmatch('<li>(.-)</li>')
      for item in list_items do
        local url, name, description
        local link_match = item:match('<a.->(.-)</a>')
        if link_match then
          name = link_match:match('<strong>(.-)</strong>') or link_match
          url = item:match('href="(.-)"')
          description = item:gsub('<[^>]+>', ''):gsub(name, '', 1):match('^:%s*(.*)') or ''
          table.insert(plugins, { name = name, url = url, description = description })
          -- vim.notify("Parsed plugin: " .. name, vim.log.levels.INFO) -- Removed per-plugin log
        end
      end
    end
  end
  vim.notify("Finished parsing, found " .. #plugins .. " plugins.", vim.log.levels.INFO)
  return plugins
end

-- Get available plugins from the plugin directory
function M.get_available_plugins()
  vim.notify("Getting available plugins...", vim.log.levels.INFO)
  local cached_plugins = cache.get('available_plugins')
  if cached_plugins then
    vim.notify("Returning cached plugins.", vim.log.levels.INFO)
    return cached_plugins
  end

  vim.notify("Fetching plugins from URL...", vim.log.levels.INFO)
  local plugins_html = vim.fn.system('curl -s https://llm.datasette.io/en/stable/plugins/directory.html')
  if not plugins_html or plugins_html == "" then
    vim.notify("Failed to fetch HTML from URL.", vim.log.levels.ERROR)
    return {}
  end
  vim.notify("Fetched HTML content, length: " .. #plugins_html, vim.log.levels.INFO)

  local plugins = parse_plugins_html(plugins_html)
  vim.notify("Parsed " .. #plugins .. " plugins from HTML.", vim.log.levels.INFO)

  cache.set('available_plugins', plugins)
  return plugins
end

-- Get installed plugins from llm CLI
function M.get_installed_plugins()
  vim.notify("Getting installed plugins...", vim.log.levels.INFO)
  local cached_plugins = cache.get('installed_plugins')
  if cached_plugins then
    vim.notify("Returning cached installed plugins.", vim.log.levels.INFO)
    return cached_plugins
  end

  vim.notify("Running 'llm plugins' command...", vim.log.levels.INFO)
  local plugins_output = llm_cli.run_llm_command('plugins')
  if not plugins_output then
    vim.notify("'llm plugins' command returned no output.", vim.log.levels.WARN)
    return {}
  end
  vim.notify("Raw 'llm plugins' output:\n" .. plugins_output, vim.log.levels.INFO)

  local plugins = {}
  local ok, decoded_plugins = pcall(vim.json.decode, plugins_output)
  if not ok then
    vim.notify("Failed to decode JSON from 'llm plugins' command: " .. decoded_plugins, vim.log.levels.ERROR)
    return {}
  end

  if type(decoded_plugins) == 'table' then
    for _, plugin_data in ipairs(decoded_plugins) do
      if plugin_data and plugin_data.name then
        table.insert(plugins, { name = plugin_data.name })
        vim.notify("Parsed installed plugin: '" .. plugin_data.name .. "'", vim.log.levels.INFO)
      end
    end
  end
  vim.notify("Finished parsing installed plugins, found " .. #plugins .. ".", vim.log.levels.INFO)
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
  cache.invalidate('available_plugins')
  return result ~= nil
end

-- Uninstall a plugin using llm CLI
function M.uninstall_plugin(plugin_name)
  local result = llm_cli.run_llm_command('uninstall ' .. plugin_name .. ' -y')
  cache.invalidate('installed_plugins')
  cache.invalidate('available_plugins')
  return result ~= nil
end

-- Populate the buffer with plugin management content
function M.populate_plugins_buffer(bufnr)
  vim.notify("Populating plugins buffer...", vim.log.levels.INFO)
  local available_plugins = M.get_available_plugins()
  vim.notify("Got " .. #available_plugins .. " available plugins.", vim.log.levels.INFO)

  if not available_plugins or #available_plugins == 0 then
    vim.notify("No available plugins found. Displaying error message.", vim.log.levels.WARN)
    api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      "# Plugin Management - Error",
      "",
      "No plugins found. Make sure llm is properly configured and plugin cache is up-to-date.",
      "",
      "Press [q]uit or use navigation keys ([M]odels, [K]eys, etc.)"
    })
    return {}, {} -- Return empty lookup tables
  end

  local installed_plugins = M.get_installed_plugins()
  local installed_set = {}
  vim.notify("--- INSTALLED PLUGINS (" .. #installed_plugins .. ") ---", vim.log.levels.INFO)
  for _, plugin in ipairs(installed_plugins) do
    installed_set[plugin.name] = true
    -- vim.notify("Installed: '" .. plugin.name .. "' (added to set)", vim.log.levels.INFO) -- Removed per-plugin log
  end

  local available_plugin_names = {}
  for _, plugin in ipairs(available_plugins) do
    table.insert(available_plugin_names, plugin.name)
  end
  vim.notify("--- AVAILABLE PLUGINS (" .. #available_plugins .. ") ---\n" .. table.concat(available_plugin_names, ", "),
    vim.log.levels.INFO)

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
    local is_installed = installed_set[plugin.name]
    local status_char = is_installed and "✓" or " "
    local status_text = is_installed and "Installed" or "Not Installed"
    local line = string.format("[%s] %-30s - %s", status_char, plugin.name, status_text)
    table.insert(lines, line)
    plugin_data[plugin.name] = { line = current_line, installed = is_installed or false }
    line_to_plugin[current_line] = plugin.name
    current_line = current_line + 1
  end
  vim.notify("Prepared " .. #lines .. " lines for the buffer.", vim.log.levels.INFO)
  api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- Apply syntax highlighting and line-specific highlights
  styles.setup_highlights()
  styles.setup_buffer_syntax(bufnr) -- Use styles module

  -- Apply line-specific highlights for installed status
  local ns_id = api.nvim_create_namespace('LLMPluginsManagerHighlights')
  api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  for i, plugin in ipairs(available_plugins) do
    local highlight_group = installed_set[plugin.name] and "LLMPluginInstalled" or "LLMPluginNotInstalled"
    local header_lines_count = 6                -- Number of fixed header lines
    local line_idx = header_lines_count + i - 1 -- Calculate the correct 0-based line index
    api.nvim_buf_add_highlight(bufnr, ns_id, highlight_group, line_idx, 0, -1)
  end

  -- Store lookup tables in buffer variables
  vim.b[bufnr].line_to_plugin = line_to_plugin
  vim.b[bufnr].plugin_data = plugin_data

  vim.notify("Finished populating plugins buffer.", vim.log.levels.INFO)
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
function M.refresh_plugin_list(bufnr)
  M.refresh_available_plugins(function()
    require('llm.ui.unified_manager').switch_view("Plugins")
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

function M.refresh_available_plugins(callback)
  vim.notify("Refreshing available plugins...", vim.log.levels.INFO)
  cache.invalidate('available_plugins')
  -- Fetch in the background
  vim.defer_fn(function()
    local plugins = M.get_available_plugins()
    vim.notify("Finished refreshing plugins: " .. #plugins .. " found.", vim.log.levels.INFO)
    if callback then
      callback()
    end
  end, 0)
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
