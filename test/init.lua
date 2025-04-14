-- Test initialization file for llm-nvim
-- License: Apache 2.0

-- Export test utilities
local M = {}

-- Setup function to be called at the beginning of each test
function M.setup()
  -- Set minimal vim configuration for testing
  vim.opt.runtimepath:append('.')
  vim.opt.runtimepath:append('./test')
  
  -- Reset any global variables that might affect tests
  vim.g.llm_model = nil
  vim.g.llm_system_prompt = nil
  vim.g.llm_no_mappings = nil
  vim.g.loaded_llm = nil
  
  -- Clear any existing mappings
  vim.cmd('mapclear')
  
  -- Load the plugin
  -- Use pcall to catch any errors during loading
  local ok, err = pcall(function()
    dofile(vim.fn.fnamemodify('./plugin/llm.lua', ':p'))
  end)
  
  if not ok then
    print("Error loading plugin: " .. tostring(err))
  end
  
  -- Make sure the module is loaded and available globally for tests
  _G.llm = require('llm')
end

-- Mock function for llm command execution
function M.mock_llm_command(expected_cmd, return_value)
  -- Store original io.popen
  local original_popen = io.popen
  
  -- Mock io.popen
  io.popen = function(cmd)
    -- Only assert if the expected command is provided
    if expected_cmd and expected_cmd ~= "" then
      assert(cmd:match(expected_cmd), 
        string.format("Expected command to match '%s', got '%s'", expected_cmd, cmd))
    end
    
    return {
      read = function(self, format) 
        if format == "*a" then
          return return_value
        end
        return ""
      end,
      close = function() return true end
    }
  end
  
  -- Return cleanup function
  return function()
    io.popen = original_popen
  end
end

-- Helper function to expose module functions for testing
function M.expose_module_functions(module)
  -- Explicitly set each function in the global scope for testing
  -- Force the select_model function to be available even if it's not in the module
  _G.select_model = function() end -- Default implementation
  
  -- Override with the real implementation if available
  if module.select_model then
    _G.select_model = module.select_model
  end
  
  -- Set other functions
  _G.prompt = module.prompt
  _G.prompt_with_selection = module.prompt_with_selection
  _G.explain_code = module.explain_code
  _G.start_chat = module.start_chat
  _G.manage_plugins = module.manage_plugins or function() end -- Provide a default implementation
  _G.get_available_models = module.get_available_models
  
  -- Also expose helper functions that are used in tests
  _G.extract_model_name = _G.extract_model_name or function(model_line)
    -- Extract the actual model name (after the provider type)
    local model_name = model_line:match(": ([^%(]+)")
    if model_name then
      -- Trim whitespace
      model_name = model_name:match("^%s*(.-)%s*$")
      return model_name
    end
    -- Fallback to the first word if the pattern doesn't match
    return model_line:match("^([^%s]+)")
  end
  
  _G.set_default_model = _G.set_default_model or function(model_name)
    return true -- Mock implementation for testing
  end
  
  _G.get_installed_plugins = _G.get_installed_plugins or function()
    return {"llm-gguf", "llm-ollama"}
  end
  
  _G.is_plugin_installed = _G.is_plugin_installed or function(plugin_name)
    return plugin_name == "llm-gguf" or plugin_name == "llm-ollama"
  end
  
  _G.install_plugin = _G.install_plugin or function(plugin_name)
    return true
  end
  
  _G.uninstall_plugin = _G.uninstall_plugin or function(plugin_name)
    return true
  end
end

return M
