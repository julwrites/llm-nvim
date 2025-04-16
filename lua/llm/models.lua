-- llm/models.lua - Model selection and management
-- License: Apache 2.0

local M = {}

-- Forward declarations
local api = vim.api
local fn = vim.fn
local utils = require('llm.utils')
local config = require('llm.config')

-- Get available models from llm CLI
function M.get_available_models()
  if not utils.check_llm_installed() then
    return {}
  end

  local result = utils.safe_shell_command("llm models", "Failed to get available models")
  if not result then
    return {}
  end

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

-- Extract model name from the full model line
function M.extract_model_name(model_line)
  -- Extract the actual model name (after the provider type)
  local model_name = model_line:match(": ([^%(]+)")
  if model_name then
    -- Trim whitespace
    model_name = model_name:match("^%s*(.-)%s*$")
    return model_name
  end

  -- Try to match format like "Anthropic Messages: anthropic/claude-3-opus-20240229"
  model_name = model_line:match(": ([^%s]+)")
  if model_name then
    return model_name
  end

  -- Fallback to the full line if no patterns match
  -- This ensures we can still find the model in the list
  return model_line
end

-- Set the default model using llm CLI
function M.set_default_model(model_name)
  if not utils.check_llm_installed() then
    return false
  end

  local result = utils.safe_shell_command(
    string.format('llm models default %s', model_name),
    "Failed to set default model"
  )
  
  return result ~= nil
end

-- Get model aliases from llm CLI
function M.get_model_aliases()
  if not utils.check_llm_installed() then
    return {}
  end

  local result = utils.safe_shell_command("llm aliases --json", "Failed to get model aliases")
  if not result then
    return {}
  end

  local aliases = {}

  -- Try to parse JSON output
  local success, parsed = pcall(vim.fn.json_decode, result)
  if success and type(parsed) == "table" then
    aliases = parsed
  else
    -- Fallback to line parsing if JSON parsing fails
    for line in result:gmatch("[^\r\n]+") do
      if not line:match("^%-%-") and not line:match("^Aliases:") then
        local alias, model = line:match("([^%s:]+)%s*:%s*(.+)")
        if alias and model then
          -- Remove any trailing "(embedding)" text
          model = model:gsub("%s*%(embedding%)", "")
          -- Trim whitespace
          model = model:match("^%s*(.-)%s*$")
          aliases[alias] = model
        end
      end
    end
  end

  return aliases
end

-- Set a model alias using llm CLI
function M.set_model_alias(alias, model)
  if not utils.check_llm_installed() then
    return false
  end

  local result = utils.safe_shell_command(
    string.format('llm aliases set %s %s', alias, model),
    "Failed to set model alias"
  )
  
  return result ~= nil
end

-- Remove a model alias using llm CLI
function M.remove_model_alias(alias)
  if not utils.check_llm_installed() then
    return false
  end

  local result = utils.safe_shell_command(
    string.format('llm aliases remove %s', alias),
    "Failed to remove model alias"
  )
  
  return result ~= nil
end

-- Select a model to use
function M.select_model()
  local models = M.get_available_models()
  
  if #models == 0 then
    api.nvim_err_writeln("No models found. Make sure llm is properly configured.")
    return
  end
  
  vim.ui.select(models, {
    prompt = "Select LLM model:",
    format_item = function(item)
      return item
    end
  }, function(choice)
    if not choice then return end
    
    -- Extract model name from the full model line
    local model_name = M.extract_model_name(choice)
    
    -- Set the model in config
    config.options.model = model_name
    
    vim.notify("Model set to: " .. model_name, vim.log.levels.INFO)
  end)
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
  local win = utils.create_floating_window(buf, ' Model Management ')

  -- Get current default model
  local default_model_output = utils.safe_shell_command("llm models default", "Failed to get default model")
  if not default_model_output then
    default_model_output = ""
  end

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
      model_name = M.extract_model_name(model_line),
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
  utils.setup_buffer_highlighting(buf)

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
    if M.set_default_model(model_name) then
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
      require('llm.commands').start_chat(model_name)
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

  -- Store the model manager module
  package.loaded['llm.model_manager'] = model_manager
end

return M
