-- llm.lua - Main plugin code for llm Neovim integration
-- License: Apache 2.0

-- Re-export the module from llm/init.lua
local llm = require('llm.init')

-- Import manager modules
local models_manager = require('llm.managers.models_manager')
local plugins_manager = require('llm.managers.plugins_manager')
local keys_manager = require('llm.managers.keys_manager')
local fragments_manager = require('llm.managers.fragments_manager')
local fragments_loader = require('llm.loaders.fragments_loader')

-- Make sure all functions are properly exposed
if not llm.manage_models then
  llm.manage_models = models_manager.manage_models
end

if not llm.manage_plugins then
  llm.manage_plugins = plugins_manager.manage_plugins
end

if not llm.get_available_models then
  llm.get_available_models = models_manager.get_available_models
end

if not llm.manage_keys then
  llm.manage_keys = keys_manager.manage_keys
end

if not llm.manage_fragments then
  llm.manage_fragments = fragments_manager.manage_fragments
end

if not llm.select_fragment then
  llm.select_fragment = fragments_loader.select_file_as_fragment
end

if not llm.prompt_with_fragments then
  llm.prompt_with_fragments = fragments_loader.prompt_with_fragments
end

if not llm.prompt_with_selection_and_fragments then
  llm.prompt_with_selection_and_fragments = fragments_loader.prompt_with_selection_and_fragments
end

-- Uncomment when templates and schemas are ready
-- if not llm.manage_templates then
--   llm.manage_templates = require('llm.managers.templates_manager').manage_templates
-- end
--
-- if not llm.select_template then
--   llm.select_template = require('llm.managers.templates_manager').select_template
-- end
--
-- if not llm.manage_schemas then
--   llm.manage_schemas = require('llm.managers.schemas_manager').manage_schemas
-- end
--
-- if not llm.select_schema then
--   llm.select_schema = require('llm.managers.schemas_manager').select_schema
-- end

return llm
