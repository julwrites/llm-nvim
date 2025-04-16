-- llm.lua - Main plugin code for llm Neovim integration
-- License: Apache 2.0

-- Re-export the module from llm/init.lua
local llm = require('llm.init')

-- Make sure all functions are properly exposed
if not llm.manage_models then
  llm.manage_models = require('llm.init').manage_models
end

if not llm.manage_plugins then
  llm.manage_plugins = require('llm.init').manage_plugins
end

if not llm.get_available_models then
  llm.get_available_models = require('llm.init').get_available_models
end

if not llm.manage_keys then
  llm.manage_keys = require('llm.init').manage_keys
end

if not llm.manage_fragments then
  llm.manage_fragments = require('llm.init').manage_fragments
end

if not llm.select_fragment then
  llm.select_fragment = require('llm.init').select_fragment
end
--
-- if not llm.manage_templates then
--   llm.manage_templates = require('llm.init').manage_templates
-- end
--
-- if not llm.select_template then
--   llm.select_template = require('llm.init').select_template
-- end

return llm
