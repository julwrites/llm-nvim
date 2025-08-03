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
  vim.notify("Starting LLM CLI update...", vim.log.levels.INFO)
  vim.defer_fn(function()
    local result = shell.update_llm_cli()

    if result and result.success then
      vim.notify("LLM CLI update successful.", vim.log.levels.INFO)
    elseif result then -- Not nil, but success is false
      local msg = "LLM CLI update failed."
      if result.message and type(result.message) == "string" and #result.message > 0 then
        msg = msg .. " Details:\n" .. result.message
      end
      vim.notify(msg, vim.log.levels.WARN)
    else -- Result itself is nil
      vim.notify("LLM CLI update command failed to execute.", vim.log.levels.ERROR)
    end
  end, 100) -- Short delay to allow the initial notification to display
end

-- Command handler registry
local command_handlers = {
  file = function(prompt, _, bufnr) require('llm.commands').prompt_with_current_file(prompt, nil, bufnr) end,
  selection = function(prompt, is_range, bufnr)
    require('llm.commands').prompt_with_selection(prompt, nil, is_range, bufnr)
  end,
  explain = function(_, _, bufnr) require('llm.commands').explain_code(nil, bufnr) end,
  schema = function() require('llm.managers.schemas_manager').select_schema() end,
  template = function() require('llm.managers.templates_manager').select_template() end,
  fragments = function() llm.interactive_prompt_with_fragments() end,
  update = manual_cli_update
}

-- Main LLM command with subcommands
-- Usage: :LLM [subcommand] [prompt]
-- Subcommands: file, selection, explain, schema, template, fragments
vim.api.nvim_create_user_command("LLM", function(opts)
  local chat_bufnr = require('llm.chat').start_chat()

  if not opts.args or opts.args == "" then
    return
  end
  local args = vim.split(opts.args, "%s+")
  local subcmd = args[1]
  local handler = command_handlers[subcmd]
  if handler then
    handler(table.concat(args, " ", 2), opts.range > 0, chat_bufnr)
  else
    require('llm.commands').prompt(opts.args, nil, chat_bufnr)
  end
end, {
  nargs = "*",
  range = true,
  desc = "Send a prompt to llm",
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


-- Helper function to validate and normalize view names
local function validate_view_name(view)
  if not view or view == "" then return nil end
  -- Convert to proper case (first letter capitalized)
  view = view:sub(1, 1):upper() .. view:sub(2):lower()
  -- Validate view name
  local valid_views = {
    Models = true,
    Plugins = true,
    Keys = true,
    Fragments = true,
    Templates = true,
    Schemas = true
  }
  if not valid_views[view] then
    vim.notify("Invalid view: " .. view .. "\nValid views: Models, Plugins, Keys, Fragments, Templates, Schemas",
      vim.log.levels.ERROR)
    return nil
  end
  return view
end

-- Command to toggle the unified manager with an optional initial view
-- Usage: :LLMToggle [view] where view is one of: models, plugins, keys, fragments, templates, schemas
vim.api.nvim_create_user_command('LLMToggle', function(opts)
  require('llm.commands').dispatch_command('toggle', opts.fargs[1])
end, {
  nargs = '?',
  complete = function()
    return { "Models", "Plugins", "Keys", "Fragments", "Templates", "Schemas" }
  end
})
