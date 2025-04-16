-- llm/init.lua - Entry point for lazy.nvim integration
-- License: Apache 2.0

-- Create module
local M = {}

-- Forward declarations
local api = vim.api
local fn = vim.fn

-- Load utility modules
local utils = require('llm.utils')
local commands = require('llm.commands')
local models = require('llm.models')

-- Forward declaration of other modules
local config
local fragments
local templates
local schemas

-- Send a prompt to llm
function M.prompt(prompt, fragment_paths)
  commands.prompt(prompt, fragment_paths)
end

-- Send selected text with a prompt to llm
function M.prompt_with_selection(prompt, fragment_paths)
  commands.prompt_with_selection(prompt, fragment_paths)
end

-- Explain the current buffer or selection
function M.explain_code(fragment_paths)
  commands.explain_code(fragment_paths)
end

-- Start a chat session with llm
function M.start_chat(model_override)
  commands.start_chat(model_override)
end

-- Prompt with fragments
function M.prompt_with_fragments(prompt)
  -- This function will be implemented in the fragments module
  require('llm.fragments').prompt_with_fragments(prompt)
end

-- Prompt with selection and fragments
function M.prompt_with_selection_and_fragments(prompt)
  -- This function will be implemented in the fragments module
  require('llm.fragments').prompt_with_selection_and_fragments(prompt)
end

-- Get available models from llm CLI
function M.get_available_models()
  return models.get_available_models()
end

-- Extract model name from the full model line
function M.extract_model_name(model_line)
  return models.extract_model_name(model_line)
end

-- Select a model to use
function M.select_model()
  models.select_model()
end

-- Create a new module for plugin management
lua_plugins = require('llm.plugins')

-- Get available plugins from the plugin directory
function M.get_available_plugins()
  return lua_plugins.get_available_plugins()
end

-- Get installed plugins from llm CLI
function M.get_installed_plugins()
  return lua_plugins.get_installed_plugins()
end

-- Check if a plugin is installed
function M.is_plugin_installed(plugin_name)
  return lua_plugins.is_plugin_installed(plugin_name)
end

-- Install a plugin using llm CLI
function M.install_plugin(plugin_name)
  return lua_plugins.install_plugin(plugin_name)
end

-- Uninstall a plugin using llm CLI
function M.uninstall_plugin(plugin_name)
  return lua_plugins.uninstall_plugin(plugin_name)
end

-- Get model aliases from llm CLI
function M.get_model_aliases()
  return models.get_model_aliases()
end

-- Set a model alias using llm CLI
function M.set_model_alias(alias, model)
  return models.set_model_alias(alias, model)
end

-- Remove a model alias using llm CLI
function M.remove_model_alias(alias)
  return models.remove_model_alias(alias)
end

-- Manage models and aliases
function M.manage_models()
  if not utils.check_llm_installed() then
    return
  end

  local models = M.get_available_models()
  if #models == 0 then
    api.nvim_err_writeln("No models found. Make sure llm is properly configured.")
    return
  end

  -- Get model aliases
  local aliases = M.get_model_aliases()

  -- Create a new buffer for the model manager
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(buf, 'swapfile', false)
  api.nvim_buf_set_name(buf, 'LLM Models')

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
    title = ' Model Management ',
    title_pos = 'center',
  }

  local win = api.nvim_open_win(buf, true, opts)
  api.nvim_win_set_option(win, 'cursorline', true)
  api.nvim_win_set_option(win, 'winblend', 0)

  -- Get current default model
  local handle = io.popen("llm models default")
  local default_model_output = handle:read("*a")
  handle:close()

  local default_model = default_model_output:match("Default model: ([^\r\n]+)")
  if not default_model then
    -- Try alternative format (some versions just output the model name)
    default_model = default_model_output:match("([^\r\n]+)")
  end
  if not default_model or default_model == "" then
    default_model = ""
  end

  vim.notify("Default model: " .. (default_model or "none"), vim.log.levels.DEBUG)

  -- Set buffer content
  local lines = {
    "# Model Management",
    "",
    "Actions: [s]et as default, [a]dd alias, [r]emove alias, [c]hat with model, [q]uit",
    "──────────────────────────────────────────────────────────────",
    ""
  }

  -- Create a reverse lookup of aliases to models
  local model_to_aliases = {}
  for alias, model in pairs(aliases) do
    if not model_to_aliases[model] then
      model_to_aliases[model] = {}
    end
    table.insert(model_to_aliases[model], alias)
  end

  -- Group models by provider
  local providers = {
    ["OpenAI"] = {},
    ["Anthropic"] = {},
    ["Mistral"] = {},
    ["Gemini"] = {},
    ["Groq"] = {},
    ["Local Models"] = {},
    ["Other"] = {}
  }

  -- Categorize models
  for _, model_line in ipairs(models) do
    local entry = {
      full_line = model_line,
      model_name = extract_model_name(model_line),
      is_default = false,
      aliases = {}
    }

    -- Check if this is the default model
    if entry.model_name == default_model then
      entry.is_default = true
      vim.notify("Found default model: " .. entry.model_name, vim.log.levels.DEBUG)
    end

    -- Add aliases for this model
    if model_to_aliases[entry.model_name] then
      entry.aliases = model_to_aliases[entry.model_name]
    end

    if model_line:match("OpenAI") then
      table.insert(providers["OpenAI"], entry)
    elseif model_line:match("Anthropic") then
      table.insert(providers["Anthropic"], entry)
    elseif model_line:match("Mistral") then
      table.insert(providers["Mistral"], entry)
    elseif model_line:match("Gemini") then
      table.insert(providers["Gemini"], entry)
    elseif model_line:match("Groq") then
      table.insert(providers["Groq"], entry)
    elseif model_line:match("gguf") or model_line:match("ollama") or model_line:match("local") then
      table.insert(providers["Local Models"], entry)
    else
      table.insert(providers["Other"], entry)
    end
  end

  -- Model data for lookup
  local model_data = {}
  local line_to_model = {}
  local current_line = #lines + 1

  -- Check if we found the default model in any category
  local default_found = false
  for _, provider_models in pairs(providers) do
    for _, model in ipairs(provider_models) do
      if model.is_default then
        default_found = true
        break
      end
    end
    if default_found then break end
  end

  -- If default model wasn't found but we have a default model name,
  -- try a more flexible matching approach
  if not default_found and default_model ~= "" then
    for _, provider_models in pairs(providers) do
      for _, model in ipairs(provider_models) do
        -- Try to match by substring
        if model.model_name:find(default_model, 1, true) or
            default_model:find(model.model_name, 1, true) then
          model.is_default = true
          vim.notify("Matched default model by substring: " .. model.model_name, vim.log.levels.DEBUG)
          default_found = true
          break
        end
      end
      if default_found then break end
    end
  end

  -- Add categories and models to the buffer
  for provider, provider_models in pairs(providers) do
    if #provider_models > 0 then
      table.insert(lines, provider)
      table.insert(lines, string.rep("─", #provider))
      current_line = current_line + 2

      table.sort(provider_models, function(a, b) return a.full_line < b.full_line end)

      for _, model in ipairs(provider_models) do
        local status = model.is_default and "✓" or " "
        local alias_text = ""
        if #model.aliases > 0 then
          alias_text = " (aliases: " .. table.concat(model.aliases, ", ") .. ")"
        end
        local line = string.format("[%s] %s%s", status, model.full_line, alias_text)
        table.insert(lines, line)

        -- Store model data for lookup
        model_data[model.model_name] = {
          line = current_line,
          is_default = model.is_default,
          full_line = model.full_line,
          aliases = model.aliases
        }
        line_to_model[current_line] = model.model_name
        current_line = current_line + 1
      end

      table.insert(lines, "")
      current_line = current_line + 1
    end
  end

  -- Add option to add a custom alias
  table.insert(lines, "")
  table.insert(lines, "[+] Add custom alias")

  api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Set buffer options
  api.nvim_buf_set_option(buf, 'modifiable', false)

  -- Set up syntax highlighting
  M.setup_buffer_highlighting(buf)

  -- Add model-specific highlighting
  vim.cmd([[
    highlight default LLMModelOpenAI guifg=#56b6c2
    highlight default LLMModelAnthropic guifg=#98c379
    highlight default LLMModelMistral guifg=#c678dd
    highlight default LLMModelGemini guifg=#e5c07b
    highlight default LLMModelGroq guifg=#61afef
    highlight default LLMModelLocal guifg=#d19a66
    highlight default LLMModelDefault guifg=#e06c75 gui=bold
    highlight default LLMModelAlias guifg=#c678dd
    highlight default LLMModelAliasAction guifg=#98c379 gui=bold
  ]])

  -- Apply provider-specific highlighting
  local syntax_cmds = {
    "syntax match LLMModelOpenAI /^OpenAI.*$/",
    "syntax match LLMModelOpenAI /\\[ \\] OpenAI.*/",
    "syntax match LLMModelAnthropic /^Anthropic.*$/",
    "syntax match LLMModelAnthropic /\\[ \\] Anthropic.*/",
    "syntax match LLMModelMistral /^Mistral.*$/",
    "syntax match LLMModelMistral /\\[ \\] Mistral.*/",
    "syntax match LLMModelGemini /^Gemini.*$/",
    "syntax match LLMModelGemini /\\[ \\] Gemini.*/",
    "syntax match LLMModelGroq /^Groq.*$/",
    "syntax match LLMModelGroq /\\[ \\] Groq.*/",
    "syntax match LLMModelLocal /^Local Models.*$/",
    "syntax match LLMModelLocal /\\[ \\] .*gguf.*/",
    "syntax match LLMModelLocal /\\[ \\] .*ollama.*/",
    "syntax match LLMModelDefault /\\[✓\\].*/",
    "syntax match LLMModelAliasAction /^\\[+\\] Add custom alias$/",
  }

  for _, cmd in ipairs(syntax_cmds) do
    vim.api.nvim_buf_call(buf, function()
      vim.cmd(cmd)
    end)
  end

  -- Helper function to update model status in the buffer
  local function update_model_status(model_name, is_default)
    -- Reset all models to not default
    for name, data in pairs(model_data) do
      if data.is_default and name ~= model_name then
        local line_num = data.line

        api.nvim_buf_set_option(buf, 'modifiable', true)
        local line = api.nvim_buf_get_lines(buf, line_num - 1, line_num, false)[1]
        local new_line = "[ ]" .. line:sub(4)
        api.nvim_buf_set_lines(buf, line_num - 1, line_num, false, { new_line })
        api.nvim_buf_set_option(buf, 'modifiable', false)

        -- Update model data
        model_data[name].is_default = false
      end
    end

    -- Set the new default
    if model_data[model_name] then
      local line_num = model_data[model_name].line

      api.nvim_buf_set_option(buf, 'modifiable', true)
      local line = api.nvim_buf_get_lines(buf, line_num - 1, line_num, false)[1]
      local new_line = "[✓]" .. line:sub(4)
      api.nvim_buf_set_lines(buf, line_num - 1, line_num, false, { new_line })
      api.nvim_buf_set_option(buf, 'modifiable', false)

      -- Update model data
      model_data[model_name].is_default = true
    end
  end

  -- Set keymaps
  local function set_keymap(mode, lhs, rhs)
    api.nvim_buf_set_keymap(buf, mode, lhs, rhs, { noremap = true, silent = true })
  end

  -- Set model under cursor as default
  set_keymap('n', 's', [[<cmd>lua require('llm.model_manager').set_model_under_cursor()<CR>]])

  -- Set alias for model under cursor
  set_keymap('n', 'a', [[<cmd>lua require('llm.model_manager').set_alias_for_model_under_cursor()<CR>]])

  -- Remove alias for model under cursor
  set_keymap('n', 'r', [[<cmd>lua require('llm.model_manager').remove_alias_for_model_under_cursor()<CR>]])

  -- Chat with model under cursor
  set_keymap('n', 'c', [[<cmd>lua require('llm.model_manager').chat_with_model_under_cursor()<CR>]])

  -- Add custom alias (when on the [+] line)
  set_keymap('n', '<CR>', [[<cmd>lua require('llm.model_manager').handle_action_under_cursor()<CR>]])

  -- Close window
  set_keymap('n', 'q', [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])
  set_keymap('n', '<Esc>', [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])

  -- Create model manager module for the helper functions
  local model_manager = {}

  function model_manager.set_model_under_cursor()
    local current_line = api.nvim_win_get_cursor(0)[1]
    local model_name = line_to_model[current_line]

    if not model_name then return end
    if model_data[model_name].is_default then
      vim.notify("Model " .. model_name .. " is already the default", vim.log.levels.INFO)
      return
    end

    vim.notify("Setting default model to: " .. model_name, vim.log.levels.INFO)

    -- Set as default model using llm CLI
    if models.set_default_model(model_name) then
      -- Update the model in config
      config.options.model = model_name
      vim.notify("Default model set to: " .. model_name, vim.log.levels.INFO)

      -- Close and reopen the model manager to refresh
      vim.api.nvim_win_close(0, true)
      vim.schedule(function()
        M.manage_models()
      end)
    else
      vim.notify("Failed to set default model", vim.log.levels.ERROR)
    end
  end

  function model_manager.set_alias_for_model_under_cursor()
    local current_line = api.nvim_win_get_cursor(0)[1]
    local model_name = line_to_model[current_line]

    if not model_name then return end

    -- Prompt for alias
    vim.ui.input({
      prompt = "Enter alias for model " .. model_name .. ": "
    }, function(alias)
      if not alias or alias == "" then return end

      -- Set alias
      if M.set_model_alias(alias, model_name) then
        vim.notify("Alias set: " .. alias .. " -> " .. model_name, vim.log.levels.INFO)

        -- Close and reopen the model manager to refresh
        vim.api.nvim_win_close(0, true)
        vim.schedule(function()
          M.manage_models()
        end)
      else
        vim.notify("Failed to set alias", vim.log.levels.ERROR)
      end
    end)
  end

  function model_manager.chat_with_model_under_cursor()
    local current_line = api.nvim_win_get_cursor(0)[1]
    local model_name = line_to_model[current_line]

    if not model_name then return end

    -- Close the window and start chat with the selected model
    vim.api.nvim_win_close(0, true)

    vim.schedule(function()
      M.start_chat(model_name)
    end)
  end

  function model_manager.handle_action_under_cursor()
    local current_line = api.nvim_win_get_cursor(0)[1]
    local line_content = api.nvim_buf_get_lines(buf, current_line - 1, current_line, false)[1]

    if line_content == "[+] Add custom alias" then
      -- Add new alias
      vim.ui.input({
        prompt = "Enter alias name: "
      }, function(alias)
        if not alias or alias == "" then return end

        -- Prompt for model
        vim.ui.input({
          prompt = "Enter model name: "
        }, function(model)
          if not model or model == "" then return end

          -- Set alias
          if M.set_model_alias(alias, model) then
            vim.notify("Alias set: " .. alias .. " -> " .. model, vim.log.levels.INFO)

            -- Close and reopen the model manager to refresh
            vim.api.nvim_win_close(0, true)
            vim.schedule(function()
              M.manage_models()
            end)
          else
            vim.notify("Failed to set alias", vim.log.levels.ERROR)
          end
        end)
      end)
    end
  end

  function model_manager.remove_alias_for_model_under_cursor()
    local current_line = api.nvim_win_get_cursor(0)[1]
    local model_name = line_to_model[current_line]

    if not model_name then return end

    local model = model_data[model_name]
    if not model or #model.aliases == 0 then
      vim.notify("No aliases found for this model", vim.log.levels.WARN)
      return
    end

    -- Let user select which alias to remove
    vim.ui.select(model.aliases, {
      prompt = "Select alias to remove:"
    }, function(alias)
      if not alias then return end

      -- Remove alias
      if M.remove_model_alias(alias) then
        vim.notify("Alias removed: " .. alias, vim.log.levels.INFO)

        -- Close and reopen the model manager to refresh
        vim.api.nvim_win_close(0, true)
        vim.schedule(function()
          M.manage_models()
        end)
      else
        vim.notify("Failed to remove alias", vim.log.levels.ERROR)
      end
    end)
  end

  -- Store the model manager module
  package.loaded['llm.model_manager'] = model_manager
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

  -- Set up syntax highlighting
  M.setup_buffer_highlighting(buf)

  -- Helper function to update plugin status in the buffer
  local function update_plugin_status(plugin_name, installed)
    if not plugin_data[plugin_name] then return end

    local line_num = plugin_data[plugin_name].line
    local status = installed and "✓" or " "

    api.nvim_buf_set_option(buf, 'modifiable', true)
    local line = api.nvim_buf_get_lines(buf, line_num - 1, line_num, false)[1]
    local new_line = "[" .. status .. "]" .. line:sub(4)
    api.nvim_buf_set_lines(buf, line_num - 1, line_num, false, { new_line })
    api.nvim_buf_set_option(buf, 'modifiable', false)

    -- Update plugin data
    plugin_data[plugin_name].installed = installed
  end

  -- Set keymaps
  local function set_keymap(mode, lhs, rhs)
    api.nvim_buf_set_keymap(buf, mode, lhs, rhs, { noremap = true, silent = true })
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

  -- Store the plugin manager module
  package.loaded['llm.plugin_manager'] = plugin_manager
end

-- Setup function for configuration
function M.setup(opts)
  -- Load the configuration module
  config = require('llm.config')
  config.setup(opts)

  -- Load the fragments module
  fragments = require('llm.fragments')

  -- Load the templates module
  templates = require('llm.templates')

  return M
end

-- Initialize with default configuration
config = require('llm.config')
config.setup()

-- Load the fragments module
fragments = require('llm.fragments')

-- Load the templates module
templates = require('llm.templates')

-- Load the schemas module
schemas = require('llm.schemas')

-- Get stored API keys from llm CLI
function M.get_stored_keys()
  if not utils.check_llm_installed() then
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
  if not utils.check_llm_installed() then
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
  if not utils.check_llm_installed() then
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

-- Manage fragments
function M.manage_fragments()
  fragments.manage_fragments()
end

-- Select a file to use as a fragment
function M.select_fragment()
  fragments.select_file_as_fragment()
end

-- Manage templates
function M.manage_templates()
  templates.manage_templates()
end

-- Select and run a template
function M.select_template()
  templates.select_template()
end

-- Manage schemas
function M.manage_schemas()
  schemas.manage_schemas()
end

-- Select and run a schema
function M.select_schema()
  schemas.select_schema()
end

-- Setup function for configuration
function M.setup(opts)
  -- Load the configuration module
  config = require('llm.config')
  config.setup(opts)

  -- Load the fragments module
  fragments = require('llm.fragments')

  -- Load the templates module
  templates = require('llm.templates')

  -- Load the schemas module
  schemas = require('llm.schemas')

  return M
end

-- Initialize with default configuration
config = require('llm.config')
config.setup()

-- Load the fragments module
fragments = require('llm.fragments')

-- Load the templates module
templates = require('llm.templates')

-- Load the schemas module
schemas = require('llm.schemas')

-- Set up syntax highlighting for plugin/key manager buffers
function M.setup_buffer_highlighting(buf)
  utils.setup_buffer_highlighting(buf)
end

return M
