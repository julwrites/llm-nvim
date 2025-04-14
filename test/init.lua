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
end

-- Mock function for llm command execution
function M.mock_llm_command(expected_cmd, return_value)
  -- Store original io.popen
  local original_popen = io.popen
  
  -- Mock io.popen
  io.popen = function(cmd)
    assert(cmd:match(expected_cmd), 
      string.format("Expected command to match '%s', got '%s'", expected_cmd, cmd))
    
    return {
      read = function() return return_value end,
      close = function() return true end
    }
  end
  
  -- Return cleanup function
  return function()
    io.popen = original_popen
  end
end

return M
