-- llm.lua - Neovim plugin for simonw/llm
-- Maintainer: julwrites
-- Version: 0.1
-- License: Apache 2.0

-- Prevent loading twice
if vim.g.loaded_llm == 1 then
  return
end
vim.g.loaded_llm = 1

local shell = require('llm.core.utils.shell')

-- Load the main module from lua/llm/init.lua
-- This is the primary entry point for the plugin's Lua code.
-- Plugin managers ensure the 'lua/' directory is in runtimepath before this.
local ok, llm = pcall(require, "llm")
if not ok then
  -- If the main module fails to load, notify the user and stop.
  -- The error message from the require will provide details.
  if not vim.env.LLM_NVIM_TEST then
    if not shell.check_llm_installed() then
      vim.notify(
        "llm CLI not found.\n" ..
        "Install with: pip install llm or brew install llm\n" ..
        "If already installed, ensure it's in your PATH or set g:llm_executable_path",
        vim.log.levels.ERROR
      )
    else
      vim.notify("Failed to load llm module: " .. (llm or "unknown error"), vim.log.levels.ERROR)
    end
  end
  return
end
local config = require("llm.config") -- Load config module

-- Handler function for manually updating the LLM CLI
local function manual_cli_update()
  vim.notify("Starting LLM CLI update... Output will stream to a new buffer.", vim.log.levels.INFO)
  vim.cmd('vnew')
  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_name(bufnr, "LLM CLI Update Log - " .. os.time())
  vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(bufnr, 'swapfile', false)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "LLM CLI Update Log", "", "Please wait..." })
  vim.defer_fn(function()
    shell.update_llm_cli(bufnr)
  end, 100)
end

-- Command handler registry
local command_handlers = {
  file = function(prompt, is_range) require('llm.commands').prompt_with_current_file(prompt, nil, nil) end,
  selection = function(prompt, is_range)
    require('llm.commands').prompt_with_selection(prompt, nil, is_range, nil)
  end,
  explain = function() require('llm.commands').explain_code(nil, nil) end,
  schema = function() require('llm.managers.schemas_manager').select_schema() end,
  template = function() require('llm.managers.templates_manager').select_template() end,
  fragments = function() llm.interactive_prompt_with_fragments() end,
  update = manual_cli_update
}

-- Main LLM command with subcommands
-- Usage: :LLM [subcommand] [prompt]
-- Subcommands: file, selection, explain, schema, template, fragments, update
vim.api.nvim_create_user_command("LLM", function(opts)
  if not opts.args or opts.args == "" then
    require('llm.chat').start_chat()
    return
  end

  local args = vim.split(opts.args, "%s+")
  local subcmd = args[1]
  local handler = command_handlers[subcmd]

  if handler then
    handler(table.concat(args, " ", 2), opts.range > 0)
  else
    require('llm.commands').prompt(opts.args)
  end
end, {
  nargs = "*",
  range = true,
  desc = "Execute an LLM subcommand",
  complete = function(ArgLead, CmdLine, CursorPos)
    local args = vim.split(CmdLine, "%s+")

    -- If we're completing the first argument after LLM
    if #args == 2 then
      return {
        "file",      -- :LLM file
        "selection", -- :LLM selection
        "explain",   -- :LLM explain
        "schema",    -- :LLM schema
        "template",  -- :LLM template
        "fragments", -- :LLM fragments
        "update"     -- :LLM update
      }
    end

    return {}
  end
})

-- Command to start an LLM chat session or send a prompt to chat
-- Usage: :LLMChat [prompt]
vim.api.nvim_create_user_command('LLMChat', function(opts)
  local chat = require('llm.chat').start_chat()
  
  if opts.args and opts.args ~= "" then
    -- Pre-fill the input area with the prompt
    chat.buffer:set_input(opts.args)
    -- Switch to the buffer before sending
    vim.api.nvim_set_current_buf(chat.buffer:get_bufnr())
    -- Send the message using the module function (it will access the session from buffer variable)
    require('llm.chat').send_message()
    -- Ensure we're in normal mode after sending
    vim.cmd('stopinsert')
  end
end, {
  nargs = "*", -- Allow optional prompt argument
  desc = "Start an LLM chat session or send a prompt to chat",
})

-- Command to open the LLM configuration manager
-- Usage: :LLMConfig [view] where view is one of: models, plugins, keys, fragments, templates, schemas
vim.api.nvim_create_user_command('LLMConfig', function(opts)
  require('llm.commands').dispatch_command('toggle', opts.fargs[1])
end, {
  nargs = '?',
  complete = function()
    return { "Models", "Plugins", "Keys", "Fragments", "Templates", "Schemas" }
  end
})
