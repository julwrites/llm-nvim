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
  
  -- Format plugin entries with installation status
  local plugin_entries = {}
  for _, plugin in ipairs(available_plugins) do
    local status = installed_set[plugin] and " [✓]" or " [ ]"
    table.insert(plugin_entries, plugin .. status)
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
      prompt_title = "LLM Plugins",
      finder = finders.new_table({
        results = plugin_entries
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry(prompt_bufnr)
          actions.close(prompt_bufnr)
          
          if selection then
            -- Extract the plugin name (remove status indicator)
            local plugin_name = selection[1]:match("^(.-)%s+%[")
            
            -- Check if it's installed
            local is_installed = installed_set[plugin_name] or false
            
            -- Ask what to do
            if is_installed then
              vim.ui.select({"Keep installed", "Uninstall"}, {
                prompt = "Plugin " .. plugin_name .. " is installed:"
              }, function(choice)
                if choice == "Uninstall" then
                  if M.uninstall_plugin(plugin_name) then
                    vim.notify("Plugin uninstalled: " .. plugin_name, vim.log.levels.INFO)
                  else
                    vim.notify("Failed to uninstall plugin: " .. plugin_name, vim.log.levels.ERROR)
                  end
                end
              end)
            else
              vim.ui.select({"Install", "Skip"}, {
                prompt = "Plugin " .. plugin_name .. " is not installed:"
              }, function(choice)
                if choice == "Install" then
                  if M.install_plugin(plugin_name) then
                    vim.notify("Plugin installed: " .. plugin_name, vim.log.levels.INFO)
                  else
                    vim.notify("Failed to install plugin: " .. plugin_name, vim.log.levels.ERROR)
                  end
                end
              end)
            end
          end
        end)
        return true
      end,
    }):find()
  else
    -- Fallback to vim.ui.select if available (Neovim 0.6+)
    if vim.ui and vim.ui.select then
      vim.ui.select(plugin_entries, {
        prompt = "Select LLM Plugin:",
        format_item = function(item)
          return item
        end,
      }, function(plugin_entry)
        if plugin_entry then
          -- Extract the plugin name (remove status indicator)
          local plugin_name = plugin_entry:match("^(.-)%s+%[")
          
          -- Check if it's installed
          local is_installed = installed_set[plugin_name] or false
          
          -- Ask what to do
          if is_installed then
            vim.ui.select({"Keep installed", "Uninstall"}, {
              prompt = "Plugin " .. plugin_name .. " is installed:"
            }, function(choice)
              if choice == "Uninstall" then
                if M.uninstall_plugin(plugin_name) then
                  vim.notify("Plugin uninstalled: " .. plugin_name, vim.log.levels.INFO)
                else
                  vim.notify("Failed to uninstall plugin: " .. plugin_name, vim.log.levels.ERROR)
                end
              end
            end)
          else
            vim.ui.select({"Install", "Skip"}, {
              prompt = "Plugin " .. plugin_name .. " is not installed:"
            }, function(choice)
              if choice == "Install" then
                if M.install_plugin(plugin_name) then
                  vim.notify("Plugin installed: " .. plugin_name, vim.log.levels.INFO)
                else
                  vim.notify("Failed to install plugin: " .. plugin_name, vim.log.levels.ERROR)
                end
              end
            end)
          end
        end
      end)
    else
      -- Very basic fallback using inputlist
      local options = {"Select a plugin:"}
      for i, plugin_entry in ipairs(plugin_entries) do
        table.insert(options, i .. ": " .. plugin_entry)
      end
      
      local choice = vim.fn.inputlist(options)
      if choice >= 1 and choice <= #plugin_entries then
        local plugin_entry = plugin_entries[choice]
        local plugin_name = plugin_entry:match("^(.-)%s+%[")
        
        -- Check if it's installed
        local is_installed = installed_set[plugin_name] or false
        
        -- Ask what to do
        if is_installed then
          local action = vim.fn.confirm("Plugin " .. plugin_name .. " is installed:", "&Keep\n&Uninstall")
          if action == 2 then -- Uninstall
            if M.uninstall_plugin(plugin_name) then
              vim.notify("Plugin uninstalled: " .. plugin_name, vim.log.levels.INFO)
            else
              vim.notify("Failed to uninstall plugin: " .. plugin_name, vim.log.levels.ERROR)
            end
          end
        else
          local action = vim.fn.confirm("Plugin " .. plugin_name .. " is not installed:", "&Install\n&Skip")
          if action == 1 then -- Install
            if M.install_plugin(plugin_name) then
              vim.notify("Plugin installed: " .. plugin_name, vim.log.levels.INFO)
            else
              vim.notify("Failed to install plugin: " .. plugin_name, vim.log.levels.ERROR)
            end
          end
        end
      end
    end
  end
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

-- Make sure all functions are properly exposed in the module
-- Explicitly define select_model if it doesn't exist
if not M.select_model then
  M.select_model = function()
    -- Default implementation that does nothing
    vim.notify("select_model function called", vim.log.levels.INFO)
  end
end

M.manage_plugins = M.manage_plugins
M.get_available_models = M.get_available_models

return M
