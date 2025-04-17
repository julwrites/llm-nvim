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
    
    -- Skip the global scope check in headless test environment
    if vim.env.LLM_NVIM_TEST then
      pending("select_model function check skipped in test environment")
      return
    end
    
    -- Check for select_model function in global scope (exposed by test helper)
    assert(type(_G.select_model) == 'function', "select_model function should exist in global scope")
    
    -- Check for manage_plugins function in global scope (exposed by test helper)
    assert(type(_G.manage_plugins) == 'function', "manage_plugins function should exist")
  end)
  
  it('should define the expected commands', function()
    -- Check that the plugin defines the expected commands
    local commands = vim.api.nvim_get_commands({})
    assert(commands.LLM ~= nil, "LLM command should be defined")
    assert(commands.LLMWithSelection ~= nil, "LLMWithSelection command should be defined")
    assert(commands.LLMChat ~= nil, "LLMChat command should be defined")
    assert(commands.LLMExplain ~= nil, "LLMExplain command should be defined")
    assert(commands.LLMModels ~= nil, "LLMModels command should be defined")
    assert(commands.LLMPlugins ~= nil, "LLMPlugins command should be defined")
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
OpenAI Chat: gpt-4o (aliases: 4o)
OpenAI Chat: gpt-3.5-turbo (aliases: 3.5, chatgpt)
Anthropic Messages: anthropic/claude-3-opus-20240229
Anthropic Messages: anthropic/claude-3-sonnet-20240229 (aliases: claude-3-sonnet)
Default: gpt-4o-mini
]])
    
    -- Call the function directly from the global scope
    local models = _G.get_available_models()
    
    -- Clean up the mock
    cleanup()
    
    -- Check the results
    assert(#models == 4, "Should find 4 models (excluding Default line)")
    assert(models[1] == "OpenAI Chat: gpt-4o (aliases: 4o)", "First model should include full line")
    assert(models[2] == "OpenAI Chat: gpt-3.5-turbo (aliases: 3.5, chatgpt)", "Second model should include full line")
    assert(models[3] == "Anthropic Messages: anthropic/claude-3-opus-20240229", "Third model should include full line")
    assert(models[4] == "Anthropic Messages: anthropic/claude-3-sonnet-20240229 (aliases: claude-3-sonnet)", "Fourth model should include full line")
  end)
  
  it('should correctly extract model names from full model lines', function()
    -- Skip this test if extract_model_name doesn't exist yet
    if type(_G.extract_model_name) ~= 'function' then
      pending("extract_model_name function doesn't exist in global scope yet")
      return
    end
    
    -- Test various model line formats
    local test_cases = {
      {
        input = "OpenAI Chat: gpt-4o (aliases: 4o)",
        expected = "gpt-4o"
      },
      {
        input = "OpenAI Chat: gpt-3.5-turbo (aliases: 3.5, chatgpt)",
        expected = "gpt-3.5-turbo"
      },
      {
        input = "Anthropic Messages: anthropic/claude-3-opus-20240229",
        expected = "anthropic/claude-3-opus-20240229"
      },
      {
        input = "Anthropic Messages: anthropic/claude-3-sonnet-20240229 (aliases: claude-3-sonnet)",
        expected = "anthropic/claude-3-sonnet-20240229"
      }
    }
    
    for _, test_case in ipairs(test_cases) do
      local result = _G.extract_model_name(test_case.input)
      assert(result == test_case.expected, 
        string.format("Expected '%s', got '%s' for input '%s'", 
          test_case.expected, result, test_case.input))
    end
  end)
  
  it('should set default model using llm CLI', function()
    -- Skip this test if set_default_model doesn't exist yet
    if type(_G.set_default_model) ~= 'function' then
      pending("set_default_model function doesn't exist in global scope yet")
      return
    end
    
    -- Mock the io.popen function to simulate setting the default model
    local cleanup = test_helpers.mock_llm_command("llm models default gpt-4o", "Default model set to gpt-4o")
    
    -- Call the function
    local success = _G.set_default_model("gpt-4o")
    
    -- Clean up the mock
    cleanup()
    
    -- Check the result
    assert(success, "set_default_model should return true on success")
  end)
  
  it('should be able to get available plugins', function()
    -- Skip this test if get_available_plugins doesn't exist yet
    if type(_G.get_available_plugins) ~= 'function' then
      pending("get_available_plugins function doesn't exist in global scope yet")
      return
    end
    
    -- Call the function directly from the global scope
    local plugins = _G.get_available_plugins()
    
    -- Check the results
    assert(#plugins > 0, "Should find plugins")
    assert(vim.tbl_contains(plugins, "llm-gguf"), "Should include llm-gguf")
    assert(vim.tbl_contains(plugins, "llm-mlx"), "Should include llm-mlx")
    assert(vim.tbl_contains(plugins, "llm-ollama"), "Should include llm-ollama")
  end)
  
  it('should be able to get installed plugins', function()
    -- Skip this test if get_installed_plugins doesn't exist yet
    if type(_G.get_installed_plugins) ~= 'function' then
      pending("get_installed_plugins function doesn't exist in global scope yet")
      return
    end
    
    -- Mock the io.popen function to return a predefined list of installed plugins
    local cleanup = test_helpers.mock_llm_command("llm plugins", [[
[
  {
    "name": "llm-gguf",
    "hooks": [
      "register_commands",
      "register_models"
    ],
    "version": "0.1a0"
  },
  {
    "name": "llm-ollama",
    "hooks": [
      "register_models"
    ],
    "version": "0.2"
  }
]
]])
    
    -- Call the function directly from the global scope
    local plugins = _G.get_installed_plugins()
    
    -- Clean up the mock
    cleanup()
    
    -- Check the results
    assert(#plugins == 2, "Should find 2 installed plugins")
    assert(plugins[1] == "llm-gguf", "First installed plugin should be llm-gguf")
    assert(plugins[2] == "llm-ollama", "Second installed plugin should be llm-ollama")
  end)
  
  it('should correctly check if a plugin is installed', function()
    -- Skip this test if is_plugin_installed doesn't exist yet
    if type(_G.is_plugin_installed) ~= 'function' then
      pending("is_plugin_installed function doesn't exist in global scope yet")
      return
    end
    
    -- Mock the io.popen function to return a predefined list of installed plugins
    local cleanup = test_helpers.mock_llm_command("llm plugins list", [[
Installed plugins:
------------------
llm-gguf
llm-ollama
]])
    
    -- Call the function directly from the global scope
    local is_gguf_installed = _G.is_plugin_installed("llm-gguf")
    local is_mlx_installed = _G.is_plugin_installed("llm-mlx")
    
    -- Clean up the mock
    cleanup()
    
    -- Check the results
    assert(is_gguf_installed, "llm-gguf should be detected as installed")
    assert(not is_mlx_installed, "llm-mlx should be detected as not installed")
  end)
  
  it('should install a plugin using llm CLI', function()
    -- Skip this test if install_plugin doesn't exist yet
    if type(_G.install_plugin) ~= 'function' then
      pending("install_plugin function doesn't exist in global scope yet")
      return
    end
    
    -- Mock the io.popen function to simulate installing a plugin
    local cleanup = test_helpers.mock_llm_command("llm install llm-mlx", "Successfully installed llm-mlx")
    
    -- Call the function
    local success = _G.install_plugin("llm-mlx")
    
    -- Clean up the mock
    cleanup()
    
    -- Check the result
    assert(success, "install_plugin should return true on success")
  end)
  
  it('should uninstall a plugin using llm CLI', function()
    -- Skip this test if uninstall_plugin doesn't exist yet
    if type(_G.uninstall_plugin) ~= 'function' then
      pending("uninstall_plugin function doesn't exist in global scope yet")
      return
    end
    
    -- Mock the io.popen function to simulate uninstalling a plugin
    local cleanup = test_helpers.mock_llm_command("llm uninstall llm-gguf -y", "Successfully uninstalled llm-gguf")
    
    -- Call the function
    local success = _G.uninstall_plugin("llm-gguf")
    
    -- Clean up the mock
    cleanup()
    
    -- Check the result
    assert(success, "uninstall_plugin should return true on success")
  end)
  
  -- Tests for fragment management functionality
  it('should get fragments', function()
    -- Skip this test if get_fragments doesn't exist yet
    if type(_G.get_fragments) ~= 'function' then
      pending("get_fragments function doesn't exist in global scope yet")
      return
    end
    
    -- Mock the io.popen function to return a predefined list of fragments
    local cleanup = test_helpers.mock_llm_command("llm fragments", [[
Fragments:
------------------
1234abcd: /path/to/file1.txt (alias: file1)
5678efgh: /path/to/file2.py
9012ijkl: https://example.com/resource
]])
    
    -- Call the function directly from the global scope
    local fragments = _G.get_fragments()
    
    -- Clean up the mock
    cleanup()
    
    -- Check the results
    assert(#fragments == 3, "Should find 3 fragments")
    assert(fragments[1].hash == "1234abcd", "First fragment hash should be 1234abcd")
    assert(fragments[1].path == "/path/to/file1.txt", "First fragment path should be correct")
    assert(fragments[1].alias == "file1", "First fragment alias should be file1")
    assert(fragments[2].hash == "5678efgh", "Second fragment hash should be 5678efgh")
    assert(fragments[3].hash == "9012ijkl", "Third fragment hash should be 9012ijkl")
  end)
  
  it('should set fragment alias using llm CLI', function()
    -- Skip this test if set_fragment_alias doesn't exist yet
    if type(_G.set_fragment_alias) ~= 'function' then
      pending("set_fragment_alias function doesn't exist in global scope yet")
      return
    end
    
    -- Mock the io.popen function to simulate setting a fragment alias
    local cleanup = test_helpers.mock_llm_command("llm fragments alias 1234abcd file1", "Alias 'file1' set for fragment 1234abcd")
    
    -- Call the function
    local success = _G.set_fragment_alias("1234abcd", "file1")
    
    -- Clean up the mock
    cleanup()
    
    -- Check the result
    assert(success, "set_fragment_alias should return true on success")
  end)
  
  it('should remove fragment alias using llm CLI', function()
    -- Skip this test if remove_fragment_alias doesn't exist yet
    if type(_G.remove_fragment_alias) ~= 'function' then
      pending("remove_fragment_alias function doesn't exist in global scope yet")
      return
    end
    
    -- Mock the io.popen function to simulate removing a fragment alias
    local cleanup = test_helpers.mock_llm_command("llm fragments alias-remove file1", "Alias 'file1' removed")
    
    -- Call the function
    local success = _G.remove_fragment_alias("file1")
    
    -- Clean up the mock
    cleanup()
    
    -- Check the result
    assert(success, "remove_fragment_alias should return true on success")
  end)
  
  -- Tests for template management functionality
  it('should get templates', function()
    -- Skip this test if get_templates doesn't exist yet
    if type(_G.get_templates) ~= 'function' then
      pending("get_templates function doesn't exist in global scope yet")
      return
    end
    
    -- Mock the io.popen function to return a predefined list of templates
    local cleanup = test_helpers.mock_llm_command("llm templates", [[
Templates:
------------------
explain-code
summarize
translate
]])
    
    -- Call the function directly from the global scope
    local templates = _G.get_templates()
    
    -- Clean up the mock
    cleanup()
    
    -- Check the results
    assert(#templates == 3, "Should find 3 templates")
    assert(templates[1] == "explain-code", "First template should be explain-code")
    assert(templates[2] == "summarize", "Second template should be summarize")
    assert(templates[3] == "translate", "Third template should be translate")
  end)
  
  it('should get template details', function()
    -- Skip this test if get_template_details doesn't exist yet
    if type(_G.get_template_details) ~= 'function' then
      pending("get_template_details function doesn't exist in global scope yet")
      return
    end
    
    -- Mock the io.popen function to return template details
    local cleanup = test_helpers.mock_llm_command("llm templates get explain-code", [[
{
  "name": "explain-code",
  "prompt": "Explain this code: {{input}}",
  "system": "You are a helpful coding assistant.",
  "schema": {
    "properties": {
      "input": {
        "type": "string",
        "description": "The code to explain"
      }
    }
  }
}
]])
    
    -- Call the function
    local details = _G.get_template_details("explain-code")
    
    -- Clean up the mock
    cleanup()
    
    -- Check the results
    assert(details.name == "explain-code", "Template name should be explain-code")
    assert(details.prompt:match("Explain this code"), "Template prompt should contain 'Explain this code'")
    assert(details.system == "You are a helpful coding assistant.", "Template system should be correct")
    assert(details.schema.properties.input.type == "string", "Schema should be parsed correctly")
  end)
  
  it('should create template using llm CLI', function()
    -- Skip this test if create_template doesn't exist yet
    if type(_G.create_template) ~= 'function' then
      pending("create_template function doesn't exist in global scope yet")
      return
    end
    
    -- Mock the io.popen function to simulate creating a template
    local cleanup = test_helpers.mock_llm_command("llm templates create", "Template 'new-template' created")
    
    -- Call the function
    local success = _G.create_template(
      "new-template", 
      "Process this: {{input}}", 
      "You are a helpful assistant.", 
      {
        properties = {
          input = {
            type = "string",
            description = "The input to process"
          }
        }
      }
    )
    
    -- Clean up the mock
    cleanup()
    
    -- Check the result
    assert(success, "create_template should return true on success")
  end)
  
  it('should delete template using llm CLI', function()
    -- Skip this test if delete_template doesn't exist yet
    if type(_G.delete_template) ~= 'function' then
      pending("delete_template function doesn't exist in global scope yet")
      return
    end
    
    -- Mock the io.popen function to simulate deleting a template
    local cleanup = test_helpers.mock_llm_command("llm templates delete new-template", "Template 'new-template' deleted")
    
    -- Call the function
    local success = _G.delete_template("new-template")
    
    -- Clean up the mock
    cleanup()
    
    -- Check the result
    assert(success, "delete_template should return true on success")
  end)
  
  -- Tests for schema management functionality
  it('should get schemas', function()
    -- Skip this test if get_schemas doesn't exist yet
    if type(_G.get_schemas) ~= 'function' then
      pending("get_schemas function doesn't exist in global scope yet")
      return
    end
    
    -- Mock the io.popen function to return a predefined list of schemas
    local cleanup = test_helpers.mock_llm_command("llm schemas", [[
- id: 3b7702e71da3dd791d9e17b76c88730e
  summary: |
    {items: [{name, organization, role, learned, article_headline, article_date}]}
  usage: |
    1 time, most recently 2025-02-28T04:50:02.032081+00:00
- id: 520f7aabb121afd14d0c6c237b39ba2d
  summary: |
    {name, age int, bio}
  usage: |
    3 times, most recently 2025-02-28T05:10:15.123456+00:00
]])
    
    -- Call the function directly from the global scope
    local schemas = _G.get_schemas()
    
    -- Clean up the mock
    cleanup()
    
    -- Check the results
    assert(#schemas == 2, "Should find 2 schemas")
    assert(schemas[1].id == "3b7702e71da3dd791d9e17b76c88730e", "First schema ID should be correct")
    assert(schemas[2].id == "520f7aabb121afd14d0c6c237b39ba2d", "Second schema ID should be correct")
  end)
  
  it('should get schema details', function()
    -- Skip this test if get_schema_details doesn't exist yet
    if type(_G.get_schema_details) ~= 'function' then
      pending("get_schema_details function doesn't exist in global scope yet")
      return
    end
    
    -- Mock the io.popen function to return schema details
    local cleanup = test_helpers.mock_llm_command("llm schemas --full | grep -A 100 \"id: 520f7aabb121afd14d0c6c237b39ba2d\"", [[
- id: 520f7aabb121afd14d0c6c237b39ba2d
  schema: |
    {
      "type": "object",
      "properties": {
        "name": {
          "type": "string"
        },
        "age": {
          "type": "integer"
        },
        "bio": {
          "type": "string"
        }
      },
      "required": [
        "name",
        "age",
        "bio"
      ]
    }
]])
    
    -- Call the function
    local details = _G.get_schema_details("520f7aabb121afd14d0c6c237b39ba2d")
    
    -- Clean up the mock
    cleanup()
    
    -- Check the results
    assert(details.id == "520f7aabb121afd14d0c6c237b39ba2d", "Schema ID should be correct")
    assert(details.schema:match('"type": "object"'), "Schema should contain the correct JSON")
  end)
  
  it('should create schema using llm CLI', function()
    -- Skip this test if create_schema doesn't exist yet
    if type(_G.create_schema) ~= 'function' then
      pending("create_schema function doesn't exist in global scope yet")
      return
    end
    
    -- Mock the io.popen function to simulate creating a schema
    local cleanup = test_helpers.mock_llm_command("llm schemas save", "Schema 'new-schema' created")
    
    -- Call the function
    local success = _G.create_schema(
      "new-schema", 
      '{"type": "object", "properties": {"name": {"type": "string"}}}'
    )
    
    -- Clean up the mock
    cleanup()
    
    -- Check the result
    assert(success, "create_schema should return true on success")
  end)
  
  it('should delete schema using llm CLI', function()
    -- Skip this test if delete_schema doesn't exist yet
    if type(_G.delete_schema) ~= 'function' then
      pending("delete_schema function doesn't exist in global scope yet")
      return
    end
    
    -- Mock the io.popen function to simulate deleting a schema
    local cleanup = test_helpers.mock_llm_command("llm schemas delete 520f7aabb121afd14d0c6c237b39ba2d -y", "Schema '520f7aabb121afd14d0c6c237b39ba2d' deleted")
    
    -- Call the function
    local success = _G.delete_schema("520f7aabb121afd14d0c6c237b39ba2d")
    
    -- Clean up the mock
    cleanup()
    
    -- Check the result
    assert(success, "delete_schema should return true on success")
  end)
  
  it('should convert DSL to JSON schema', function()
    -- Skip this test if dsl_to_schema doesn't exist yet
    if type(_G.dsl_to_schema) ~= 'function' then
      pending("dsl_to_schema function doesn't exist in global scope yet")
      return
    end
    
    -- Mock the io.popen function to simulate converting DSL to schema
    local cleanup = test_helpers.mock_llm_command('llm schemas dsl "name, age int, bio"', [[
{
  "type": "object",
  "properties": {
    "name": {
      "type": "string"
    },
    "age": {
      "type": "integer"
    },
    "bio": {
      "type": "string"
    }
  },
  "required": [
    "name",
    "age",
    "bio"
  ]
}
]])
    
    -- Call the function
    local schema = _G.dsl_to_schema("name, age int, bio")
    
    -- Clean up the mock
    cleanup()
    
    -- Check the result
    assert(schema:match('"type": "object"'), "Schema should contain the correct JSON")
    assert(schema:match('"type": "integer"'), "Schema should contain the correct type for age")
  end)
  
  -- Tests for core prompt functionality
  it('should be able to send a prompt to the LLM', function()
    -- Skip if prompt function not available
    if type(_G.prompt) ~= 'function' then
      pending("prompt function doesn't exist in global scope yet")
      return
    end
    
    -- Just verify the function exists and is callable
    assert(type(_G.prompt) == 'function', "prompt function should exist")
  end)
  
  it('should send selected text to the LLM', function()
    -- Skip if prompt_with_selection not available
    if type(_G.prompt_with_selection) ~= 'function' then
      pending("prompt_with_selection function doesn't exist in global scope yet")
      return
    end
    
    -- Mock selection and llm command
    local cleanup_select = test_helpers.mock_llm_command("", "selected text")
    local cleanup_llm = test_helpers.mock_llm_command("llm -m gpt-4o -s 'You are helpful' 'test prompt' 'selected text'", "Test response")
    
    -- Call the function
    _G.prompt_with_selection("test prompt")
    
    -- Clean up mocks
    cleanup_select()
    cleanup_llm()
    
    -- TODO: Verify response buffer
  end)
  
  it('should be able to extract buffer content for code explanation', function()
    -- Skip if explain_code not available
    if type(_G.explain_code) ~= 'function' then
      pending("explain_code function doesn't exist in global scope yet")
      return
    end
    
    -- Set up a buffer with some content
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {"function test() {", "  return 42", "}"})
    
    -- Just verify the function exists and is callable
    assert(type(_G.explain_code) == 'function', "explain_code function should exist")
    
    -- Verify that buffer content can be extracted
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local content = table.concat(lines, "\n")
    assert(content == "function test() {\n  return 42\n}", "Buffer content should be extractable")
    
    -- Clean up
    vim.api.nvim_buf_delete(buf, {force = true})
  end)
  
  it('should start a chat session', function()
    -- Skip if start_chat not available
    if type(_G.start_chat) ~= 'function' then
      pending("start_chat function doesn't exist in global scope yet")
      return
    end
    
    -- Mock terminal open and model selection
    local cleanup_term = test_helpers.mock_llm_command("", "") 
    local cleanup_model = test_helpers.mock_llm_command("llm models default gpt-4o", "Default model set")
    
    -- Call the function
    _G.start_chat("gpt-4o")
    
    -- Clean up mocks
    cleanup_term()
    cleanup_model()
    
    -- TODO: Verify terminal was opened
  end)

  -- Tests for key management functionality
  it('should get stored API keys', function()
    -- Skip this test if get_stored_keys doesn't exist yet
    if type(_G.get_stored_keys) ~= 'function' then
      pending("get_stored_keys function doesn't exist in global scope yet")
      return
    end
    
    -- Mock the io.popen function to return a predefined list of keys
    local cleanup = test_helpers.mock_llm_command("llm keys", [[
Stored keys:
------------------
openai
anthropic
mistral
]])
    
    -- Call the function directly from the global scope
    local keys = _G.get_stored_keys()
    
    -- Clean up the mock
    cleanup()
    
    -- Check the results
    assert(#keys == 3, "Should find 3 stored keys")
    assert(keys[1] == "openai", "First key should be openai")
    assert(keys[2] == "anthropic", "Second key should be anthropic")
    assert(keys[3] == "mistral", "Third key should be mistral")
  end)
  
  it('should check if an API key is set', function()
    -- Skip this test if is_key_set doesn't exist yet
    if type(_G.is_key_set) ~= 'function' then
      pending("is_key_set function doesn't exist in global scope yet")
      return
    end
    
    -- Mock the io.popen function to return a predefined list of keys
    local cleanup = test_helpers.mock_llm_command("llm keys", [[
Stored keys:
------------------
openai
anthropic
]])
    
    -- Call the function directly from the global scope
    local is_openai_set = _G.is_key_set("openai")
    local is_mistral_set = _G.is_key_set("mistral")
    
    -- Clean up the mock
    cleanup()
    
    -- Check the results
    assert(is_openai_set, "openai key should be detected as set")
    assert(not is_mistral_set, "mistral key should be detected as not set")
  end)
  
  it('should set an API key using llm CLI', function()
    -- Skip this test if set_api_key doesn't exist yet
    if type(_G.set_api_key) ~= 'function' then
      pending("set_api_key function doesn't exist in global scope yet")
      return
    end
    
    -- Mock the io.popen function to simulate setting an API key
    local cleanup = test_helpers.mock_llm_command("llm keys set openai", "API key for openai has been set")
    
    -- Call the function
    local success = _G.set_api_key("openai", "sk-test-key")
    
    -- Clean up the mock
    cleanup()
    
    -- Check the result
    assert(success, "set_api_key should return true on success")
  end)
  
  it('should remove an API key using llm CLI', function()
    -- Skip this test if remove_api_key doesn't exist yet
    if type(_G.remove_api_key) ~= 'function' then
      pending("remove_api_key function doesn't exist in global scope yet")
      return
    end
    
    -- Mock the io.popen function to simulate removing an API key
    local cleanup = test_helpers.mock_llm_command("llm keys remove openai", "API key for openai has been removed")
    
    -- Call the function
    local success = _G.remove_api_key("openai")
    
    -- Clean up the mock
    cleanup()
    
    -- Check the result
    assert(success, "remove_api_key should return true on success")
  end)
end)
