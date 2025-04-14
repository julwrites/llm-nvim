-- llm/init.lua - Entry point for lazy.nvim integration
-- License: Apache 2.0

-- Load the configuration module
local config = require('llm.config')

-- Load the main module
local llm = require('llm')

-- Setup function that can be called by users
local function setup(opts)
  -- Initialize configuration
  config.setup(opts)
  
  -- Return the module for chaining
  return llm
end

-- Export the module with setup function
return setmetatable({
  setup = setup
}, {
  __index = function(_, key)
    return llm[key]
  end
})
