-- llm.lua - Main plugin code for llm Neovim integration
-- License: Apache 2.0

-- Re-export the module from llm/init.lua
local llm = require('llm.init')

-- Make sure all functions are properly exposed
if not llm.select_model then
  llm.select_model = require('llm.init').select_model
end

if not llm.get_available_models then
  llm.get_available_models = require('llm.init').get_available_models
end

return llm
