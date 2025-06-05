-- llm.lua - Neovim plugin for simonw/llm
-- Maintainer: julwrites
-- Version: 0.1
-- License: Apache 2.0

-- Prevent loading twice
if vim.g.loaded_llm == 1 then
  return
end
vim.g.loaded_llm = 1

-- Load the main module from lua/llm/init.lua
-- This is the primary entry point for the plugin's Lua code.
-- Plugin managers ensure the 'lua/' directory is in runtimepath before this.
local ok, llm = pcall(require, "llm")
if not ok then
  -- If the main module fails to load, notify the user and stop.
  -- The error message from the require will provide details.
  local shell = require('llm.utils.shell')
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
  return
end
local config = require("llm.config") -- Load config module

-- Handler function for manually updating the LLM CLI
local function manual_cli_update()
  vim.notify("Starting LLM CLI update...", vim.log.levels.INFO)
  vim.defer_fn(function()
    local shell = require('llm.utils.shell')
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
  file = function(prompt) require('llm.commands').prompt_with_current_file(prompt) end,
  selection = function(prompt, is_range)
    require('llm.commands').prompt_with_selection(prompt, nil, is_range)
  end,
  explain = function() require('llm.commands').explain_code() end,
  schema = function() require('llm.schemas.schemas_manager').select_schema() end,
  template = function() require('llm.templates.templates_manager').select_template() end,
  fragments = function() llm.interactive_prompt_with_fragments() end,
  update = manual_cli_update
}

-- Main LLM command with subcommands
-- Usage: :LLM [subcommand] [prompt]
-- Subcommands: file, selection, explain, schema, template, fragments
vim.api.nvim_create_user_command("LLM", function(opts)
  local args = vim.split(opts.args or "", "%s+")
  local subcmd = args[1]
  local handler = command_handlers[subcmd] or llm.prompt
  handler(table.concat(args, " ", subcmd and 2 or 1), opts.range > 0)
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
vim.api.nvim_create_user_command("LLMToggle", function(opts)
  llm.toggle_unified_manager(validate_view_name(opts.args))
end, {
  nargs = "?", -- Accepts 0 or 1 argument
  complete = function(ArgLead, CmdLine, CursorPos)
    -- Only complete the first argument
    if #vim.split(CmdLine, "%s+") > 2 then return {} end

    local views = { "models", "plugins", "keys", "fragments", "templates", "schemas" }
    return vim.tbl_filter(function(view)
      return view:find(ArgLead, 1, true) == 1
    end, views)
  end,
  desc = "Toggle LLM Unified Manager (optional view: models|plugins|keys|fragments|templates|schemas)"
})

-- Test environment exports
local function setup_test_exports()
  if not vim.env.LLM_NVIM_TEST then return end

  local test_exports = {
    select_model = llm.select_model,
    get_available_models = llm.get_available_models,
    extract_model_name = llm.extract_model_name,
    set_default_model = llm.set_default_model,
    get_available_plugins = llm.get_available_plugins,
    get_installed_plugins = llm.get_installed_plugins,
    is_plugin_installed = llm.is_plugin_installed,
    install_plugin = llm.install_plugin,
    uninstall_plugin = llm.uninstall_plugin,
    get_fragments = llm.get_fragments,
    set_fragment_alias = llm.set_fragment_alias,
    remove_fragment_alias = llm.remove_fragment_alias,
    get_stored_keys = llm.get_stored_keys,
    is_key_set = llm.is_key_set,
    set_api_key = llm.set_api_key,
    remove_api_key = llm.remove_api_key,
    get_schemas = llm.get_schemas,
    get_schema = llm.get_schema,
    save_schema = llm.save_schema,
    run_schema = llm.run_schema,
    get_templates = llm.get_templates,
    get_template_details = llm.get_template_details,
    delete_template = llm.delete_template,
    run_template = llm.run_template
  }

  for name, fn in pairs(test_exports) do
    _G[name] = fn
  end
end

setup_test_exports()
