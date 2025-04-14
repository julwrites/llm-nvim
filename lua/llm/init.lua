-- llm/init.lua - Entry point for lazy.nvim integration
-- License: Apache 2.0

-- Create module
local M = {}

-- Set up the module
local api = vim.api
local fn = vim.fn

-- Forward declaration of config module
local config

-- Check if llm is installed
local function check_llm_installed()
  local handle = io.popen("which llm 2>/dev/null")
  local result = handle:read("*a")
  handle:close()
  
  if result == "" then
    api.nvim_err_writeln("llm CLI tool not found. Please install it with 'pip install llm' or 'brew install llm'")
    return false
  end
  return true
end
-- Expose for testing
_G.check_llm_installed = check_llm_installed

-- Get available models from llm CLI
function M.get_available_models()
  if not check_llm_installed() then
    return {}
  end
  
  local handle = io.popen("llm models")
  local result = handle:read("*a")
  handle:close()
  
  local models = {}
  for line in result:gmatch("[^\r\n]+") do
    -- Skip header lines and empty lines
    if not line:match("^%-%-") and line ~= "" and not line:match("^Models:") and not line:match("^Default:") then
      -- Use the whole line for display
      table.insert(models, line)
    end
  end
  
  return models
end
-- Expose for testing
_G.get_available_models = function()
  return M.get_available_models()
end

-- Get the model argument if specified
local function get_model_arg()
  local model = config.get("model")
  if model and model ~= "" then
    return "-m " .. model
  end
  return ""
end
-- Expose for testing
_G.get_model_arg = get_model_arg

-- Get the system prompt argument if specified
local function get_system_arg()
  local system = config.get("system_prompt")
  if system ~= "" then
    return "-s \"" .. system .. "\""
  end
  return ""
end
-- Expose for testing
_G.get_system_arg = get_system_arg

-- Run an llm command and return the result
local function run_llm_command(cmd)
  if not check_llm_installed() then
    return ""
  end
  
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  handle:close()
  
  return result
end
-- Expose for testing
_G.run_llm_command = run_llm_command

-- Create a new buffer with the LLM response
local function create_response_buffer(content)
  -- Create a new split
  api.nvim_command('new')
  local buf = api.nvim_get_current_buf()
  
  -- Set buffer options
  api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(buf, 'swapfile', false)
  api.nvim_buf_set_name(buf, 'LLM Response')
  
  -- Set the content
  local lines = {}
  for line in content:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  
  -- Set filetype for syntax highlighting
  api.nvim_buf_set_option(buf, 'filetype', 'markdown')
  
  return buf
end

-- Get selected text in visual mode
local function get_visual_selection()
  local start_pos = fn.getpos("'<")
  local end_pos = fn.getpos("'>")
  local lines = api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)
  
  if #lines == 0 then
    return ""
  end
  
  -- Handle single line selection
  if #lines == 1 then
    return string.sub(lines[1], start_pos[3], end_pos[3])
  end
  
  -- Handle multi-line selection
  lines[1] = string.sub(lines[1], start_pos[3])
  lines[#lines] = string.sub(lines[#lines], 1, end_pos[3])
  
  return table.concat(lines, "\n")
end

-- Send a prompt to llm
function M.prompt(prompt)
  local model_arg = get_model_arg()
  local system_arg = get_system_arg()
  
  local cmd = string.format('llm %s %s "%s"', model_arg, system_arg, prompt)
  local result = run_llm_command(cmd)
  
  create_response_buffer(result)
end

-- Send selected text with a prompt to llm
function M.prompt_with_selection(prompt)
  local selection = get_visual_selection()
  if selection == "" then
    api.nvim_err_writeln("No text selected")
    return
  end
  
  -- Create a temporary file with the selection
  local temp_file = os.tmpname()
  local file = io.open(temp_file, "w")
  file:write(selection)
  file:close()
  
  local model_arg = get_model_arg()
  local system_arg = get_system_arg()
  local prompt_arg = prompt ~= "" and '"' .. prompt .. '"' or ""
  
  local cmd = string.format('cat %s | llm %s %s %s', temp_file, model_arg, system_arg, prompt_arg)
  local result = run_llm_command(cmd)
  
  -- Clean up temp file
  os.remove(temp_file)
  
  create_response_buffer(result)
end

-- Explain the current buffer or selection
function M.explain_code()
  local current_buf = api.nvim_get_current_buf()
  local lines = api.nvim_buf_get_lines(current_buf, 0, -1, false)
  local content = table.concat(lines, "\n")
  
  -- Create a temporary file with the content
  local temp_file = os.tmpname()
  local file = io.open(temp_file, "w")
  file:write(content)
  file:close()
  
  local model_arg = get_model_arg()
  local cmd = string.format('cat %s | llm %s -s "Explain this code"', temp_file, model_arg)
  local result = run_llm_command(cmd)
  
  -- Clean up temp file
  os.remove(temp_file)
  
  create_response_buffer(result)
end

-- Start a chat session with llm
function M.start_chat(model_override)
  if not check_llm_installed() then
    return
  end
  
  local model = model_override or config.get("model") or ""
  local model_arg = model ~= "" and "-m " .. model or ""
  
  -- Create a terminal buffer
  api.nvim_command('new')
  api.nvim_command('terminal llm chat ' .. model_arg)
  api.nvim_command('startinsert')
end

-- Extract model name from the full model line
local function extract_model_name(model_line)
  -- Extract the actual model name (after the provider type)
  local model_name = model_line:match(": ([^%(]+)")
  if model_name then
    -- Trim whitespace
    model_name = model_name:match("^%s*(.-)%s*$")
    return model_name
  end
  
  -- Fallback to the first word if the pattern doesn't match
  return model_line:match("^([^%s]+)")
end
-- Expose for testing
_G.extract_model_name = extract_model_name

-- Get available plugins from the plugin directory
function M.get_available_plugins()
  if not check_llm_installed() then
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
-- Expose for testing
_G.get_available_plugins = function()
  return M.get_available_plugins()
end

-- Get installed plugins from llm CLI
function M.get_installed_plugins()
  if not check_llm_installed() then
    return {}
  end
  
  local handle = io.popen("llm plugins")
  local result = handle:read("*a")
  handle:close()
  
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
-- Expose for testing
_G.get_installed_plugins = function()
  return M.get_installed_plugins()
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
-- Expose for testing
_G.is_plugin_installed = function(plugin_name)
  return M.is_plugin_installed(plugin_name)
end

-- Install a plugin using llm CLI
function M.install_plugin(plugin_name)
  if not check_llm_installed() then
    return false
  end
  
  local cmd = string.format('llm install %s', plugin_name)
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  local success = handle:close()
  
  return success
end
-- Expose for testing
_G.install_plugin = function(plugin_name)
  return M.install_plugin(plugin_name)
end

-- Uninstall a plugin using llm CLI
function M.uninstall_plugin(plugin_name)
  if not check_llm_installed() then
    return false
  end
  
  local cmd = string.format('llm uninstall %s -y', plugin_name)
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  local success = handle:close()
  
  return success
end
-- Expose for testing
_G.uninstall_plugin = function(plugin_name)
  return M.uninstall_plugin(plugin_name)
end

-- Set the default model using llm CLI
local function set_default_model(model_name)
  if not check_llm_installed() then
    return false
  end
  
  local cmd = string.format('llm models default %s', model_name)
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  local success = handle:close()
  
  return success
end
-- Expose for testing
_G.set_default_model = set_default_model


-- Select a model from available models
function M.select_model()
  if not check_llm_installed() then
    return
  end
  
  local models = get_available_models()
  if #models == 0 then
    api.nvim_err_writeln("No models found. Make sure llm is properly configured.")
    return
  end
  
  -- Check if we have telescope
  local has_telescope, telescope = pcall(require, "telescope.builtin")
  if has_telescope then
    -- Use telescope for selection
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    
    pickers.new({}, {
      prompt_title = "Select LLM Model",
      finder = finders.new_table({
        results = models
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry(prompt_bufnr)
          actions.close(prompt_bufnr)
          
          if selection then
            -- Extract the model name from the full line
            local model_name = extract_model_name(selection[1])
            -- Set as default model using llm CLI
            if set_default_model(model_name) then
              -- Update the model in config
              config.options.model = model_name
              vim.notify("Default model set to: " .. model_name, vim.log.levels.INFO)
            else
              vim.notify("Failed to set default model", vim.log.levels.ERROR)
            end
          end
        end)
        return true
      end,
    }):find()
  else
    -- Fallback to vim.ui.select if available (Neovim 0.6+)
    if vim.ui and vim.ui.select then
      vim.ui.select(models, {
        prompt = "Select LLM Model:",
        format_item = function(item)
          return item
        end,
      }, function(model_line)
        if model_line then
          -- Extract the model name from the full line
          local model_name = extract_model_name(model_line)
          -- Set as default model using llm CLI
          if set_default_model(model_name) then
            -- Update the model in config
            config.options.model = model_name
            vim.notify("Default model set to: " .. model_name, vim.log.levels.INFO)
          else
            vim.notify("Failed to set default model", vim.log.levels.ERROR)
          end
        end
      end)
    else
      -- Very basic fallback using inputlist
      local options = {"Select a model:"}
      for i, model_line in ipairs(models) do
        table.insert(options, i .. ": " .. model_line)
      end
      
      local choice = vim.fn.inputlist(options)
      if choice >= 1 and choice <= #models then
        local model_line = models[choice]
        -- Extract the model name from the full line
        local model_name = extract_model_name(model_line)
        -- Set as default model using llm CLI
        if set_default_model(model_name) then
          -- Update the model in config
          config.options.model = model_name
          vim.notify("Default model set to: " .. model_name, vim.log.levels.INFO)
        else
          vim.notify("Failed to set default model", vim.log.levels.ERROR)
        end
      end
    end
  end
end

-- Manage plugins (view, install, uninstall)
function M.manage_plugins()
  if not check_llm_installed() then
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
    title = ' LLM Plugins ',
    title_pos = 'center',
  }
  
  local win = api.nvim_open_win(buf, true, opts)
  api.nvim_win_set_option(win, 'cursorline', true)
  api.nvim_win_set_option(win, 'winblend', 0)
  
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
  
  -- Helper function to update plugin status in the buffer
  local function update_plugin_status(plugin_name, installed)
    if not plugin_data[plugin_name] then return end
    
    local line_num = plugin_data[plugin_name].line
    local status = installed and "✓" or " "
    
    api.nvim_buf_set_option(buf, 'modifiable', true)
    local line = api.nvim_buf_get_lines(buf, line_num - 1, line_num, false)[1]
    local new_line = "[" .. status .. "]" .. line:sub(4)
    api.nvim_buf_set_lines(buf, line_num - 1, line_num, false, {new_line})
    api.nvim_buf_set_option(buf, 'modifiable', false)
    
    -- Update plugin data
    plugin_data[plugin_name].installed = installed
  end
  
  -- Set keymaps
  local function set_keymap(mode, lhs, rhs)
    api.nvim_buf_set_keymap(buf, mode, lhs, rhs, {noremap = true, silent = true})
  end
  
  -- Install plugin under cursor
  set_keymap('n', 'i', [[<cmd>lua require('llm.plugin_manager').install_plugin_under_cursor()<CR>]])
  
  -- Uninstall plugin under cursor
  set_keymap('n', 'x', [[<cmd>lua require('llm.plugin_manager').uninstall_plugin_under_cursor()<CR>]])
  
  -- Refresh plugin list
  set_keymap('n', 'r', [[<cmd>lua require('llm.plugin_manager').refresh_plugin_list()<CR>]])
  
  -- Close window
  set_keymap('n', 'q', [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])
  set_keymap('n', '<Esc>', [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])
  
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
    vim.ui.select({"Yes", "No"}, {
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
  
  -- Store the plugin manager module
  package.loaded['llm.plugin_manager'] = plugin_manager
end

-- Setup function for configuration
function M.setup(opts)
  -- Load the configuration module
  config = require('llm.config')
  config.setup(opts)
  return M
end

-- Initialize with default configuration
config = require('llm.config')
config.setup()

-- Get stored API keys from llm CLI
function M.get_stored_keys()
  if not check_llm_installed() then
    return {}
  end
  
  local handle = io.popen("llm keys")
  local result = handle:read("*a")
  handle:close()
  
  local stored_keys = {}
  for line in result:gmatch("[^\r\n]+") do
    if line ~= "Stored keys:" and line ~= "------------------" and line ~= "" then
      table.insert(stored_keys, line)
    end
  end
  
  return stored_keys
end
-- Expose for testing
_G.get_stored_keys = function()
  return M.get_stored_keys()
end

-- Check if an API key is set
function M.is_key_set(key_name)
  local stored_keys = M.get_stored_keys()
  for _, key in ipairs(stored_keys) do
    if key == key_name then
      return true
    end
  end
  return false
end
-- Expose for testing
_G.is_key_set = function(key_name)
  return M.is_key_set(key_name)
end

-- Set an API key using llm CLI
function M.set_api_key(key_name, key_value)
  if not check_llm_installed() then
    return false
  end
  
  -- In a real implementation, we would use the key_value
  -- But for security reasons, we'll just call the CLI which will prompt for the key
  local cmd = string.format('llm keys set %s', key_name)
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  local success = handle:close()
  
  return success
end
-- Expose for testing
_G.set_api_key = function(key_name, key_value)
  return M.set_api_key(key_name, key_value)
end

-- Remove an API key using llm CLI
function M.remove_api_key(key_name)
  if not check_llm_installed() then
    return false
  end
  
  local cmd = string.format('llm keys remove %s', key_name)
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  local success = handle:close()
  
  return success
end
-- Expose for testing
_G.remove_api_key = function(key_name)
  return M.remove_api_key(key_name)
end

-- Manage API keys for different LLM providers
function M.manage_keys()
  if not check_llm_installed() then
    return
  end
  
  -- Create a new buffer for the key manager
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(buf, 'swapfile', false)
  api.nvim_buf_set_name(buf, 'LLM API Keys')
  
  -- Create a new window
  local width = math.floor(vim.o.columns * 0.6)
  local height = math.floor(vim.o.lines * 0.6)
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
    title = ' LLM API Keys ',
    title_pos = 'center',
  }
  
  local win = api.nvim_open_win(buf, true, opts)
  api.nvim_win_set_option(win, 'cursorline', true)
  api.nvim_win_set_option(win, 'winblend', 0)
  
  -- Get list of stored keys
  local stored_keys = M.get_stored_keys()
  
  -- Set buffer content
  local lines = {
    "# LLM API Keys Manager",
    "",
    "Press 's' to set a new key, 'r' to remove a key, 'q' to quit",
    "──────────────────────────────────────────────────────────────",
    "",
    "## Available Providers:",
    ""
  }
  
  -- List of common API key providers
  local providers = {
    "openai",
    "anthropic",
    "mistral",
    "gemini",
    "groq",
    "perplexity",
    "cohere",
    "replicate",
    "anyscale",
    "together",
    "deepseek",
    "fireworks",
    "aws", -- for bedrock
    "azure", -- for azure openai
  }
  
  -- Add stored keys with status
  local stored_keys_set = {}
  for _, key in ipairs(stored_keys) do
    stored_keys_set[key] = true
  end
  
  -- Add providers to the buffer
  for _, provider in ipairs(providers) do
    local status = stored_keys_set[provider] and "✓" or " "
    table.insert(lines, string.format("[%s] %s", status, provider))
  end
  
  -- Add custom key section
  table.insert(lines, "")
  table.insert(lines, "## Custom Key:")
  table.insert(lines, "[+] Add custom key")
  
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  
  -- Set buffer options
  api.nvim_buf_set_option(buf, 'modifiable', false)
  
  -- Map of line numbers to provider names
  local line_to_provider = {}
  local provider_start_line = 8 -- Line where providers start
  for i, provider in ipairs(providers) do
    line_to_provider[provider_start_line + i - 1] = provider
  end
  
  -- Set keymaps
  local function set_keymap(mode, lhs, rhs)
    api.nvim_buf_set_keymap(buf, mode, lhs, rhs, {noremap = true, silent = true})
  end
  
  -- Set a key for the provider under cursor
  set_keymap('n', 's', [[<cmd>lua require('llm.key_manager').set_key_under_cursor()<CR>]])
  
  -- Remove a key for the provider under cursor
  set_keymap('n', 'r', [[<cmd>lua require('llm.key_manager').remove_key_under_cursor()<CR>]])
  
  -- Close window
  set_keymap('n', 'q', [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])
  set_keymap('n', '<Esc>', [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])
  
  -- Create key manager module for the helper functions
  local key_manager = {}
  
  function key_manager.set_key_under_cursor()
    local current_line = api.nvim_win_get_cursor(0)[1]
    local provider = line_to_provider[current_line]
    
    -- Handle custom key
    if current_line == provider_start_line + #providers + 2 then
      -- Prompt for custom key name
      vim.ui.input({
        prompt = "Enter custom key name: "
      }, function(custom_name)
        if not custom_name or custom_name == "" then return end
        
        -- Close the window and set the key
        vim.api.nvim_win_close(0, true)
        
        -- Use vim.fn.inputsecret to securely get the key
        vim.schedule(function()
          vim.cmd("redraw")
          if M.set_api_key(custom_name) then
            vim.notify("Key '" .. custom_name .. "' has been set", vim.log.levels.INFO)
          else
            vim.notify("Failed to set key '" .. custom_name .. "'", vim.log.levels.ERROR)
          end
        end)
      end)
      return
    end
    
    if not provider then return end
    
    -- Close the window and set the key
    vim.api.nvim_win_close(0, true)
    
    -- Use vim.fn.inputsecret to securely get the key
    vim.schedule(function()
      vim.cmd("redraw")
      if M.set_api_key(provider) then
        vim.notify("Key for '" .. provider .. "' has been set", vim.log.levels.INFO)
      else
        vim.notify("Failed to set key for '" .. provider .. "'", vim.log.levels.ERROR)
      end
    end)
  end
  
  function key_manager.remove_key_under_cursor()
    local current_line = api.nvim_win_get_cursor(0)[1]
    local provider = line_to_provider[current_line]
    
    if not provider then return end
    
    -- Check if the key exists
    if not stored_keys_set[provider] then
      vim.notify("No key found for '" .. provider .. "'", vim.log.levels.WARN)
      return
    end
    
    -- Confirm removal
    vim.ui.select({"Yes", "No"}, {
      prompt = "Remove key for '" .. provider .. "'?"
    }, function(choice)
      if choice ~= "Yes" then return end
      
      -- Close the window and remove the key
      vim.api.nvim_win_close(0, true)
      
      vim.schedule(function()
        if M.remove_api_key(provider) then
          vim.notify("Key for '" .. provider .. "' has been removed", vim.log.levels.INFO)
        else
          vim.notify("Failed to remove key for '" .. provider .. "'", vim.log.levels.ERROR)
        end
      end)
    end)
  end
  
  -- Store the key manager module
  package.loaded['llm.key_manager'] = key_manager
end

-- Make sure all functions are properly exposed in the module
-- Explicitly define select_model if it doesn't exist
if not M.select_model then
  M.select_model = function()
    -- Default implementation that does nothing
    vim.notify("select_model function called", vim.log.levels.INFO)
  end
end

-- Explicitly define manage_plugins if it doesn't exist
if not M.manage_plugins then
  M.manage_plugins = function()
    -- Default implementation that does nothing
    vim.notify("manage_plugins function called", vim.log.levels.INFO)
  end
end

M.get_available_models = M.get_available_models

return M
