-- llm/commands.lua - Command execution for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local nvim_api = vim.api
local api = require('llm.api')
local config = require('llm.config')
local ui = require('llm.core.utils.ui')
local text = require('llm.core.utils.text')
local shell = require('llm.core.utils.shell')
local llm_cli = require('llm.core.data.llm_cli')
local job = require('llm.core.utils.job')

---------------------
-- Helper Functions
---------------------

-- Get the configured llm executable path
function M.get_llm_executable_path()
  return config.get("llm_executable_path")
end

-- Get the model argument if specified
function M.get_model_arg()
  local model = config.get("model")
  if model and model ~= "" then
    -- Return as a table element for later concatenation
    return { "-m", model }
  end
  return {} -- Return empty table if no model
end

-- Get the system prompt argument if specified
function M.get_system_arg()
  local system = config.get("system_prompt")
  if system and system ~= "" then
    -- Return as a table element for later concatenation
    return { "-s", system }
  end
  return {} -- Return empty table if no system prompt
end

-- Get fragment arguments if specified
function M.get_fragment_args(fragment_list)
  if not fragment_list or #fragment_list == 0 then
    return {} -- Return empty table if no fragments
  end

  local args = {}
  for _, fragment in ipairs(fragment_list) do
    -- Add '-f' and the fragment as separate elements
    table.insert(args, "-f")
    table.insert(args, fragment)

    -- Debug output
    local config = require('llm.config')
    if config.get('debug') then
      vim.notify("Adding fragment: " .. fragment, vim.log.levels.DEBUG)
    end
  end

  return args -- Return the table directly
end

-- Get tools arguments if specified
function M.get_tool_args()
  local tools = config.get("tools")
  if not tools or tools == "" then
    return {}
  end

  local args = {}
  local tool_list = vim.split(tools, ",")
  for _, tool in ipairs(tool_list) do
    local trimmed_tool = vim.trim(tool)
    if trimmed_tool ~= "" then
      table.insert(args, "-T")
      table.insert(args, trimmed_tool)
    end
  end

  return args
end

-- Get functions arguments if specified
function M.get_functions_arg()
  local functions = config.get("functions")
  if functions and functions ~= "" then
    return { "--functions", functions }
  end
  return {}
end

-- Get tools debug argument if specified
function M.get_tools_debug_arg()
  if config.get("tools_debug") then
    return { "--td" }
  end
  return {}
end

-- Get tools approve argument if specified
function M.get_tools_approve_arg()
  if config.get("tools_approve") then
    return { "--ta" }
  end
  return {}
end

-- Get chain limit argument if specified
function M.get_chain_limit_arg()
  local chain_limit = config.get("chain_limit")
  if chain_limit ~= nil then
    return { "--cl", tostring(chain_limit) }
  end
  return {}
end

-- Get attachment arguments if specified
function M.get_attachment_args()
  local attachment = config.get("attachment")
  if type(attachment) == "string" and attachment ~= "" then
    return { "-a", attachment }
  elseif type(attachment) == "table" then
    local args = {}
    for _, path in ipairs(attachment) do
      table.insert(args, "-a")
      table.insert(args, tostring(path))
    end
    return args
  end
  return {}
end

-- Get extract argument if specified
function M.get_extract_arg()
  local extract = config.get("extract")
  if extract then
    return { "-x" }
  end
  return {}
end

-- Get save template argument if specified
function M.get_save_template_arg()
  local save = config.get("save")
  if save and save ~= "" then
    return { "--save", save }
  end
  return {}
end

-- Get model options arguments if specified
function M.get_model_options_args()
  local model_options = config.get("model_options")
  if type(model_options) == "table" then
    local args = {}
    for key, value in pairs(model_options) do
      table.insert(args, "-o")
      table.insert(args, tostring(key))
      table.insert(args, tostring(value))
    end
    return args
  end
  return {}
end

-- Get template argument if specified
function M.get_template_arg()
  local template = config.get("template")
  if template and template ~= "" then
    return { "-t", template }
  end
  return {}
end

-- Get schema arguments if specified
function M.get_schema_args()
  local schema = config.get("schema")
  local schema_multi = config.get("schema_multi")
  if schema and schema ~= "" then
    return { "--schema", schema }
  elseif schema_multi and schema_multi ~= "" then
    return { "--schema-multi", schema_multi }
  end
  return {}
end

-- Get template parameters arguments if specified
function M.get_template_params_args()
  local template_params = config.get("template_params")
  if type(template_params) == "table" then
    local args = {}
    for key, value in pairs(template_params) do
      table.insert(args, "-p")
      table.insert(args, tostring(key))
      table.insert(args, tostring(value))
    end
    return args
  end
  return {}
end

-- Get conversation arguments if specified
function M.get_conversation_args()
  local args = {}
  local cid = config.get("conversation_id")
  if cid and cid ~= "" then
    return { "--cid", cid }
  elseif config.get("continue_conversation") then
    return { "-c" }
  end
  return {}
end

-- Build common base command arguments for llm prompt commands
function M.build_base_cmd(fragment_paths)
  local cmd_parts = { M.get_llm_executable_path() }

  vim.list_extend(cmd_parts, M.get_model_arg())
  vim.list_extend(cmd_parts, M.get_system_arg())
  vim.list_extend(cmd_parts, M.get_tool_args())
  vim.list_extend(cmd_parts, M.get_functions_arg())
  vim.list_extend(cmd_parts, M.get_tools_debug_arg())
  vim.list_extend(cmd_parts, M.get_tools_approve_arg())
  vim.list_extend(cmd_parts, M.get_chain_limit_arg())
  vim.list_extend(cmd_parts, M.get_attachment_args())
  vim.list_extend(cmd_parts, M.get_extract_arg())
  vim.list_extend(cmd_parts, M.get_model_options_args())
  vim.list_extend(cmd_parts, M.get_template_arg())
  vim.list_extend(cmd_parts, M.get_save_template_arg())
  vim.list_extend(cmd_parts, M.get_template_params_args())
  vim.list_extend(cmd_parts, M.get_schema_args())
  vim.list_extend(cmd_parts, M.get_conversation_args())

  if fragment_paths then
    vim.list_extend(cmd_parts, M.get_fragment_args(fragment_paths))
  end

  return cmd_parts
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

function M.write_context_to_temp_file(context)
  local temp_file = vim.fn.tempname()
  local file = io.open(temp_file, "w")
  if not file then
    api.nvim_err_writeln("Failed to create temporary file")
    return ""
  end

  file:write(context)
  file:close()

  return temp_file
end

function M.create_response_buffer(content)
  ui.create_buffer_with_content(content, "LLM Response", "markdown")
end

function M.fill_response_buffer(bufnr, content)
  ui.replace_buffer_with_content(content, bufnr, "markdown")
  vim.cmd("redraw")
end

function M.prepare_response_buffer_and_callbacks(bufnr, on_exit)
  local target_bufnr = bufnr
  if not target_bufnr then
    vim.cmd('vnew')
    target_bufnr = vim.api.nvim_get_current_buf()
    local buffer_name = "LLM Response - " .. os.time()
    vim.api.nvim_buf_set_name(target_bufnr, buffer_name)
    vim.api.nvim_buf_set_option(target_bufnr, 'filetype', 'markdown')
    vim.api.nvim_buf_set_lines(target_bufnr, 0, -1, false, { "Waiting for response..." })
  end

  local callbacks = {
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          ui.append_to_buffer(target_bufnr, line .. "\n", "LlmModelResponse")
        end
      end
    end,
  }

  if on_exit then
    callbacks.on_exit = on_exit
  end

  return target_bufnr, callbacks
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

-- Unified command dispatcher
function M.dispatch_command(subcmd, ...)
  local args = { ... }
  local success, err = pcall(function()
    if subcmd == "selection" then
      return M.prompt_with_selection(args[1] or "", args[2] or {})
    elseif subcmd == "toggle" then
      local unified_manager = require('llm.ui.unified_manager')
      return unified_manager.toggle(args[1] or "")
    elseif subcmd == "" then
      return ui.create_prompt_buffer()
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
function M.prompt(prompt, fragment_paths, bufnr, on_exit)
  local cmd_parts = M.build_base_cmd(fragment_paths)
  local _, callbacks = M.prepare_response_buffer_and_callbacks(bufnr, on_exit)
  api.run_streaming_command(cmd_parts, prompt, callbacks)
end



-- Explain the current buffer or selection
function M.explain_code(fragment_paths, bufnr)
  M.prompt_with_current_file("Explain this code", fragment_paths, bufnr)
end

function M.prompt_with_current_file(prompt, fragment_paths, bufnr)
  local filepath = vim.fn.expand('%:p')
  if filepath == "" then
    vim.notify("Current buffer has no file path", vim.log.levels.ERROR)
    return
  end

  local cmd_parts = M.build_base_cmd(fragment_paths)

  -- Add the current file as a fragment
  table.insert(cmd_parts, "-f")
  table.insert(cmd_parts, filepath)

  local _, callbacks = M.prepare_response_buffer_and_callbacks(bufnr)
  api.run_streaming_command(cmd_parts, prompt, callbacks)
end



-- Send selected text with a prompt to llm
function M.prompt_with_selection(prompt, fragment_paths, from_visual_mode, bufnr)
  local selection
  if from_visual_mode then
    selection = text.get_visual_selection()
  else
    selection = vim.nvim_get_current_line()
  end

  if selection == "" then
    vim.notify("No text selected", vim.log.levels.WARN)
    return
  end

  local temp_file = M.write_context_to_temp_file(selection)
  if temp_file == "" then
    return
  end

  local cmd_parts = M.build_base_cmd(fragment_paths)

  table.insert(cmd_parts, "-f")
  table.insert(cmd_parts, temp_file)

  local on_exit = function()
    vim.notify("LLM command finished.")
    -- Temporary files created via vim.fn.tempname() are automatically cleaned up by Neovim
  end

  local _, callbacks = M.prepare_response_buffer_and_callbacks(bufnr, on_exit)

  api.run_streaming_command(cmd_parts, prompt, callbacks)
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
      visual_selection_temp_file = vim.fn.tempname()
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
            -- Temporary files created via vim.fn.tempname() are automatically cleaned up by Neovim
            return
          end

          -- Decide which command to call based on whether visual selection was the *only* input
          -- Note: We currently always use M.prompt and pass the temp file path if visual selection was used.
          -- A potential enhancement is to detect if *only* the visual selection temp file is present
          -- and call M.prompt_with_selection directly with the text, but this adds complexity.
          -- For now, using the temp file path in M.prompt is simpler.

          local on_exit = nil
          if visual_selection_temp_file then
            on_exit = function()
              -- Temporary files created via vim.fn.tempname() are automatically cleaned up by Neovim
            end
          end

          M.prompt(input_prompt, fragments_list, nil, on_exit)
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
  local config = require('llm.config')
  if config.get('debug') then
    vim.notify("Testing terminal creation...", vim.log.levels.DEBUG)
    vim.cmd('new')
    local buf = vim.api.nvim_get_current_buf()
    vim.notify("Created buffer: " .. buf, vim.log.levels.DEBUG)

    local cmd = "echo 'Test terminal'"
    vim.notify("Executing: terminal " .. cmd, vim.log.levels.DEBUG)
    vim.cmd('terminal ' .. cmd)

    local term_buf = vim.api.nvim_get_current_buf()
    vim.notify("Terminal buffer: " .. term_buf, vim.log.levels.DEBUG)
    local buf_type = vim.api.nvim_buf_get_option(term_buf, 'buftype')
    vim.notify("Buffer type: " .. buf_type, vim.log.levels.DEBUG)
  end

  vim.cmd('startinsert')
end

---------------------
-- Embed Command
---------------------

function M.embed(args_str)
  local embeddings_manager = require('llm.managers.embeddings_manager')
  local result = embeddings_manager.embed(args_str)

  if result then
    vim.notify("Embeddings generated successfully.", vim.log.levels.INFO)
  else
    vim.notify("Failed to generate embeddings.", vim.log.levels.ERROR)
  end
end

return M
