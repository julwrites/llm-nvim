-- llm/commands.lua - Command execution for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local api = vim.api
local utils = require('llm.utils')
local config = require('llm.config')

-- Get the model argument if specified, properly escaped
function M.get_model_arg()
  local model = config.get("model")
  if model and model ~= "" then
    -- Return as a table element for later concatenation
    return { "-m", vim.fn.shellescape(model) }
  end
  return {} -- Return empty table if no model
end

-- Get the system prompt argument if specified, properly escaped
function M.get_system_arg()
  local system = config.get("system_prompt")
  if system and system ~= "" then
    -- Return as a table element for later concatenation
    return { "-s", vim.fn.shellescape(system) }
  end
  return {} -- Return empty table if no system prompt
end

-- Get fragment arguments if specified, properly escaped
function M.get_fragment_args(fragment_list)
  if not fragment_list or #fragment_list == 0 then
    return {} -- Return empty table if no fragments
  end

  local args = {}
  for _, fragment in ipairs(fragment_list) do
    -- Add '-f' and the escaped fragment as separate elements
    table.insert(args, "-f")
    table.insert(args, vim.fn.shellescape(fragment))

    -- Debug output
    local config = require('llm.config')
    if config.get('debug') then
      vim.notify("Adding fragment: " .. fragment, vim.log.levels.DEBUG)
    end
  end

  return args -- Return the table directly
end

-- Get system fragment arguments if specified, properly escaped
function M.get_system_fragment_args(fragment_list)
  if not fragment_list or #fragment_list == 0 then
    return {} -- Return empty table if no fragments
  end

  local args = {}
  for _, fragment in ipairs(fragment_list) do
    -- Add '--system-fragment' and the escaped fragment as separate elements
    table.insert(args, "--system-fragment")
    table.insert(args, vim.fn.shellescape(fragment))
  end

  return args -- Return the table directly
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
  local cmd_parts = { "llm" }

  -- Add model args (returns a table)
  vim.list_extend(cmd_parts, M.get_model_arg())
  -- Add system args (returns a table)
  vim.list_extend(cmd_parts, M.get_system_arg())
  -- Add fragment args (returns a table)
  vim.list_extend(cmd_parts, M.get_fragment_args(fragment_paths))

  -- Add the main prompt, escaped
  table.insert(cmd_parts, vim.fn.shellescape(prompt))

  -- Construct the final command string
  local cmd = table.concat(cmd_parts, " ")

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

  local llm_cmd_parts = { "llm" }
  -- Add model args
  vim.list_extend(llm_cmd_parts, M.get_model_arg())
  -- Add system args
  vim.list_extend(llm_cmd_parts, M.get_system_arg())
  -- Add fragment args
  vim.list_extend(llm_cmd_parts, M.get_fragment_args(fragment_paths))
  -- Add the optional prompt, escaped
  if prompt and prompt ~= "" then
    table.insert(llm_cmd_parts, vim.fn.shellescape(prompt))
  end

  -- Construct the llm part of the command
  local llm_cmd = table.concat(llm_cmd_parts, " ")

  -- Construct the full command with cat and pipe
  local cmd = string.format("cat %s | %s", vim.fn.shellescape(temp_file), llm_cmd)

  -- Debug output
  local config = require('llm.config')
  if config.get('debug') then
    vim.notify("Executing command: " .. cmd, vim.log.levels.DEBUG)
  end

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

  local llm_cmd_parts = { "llm" }
  -- Add model args
  vim.list_extend(llm_cmd_parts, M.get_model_arg())
  -- Add system prompt specifically for explain
  table.insert(llm_cmd_parts, "-s")
  table.insert(llm_cmd_parts, vim.fn.shellescape("Explain this code"))
  -- Add fragment args
  vim.list_extend(llm_cmd_parts, M.get_fragment_args(fragment_paths))

  -- Construct the llm part of the command
  local llm_cmd = table.concat(llm_cmd_parts, " ")

  -- Construct the full command with cat and pipe
  local cmd = string.format("cat %s | %s", vim.fn.shellescape(temp_file), llm_cmd)

  -- Debug output
  local config = require('llm.config')
  if config.get('debug') then
    vim.notify("Executing command: " .. cmd, vim.log.levels.DEBUG)
  end

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

-- Helper function to select an existing fragment alias
local function select_existing_fragment(callback)
  local fragments_loader = require('llm.fragments.fragments_loader')
  local existing_fragments = fragments_loader.get_fragments() -- Get fragments with aliases

  if not existing_fragments or #existing_fragments == 0 then
    vim.notify("No existing fragments with aliases found.", vim.log.levels.WARN)
    callback(nil) -- Indicate no selection
    return
  end

  local items = {}
  local fragment_map = {}
  for i, frag in ipairs(existing_fragments) do
    local display_name = (#frag.aliases > 0 and frag.aliases[1] or frag.hash:sub(1, 8)) ..
        " (" .. (frag.source or "hash") .. ")"
    table.insert(items, display_name)
    fragment_map[i] = (#frag.aliases > 0 and frag.aliases[1] or frag.hash) -- Store identifier (prefer alias)
  end

  vim.ui.select(items, {
    prompt = "Select an existing fragment:",
    format_item = function(item) return item end
  }, function(choice, idx)
    if not choice then
      callback(nil)
      return
    end
    local identifier = fragment_map[idx]
    callback(identifier)
  end)
end


-- Interactive prompt allowing selection of multiple fragments
function M.interactive_prompt_with_fragments(opts)
  opts = opts or {}
  local fragments_loader = require('llm.fragments.fragments_loader') -- Load here to avoid circular dependency issues at top level
  local fragments_list = {}
  local visual_selection_text = nil
  local visual_selection_temp_file = nil

  -- Check for visual selection
  if opts.range and opts.range > 0 then
    visual_selection_text = utils.get_visual_selection()
    if visual_selection_text and visual_selection_text ~= "" then
      -- Save selection to a temporary file to treat it like a fragment source
      visual_selection_temp_file = os.tmpname()
      local file = io.open(visual_selection_temp_file, "w")
      if file then
        file:write(visual_selection_text)
        file:close()
        table.insert(fragments_list, visual_selection_temp_file)
        vim.notify("Added visual selection as fragment source.", vim.log.levels.INFO)
      else
        vim.notify("Failed to create temporary file for visual selection.", vim.log.levels.ERROR)
        visual_selection_temp_file = nil -- Ensure it's nil if creation failed
      end
    else
      visual_selection_text = nil -- Reset if selection was empty
    end
  end

  local function add_more_fragments()
    local options = {
      "Select existing fragment (alias/hash)",
      "Select file as fragment",
      "Enter fragment path/URL",
      "Use GitHub repository",
      "Done - continue with prompt"
    }

    vim.ui.select(options, {
      prompt = "Add fragments to prompt (" .. #fragments_list .. " added):"
    }, function(choice)
      if not choice then return end -- User cancelled selection loop

      local function handle_fragment_added(identifier)
        if identifier then
          -- Avoid adding duplicates
          local found = false
          for _, existing in ipairs(fragments_list) do
            if existing == identifier then
              found = true
              break
            end
          end
          if not found then
            table.insert(fragments_list, identifier)
            vim.notify("Added fragment: " .. identifier, vim.log.levels.INFO)
          else
            vim.notify("Fragment already added: " .. identifier, vim.log.levels.WARN)
          end
        end
        vim.schedule(add_more_fragments) -- Continue the loop
      end

      if choice == "Select existing fragment (alias/hash)" then
        select_existing_fragment(handle_fragment_added)
      elseif choice == "Select file as fragment" then
        fragments_loader.select_file_as_fragment(handle_fragment_added, true) -- Force manual input for consistency
      elseif choice == "Enter fragment path/URL" then
        vim.ui.input({ prompt = "Enter fragment path/URL: " }, function(input)
          if input and input ~= "" then
            handle_fragment_added(input)
          else
            add_more_fragments() -- Re-prompt if input is empty
          end
        end)
      elseif choice == "Use GitHub repository" then
        fragments_loader.add_github_fragment(handle_fragment_added)
      elseif choice == "Done - continue with prompt" then
        if #fragments_list == 0 then
          vim.notify("No fragments selected.", vim.log.levels.WARN)
          return -- Exit if no fragments
        end

        -- Now ask for the prompt
        vim.ui.input({
          prompt = "Enter prompt: "
        }, function(input_prompt)
          if not input_prompt or input_prompt == "" then
            vim.notify("Prompt cannot be empty.", vim.log.levels.ERROR)
            -- Clean up temp file if prompt is cancelled
            if visual_selection_temp_file then os.remove(visual_selection_temp_file) end
            return
          end

          -- Decide which command to call based on whether visual selection was the *only* input
          -- Note: We currently always use M.prompt and pass the temp file path if visual selection was used.
          -- A potential enhancement is to detect if *only* the visual selection temp file is present
          -- and call M.prompt_with_selection directly with the text, but this adds complexity.
          -- For now, using the temp file path in M.prompt is simpler.

          M.prompt(input_prompt, fragments_list)

          -- Clean up temp file *after* the command runs (or is supposed to run)
          -- Using defer_fn to ensure it runs after the current execution context
          if visual_selection_temp_file then
            vim.defer_fn(function() os.remove(visual_selection_temp_file) end, 100)
          end
        end)
      else
        add_more_fragments() -- Should not happen, but ensures loop continues
      end
    end)
  end

  -- Start the fragment selection loop
  add_more_fragments()
end

return M
