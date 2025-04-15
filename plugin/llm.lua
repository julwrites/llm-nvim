-- llm.lua - Neovim plugin for simonw/llm
-- Maintainer: julwrites
-- Version: 0.1
-- License: Apache 2.0

-- Prevent loading twice
if vim.g.loaded_llm == 1 then
  return
end
vim.g.loaded_llm = 1

-- Load the main module
local ok, llm = pcall(require, "llm")
if not ok then
  vim.notify("Failed to load llm module: " .. (llm or "unknown error"), vim.log.levels.ERROR)
  return
end

-- Define commands
vim.api.nvim_create_user_command("LLM", function(opts)
  llm.prompt(opts.args)
end, { nargs = 1 })

vim.api.nvim_create_user_command("LLMWithSelection", function(opts)
  llm.prompt_with_selection(opts.args)
end, { nargs = "?", range = true })

vim.api.nvim_create_user_command("LLMChat", function(opts)
  llm.start_chat(opts.args)
end, { nargs = "?" })

vim.api.nvim_create_user_command("LLMExplain", function()
  llm.explain_code()
end, { nargs = 0 })

vim.api.nvim_create_user_command("LLMModels", function()
  llm.manage_models()
end, { nargs = 0 })

vim.api.nvim_create_user_command("LLMPlugins", function()
  llm.manage_plugins()
end, { nargs = 0 })

vim.api.nvim_create_user_command("LLMKeys", function()
  llm.manage_keys()
end, { nargs = 0 })

vim.api.nvim_create_user_command("LLMFragments", function()
  llm.manage_fragments()
end, { nargs = 0 })

vim.api.nvim_create_user_command("LLMSelectFragment", function()
  llm.select_fragment()
end, { nargs = 0 })

vim.api.nvim_create_user_command("LLMWithFragments", function(opts)
  llm.prompt_with_fragments(opts.args)
end, { nargs = "?" })

vim.api.nvim_create_user_command("LLMWithSelectionAndFragments", function(opts)
  llm.prompt_with_selection_and_fragments(opts.args)
end, { nargs = "?", range = true })

vim.api.nvim_create_user_command("LLMTemplates", function()
  llm.manage_templates()
end, { nargs = 0 })

vim.api.nvim_create_user_command("LLMTemplate", function()
  llm.select_template()
end, { nargs = 0 })

vim.api.nvim_create_user_command("LLMSchemas", function()
  llm.manage_schemas()
end, { nargs = 0 })

vim.api.nvim_create_user_command("LLMSchema", function()
  llm.select_schema()
end, { nargs = 0 })

-- Define key mappings
vim.keymap.set("n", "<Plug>(llm-prompt)", ":LLM ", { silent = true })
vim.keymap.set("v", "<Plug>(llm-selection)", ":LLMWithSelection ", { silent = true })
vim.keymap.set("n", "<Plug>(llm-explain)", ":LLMExplain<CR>", { silent = true })
vim.keymap.set("n", "<Plug>(llm-chat)", ":LLMChat<CR>", { silent = true })
vim.keymap.set("n", "<Plug>(llm-models)", ":LLMModels<CR>", { silent = true })
vim.keymap.set("n", "<Plug>(llm-plugins)", ":LLMPlugins<CR>", { silent = true })
vim.keymap.set("n", "<Plug>(llm-keys)", ":LLMKeys<CR>", { silent = true })
vim.keymap.set("n", "<Plug>(llm-fragments)", ":LLMFragments<CR>", { silent = true })
vim.keymap.set("n", "<Plug>(llm-select-fragment)", ":LLMSelectFragment<CR>", { silent = true })
vim.keymap.set("n", "<Plug>(llm-with-fragments)", ":LLMWithFragments<CR>", { silent = true })
vim.keymap.set("v", "<Plug>(llm-selection-with-fragments)", ":LLMWithSelectionAndFragments<CR>", { silent = true })
vim.keymap.set("n", "<Plug>(llm-templates)", ":LLMTemplates<CR>", { silent = true })
vim.keymap.set("n", "<Plug>(llm-template)", ":LLMTemplate<CR>", { silent = true })
vim.keymap.set("n", "<Plug>(llm-schemas)", ":LLMSchemas<CR>", { silent = true })
vim.keymap.set("n", "<Plug>(llm-schema)", ":LLMSchema<CR>", { silent = true })

-- Default mappings (can be disabled with config option)
local config = require("llm.config")
if not config.get("no_mappings") then
  vim.keymap.set("n", "<leader>llp", "<Plug>(llm-prompt)")
  vim.keymap.set("v", "<leader>lls", "<Plug>(llm-selection)")
  vim.keymap.set("n", "<leader>lle", "<Plug>(llm-explain)")
  vim.keymap.set("n", "<leader>llc", "<Plug>(llm-chat)")
  vim.keymap.set("n", "<leader>llm", "<Plug>(llm-models)")
  vim.keymap.set("n", "<leader>llg", "<Plug>(llm-plugins)")
  vim.keymap.set("n", "<leader>llk", "<Plug>(llm-keys)")
  vim.keymap.set("n", "<leader>llf", "<Plug>(llm-fragments)")
  vim.keymap.set("n", "<leader>llsf", "<Plug>(llm-select-fragment)")
  vim.keymap.set("n", "<leader>llwf", "<Plug>(llm-with-fragments)")
  vim.keymap.set("v", "<leader>llwf", "<Plug>(llm-selection-with-fragments)")
  vim.keymap.set("n", "<leader>llt", "<Plug>(llm-templates)")
  vim.keymap.set("n", "<leader>llrt", "<Plug>(llm-template)")
  vim.keymap.set("n", "<leader>lls", "<Plug>(llm-schemas)")
  vim.keymap.set("n", "<leader>llrs", "<Plug>(llm-schema)")
end
