-- llm/managers/plugins_manager.lua - Plugin management for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local api = vim.api
local utils = require('llm.utils')
local plugins_loader = require('llm.loaders.plugins_loader')

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

-- Manage plugins (view, install, uninstall)
function M.manage_plugins()
  if not utils.check_llm_installed() then
    return
  end

  local available_plugins = M.get_available_plugins()
  if not available_plugins or #available_plugins == 0 then
    vim.notify("No plugins found from loader. Using fallback list.", vim.log.levels.WARN)
    available_plugins = {
      "llm-gguf", "llm-mlx", "llm-ollama", "llm-llamafile", "llm-mlc",
      "llm-gpt4all", "llm-mpt30b", "llm-mistral", "llm-gemini", "llm-anthropic"
    }
  end

  -- Get installed plugins to mark them
  local installed_plugins = M.get_installed_plugins()
  local installed_set = {}
  for _, plugin in ipairs(installed_plugins) do
    installed_set[plugin] = true
  end
  
  -- Get plugin descriptions
  local plugin_descriptions = M.get_plugin_descriptions()

  -- Create a new buffer for the plugin manager
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(buf, 'swapfile', false)
  api.nvim_buf_set_name(buf, 'LLM Plugins')

  -- Create a new window
  local win = utils.create_floating_window(buf, ' LLM Plugins ')

  -- Set buffer content
  local lines = {
    "# LLM Plugins Manager",
    "",
    "This shows all available and installed plugins for LLM.",
    "Plugins are shown with their descriptions",
    "- [✓] means the plugin is installed (green)",
    "- [ ] means the plugin is available to install (red)",
    "",
    "Press 'i' to install plugin under cursor",
    "Press 'x' to uninstall plugin under cursor",
    "Press 'r' to refresh the plugin list",
    "Press 'q' to quit",
    "──────────────────────────────────────────────────────────────",
    ""
  }

  -- Get plugins by category from the loader
  local plugins_by_category = plugins_loader.get_plugins_by_category()
  local categories = {}
  
  -- Get all plugins with descriptions
  local all_plugins = M.get_available_plugins_with_descriptions()
  
  -- Convert to the format expected by the UI
  for category_name, plugin_names in pairs(plugins_by_category) do
    categories[category_name] = {}
    
    for _, plugin_name in ipairs(plugin_names) do
      local status = installed_set[plugin_name] and "✓" or " "
      local plugin_data = all_plugins[plugin_name] or {}
      local entry = {
        name = plugin_name,
        installed = installed_set[plugin_name] or false,
        description = plugin_data.description or ""
      }
      table.insert(categories[category_name], entry)
    end
  end
  
  -- Add any installed plugins that aren't in the documentation
  local other_category = categories["Other"] or {}
  categories["Other"] = other_category
  
  for plugin_name, _ in pairs(installed_set) do
    local found = false
    for _, category_plugins in pairs(categories) do
      for _, entry in ipairs(category_plugins) do
        if entry.name == plugin_name then
          found = true
          break
        end
      end
      if found then break end
    end
    
    if not found then
      table.insert(other_category, {
        name = plugin_name,
        status = "✓",
        installed = true,
        description = "Installed plugin (no description available)"
      })
    end
  end

  -- Plugin data for lookup
  local plugin_data = {}
  local line_to_plugin = {}
  local current_line = #lines + 1

  -- Add categories and plugins to the buffer
  for category, plugins in pairs(categories) do
    if #plugins > 0 then
      table.insert(lines, category)
      table.insert(lines, string.rep("─", #category))
      current_line = current_line + 2

      table.sort(plugins, function(a, b) return a.name < b.name end)

      for _, plugin in ipairs(plugins) do
        local description = plugin.description or plugin_descriptions[plugin.name] or ""
        -- Truncate description if it's too long
        if #description > 50 then
          description = description:sub(1, 47) .. "..."
        end
        
        -- Format: [✓] plugin-name - Description
        local status_indicator = plugin.installed and "✓" or " "
        
        -- Truncate description if it's too long for display
        if #description > 50 then
          description = description:sub(1, 47) .. "..."
        end
        
        local line = string.format("[%s] %-20s - %s", 
                                  status_indicator, 
                                  plugin.name, 
                                  description)
        table.insert(lines, line)

        -- Store plugin data for lookup
        plugin_data[plugin.name] = {
          line = current_line,
          installed = plugin.installed
        }
        line_to_plugin[current_line] = plugin.name
        current_line = current_line + 1
      end

      table.insert(lines, "")
      current_line = current_line + 1
    end
  end

  api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Set buffer options
  api.nvim_buf_set_option(buf, 'modifiable', false)

  -- Set up syntax highlighting
  utils.setup_buffer_highlighting(buf)

  -- Create plugin manager module for the helper functions
  local plugin_manager = {}

  function plugin_manager.install_plugin_under_cursor()
    local current_line = api.nvim_win_get_cursor(0)[1]
    local plugin_name = line_to_plugin[current_line]

    if not plugin_name then return end
    if plugin_data[plugin_name].installed then
      vim.notify("Plugin " .. plugin_name .. " is already installed", vim.log.levels.INFO)
      return
    end

    vim.notify("Installing plugin: " .. plugin_name .. "...", vim.log.levels.INFO)

    -- Run in background to avoid blocking UI
    vim.schedule(function()
      if M.install_plugin(plugin_name) then
        vim.notify("Plugin installed: " .. plugin_name, vim.log.levels.INFO)
        -- Close and reopen the plugin manager to refresh the list
        vim.api.nvim_win_close(0, true)
        vim.schedule(function()
          M.manage_plugins()
        end)
      else
        vim.notify("Failed to install plugin: " .. plugin_name, vim.log.levels.ERROR)
      end
    end)
  end

  function plugin_manager.uninstall_plugin_under_cursor()
    local current_line = api.nvim_win_get_cursor(0)[1]
    local plugin_name = line_to_plugin[current_line]

    if not plugin_name then return end
    if not plugin_data[plugin_name].installed then
      vim.notify("Plugin " .. plugin_name .. " is not installed", vim.log.levels.INFO)
      return
    end

    -- Confirm uninstallation
    vim.ui.select({ "Yes", "No" }, {
      prompt = "Uninstall " .. plugin_name .. "?"
    }, function(choice)
      if choice ~= "Yes" then return end

      vim.notify("Uninstalling plugin: " .. plugin_name .. "...", vim.log.levels.INFO)

      -- Run in background to avoid blocking UI
      vim.schedule(function()
        if M.uninstall_plugin(plugin_name) then
          vim.notify("Plugin uninstalled: " .. plugin_name, vim.log.levels.INFO)
          -- Close and reopen the plugin manager to refresh the list
          vim.api.nvim_win_close(0, true)
          vim.schedule(function()
            M.manage_plugins()
          end)
        else
          vim.notify("Failed to uninstall plugin: " .. plugin_name, vim.log.levels.ERROR)
        end
      end)
    end)
  end

  function plugin_manager.refresh_plugin_list()
    -- Force refresh the plugins cache
    vim.notify("Refreshing plugin list from website...", vim.log.levels.INFO)
    local plugins = plugins_loader.refresh_plugins_cache()
    
    -- Only close and reopen if we got plugins
    if plugins and vim.tbl_count(plugins) > 0 then
      vim.api.nvim_win_close(0, true)
      vim.schedule(function()
        M.manage_plugins()
      end)
    else
      -- Just notify the user that refresh failed
      vim.notify("Plugin refresh failed, keeping current view", vim.log.levels.WARN)
    end
  end

  -- Set keymaps
  local function set_keymap(mode, lhs, rhs)
    api.nvim_buf_set_keymap(buf, mode, lhs, rhs, { noremap = true, silent = true })
  end

  -- Install plugin under cursor
  set_keymap('n', 'i', [[<cmd>lua require('llm.managers.plugins_manager').install_plugin_under_cursor()<CR>]])

  -- Uninstall plugin under cursor
  set_keymap('n', 'x', [[<cmd>lua require('llm.managers.plugins_manager').uninstall_plugin_under_cursor()<CR>]])

  -- Refresh plugin list
  set_keymap('n', 'r', [[<cmd>lua require('llm.managers.plugins_manager').refresh_plugin_list()<CR>]])

  -- Debug functions
  function plugin_manager.run_debug_functions()
    vim.notify("Running plugin loader debug functions...", vim.log.levels.INFO)
    plugins_loader.parse_debug_html()
    plugins_loader.test_pattern_matching()
    vim.notify("Debug complete. Check your config directory for analysis files.", vim.log.levels.INFO)
  end
  
  -- Close window
  set_keymap('n', 'q', [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])
  set_keymap('n', '<Esc>', [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])
  
  -- Debug key
  set_keymap('n', 'D', [[<cmd>lua require('llm.managers.plugins_manager').run_debug_functions()<CR>]])

  -- Store the plugin manager module
  package.loaded['llm.managers.plugins_manager'] = plugin_manager
end

return M
