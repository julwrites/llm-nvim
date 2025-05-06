-- llm/plugins/plugins_manager.lua - Plugin management for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local api = vim.api
local utils = require('llm.utils')
local plugins_loader = require('llm.plugins.plugins_loader')
local styles = require('llm.styles') -- Added for highlighting

-- Get plugin descriptions
function M.get_plugin_descriptions()
  local plugins_data = plugins_loader.get_plugins_with_descriptions()
  local descriptions = {}

  for name, plugin in pairs(plugins_data) do
    descriptions[name] = plugin.description
  end

  return descriptions
end

-- Get available plugins from the plugin directory
function M.get_available_plugins()
  if not utils.check_llm_installed() then
    return {}
  end

  -- Get plugins from the loader
  return plugins_loader.get_all_plugin_names()
end

-- Get available plugins with their descriptions
function M.get_available_plugins_with_descriptions()
  if not utils.check_llm_installed() then
    return {}
  end

  return plugins_loader.get_plugins_with_descriptions()
end

-- Get installed plugins from llm CLI
function M.get_installed_plugins()
  if not utils.check_llm_installed() then
    return {}
  end

  local result = utils.safe_shell_command("llm plugins", "Failed to get installed plugins")
  if not result then
    return {}
  end

  local plugins = {}

  -- Try to parse JSON output
  local success, parsed = pcall(vim.fn.json_decode, result)
  if success and type(parsed) == "table" then
    for _, plugin in ipairs(parsed) do
      if plugin.name then
        table.insert(plugins, plugin.name)
      end
    end
  else
    -- Fallback to line parsing if JSON parsing fails
    for line in result:gmatch("[^\r\n]+") do
      -- Look for plugin names in the output
      local plugin_name = line:match('"name":%s*"([^"]+)"')
      if plugin_name then
        table.insert(plugins, plugin_name)
      end
    end
  end

  return plugins
end

-- Check if a plugin is installed
function M.is_plugin_installed(plugin_name)
  local installed_plugins = M.get_installed_plugins()
  for _, plugin in ipairs(installed_plugins) do
    if plugin == plugin_name then
      return true
    end
  end
  return false
end

-- Install a plugin using llm CLI
function M.install_plugin(plugin_name)
  if not utils.check_llm_installed() then
    return false
  end

  local result = utils.safe_shell_command(
    string.format('llm install %s', plugin_name),
    "Failed to install plugin: " .. plugin_name
  )

  return result ~= nil
end

-- Uninstall a plugin using llm CLI
function M.uninstall_plugin(plugin_name)
  if not utils.check_llm_installed() then
    return false
  end

  local result = utils.safe_shell_command(
    string.format('llm uninstall %s -y', plugin_name),
    "Failed to uninstall plugin: " .. plugin_name
  )

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
  for _, plugin in ipairs(installed_plugins) do installed_set[plugin] = true end

  local plugin_descriptions = M.get_plugin_descriptions()

  local lines = {
    "# Plugin Management",
    "",
    "Navigate: [M]odels [K]eys [F]ragments [T]emplates [S]chemas",
    "Actions: [i]nstall [x]uninstall [r]efresh [q]uit",
    "──────────────────────────────────────────────────────────────",
    ""
  }
  -- Get plugins by category and format for display
  local plugins_by_category = plugins_loader.get_plugins_by_category()
  local categories = {}
  local all_plugins_data = M.get_available_plugins_with_descriptions()

  for category_name, plugin_names in pairs(plugins_by_category) do
    categories[category_name] = {}
    for _, plugin_name in ipairs(plugin_names) do
      local plugin_info = all_plugins_data[plugin_name] or {}
      table.insert(categories[category_name], {
        name = plugin_name,
        installed = installed_set[plugin_name] or false,
        description = plugin_info.description or ""
      })
    end
  end

  -- Add installed plugins not found in categories
  local other_category = categories["Other"] or {}
  categories["Other"] = other_category
  for plugin_name, _ in pairs(installed_set) do
    local found = false
    for _, cat_plugins in pairs(categories) do
      for _, p in ipairs(cat_plugins) do
        if p.name == plugin_name then
          found = true; break
        end
      end
      if found then break end
    end
    if not found then
      table.insert(other_category, { name = plugin_name, installed = true, description = "Installed (no description)" })
    end
  end

  local plugin_data = {}
  local line_to_plugin = {}
  local current_line = #lines + 1
  -- Add content to buffer
  for category, cat_plugins in pairs(categories) do
    if #cat_plugins > 0 then
      table.insert(lines, category)
      table.insert(lines, string.rep("─", #category))
      current_line = current_line + 2
      table.sort(cat_plugins, function(a, b) return a.name < b.name end)
      for _, plugin in ipairs(cat_plugins) do
        local desc = plugin.description or ""
        if #desc > 50 then desc = desc:sub(1, 47) .. "..." end
        local status = plugin.installed and "✓" or " "
        local line = string.format("[%s] %-20s - %s", status, plugin.name, desc)
        table.insert(lines, line)
        plugin_data[plugin.name] = { line = current_line, installed = plugin.installed }
        line_to_plugin[current_line] = plugin.name
        current_line = current_line + 1
      end
      table.insert(lines, "")
      current_line = current_line + 1
    end
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

  -- Helper to get plugin info
  local function get_plugin_info_under_cursor()
    local current_line = api.nvim_win_get_cursor(0)[1]
    local line_to_plugin = vim.b[bufnr].line_to_plugin
    local plugin_data = vim.b[bufnr].plugin_data
    local plugin_name = line_to_plugin and line_to_plugin[current_line]
    if plugin_name and plugin_data and plugin_data[plugin_name] then
      return plugin_name, plugin_data[plugin_name]
    end
    return nil, nil
  end

  -- Install plugin under cursor
  set_keymap('n', 'i',
    string.format([[<Cmd>lua require('%s').install_plugin_under_cursor(%d)<CR>]],
      manager_module.__name or 'llm.plugins.plugins_manager', bufnr))

  -- Uninstall plugin under cursor
  set_keymap('n', 'x',
    string.format([[<Cmd>lua require('%s').uninstall_plugin_under_cursor(%d)<CR>]],
      manager_module.__name or 'llm.plugins.plugins_manager', bufnr))

  -- Refresh plugin list
  set_keymap('n', 'r',
    string.format([[<Cmd>lua require('%s').refresh_plugin_list(%d)<CR>]],
      manager_module.__name or 'llm.plugins.plugins_manager', bufnr))

  -- Debug key (if needed)
  -- set_keymap('n', 'D', string.format([[<Cmd>lua require('%s').run_debug_functions(%d)<CR>]], manager_module.__name or 'llm.plugins.plugins_manager', bufnr))
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
      require('llm.unified_manager').switch_view("Plugins")
    else
      vim.notify("Failed to install plugin: " .. plugin_name, vim.log.levels.ERROR)
    end
  end)
end

function M.uninstall_plugin_under_cursor(bufnr)
  local plugin_name, plugin_info = M.get_plugin_info_under_cursor(bufnr)
  if not plugin_name then return end
  if not plugin_info.installed then
    vim.notify("Plugin " .. plugin_name .. " is not installed", vim.log.levels.INFO)
    return
  end
  utils.floating_confirm({
    prompt = "Uninstall " .. plugin_name .. "?",
    options = { "Yes", "No" }
  }, function(choice)
    if choice ~= "Yes" then return end
    vim.notify("Uninstalling plugin: " .. plugin_name .. "...", vim.log.levels.INFO)
    vim.schedule(function()
      if M.uninstall_plugin(plugin_name) then
        vim.notify("Plugin uninstalled: " .. plugin_name, vim.log.levels.INFO)
        require('llm.unified_manager').switch_view("Plugins")
      else
        vim.notify("Failed to uninstall plugin: " .. plugin_name, vim.log.levels.ERROR)
      end
    end)
  end)
end

function M.refresh_plugin_list(bufnr)
  vim.notify("Refreshing plugin list from website...", vim.log.levels.INFO)
  local plugins = plugins_loader.refresh_plugins_cache()
  if plugins and vim.tbl_count(plugins) > 0 then
    require('llm.unified_manager').switch_view("Plugins")
  else
    vim.notify("Plugin refresh failed, keeping current view", vim.log.levels.WARN)
  end
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
  require('llm.unified_manager').open_specific_manager("Plugins")
end

-- Add module name for require path in keymaps
M.__name = 'llm.plugins.plugins_manager'

return M
