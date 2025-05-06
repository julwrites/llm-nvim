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
  vim.notify("Failed to load llm module: " .. (llm or "unknown error"), vim.log.levels.ERROR)
  return
end

-- Define commands using the functions from the loaded 'llm' module
vim.api.nvim_create_user_command("LLM", function(opts)
  llm.prompt(opts.args)
end, { nargs = 1, desc = "Send a prompt to llm" })

vim.api.nvim_create_user_command("LLMWithSelection", function(opts)
  llm.prompt_with_selection(opts.args)
end, { nargs = "?", range = true, desc = "Send visual selection with a prompt to llm" })

vim.api.nvim_create_user_command("LLMChat", function(opts)
  llm.start_chat(opts.args)
end, { nargs = "?", desc = "Start an llm chat session (optional model)" })

vim.api.nvim_create_user_command("LLMExplain", function()
  llm.explain_code()
end, { nargs = 0, desc = "Explain the current buffer or visual selection" })

-- Commands to open specific views in the unified manager
vim.api.nvim_create_user_command("LLMModels", function()
  llm.toggle_unified_manager("Models")
end, { nargs = 0, desc = "Open LLM Models Manager" })

vim.api.nvim_create_user_command("LLMPlugins", function()
  llm.toggle_unified_manager("Plugins")
end, { nargs = 0, desc = "Open LLM Plugins Manager" })

vim.api.nvim_create_user_command("LLMKeys", function()
  llm.toggle_unified_manager("Keys")
end, { nargs = 0, desc = "Open LLM API Keys Manager" })

vim.api.nvim_create_user_command("LLMFragments", function()
  llm.toggle_unified_manager("Fragments")
end, { nargs = 0, desc = "Open LLM Fragments Manager" })

-- Command for interactive fragment selection (handles visual selection internally)
vim.api.nvim_create_user_command("LLMWithFragments", function(opts)
  llm.interactive_prompt_with_fragments(opts)
end, { nargs = 0, desc = "Interactive prompt with fragments" })

-- Command for visual selection + interactive fragments (alias for LLMWithFragments with range=true)
vim.api.nvim_create_user_command("LLMWithSelectionAndFragments", function(opts)
  llm.interactive_prompt_with_fragments(opts)
end, { nargs = 0, range = true, desc = "Interactive prompt with visual selection and fragments" })

-- Commands for Templates
vim.api.nvim_create_user_command("LLMTemplates", function()
  llm.toggle_unified_manager("Templates")
end, { nargs = 0, desc = "Open LLM Templates Manager" })

vim.api.nvim_create_user_command("LLMTemplate", function()
  llm.select_template()
end, { nargs = 0, range = true, desc = "Select and run an LLM template" })

-- Commands for Schemas
vim.api.nvim_create_user_command("LLMSchemas", function()
  llm.toggle_unified_manager("Schemas")
end, { nargs = 0, desc = "Open LLM Schemas Manager" })

vim.api.nvim_create_user_command("LLMSchema", function()
  llm.select_schema()
end, { nargs = 0, range = true, desc = "Select and run an LLM schema" })

-- Command to toggle the unified manager with an optional initial view
vim.api.nvim_create_user_command("LLMToggle", function(opts)
  llm.toggle_unified_manager(opts.args ~= "" and opts.args or nil)
end, {
  nargs = "?",
  complete = function()
    -- Provide completion for view names
    return {"Models", "Plugins", "Keys", "Fragments", "Templates", "Schemas"}
  end,
  desc = "Toggle LLM Unified Manager (optional initial view)"
})

-- Define key mappings using the commands or direct lua calls
-- Using commands is simpler for basic calls, direct lua is better for complex ones or when avoiding command-line buffer is desired.
-- Let's update to use direct lua calls for the toggle and managers for better performance and consistency.

vim.keymap.set("n", "<Plug>(llm-toggle)", "<Cmd>lua require('llm').toggle_unified_manager()<CR>", { silent = true, desc = "Toggle LLM Unified Manager" })
vim.keymap.set("n", "<Plug>(llm-prompt)", ":LLM ", { silent = true, desc = "Prompt LLM" })
vim.keymap.set("v", "<Plug>(llm-selection)", ":LLMWithSelection ", { silent = true, desc = "Prompt LLM with selection" })
vim.keymap.set("n", "<Plug>(llm-explain)", "<Cmd>LLMExplain<CR>", { silent = true, desc = "Explain code" })
vim.keymap.set("n", "<Plug>(llm-chat)", "<Cmd>LLMChat<CR>", { silent = true, desc = "Start LLM chat" })

-- Use direct lua calls for manager keymaps
vim.keymap.set("n", "<Plug>(llm-models)", "<Cmd>lua require('llm').toggle_unified_manager('Models')<CR>", { silent = true, desc = "Open LLM Models Manager" })
vim.keymap.set("n", "<Plug>(llm-plugins)", "<Cmd>lua require('llm').toggle_unified_manager('Plugins')<CR>", { silent = true, desc = "Open LLM Plugins Manager" })
vim.keymap.set("n", "<Plug>(llm-keys)", "<Cmd>lua require('llm').toggle_unified_manager('Keys')<CR>", { silent = true, desc = "Open LLM Keys Manager" })
vim.keymap.set("n", "<Plug>(llm-fragments)", "<Cmd>lua require('llm').toggle_unified_manager('Fragments')<CR>", { silent = true, desc = "Open LLM Fragments Manager" })

vim.keymap.set("n", "<Plug>(llm-with-fragments)", "<Cmd>LLMWithFragments<CR>", { silent = true, desc = "Interactive prompt with fragments" }) -- Calls interactive command
vim.keymap.set("v", "<Plug>(llm-selection-with-fragments)", "<Cmd>LLMWithSelectionAndFragments<CR>", { silent = true, desc = "Interactive prompt with selection and fragments" }) -- Calls interactive command

-- Use direct lua calls for template/schema managers
vim.keymap.set("n", "<Plug>(llm-templates)", "<Cmd>lua require('llm').toggle_unified_manager('Templates')<CR>", { silent = true, desc = "Open LLM Templates Manager" })
vim.keymap.set("n", "<Plug>(llm-template)", "<Cmd>LLMTemplate<CR>", { silent = true, desc = "Select and run LLM template" }) -- Calls command

vim.keymap.set("n", "<Plug>(llm-schemas)", "<Cmd>lua require('llm').toggle_unified_manager('Schemas')<CR>", { silent = true, desc = "Open LLM Schemas Manager" })
vim.keymap.set("n", "<Plug>(llm-schema)", "<Cmd>LLMSchema<CR>", { silent = true, desc = "Select and run LLM schema" }) -- Calls command

-- Default mappings (can be disabled with config option)
-- Access config via the loaded llm module
if not llm.get_config("no_mappings") then
  vim.keymap.set("n", "<leader>ll", "<Plug>(llm-toggle)", { desc = "LLM: Toggle Manager" }) -- Added toggle mapping
  vim.keymap.set("n", "<leader>lp", "<Plug>(llm-prompt)", { desc = "LLM: Prompt" }) -- Changed leader key for prompt
  vim.keymap.set("v", "<leader>ls", "<Plug>(llm-selection)", { desc = "LLM: Prompt Selection" }) -- Changed leader key for selection
  vim.keymap.set("n", "<leader>le", "<Plug>(llm-explain)", { desc = "LLM: Explain Code" }) -- Changed leader key for explain
  vim.keymap.set("n", "<leader>lc", "<Plug>(llm-chat)", { desc = "LLM: Chat" }) -- Changed leader key for chat
  vim.keymap.set("n", "<leader>lm", "<Plug>(llm-models)", { desc = "LLM: Models Manager" }) -- Changed leader key for models
  vim.keymap.set("n", "<leader>lg", "<Plug>(llm-plugins)", { desc = "LLM: Plugins Manager" }) -- Changed leader key for plugins
  vim.keymap.set("n", "<leader>lk", "<Plug>(llm-keys)", { desc = "LLM: Keys Manager" }) -- Changed leader key for keys
  vim.keymap.set("n", "<leader>lf", "<Plug>(llm-fragments)", { desc = "LLM: Fragments Manager" }) -- Changed leader key for fragments
  vim.keymap.set("n", "<leader>lwf", "<Plug>(llm-with-fragments)", { desc = "LLM: Prompt with Fragments" }) -- Changed leader key for interactive fragments
  vim.keymap.set("v", "<leader>lwf", "<Plug>(llm-selection-with-fragments)", { desc = "LLM: Prompt Selection with Fragments" }) -- Changed leader key for interactive fragments (visual)
  vim.keymap.set("n", "<leader>lt", "<Plug>(llm-templates)", { desc = "LLM: Templates Manager" }) -- Changed leader key for templates
  vim.keymap.set("n", "<leader>lrt", "<Plug>(llm-template)", { desc = "LLM: Run Template" }) -- Changed leader key for run template
  vim.keymap.set("n", "<leader>ls", "<Plug>(llm-schemas)", { desc = "LLM: Schemas Manager" }) -- Changed leader key for schemas
  vim.keymap.set("n", "<leader>lrs", "<Plug>(llm-schema)", { desc = "LLM: Run Schema" }) -- Changed leader key for run schema
  -- Removed <leader>llcs as there's no direct command for it, use manager
end

-- Expose functions to global scope for testing purposes only
-- These should ideally be conditional on a test environment flag
if vim.env.LLM_NVIM_TEST then
  _G.select_model = llm.select_model
  _G.get_available_models = llm.get_available_models
  _G.extract_model_name = llm.extract_model_name
  _G.set_default_model = llm.set_default_model
  _G.get_available_plugins = llm.get_available_plugins
  _G.get_installed_plugins = llm.get_installed_plugins
  _G.is_plugin_installed = llm.is_plugin_installed
  _G.install_plugin = llm.install_plugin
  _G.uninstall_plugin = llm.uninstall_plugin
  _G.get_fragments = llm.get_fragments
  _G.set_fragment_alias = llm.set_fragment_alias
  _G.remove_fragment_alias = llm.remove_fragment_alias
  _G.get_stored_keys = llm.get_stored_keys
  _G.is_key_set = llm.is_key_set
  _G.set_api_key = llm.set_api_key
  _G.remove_api_key = llm.remove_api_key
  _G.get_schemas = llm.get_schemas
  _G.get_schema = llm.get_schema
  _G.save_schema = llm.save_schema
  _G.run_schema = llm.run_schema
  _G.get_templates = llm.get_templates
  _G.get_template_details = llm.get_template_details
  _G.delete_template = llm.delete_template
  _G.run_template = llm.run_template
end
