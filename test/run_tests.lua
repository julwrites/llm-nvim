-- Test runner for llm-nvim
-- License: Apache 2.0

-- This script should be run with 'nvim -l' not directly with lua
-- Example: nvim --headless -l test/run_tests.lua

-- Check if we're running inside Neovim
if not vim then
  print("Error: This test runner must be executed within Neovim")
  print("Usage: nvim --headless -l test/run_tests.lua")
  os.exit(1)
end

-- Add the current directory to package.path
package.path = package.path .. ';./?.lua;./test/?.lua'

-- Check if plenary.nvim exists
local plenary_path = './test/plenary.nvim'
local f = io.open(plenary_path .. '/lua/plenary/init.lua', 'r')
if not f then
  print("Error: plenary.nvim not found or incomplete in test directory")
  print("The test runner script should have cloned it automatically.")
  print("If not, please run: git clone --depth 1 https://github.com/nvim-lua/plenary.nvim.git test/plenary.nvim")
  vim.cmd('cq 1')  -- Exit with error code
  return
end
f:close()

-- Setup the runtime path properly
vim.opt.runtimepath:append(plenary_path)
vim.opt.runtimepath:append('.')

-- Load the plugin
vim.cmd('runtime plugin/llm.lua')

-- Run tests using plenary.nvim
local status, err = pcall(function()
  local busted = require('plenary.busted')
  busted.run('./test/spec')
end)

if not status then
  print("Test execution failed: " .. tostring(err))
  vim.cmd('cq 1')  -- Exit with error code
else
  vim.cmd('qa!')   -- Exit normally
end
