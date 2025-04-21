-- llm/commands.lua - Command execution for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local api = vim.api
local utils = require('llm.utils')
local config = require('llm.config')

-- Get the model argument if specified
function M.get_model_arg()
  local model = config.get("model")
  if model and model ~= "" then
    return "-m " .. model
  end
  return ""
end

-- Get the system prompt argument if specified
function M.get_system_arg()
  local system = config.get("system_prompt")
  if system and system ~= "" then
    return "-s \"" .. system .. "\""
  end
  return ""
end

-- Get fragment arguments if specified
function M.get_fragment_args(fragment_list)
  if not fragment_list or #fragment_list == 0 then
    return ""
  end

  local args = {}
  for _, fragment in ipairs(fragment_list) do
    table.insert(args, "-f \"" .. fragment .. "\"")
    
    -- Debug output
    local config = require('llm.config')
    if config.get('debug') then
      vim.notify("Adding fragment: " .. fragment, vim.log.levels.DEBUG)
    end
  end

  return table.concat(args, " ")
end

-- Get system fragment arguments if specified
function M.get_system_fragment_args(fragment_list)
  if not fragment_list or #fragment_list == 0 then
    return ""
  end

  local args = {}
  for _, fragment in ipairs(fragment_list) do
    table.insert(args, "--system-fragment \"" .. fragment .. "\"")
  end

  return table.concat(args, " ")
end

-- Run an llm command and return the result
function M.run_llm_command(cmd)
  if not utils.check_llm_installed() then
    return ""
  end

  return utils.safe_shell_command(cmd, "Failed to execute LLM command")
end

-- Create a new buffer with the LLM response
function M.create_response_buffer(content)
  local buf = utils.create_buffer_with_content(content, "LLM Response", "markdown")

  -- Add custom highlighting for the response buffer
  vim.cmd([[
    highlight default LLMCodeBlock guibg=#2c323c
    highlight default LLMHeading guifg=#61afef gui=bold
    highlight default LLMSubHeading guifg=#56b6c2 gui=bold
    highlight default LLMBold guifg=#e5c07b gui=bold
    highlight default LLMItalic guifg=#c678dd gui=italic
    highlight default LLMListItem guifg=#98c379

    " Define syntax regions and matches
    syntax region LLMCodeBlock start=/```/ end=/```/ contains=@Markdown
    syntax match LLMHeading /^# .*/
    syntax match LLMSubHeading /^## .*/
    syntax match LLMBold /\*\*.\{-}\*\*/
    syntax match LLMItalic /\*.\{-}\*/
    syntax match LLMListItem /^- .*/
  ]])

  return buf
end

-- Send a prompt to llm
function M.prompt(prompt, fragment_paths)
  local model_arg = M.get_model_arg()
  local system_arg = M.get_system_arg()
  local fragment_args = M.get_fragment_args(fragment_paths)

  local cmd = string.format('llm %s %s %s "%s"', model_arg, system_arg, fragment_args, prompt)
  
  -- Debug output
  local config = require('llm.config')
  if config.get('debug') then
    vim.notify("Executing command: " .. cmd, vim.log.levels.DEBUG)
  end
  
  local result = M.run_llm_command(cmd)
  
  if result then
    M.create_response_buffer(result)
  else
    vim.notify("No response received from LLM. Check your fragment identifier and API key.", vim.log.levels.ERROR)
  end
end

-- Send selected text with a prompt to llm
function M.prompt_with_selection(prompt, fragment_paths)
  local selection = utils.get_visual_selection()
  if selection == "" then
    api.nvim_err_writeln("No text selected")
    return
  end

  -- Create a temporary file with the selection
  local temp_file = os.tmpname()
  local file = io.open(temp_file, "w")
  if not file then
    api.nvim_err_writeln("Failed to create temporary file")
    return
  end
  
  file:write(selection)
  file:close()

  local model_arg = M.get_model_arg()
  local system_arg = M.get_system_arg()
  local fragment_args = M.get_fragment_args(fragment_paths)
  local prompt_arg = prompt ~= "" and '"' .. prompt .. '"' or ""

  local cmd = string.format('cat %s | llm %s %s %s %s', temp_file, model_arg, system_arg, fragment_args, prompt_arg)
  local result = M.run_llm_command(cmd)

  -- Clean up temp file
  os.remove(temp_file)

  if result then
    M.create_response_buffer(result)
  end
end

-- Explain the current buffer or selection
function M.explain_code(fragment_paths)
  local current_buf = api.nvim_get_current_buf()
  local lines = api.nvim_buf_get_lines(current_buf, 0, -1, false)
  local content = table.concat(lines, "\n")

  -- Create a temporary file with the content
  local temp_file = os.tmpname()
  local file = io.open(temp_file, "w")
  if not file then
    api.nvim_err_writeln("Failed to create temporary file")
    return
  end
  
  file:write(content)
  file:close()

  local model_arg = M.get_model_arg()
  local fragment_args = M.get_fragment_args(fragment_paths)

  local cmd = string.format('cat %s | llm %s -s "Explain this code" %s', temp_file, model_arg, fragment_args)
  local result = M.run_llm_command(cmd)

  -- Clean up temp file
  os.remove(temp_file)

  if result then
    M.create_response_buffer(result)
  end
end

-- Start a chat session with llm
function M.start_chat(model_override)
  if not utils.check_llm_installed() then
    return
  end

  local model = model_override or config.get("model") or ""
  local model_arg = model ~= "" and "-m " .. model or ""

  -- Create a terminal buffer
  api.nvim_command('new')
  api.nvim_command('terminal llm chat ' .. model_arg)

  -- Set buffer name
  local buf = api.nvim_get_current_buf()
  local chat_title = model ~= "" and "LLM Chat (" .. model .. ")" or "LLM Chat"
  api.nvim_buf_set_name(buf, chat_title)

  -- Set terminal colors
  vim.cmd([[
    highlight default LLMChatUser ctermfg=14 guifg=#56b6c2
    highlight default LLMChatAssistant ctermfg=10 guifg=#98c379
    highlight default LLMChatSystem ctermfg=13 guifg=#c678dd
    highlight default LLMChatPrompt ctermfg=11 guifg=#e5c07b

    " Match patterns in the terminal buffer
    match LLMChatUser /^User: .*/
    match LLMChatAssistant /^Assistant: .*/
    match LLMChatSystem /^System: .*/
    match LLMChatPrompt /^Prompt: .*/
  ]])

  -- Start insert mode
  api.nvim_command('startinsert')
end

return M
