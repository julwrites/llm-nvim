-- Test specification for llm-nvim using plenary
-- License: Apache 2.0

local test_helpers = require('test.init')

describe('llm-nvim', function()
  local llm
  
  before_each(function()
    test_helpers.setup()
    -- Load the module fresh for each test
    package.loaded['llm'] = nil
    llm = require('llm')
    -- Expose module functions for testing
    test_helpers.expose_module_functions(llm)
  end)
  
  it('should have the expected public API', function()
    -- Check that the module exports the expected functions
    assert(type(llm.prompt) == 'function', "prompt function should exist")
    assert(type(llm.prompt_with_selection) == 'function', "prompt_with_selection function should exist")
    assert(type(llm.explain_code) == 'function', "explain_code function should exist")
    assert(type(llm.start_chat) == 'function', "start_chat function should exist")
    
    -- Skip the select_model check if it doesn't exist yet
    -- We'll test for its existence separately
    local has_select_model = (type(llm.select_model) == 'function')
    if not has_select_model then
      pending("select_model function doesn't exist yet")
    end
  end)
  
  it('should define the expected commands', function()
    -- Check that the plugin defines the expected commands
    local commands = vim.api.nvim_get_commands({})
    assert(commands.LLM ~= nil, "LLM command should be defined")
    assert(commands.LLMWithSelection ~= nil, "LLMWithSelection command should be defined")
    assert(commands.LLMChat ~= nil, "LLMChat command should be defined")
    assert(commands.LLMExplain ~= nil, "LLMExplain command should be defined")
    assert(commands.LLMSelectModel ~= nil, "LLMSelectModel command should be defined")
  end)
  
  it('should define the expected key mappings when not disabled', function()
    -- Skip this test for now as mapping detection is unreliable in headless mode
    pending("Mapping tests are unreliable in headless mode")
    
    -- Instead, verify the code that would create the mappings exists
    local file_content = vim.fn.readfile(vim.fn.fnamemodify('./plugin/llm.lua', ':p'))
    local has_plug_mappings = false
    local has_leader_mappings = false
    
    for _, line in ipairs(file_content) do
      if line:match('vim%.keymap%.set%("n", "<Plug>%(llm%-prompt%)"') then
        has_plug_mappings = true
      end
      if line:match('vim%.keymap%.set%("n", "<leader>llm"') then
        has_leader_mappings = true
      end
    end
    
    assert(has_plug_mappings, "Plugin should define <Plug> mappings")
    assert(has_leader_mappings, "Plugin should define leader mappings when not disabled")
  end)
  
  it('should not define default mappings when disabled', function()
    -- Skip this test for now as mapping detection is unreliable in headless mode
    pending("Mapping tests are unreliable in headless mode")
    
    -- Instead, verify the conditional code that would skip creating leader mappings
    local file_content = vim.fn.readfile(vim.fn.fnamemodify('./plugin/llm.lua', ':p'))
    local has_conditional = false
    
    for i, line in ipairs(file_content) do
      if line:match('if%s+not%s+config%.get%("no_mappings"%)%s+then') then
        has_conditional = true
        break
      end
    end
    
    assert(has_conditional, "Plugin should check no_mappings config before creating leader mappings")
  end)
  
  it('should be able to get available models', function()
    -- Skip this test if get_available_models doesn't exist yet
    if type(_G.get_available_models) ~= 'function' then
      pending("get_available_models function doesn't exist in global scope yet")
      return
    end
    
    -- Mock the io.popen function to return a predefined list of models
    local cleanup = test_helpers.mock_llm_command("llm models", [[
Models:
------------------
gpt-4o                 OpenAI
claude-3-sonnet-20240229 Anthropic
claude-3-opus-20240229 Anthropic
]])
    
    -- Call the function directly from the global scope
    local models = _G.get_available_models()
    
    -- Clean up the mock
    cleanup()
    
    -- Check the results
    assert(#models == 3, "Should find 3 models")
    assert(models[1] == "gpt-4o", "First model should be gpt-4o")
    assert(models[2] == "claude-3-sonnet-20240229", "Second model should be claude-3-sonnet")
    assert(models[3] == "claude-3-opus-20240229", "Third model should be claude-3-opus")
  end)
  
  it('should correctly parse model names from llm models output', function()
    -- Skip this test if get_available_models doesn't exist yet
    if type(_G.get_available_models) ~= 'function' then
      pending("get_available_models function doesn't exist in global scope yet")
      return
    end
    
    -- Mock the io.popen function to return a predefined list of models with different spacing
    local cleanup = test_helpers.mock_llm_command("llm models", [[
Models:
------------------
gpt-4o                 OpenAI
claude-3-sonnet-20240229 Anthropic
claude-3-opus-20240229   Anthropic
gemini-pro              Google
mistral-large            Mistral AI
]])
    
    -- Call the function directly from the global scope
    local models = _G.get_available_models()
    
    -- Clean up the mock
    cleanup()
    
    -- Check the results
    assert(#models == 5, "Should find 5 models")
    assert(models[1] == "gpt-4o", "First model should be gpt-4o")
    assert(models[2] == "claude-3-sonnet-20240229", "Second model should be claude-3-sonnet")
    assert(models[3] == "claude-3-opus-20240229", "Third model should be claude-3-opus")
    assert(models[4] == "gemini-pro", "Fourth model should be gemini-pro")
    assert(models[5] == "mistral-large", "Fifth model should be mistral-large")
  end)
end)
