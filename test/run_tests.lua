#!/usr/bin/env lua

-- Test runner for llm-nvim
-- License: Apache 2.0

-- This script is intended to be run directly from the command line.
-- It will bootstrap by cloning plenary if not present, then execute tests.

local function file_exists(path)
  local f = io.open(path, "r")
  if f then
    f:close()
    return true
  end
  return false
end

local function run_command(cmd)
  print("Executing: " .. cmd)
  local handle = os.execute(cmd)
  return handle
end

local plenary_path = './test/plenary.nvim'
if not file_exists(plenary_path .. '/lua/plenary/init.lua') then
  print("Cloning plenary.nvim...")
  local code = run_command("git clone --depth 1 https://github.com/nvim-lua/plenary.nvim.git " .. plenary_path)
  if code ~= 0 then
    print("Failed to clone plenary.nvim")
    os.exit(1)
  end
end

local nvim_executable = os.getenv("NEOVIM_BIN") or "nvim"

-- Check if nvim is in the path
local nvim_path_output = run_command("command -v " .. nvim_executable)
if nvim_path_output == "" or nvim_path_output:match("not found") then
    print("Error: Neovim executable ('" .. nvim_executable .. "') not found in PATH.")
    print("Please install Neovim or set the NEOVIM_BIN environment variable.")
    os.exit(1)
end


-- Use a timeout for the nvim command to prevent it from hanging
local timeout_duration = 30 -- seconds
local test_path = "./test/spec/"
if #arg > 0 then
  test_path = arg[1]
end

local nvim_command = string.format(
    "timeout %d %s --headless -u NONE -i NONE -n " ..
    '-c "set runtimepath+=%s" ' ..
    '-c "set runtimepath+=." ' ..
    '-c "lua require(\'plenary.busted\').run(\'%s\')"',
    timeout_duration,
    nvim_executable,
    plenary_path,
    test_path
)

local code = run_command(nvim_command)


if code == 124 then -- Timeout exit code
  print("\nError: Test runner timed out after " .. timeout_duration .. " seconds.")
  print("This might indicate a hanging test or an issue with the Neovim process.")
  os.exit(124)
elseif code ~= 0 then
  print("\nTests failed with exit code: " .. tostring(code))
  os.exit(code)
end

print("\nTests completed successfully.")
os.exit(0)
