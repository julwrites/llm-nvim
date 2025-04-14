-- Test runner for llm-nvim
-- License: Apache 2.0

-- Add the current directory to package.path
package.path = package.path .. ';./?.lua;./test/?.lua'

-- Ensure plenary is in the runtime path
vim.opt.runtimepath:append('./test/plenary.nvim')

-- Run tests using plenary.nvim
require('plenary.busted').run('./test/spec')
