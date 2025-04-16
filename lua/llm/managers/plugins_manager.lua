-- llm/managers/plugins_manager.lua - Plugin management for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local api = vim.api
local utils = require('llm.utils')

-- Get available plugins from the plugin directory
function M.get_available_plugins()
  if not utils.check_llm_installed() then
    return {}
  end

  -- This is a hardcoded list of plugins from the directory
  -- In a real implementation, we might want to fetch this from the web
  local plugins = {
    -- Local models
    "llm-gguf", "llm-mlx", "llm-ollama", "llm-llamafile", "llm-mlc",
    "llm-gpt4all", "llm-mpt30b",
    -- Remote APIs
    "llm-mistral", "llm-gemini", "llm-anthropic", "llm-command-r",
    "llm-reka", "llm-perplexity", "llm-groq", "llm-grok",
    "llm-anyscale-endpoints", "llm-replicate", "llm-fireworks",
    "llm-openrouter", "llm-cohere", "llm-bedrock", "llm-bedrock-anthropic",
    "llm-bedrock-meta", "llm-together", "llm-deepseek", "llm-lambda-labs",
    "llm-venice",
    -- Embedding models
    "llm-sentence-transformers", "llm-clip", "llm-embed-jina", "llm-embed-onnx",
    -- Extra commands
    "llm-cmd", "llm-cmd-comp", "llm-python", "llm-cluster", "llm-jq",
    -- Fragments and template loaders
    "llm-templates-github", "llm-templates-fabric", "llm-fragments-github",
    "llm-hacker-news",
    -- Just for fun
    "llm-markov"
  }

  return plugins
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
  if #available_plugins == 0 then
    api.nvim_err_writeln("No plugins found. Make sure llm is properly configured.")
    return
  end

  -- Get installed plugins to mark them
  local installed_plugins = M.get_installed_plugins()
  local installed_set = {}
  for _, plugin in ipairs(installed_plugins) do
    installed_set[plugin] = true
  end

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
    "# LLM Plugins",
    "",
    "Press 'i' to install, 'x' to uninstall, 'r' to refresh, 'q' to quit",
    "──────────────────────────────────────────────────────────────",
    ""
  }

  -- Group plugins by category
  local categories = {
    ["Local Models"] = {},
    ["Remote APIs"] = {},
    ["Embedding Models"] = {},
    ["Extra Commands"] = {},
    ["Templates & Fragments"] = {},
    ["Other"] = {}
  }

  -- Categorize plugins
  for _, plugin in ipairs(available_plugins) do
    local status = installed_set[plugin] and "✓" or " "
    local entry = {
      name = plugin,
      status = status,
      installed = installed_set[plugin] or false
    }

    if plugin:match("^llm%-gguf") or plugin:match("^llm%-mlx") or plugin:match("^llm%-ollama") or
        plugin:match("^llm%-llamafile") or plugin:match("^llm%-mlc") or plugin:match("^llm%-gpt4all") then
      table.insert(categories["Local Models"], entry)
    elseif plugin:match("^llm%-sentence") or plugin:match("^llm%-clip") or plugin:match("^llm%-embed") then
      table.insert(categories["Embedding Models"], entry)
    elseif plugin:match("^llm%-cmd") or plugin:match("^llm%-python") or plugin:match("^llm%-cluster") or plugin:match("^llm%-jq") then
      table.insert(categories["Extra Commands"], entry)
    elseif plugin:match("^llm%-templates") or plugin:match("^llm%-fragments") or plugin:match("^llm%-hacker") then
      table.insert(categories["Templates & Fragments"], entry)
    elseif plugin:match("^llm%-mistral") or plugin:match("^llm%-gemini") or plugin:match("^llm%-anthropic") or
        plugin:match("^llm%-command%-r") or plugin:match("^llm%-reka") or plugin:match("^llm%-perplexity") or
        plugin:match("^llm%-groq") or plugin:match("^llm%-grok") or plugin:match("^llm%-anyscale") or
        plugin:match("^llm%-replicate") or plugin:match("^llm%-fireworks") or plugin:match("^llm%-openrouter") or
        plugin:match("^llm%-cohere") or plugin:match("^llm%-bedrock") or plugin:match("^llm%-together") or
        plugin:match("^llm%-deepseek") or plugin:match("^llm%-lambda") or plugin:match("^llm%-venice") then
      table.insert(categories["Remote APIs"], entry)
    else
      table.insert(categories["Other"], entry)
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
        local line = string.format("[%s] %s", plugin.status, plugin.name)
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
    vim.api.nvim_win_close(0, true)
    M.manage_plugins()
  end

  -- Set keymaps
  local function set_keymap(mode, lhs, rhs)
    api.nvim_buf_set_keymap(buf, mode, lhs, rhs, { noremap = true, silent = true })
  end

  -- Install plugin under cursor
  set_keymap('n', 'i', [[<cmd>lua require('llm.managers.plugin_manager').install_plugin_under_cursor()<CR>]])

  -- Uninstall plugin under cursor
  set_keymap('n', 'x', [[<cmd>lua require('llm.managers.plugin_manager').uninstall_plugin_under_cursor()<CR>]])

  -- Refresh plugin list
  set_keymap('n', 'r', [[<cmd>lua require('llm.managers.plugin_manager').refresh_plugin_list()<CR>]])

  -- Close window
  set_keymap('n', 'q', [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])
  set_keymap('n', '<Esc>', [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])

  -- Store the plugin manager module
  package.loaded['llm.managers.plugin_manager'] = plugin_manager
end

return M
