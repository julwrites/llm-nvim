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

-- Load the plugin is handled by minimal_init in test/init.lua

-- Run tests using plenary.nvim's PlenaryBustedDirectory command
local status, err = pcall(function()
  -- Use the PlenaryBustedDirectory command to run tests in the directory
  -- minimal_init tells Busted to source test/init.lua before each test file
  vim.cmd('PlenaryBustedDirectory test/spec { minimal_init = "test/init.lua" }')
end)

if not status then
  print("Test execution failed: " .. tostring(err))
  vim.cmd('cq 1')  -- Exit with error code
else
  -- PlenaryBustedDirectory sets the exit code based on test results,
  -- so we can just exit normally if the command itself didn't error.
  vim.cmd('qa!')   -- Exit normally
end
