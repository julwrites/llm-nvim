-- llm/commands.lua - Command execution for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local api = vim.api
local config = require('llm.config')
local ui = require('llm.core.utils.ui')
local text = require('llm.core.utils.text')
local shell = require('llm.core.utils.shell')
local llm_cli = require('llm.core.data.llm_cli')

---------------------
-- Helper Functions
---------------------

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

function M.get_pre_response_message(source, prompt, fragment_paths)
  local message_parts = {}

  table.insert(message_parts, "Passing your prompt to llm tool")
  table.insert(message_parts, " ")
  table.insert(message_parts, "---")
  table.insert(message_parts, " ")
  table.insert(message_parts, "Prompt: " .. prompt)
  table.insert(message_parts, "Source: " .. source)
  if fragment_paths and #fragment_paths > 0 then
    table.insert(message_parts, "Fragments: " .. table.concat(fragment_paths, ", "))
  end
  table.insert(message_parts, " ")
  table.insert(message_parts, "---")
  table.insert(message_parts, " ")
  table.insert(message_parts, "Processing, please wait...")
  table.insert(message_parts, " ")
  table.insert(message_parts, "(Note that results will be written to this buffer)")

  return table.concat(message_parts, "\n")
end

-- Create a new buffer with the LLM response
function M.create_response_buffer(content)
  local buf = ui.create_buffer_with_content(content, "LLM Response", "markdown")

  vim.notify("Response buffer is created")

  return buf
end

function M.fill_response_buffer(buffer, content)
  local buf = ui.replace_buffer_with_content(content, buffer, "markdown")

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

function M.write_context_to_temp_file(context)
  local temp_file = os.tmpname()
  local file = io.open(temp_file, "w")
  if not file then
    api.nvim_err_writeln("Failed to create temporary file")
    return ""
  end

  file:write(context)
  file:close()

  return temp_file
end

function M.llm_stream_and_display_response(buf, cmd)
    local response_chunks = {}
    llm_cli.stream_llm_command(
        cmd,
        function(chunk)
            table.insert(response_chunks, chunk)
            local partial_response = table.concat(response_chunks, "")
            vim.schedule(function()
                M.fill_response_buffer(buf, partial_response)
            end)
        end,
        function(stderr)
            vim.notify("Error from llm command: " .. stderr, vim.log.levels.ERROR)
        end,
        function(code)
            if code ~= 0 then
                vim.notify("llm command failed with code: " .. code, vim.log.levels.ERROR)
            end
            vim.schedule(function()
                vim.api.nvim_set_current_buf(buf)
                vim.cmd('stopinsert')
            end)
        end
    )
end

-- Helper function to select an existing fragment alias
local function select_existing_fragment(callback)
  local fragments_manager = require('llm.managers.fragments_manager')
  local existing_fragments = fragments_manager.get_fragments() -- Get fragments with aliases

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

---------------------
-- LLM Prompt Commands
---------------------

function M.open_chat_scratchpad()
    local models_manager = require('llm.managers.models_manager')
    local default_model = models_manager.get_default_model()
    local content = "Welcome to the LLM chat scratchpad.\n\nModel: " .. (default_model or "default") .. "\n\n"
    local buf = ui.create_buffer_with_content(content, "LLM Chat", "markdown")

    vim.api.nvim_buf_set_option(buf, 'buftype', 'prompt')
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'hide')

    vim.api.nvim_buf_set_keymap(buf, 'n', '<CR>', '<Cmd>lua require("llm.commands").send_chat_prompt(' .. buf .. ')<CR>', { noremap = true, silent = true })

    vim.api.nvim_set_current_buf(buf)
    vim.cmd('startinsert')
end

function M.send_chat_prompt(buf)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local prompt = lines[#lines]

    local cmd_parts = { "llm" }
    vim.list_extend(cmd_parts, M.get_model_arg())
    vim.list_extend(cmd_parts, M.get_system_arg())
    table.insert(cmd_parts, vim.fn.shellescape(prompt))
    local cmd = table.concat(cmd_parts, " ")

    M.llm_stream_and_display_response(buf, cmd)
end

-- Unified command dispatcher
function M.dispatch_command(subcmd, ...)
  local args = { ... }
  local success, err = pcall(function()
    if subcmd == nil or subcmd == "" then
      return M.open_chat_scratchpad()
    elseif subcmd == "selection" then
      return M.prompt_with_selection(args[1] or "", args[2] or {})
    elseif subcmd == "toggle" then
      local unified_manager = require('llm.ui.unified_manager')
      return unified_manager.toggle(args[1] or "")
    else
      -- Default case: treat as direct prompt
      return M.prompt(subcmd, args[1] or {})
    end
  end)

  if not success then
    vim.notify("Error dispatching command: " .. tostring(err), vim.log.levels.ERROR)
  end
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
    if prompt and prompt ~= "" then
        table.insert(cmd_parts, vim.fn.shellescape(prompt))
    end

    -- Construct the final command string
    local cmd = table.concat(cmd_parts, " ")
    vim.notify("Final command: " .. cmd, vim.log.levels.DEBUG)

    local buf = M.create_response_buffer("Processing, please wait...")
    M.llm_stream_and_display_response(buf, cmd)
end

-- Explain the current buffer or selection
function M.explain_code(fragment_paths)
  M.prompt_with_current_file("Explain this code", fragment_paths)
end

function M.prompt_with_current_file(prompt, fragment_paths)
  local filepath = vim.api.nvim_buf_get_name(0)
  if filepath == "" then
    vim.notify("Current buffer has no file path", vim.log.levels.ERROR)
    return
  end

  M.execute_prompt_async("Current file", prompt, filepath, fragment_paths)
end

-- Send selected text with a prompt to llm
function M.prompt_with_selection(prompt, fragment_paths, from_visual_mode)
  local selection
  if from_visual_mode then
    selection = text.get_visual_selection()
  else
    -- For non-visual mode calls, get the current line
    selection = vim.api.nvim_get_current_line()
  end

  if selection == "" then
    vim.notify("No text selected", vim.log.levels.WARN)
    return
  end

  local temp_file = M.write_context_to_temp_file(selection)

  M.execute_prompt_async("Current selection", prompt, temp_file, fragment_paths,
    function()
      os.remove(temp_file)
    end)
end

function M.execute_prompt_async(source, prompt, filepath, fragment_paths, cleanup_callback)
  -- If no prompt provided, show floating input
  if not prompt or prompt == "" then
    ui.floating_input(
    -- opts
      { prompt = "Enter prompt for current file:" },
      -- on_confirm
      function(input_prompt)
        local msg = M.get_pre_response_message(source, input_prompt, fragment_paths)
        local buf = M.create_response_buffer(msg)

        if input_prompt and input_prompt ~= "" then
          -- Close the floating input window before showing response
          vim.schedule(function()
            M.execute_prompt_with_file(buf, input_prompt, filepath, fragment_paths)
            if cleanup_callback then
              cleanup_callback()
            end
          end)
        else
          vim.notify("Prompt cannot be empty", vim.log.levels.WARN)
        end
      end
    )
  else
    local msg = M.get_pre_response_message(source, prompt, fragment_paths)
    local buf = M.create_response_buffer(msg)
    -- Scheduling so that the response buffer gets to be created before the buffer-control gets starved
    vim.schedule(function()
      M.execute_prompt_with_file(buf, prompt, filepath, fragment_paths)
      if cleanup_callback then
        cleanup_callback()
      end
    end)
  end
end

function M.execute_prompt_with_file(buffer, prompt, filepath, fragment_paths)
    vim.notify("DEBUG: _execute_prompt_with_file called", vim.log.levels.DEBUG)
    vim.notify("Prompt: " .. prompt, vim.log.levels.DEBUG)
    vim.notify("Filepath: " .. filepath, vim.log.levels.DEBUG)

    local cmd_parts = { "llm" }
    -- Add model args
    vim.list_extend(cmd_parts, M.get_model_arg())
    -- Add system args
    vim.list_extend(cmd_parts, M.get_system_arg())
    -- Add fragment args
    vim.list_extend(cmd_parts, M.get_fragment_args(fragment_paths))
    -- Add the file
    table.insert(cmd_parts, "-f " .. vim.fn.shellescape(filepath))
    -- Add the prompt
    if prompt and prompt ~= "" then
        table.insert(cmd_parts, vim.fn.shellescape(prompt))
    end

    local cmd = table.concat(cmd_parts, " ")

    -- Debug output
    local config = require('llm.config')
    if config.get('debug') then
        vim.notify("Executing command: " .. cmd, vim.log.levels.DEBUG)
    end

    M.llm_stream_and_display_response(buffer, cmd)
end

---------------------
-- Interactive Commands
---------------------

-- Interactive prompt allowing selection of multiple fragments
-- NOTE: This function is not fully tested due to the complexity of mocking the interactive UI.
function M.interactive_prompt_with_fragments(opts)
  opts = opts or {}
  local fragments_manager = require('llm.managers.fragments_manager') -- Load here to avoid circular dependency issues at top level
  local fragments_list = {}
  local visual_selection_text = nil
  local visual_selection_temp_file = nil

  -- Check for visual selection
  if opts.range and opts.range > 0 then
    visual_selection_text = text.get_visual_selection()
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
        fragments_manager.add_file_fragment(nil)
      elseif choice == "Enter fragment path/URL" then
        vim.ui.input({ prompt = "Enter fragment path/URL: " }, function(input)
          if input and input ~= "" then
            handle_fragment_added(input)
          else
            add_more_fragments() -- Re-prompt if input is empty
          end
        end)
      elseif choice == "Use GitHub repository" then
        fragments_manager.add_github_fragment_from_manager(nil)
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

-- Test function to verify terminal creation
function M.test_terminal_creation()
  vim.notify("Testing terminal creation...", vim.log.levels.INFO)
  vim.cmd('new')
  local buf = vim.api.nvim_get_current_buf()
  vim.notify("Created buffer: " .. buf, vim.log.levels.INFO)

  local cmd = "echo 'Test terminal'"
  vim.notify("Executing: terminal " .. cmd, vim.log.levels.INFO)
  vim.cmd('terminal ' .. cmd)

  local term_buf = vim.api.nvim_get_current_buf()
  vim.notify("Terminal buffer: " .. term_buf, vim.log.levels.INFO)
  local buf_type = vim.api.nvim_buf_get_option(term_buf, 'buftype')
  vim.notify("Buffer type: " .. buf_type, vim.log.levels.INFO)

  vim.cmd('startinsert')
end

return M
