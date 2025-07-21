vim.loader.enable()
vim.opt.rtp:prepend(vim.fn.getcwd())

-- Set up package.path to include the lua directory
package.path = package.path .. ";" .. vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua"

-- Debugging: Print the current working directory and final package.path
vim.notify("Current working directory: " .. vim.fn.getcwd(), vim.log.levels.INFO)
vim.notify("Final package.path: " .. package.path, vim.log.levels.INFO)