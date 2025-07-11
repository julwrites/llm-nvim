-- test/init.lua
-- Minimal init file for running tests

-- Add plenary to the runtime path and load the plugin
vim.opt.rtp:append('./test/plenary.nvim')
vim.cmd('runtime! plugin/plenary.vim')

-- Set up package path to include the plugin's lua directory
package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua'

-- Mock the llm module to avoid running actual commands
_G.llm = {
  run_cmd = function() return "", "" end,
}

-- Mock llm.utils.shell to prevent network calls during tests
local shell_utils = require('llm.utils.shell')
function shell_utils.update_llm_cli()
  return { success = true, message = "Mocked update" }
end

-- Directly inject a mock for llm.plugins.plugins_loader into package.loaded
package.loaded['llm.plugins.plugins_loader'] = {
  fetch_plugins_from_website = function() return {} end,
  get_plugins_with_descriptions = function() return {} end,
  get_all_plugin_names = function() return {} end,
  get_plugins_by_category = function() return {} end,
  refresh_plugins_cache = function() return {} end,
}

-- Mock llm.config.get to control system_prompt during tests
local config_module = require('llm.config')
local original_config_get = config_module.get
function config_module.get(key)
  if key == "system_prompt" then
    return nil -- Ensure no system prompt is returned for tests
  end
  return original_config_get(key)
end

-- Directly require the main llm module
require('llm')
