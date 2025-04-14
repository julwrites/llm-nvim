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

vim.api.nvim_create_user_command("LLMSelectModel", function()
  llm.select_model()
end, { nargs = 0 })

vim.api.nvim_create_user_command("LLMPlugins", function()
  llm.manage_plugins()
end, { nargs = 0 })

vim.api.nvim_create_user_command("LLMKeys", function()
  llm.manage_keys()
end, { nargs = 0 })

-- Define key mappings
vim.keymap.set("n", "<Plug>(llm-prompt)", ":LLM ", { silent = true })
vim.keymap.set("v", "<Plug>(llm-selection)", ":LLMWithSelection ", { silent = true })
vim.keymap.set("n", "<Plug>(llm-explain)", ":LLMExplain<CR>", { silent = true })
vim.keymap.set("n", "<Plug>(llm-chat)", ":LLMChat<CR>", { silent = true })
vim.keymap.set("n", "<Plug>(llm-select-model)", ":LLMSelectModel<CR>", { silent = true })
vim.keymap.set("n", "<Plug>(llm-plugins)", ":LLMPlugins<CR>", { silent = true })
vim.keymap.set("n", "<Plug>(llm-keys)", ":LLMKeys<CR>", { silent = true })

-- Default mappings (can be disabled with config option)
local config = require("llm.config")
if not config.get("no_mappings") then
  vim.keymap.set("n", "<leader>llm", "<Plug>(llm-prompt)")
  vim.keymap.set("v", "<leader>llm", "<Plug>(llm-selection)")
  vim.keymap.set("n", "<leader>lle", "<Plug>(llm-explain)")
  vim.keymap.set("n", "<leader>llc", "<Plug>(llm-chat)")
  vim.keymap.set("n", "<leader>lls", "<Plug>(llm-select-model)")
  vim.keymap.set("n", "<leader>llp", "<Plug>(llm-plugins)")
  vim.keymap.set("n", "<leader>llk", "<Plug>(llm-keys)")
end
