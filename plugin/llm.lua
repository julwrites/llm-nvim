-- llm.lua - Neovim plugin for simonw/llm
-- Maintainer: julwrites
-- Version: 0.1
-- License: Apache 2.0

-- Prevent loading twice
if vim.g.loaded_llm == 1 then
  return
end
vim.g.loaded_llm = 1

-- Default configuration
vim.g.llm_model = vim.g.llm_model or ""
vim.g.llm_system_prompt = vim.g.llm_system_prompt or ""

-- Load the main module
local ok, llm = pcall(require, "llm")
if not ok then
  vim.notify("Failed to load llm module", vim.log.levels.ERROR)
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

-- Define key mappings
vim.keymap.set("n", "<Plug>(llm-prompt)", ":LLM ", { silent = true })
vim.keymap.set("v", "<Plug>(llm-selection)", ":LLMWithSelection ", { silent = true })
vim.keymap.set("n", "<Plug>(llm-explain)", ":LLMExplain<CR>", { silent = true })
vim.keymap.set("n", "<Plug>(llm-chat)", ":LLMChat<CR>", { silent = true })

-- Default mappings (can be disabled with let g:llm_no_mappings = 1)
if vim.g.llm_no_mappings ~= 1 then
  vim.keymap.set("n", "<leader>llm", "<Plug>(llm-prompt)")
  vim.keymap.set("v", "<leader>llm", "<Plug>(llm-selection)")
  vim.keymap.set("n", "<leader>lle", "<Plug>(llm-explain)")
  vim.keymap.set("n", "<leader>llc", "<Plug>(llm-chat)")
end
