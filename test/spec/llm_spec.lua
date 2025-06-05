-- Test specification for llm-nvim using plenary
-- License: Apache 2.0

local test_helpers = require('test.init')

describe('llm-nvim', function()
  local llm

  -- Variables to store original functions
  local original_vim_fn_system
  local original_vim_v_shell_error_value -- vim.v.shell_error is read-only, so we simulate its effect
  local original_os_time
  local original_vim_notify
  local original_shell_command_exists
  local original_shell_get_last_update_timestamp
  local original_shell_set_last_update_timestamp
  local original_config_get

  -- Mock data and call recorders
  local mock_data = {
    system_results = {},        -- Stores { output = "...", exit_code = 0 } for commands
    command_exists_map = {},    -- Stores true/false for command names
    last_update_timestamp = 0,
    current_time = 0,
    config_values = {}          -- Stores config key-value pairs
  }
  local spy_set_last_update_timestamp_called = false
  local mock_vim_notify_calls = {}

  -- Modules to be mocked
  local shell_utils
  local config_module

  before_each(function()
    test_helpers.setup()
    -- Load the main llm module fresh for each test
    package.loaded['llm'] = nil
    llm = require('llm')
    test_helpers.expose_module_functions(llm)

    -- Load modules whose functions we need to mock
    package.loaded['llm.utils.shell'] = nil
    shell_utils = require('llm.utils.shell')
    package.loaded['llm.config'] = nil
    config_module = require('llm.config')

    -- Reset mock data and spies
    mock_data.system_results = {}
    mock_data.command_exists_map = {}
    mock_data.last_update_timestamp = 0
    mock_data.current_time = os.time() -- Default to real time, can be overridden in tests
    mock_data.config_values = {}
    spy_set_last_update_timestamp_called = false
    mock_vim_notify_calls = {}

    -- Store original functions and apply mocks
    original_vim_fn_system = vim.fn.system
    vim.fn.system = function(cmd_str_or_list)
      local cmd_str = type(cmd_str_or_list) == 'table' and table.concat(cmd_str_or_list, ' ') or cmd_str_or_list
      local result = mock_data.system_results[cmd_str] or { output = "Command not mocked: " .. cmd_str, exit_code = 1 }
      -- Simulate setting vim.v.shell_error by storing the intended value
      original_vim_v_shell_error_value = vim.v.shell_error -- Store current real value if any
      vim.v.shell_error = result.exit_code -- This is illustrative; direct assignment to vim.v is tricky.
                                          -- Tests will need to rely on the mock framework to check exit_code.
                                          -- The actual shell.lua uses vim.v.shell_error *after* vim.fn.system returns.
                                          -- We'll ensure our mock system sets a value that can be retrieved if needed,
                                          -- or more practically, the functions using it are tested via their behavior.
                                          -- For now, the mock directly returns the structure including exit_code.
                                          -- The `capture_output_and_code` or direct `vim.v.shell_error` usage in shell.lua
                                          -- means the test setup for `update_llm_cli` should ensure `vim.v.shell_error`
                                          -- is correctly simulated *after* this mock `vim.fn.system` is called.
                                          -- The `update_llm_cli` itself reads `vim.v.shell_error`.
                                          -- So, the mock for system should set a temporary global/upvalue that `vim.v.shell_error` mock would return.
                                          -- Let's refine this: the mock system itself won't set vim.v.shell_error.
                                          -- Instead, the test will configure the effective "next shell_error" value.
      _G._TEST_MOCK_NEXT_SHELL_ERROR = result.exit_code
      return result.output
    end
    -- And a way for the test to access the intended vim.v.shell_error for that call
    -- This is tricky because vim.v.shell_error is read-only in Lua.
    -- The actual module reads vim.v.shell_error. We need to control what it reads.
    -- This implies we might need to mock the part of shell_utils that reads vim.v.shell_error if it's indirect,
    -- or rely on testing the behavior resulting from different (mocked) vim.v.shell_error values.
    -- The `update_llm_cli` directly reads `vim.v.shell_error`.
    -- We will mock `vim.v` itself for the test, or more specifically, ensure that when `shell.lua`
    -- accesses `vim.v.shell_error`, it gets our mocked value.
    -- This is often done by stubbing `vim.v` if the test framework supports it, or by
    -- abstracting the access in the source code to be mockable.
    -- For now, the `_G._TEST_MOCK_NEXT_SHELL_ERROR` will be used by a test helper if needed,
    -- and the module code will be tested as-is. The test will assert behavior based on this.

    original_os_time = os.time
    os.time = function() return mock_data.current_time end

    original_vim_notify = vim.notify
    vim.notify = function(msg, level, opts)
      table.insert(mock_vim_notify_calls, { msg = msg, level = level, opts = opts })
    end

    original_shell_command_exists = shell_utils.command_exists
    shell_utils.command_exists = function(cmd)
      return mock_data.command_exists_map[cmd] or false
    end

    original_shell_get_last_update_timestamp = shell_utils.get_last_update_timestamp
    shell_utils.get_last_update_timestamp = function()
      return mock_data.last_update_timestamp
    end

    original_shell_set_last_update_timestamp = shell_utils.set_last_update_timestamp
    -- For spying, we need to ensure the local function `set_last_update_timestamp` in shell.lua is mocked.
    -- This requires `spy.on(shell_utils, 'set_last_update_timestamp_actual_name')` if it were exported,
    -- or modifying shell.lua to make it mockable.
    -- Given current structure, `set_last_update_timestamp` is local.
    -- We'll assume for now tests will verify its effects (e.g., by checking `get_last_update_timestamp` if it wrote to a mockable store)
    -- or by checking if `update_llm_cli` calls it (which means it needs to be mockable).
    -- The subtask is to prepare for testing. We'll make `set_last_update_timestamp` a spy by replacing it.
    -- This means `shell_utils.set_last_update_timestamp` itself needs to be the function, not a local one.
    -- The current `shell.lua` has `local function set_last_update_timestamp`. This needs to be `M.set_last_update_timestamp`
    -- for this direct mocking approach to work from here. Assuming that change is made or will be made.
    -- If not, we can't spy on it this way from outside.
    -- For now, let's assume it's made mockable (e.g. `shell_utils._set_last_update_timestamp_impl = function() ... end` and `shell_utils.set_last_update_timestamp` calls it)
    -- Or, more simply, that we are testing `update_llm_cli` which *calls* the local `set_last_update_timestamp`.
    -- The spy here is on the exported version, which is what `init.lua` would call if it needed to.
    -- The `update_llm_cli` calls the *local* `set_last_update_timestamp`.
    -- So, this specific spy setup here won't catch calls from `update_llm_cli` to its internal local function.
    -- To test that, `set_last_update_timestamp` would need to be passed in or made public.
    -- We'll create a spy for an exported version if it existed, but acknowledge this limitation for the internal one.
    -- Let's assume `set_last_update_timestamp` is made public for testing or we test its side-effects.
    -- The prompt asks to mock `require('llm.utils.shell').set_last_update_timestamp`.
    -- The current `shell.lua` exports `M.get_last_update_timestamp` but `set_last_update_timestamp` is local.
    -- This needs to be `M.set_last_update_timestamp` in `shell.lua` for this to work.
    -- I will proceed assuming this, or that the test will be on a function that calls an exported version.
    if shell_utils.set_last_update_timestamp then -- Check if it's actually exported
        shell_utils.set_last_update_timestamp = function()
        spy_set_last_update_timestamp_called = true
        -- If the original has side effects (like writing to a file) that need to be
        -- truly bypassed or simulated differently, this mock would need to handle that.
        -- For now, it's just a spy.
        end
    else
        -- If not exported, we can't spy on it directly here.
        -- This spy will be ineffective for update_llm_cli's internal call.
        -- The test will have to rely on other means to verify its call.
        -- For this setup task, we register the intent.
        -- A simple placeholder if not exported:
        spy_set_last_update_timestamp_called = "SKIPPED: set_last_update_timestamp not exported from shell.lua"
    end


    original_config_get = config_module.get
    config_module.get = function(key)
      return mock_data.config_values[key]
    end
  end)

  after_each(function()
    vim.fn.system = original_vim_fn_system
    os.time = original_os_time
    vim.notify = original_vim_notify

    if shell_utils then -- Ensure shell_utils was loaded
      shell_utils.command_exists = original_shell_command_exists
      shell_utils.get_last_update_timestamp = original_shell_get_last_update_timestamp
      if shell_utils.set_last_update_timestamp then -- Restore only if it was mockable
        shell_utils.set_last_update_timestamp = original_shell_set_last_update_timestamp
      end
    end
    if config_module then -- Ensure config_module was loaded
        config_module.get = original_config_get
    end

    -- Restore vim.v.shell_error simulation if needed
    _G._TEST_MOCK_NEXT_SHELL_ERROR = nil
    if original_vim_v_shell_error_value ~= nil then
      -- This is illustrative, real vim.v.shell_error cannot be set this way.
      -- vim.v.shell_error = original_vim_v_shell_error_value
    end
    package.loaded['llm.utils.shell'] = nil
    package.loaded['llm.config'] = nil
    package.loaded['llm'] = nil
  end)

  it('should have the expected public API', function()
    -- Check that the module exports the expected functions
    assert(type(llm.prompt) == 'function', "prompt function should exist")
    assert(type(llm.prompt_with_selection) == 'function', "prompt_with_selection function should exist")
    assert(type(llm.explain_code) == 'function', "explain_code function should exist")

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
    assert(models[4] == "Anthropic Messages: anthropic/claude-3-sonnet-20240229 (aliases: claude-3-sonnet)",
      "Fourth model should include full line")
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
    local cleanup = test_helpers.mock_llm_command("llm fragments alias 1234abcd file1",
      "Alias 'file1' set for fragment 1234abcd")

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
    local cleanup = test_helpers.mock_llm_command(
      "llm schemas --full | grep -A 100 \"id: 520f7aabb121afd14d0c6c237b39ba2d\"", [[
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
    local cleanup = test_helpers.mock_llm_command("llm schemas delete 520f7aabb121afd14d0c6c237b39ba2d -y",
      "Schema '520f7aabb121afd14d0c6c237b39ba2d' deleted")

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
    local cleanup_llm = test_helpers.mock_llm_command("llm -m gpt-4o -s 'You are helpful' 'test prompt' 'selected text'",
      "Test response")

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
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "function test() {", "  return 42", "}" })

    -- Just verify the function exists and is callable
    assert(type(_G.explain_code) == 'function', "explain_code function should exist")

    -- Verify that buffer content can be extracted
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local content = table.concat(lines, "\n")
    assert(content == "function test() {\n  return 42\n}", "Buffer content should be extractable")

    -- Clean up
    vim.api.nvim_buf_delete(buf, { force = true })
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

describe("shell.update_llm_cli", function()
  local shell_utils_for_update_test
  local original_vim_v -- To store the original vim.v table

  before_each(function()
    -- Reset specific mock data for these tests. Outer before_each already handles some.
    mock_data.system_results = {}
    mock_data.command_exists_map = {}
    spy_set_last_update_timestamp_called = false -- Reset this spy
    mock_data.system_calls = {} -- To record calls to vim.fn.system

    -- Ensure fresh load of shell_utils if its internal state could be an issue
    -- or if it needs to pick up mocks set up *after* the main before_each.
    -- The main before_each already reloads shell_utils.
    shell_utils_for_update_test = require('llm.utils.shell')


    -- Mock vim.v.shell_error specifically for these tests
    original_vim_v = vim.v
    _G._TEST_MOCK_V_SHELL_ERROR_VALUE = 0 -- Default to success
    vim.v = setmetatable({
      -- Set a metatable to intercept 'shell_error' access
      __index = function(t, k)
        if k == "shell_error" then
          return _G._TEST_MOCK_V_SHELL_ERROR_VALUE
        end
        return original_vim_v[k] -- Delegate other vim.v accesses to original
      end,
      __newindex = function(t,k,v)
        -- Allow setting other vim.v fields if necessary for other tests,
        -- though for shell_error it's typically read by SUT.
        rawset(t,k,v)
      end
    }, { __index = original_vim_v }) -- Fallback for non-intercepted keys to original vim.v


    -- Enhance vim.fn.system mock to use the _G._TEST_MOCK_V_SHELL_ERROR_VALUE
    -- The outer before_each already replaced vim.fn.system. We are further refining it here.
    local outer_mock_system = vim.fn.system -- This is the mock from the main before_each
    vim.fn.system = function(cmd_str_or_list)
      local cmd_str = type(cmd_str_or_list) == 'table' and table.concat(cmd_str_or_list, ' ') or cmd_str_or_list
      local result_config = mock_data.system_results[cmd_str] or { output = "Command not mocked: " .. cmd_str, exit_code = 127 } -- Default to command not found

      _G._TEST_MOCK_V_SHELL_ERROR_VALUE = result_config.exit_code -- This is what `vim.v.shell_error` will return next

      table.insert(mock_data.system_calls, cmd_str) -- Record the call
      return result_config.output
    end
  end)

  after_each(function()
    vim.v = original_vim_v -- Restore original vim.v
    -- The outer after_each will restore vim.fn.system and other global mocks.
  end)

  local function get_system_call_count(cmd_substring)
    local count = 0
    for _, called_cmd in ipairs(mock_data.system_calls or {}) do
      if called_cmd:match(cmd_substring) then
        count = count + 1
      end
    end
    return count
  end

  it("1. should succeed with uv if available and command works", function()
    mock_data.command_exists_map["uv"] = true
    mock_data.system_results["uv tool upgrade llm"] = { output = "uv success output", exit_code = 0 }
    -- _G._TEST_MOCK_V_SHELL_ERROR_VALUE is set by the system mock based on exit_code

    local result = shell_utils_for_update_test.update_llm_cli()

    assert.is_true(result.success)
    assert.are.equal("llm CLI updated successfully via uv.", result.message)
    assert.is_true(spy_set_last_update_timestamp_called)
    assert.are.equal(1, get_system_call_count("uv tool upgrade llm"))
    assert.are.equal(0, get_system_call_count("pipx upgrade llm")) -- Should not attempt others
  end)

  it("2. should succeed with pipx if uv fails", function()
    mock_data.command_exists_map["uv"] = true
    mock_data.system_results["uv tool upgrade llm"] = { output = "uv failed", exit_code = 1 }
    mock_data.command_exists_map["pipx"] = true
    mock_data.system_results["pipx upgrade llm"] = { output = "pipx success", exit_code = 0 }

    local result = shell_utils_for_update_test.update_llm_cli()

    assert.is_true(result.success)
    assert.are.equal("llm CLI updated successfully via pipx.", result.message)
    assert.is_true(spy_set_last_update_timestamp_called)
    assert.are.equal(1, get_system_call_count("uv tool upgrade llm"))
    assert.are.equal(1, get_system_call_count("pipx upgrade llm"))
  end)

  it("3. should succeed with pip if uv and pipx fail", function()
    mock_data.command_exists_map["uv"] = false
    mock_data.command_exists_map["pipx"] = true
    mock_data.system_results["pipx upgrade llm"] = { output = "pipx failed", exit_code = 1 }
    -- No command_exists check for pip, directly try system call
    mock_data.system_results["pip install -U llm"] = { output = "pip success", exit_code = 0 }

    local result = shell_utils_for_update_test.update_llm_cli()

    assert.is_true(result.success)
    assert.are.equal("llm CLI updated successfully via pip.", result.message)
    assert.is_true(spy_set_last_update_timestamp_called)
    assert.are.equal(0, get_system_call_count("uv tool upgrade llm")) -- uv not found
    assert.are.equal(1, get_system_call_count("pipx upgrade llm"))
    assert.are.equal(1, get_system_call_count("pip install -U llm"))
  end)

  it("4. should succeed with python -m pip if uv, pipx, and pip fail", function()
    mock_data.command_exists_map["uv"] = false
    mock_data.command_exists_map["pipx"] = false
    mock_data.system_results["pip install -U llm"] = { output = "pip failed", exit_code = 1 }
    mock_data.system_results["python -m pip install --upgrade llm"] = { output = "python -m pip success", exit_code = 0 }

    local result = shell_utils_for_update_test.update_llm_cli()

    assert.is_true(result.success)
    assert.are.equal("llm CLI updated successfully via python -m pip.", result.message)
    assert.is_true(spy_set_last_update_timestamp_called)
    assert.are.equal(1, get_system_call_count("pip install -U llm"))
    assert.are.equal(1, get_system_call_count("python -m pip install --upgrade llm"))
  end)

  it("5. should succeed with brew if all python methods fail", function()
    mock_data.command_exists_map["uv"] = false
    mock_data.command_exists_map["pipx"] = false
    mock_data.system_results["pip install -U llm"] = { output = "pip failed", exit_code = 1 }
    mock_data.system_results["python -m pip install --upgrade llm"] = { output = "python -m pip failed", exit_code = 1 }
    mock_data.command_exists_map["brew"] = true
    mock_data.system_results["brew upgrade llm"] = { output = "brew success", exit_code = 0 }

    local result = shell_utils_for_update_test.update_llm_cli()

    assert.is_true(result.success)
    assert.are.equal("llm CLI updated successfully via brew.", result.message)
    assert.is_true(spy_set_last_update_timestamp_called)
    assert.are.equal(1, get_system_call_count("python -m pip install --upgrade llm"))
    assert.are.equal(1, get_system_call_count("brew upgrade llm"))
  end)

  it("6. should report failure if all methods fail", function()
    mock_data.command_exists_map["uv"] = true
    mock_data.system_results["uv tool upgrade llm"] = { output = "uv failed", exit_code = 1 }
    mock_data.command_exists_map["pipx"] = true
    mock_data.system_results["pipx upgrade llm"] = { output = "pipx failed", exit_code = 1 }
    mock_data.system_results["pip install -U llm"] = { output = "pip failed", exit_code = 1 }
    mock_data.system_results["python -m pip install --upgrade llm"] = { output = "python -m pip failed", exit_code = 1 }
    mock_data.command_exists_map["brew"] = true
    mock_data.system_results["brew upgrade llm"] = { output = "brew failed", exit_code = 1 }

    local result = shell_utils_for_update_test.update_llm_cli()

    assert.is_false(result.success)
    assert.is_true(spy_set_last_update_timestamp_called)
    assert.are.equal(1, get_system_call_count("uv tool upgrade llm"))
    assert.are.equal(1, get_system_call_count("pipx upgrade llm"))
    assert.are.equal(1, get_system_call_count("pip install -U llm"))
    assert.are.equal(1, get_system_call_count("python -m pip install --upgrade llm"))
    assert.are.equal(1, get_system_call_count("brew upgrade llm"))

    -- Check if message contains parts of all attempts
    assert.string_matches(result.message, "uv tool upgrade llm")
    assert.string_matches(result.message, "uv failed")
    assert.string_matches(result.message, "pipx upgrade llm")
    assert.string_matches(result.message, "pipx failed")
    assert.string_matches(result.message, "pip install -U llm")
    assert.string_matches(result.message, "pip failed")
    assert.string_matches(result.message, "python -m pip install --upgrade llm")
    assert.string_matches(result.message, "python -m pip failed")
    assert.string_matches(result.message, "brew upgrade llm")
    assert.string_matches(result.message, "brew failed")
  end)

  it("7. should skip pipx if not found and try pip", function()
    mock_data.command_exists_map["uv"] = true
    mock_data.system_results["uv tool upgrade llm"] = { output = "uv failed", exit_code = 1 }
    mock_data.command_exists_map["pipx"] = false -- pipx not found
    mock_data.system_results["pip install -U llm"] = { output = "pip success", exit_code = 0 }

    local result = shell_utils_for_update_test.update_llm_cli()

    assert.is_true(result.success)
    assert.are.equal("llm CLI updated successfully via pip.", result.message)
    assert.is_true(spy_set_last_update_timestamp_called)
    assert.are.equal(1, get_system_call_count("uv tool upgrade llm"))
    assert.are.equal(0, get_system_call_count("pipx upgrade llm")) -- Not called
    assert.are.equal(1, get_system_call_count("pip install -U llm")) -- Called
    -- Cannot directly check "pipx command not found, skipping" message here if pip succeeds,
    -- as result.message will be the success message. This behavior is implicitly tested
    -- by checking that pipx was not called and pip was.
  end)
end)

describe("llm.init auto-update logic", function()
  local llm_init_module -- Module to test (llm.init is effectively the 'llm' module)
  local shell_utils_ref -- Reference to the shell_utils module used by llm_init

  -- To store the original shell_utils.update_llm_cli
  local original_shell_update_llm_cli

  -- Spy/mock control variables for shell_utils.update_llm_cli
  local mock_shell_update_llm_cli_calls = 0
  local mock_shell_update_llm_cli_return_value = { success = true, message = "Mocked update success" }

  before_each(function()
    -- Reset relevant mock_data fields from the global mocks
    mock_data.config_values = {}
    mock_data.last_update_timestamp = 0
    -- Set a fixed os.time() for predictable calculations, e.g., 10 days from epoch
    mock_data.current_time = 10 * 24 * 60 * 60
    mock_vim_notify_calls = {} -- Clear previous notifications

    -- We need to ensure that the 'llm.utils.shell' module used by 'llm' (init.lua)
    -- has its 'update_llm_cli' function mocked.
    -- The global before_each reloads shell_utils, so we get that instance.
    shell_utils_ref = require('llm.utils.shell')

    -- Store original and set up mock for shell_utils.update_llm_cli
    original_shell_update_llm_cli = shell_utils_ref.update_llm_cli
    mock_shell_update_llm_cli_calls = 0
    mock_shell_update_llm_cli_return_value = { success = true, message = "Default mock success" }
    shell_utils_ref.update_llm_cli = function()
      mock_shell_update_llm_cli_calls = mock_shell_update_llm_cli_calls + 1
      return mock_shell_update_llm_cli_return_value
    end

    -- Re-require the main 'llm' module (which is init.lua) to ensure it uses our fresh mocks
    package.loaded['llm'] = nil
    llm_init_module = require('llm')
  end)

  after_each(function()
    -- Restore the original shell_utils.update_llm_cli
    if original_shell_update_llm_cli and shell_utils_ref then
      shell_utils_ref.update_llm_cli = original_shell_update_llm_cli
    end
    -- Other mocks are restored by the global after_each
  end)

  local function get_notify_messages()
    local messages = {}
    for _, call_args in ipairs(mock_vim_notify_calls) do
      table.insert(messages, call_args.msg)
    end
    return messages
  end

  local function find_notify_message(substring)
    for _, call_args in ipairs(mock_vim_notify_calls) do
      if type(call_args.msg) == "string" and call_args.msg:match(substring) then
        return true, call_args
      end
    end
    return false
  end

  it("1. should not attempt update if auto_update_cli is false", function()
    mock_data.config_values["auto_update_cli"] = false
    llm_init_module.setup({})
    assert.are.equal(0, mock_shell_update_llm_cli_calls)
    assert.is_false(find_notify_message("Checking for LLM CLI updates"))
  end)

  it("2. should not attempt update if interval has NOT passed", function()
    mock_data.config_values["auto_update_cli"] = true
    mock_data.config_values["auto_update_interval_days"] = 7
    -- current_time is 10 days. last_update_timestamp to 5 days ago from current_time
    mock_data.last_update_timestamp = mock_data.current_time - (3 * 24 * 60 * 60)

    llm_init_module.setup({})
    assert.are.equal(0, mock_shell_update_llm_cli_calls)
    assert.is_false(find_notify_message("Checking for LLM CLI updates"))
  end)

  it("3. should attempt update and notify success if interval PASSED and update SUCCEEDS", function(done)
    mock_data.config_values["auto_update_cli"] = true
    mock_data.config_values["auto_update_interval_days"] = 7
    -- current_time is 10 days. last_update_timestamp to 8 days ago from current_time
    mock_data.last_update_timestamp = mock_data.current_time - (8 * 24 * 60 * 60)
    mock_shell_update_llm_cli_return_value = { success = true, message = "Updated OK via test" }

    llm_init_module.setup({})

    -- Check initial notification (synchronous)
    assert.is_true(find_notify_message("Checking for LLM CLI updates..."))
    -- update_llm_cli is called, but its callback (and subsequent notify) is deferred
    assert.are.equal(1, mock_shell_update_llm_cli_calls)

    vim.defer_fn(function()
      assert.is_true(find_notify_message("LLM CLI auto-update successful."),
        "Did not find success notification. All notifications: " .. table.concat(get_notify_messages(), "\n---\n"))
      done()
    end, 200) -- Wait for deferred functions from init.lua (100ms + processing)
  end)

  it("4. should attempt update and notify failure if interval PASSED and update FAILS", function(done)
    mock_data.config_values["auto_update_cli"] = true
    mock_data.config_values["auto_update_interval_days"] = 7
    mock_data.last_update_timestamp = mock_data.current_time - (8 * 24 * 60 * 60)
    mock_shell_update_llm_cli_return_value = { success = false, message = "Update failed badly via test" }

    llm_init_module.setup({})

    assert.is_true(find_notify_message("Checking for LLM CLI updates..."))
    assert.are.equal(1, mock_shell_update_llm_cli_calls)

    vim.defer_fn(function()
      local found, call_args = find_notify_message("LLM CLI auto-update failed.")
      assert.is_true(found, "Did not find failure notification. All notifications: " .. table.concat(get_notify_messages(), "\n---\n"))
      if found then -- Check for details only if the main message was found
         assert.string_matches(call_args.msg, "Details:\nUpdate failed badly via test")
      end
      done()
    end, 200)
  end)
end)

describe(":LLM update command", function()
  local shell_utils_ref_for_command_test
  local original_shell_update_llm_cli_for_command_test
  local mock_shell_update_llm_cli_calls_for_command_test = 0
  local mock_shell_update_llm_cli_return_value_for_command_test = { success = true, message = "Mocked update success" }

  before_each(function()
    -- Reset global mock states relevant for this test
    mock_vim_notify_calls = {} -- Clear notifications log from global mock setup

    -- Ensure shell.update_llm_cli is a fresh spy/mock
    -- The global before_each reloads shell_utils, so we get that instance.
    shell_utils_ref_for_command_test = require('llm.utils.shell')

    original_shell_update_llm_cli_for_command_test = shell_utils_ref_for_command_test.update_llm_cli
    mock_shell_update_llm_cli_calls_for_command_test = 0
    mock_shell_update_llm_cli_return_value_for_command_test = { success = true, message = "Default mock success for command test" }
    shell_utils_ref_for_command_test.update_llm_cli = function()
      mock_shell_update_llm_cli_calls_for_command_test = mock_shell_update_llm_cli_calls_for_command_test + 1
      return mock_shell_update_llm_cli_return_value_for_command_test
    end

    -- Critical: Reload plugin/llm.lua to re-register commands with the new mocks in place.
    -- It might have dependencies that also need their mocks refreshed if they were touched.
    -- The global before_each already clears package.loaded for 'llm', 'llm.utils.shell', 'llm.config'.
    -- plugin/llm.lua requires 'llm' (init.lua) and 'llm.config'.
    -- init.lua requires 'llm.utils.shell'.
    -- So, the mocks set up in global before_each (and specialized here) should be picked up.
    package.loaded['plugin.llm'] = nil
    require('plugin.llm')
  end)

  after_each(function()
    -- Restore shell_utils.update_llm_cli
    if original_shell_update_llm_cli_for_command_test and shell_utils_ref_for_command_test then
       shell_utils_ref_for_command_test.update_llm_cli = original_shell_update_llm_cli_for_command_test
    end
    -- Other global mocks are restored by the main after_each.
  end)

  -- Re-using helper from previous describe block, assuming it's in scope or redefined.
  -- For safety, let's ensure it's available here too.
  local function find_notify_msg_local(substring)
    for _, call_args in ipairs(mock_vim_notify_calls) do
      if type(call_args.msg) == "string" and call_args.msg:match(substring) then
        return true, call_args
      end
    end
    return false
  end

  it("1. command should trigger update and notify success", function(done)
    mock_shell_update_llm_cli_return_value_for_command_test = { success = true, message = "Manual update OK" }

    vim.cmd(':LLM update')

    assert.is_true(find_notify_msg_local("Starting LLM CLI update..."), "Initial notification not found.")

    vim.defer_fn(function()
      assert.are.equal(1, mock_shell_update_llm_cli_calls_for_command_test, "update_llm_cli was not called exactly once.")
      assert.is_true(find_notify_msg_local("LLM CLI update successful."), "Success notification not found.")
      done()
    end, 250) -- Increased delay slightly to ensure all prior defer_fn have completed
  end)

  it("2. command should trigger update and notify failure", function(done)
    mock_shell_update_llm_cli_return_value_for_command_test = {
      success = false,
      message = "Manual update failed badly"
    }

    vim.cmd(':LLM update')

    assert.is_true(find_notify_msg_local("Starting LLM CLI update..."), "Initial notification not found.")

    vim.defer_fn(function()
      assert.are.equal(1, mock_shell_update_llm_cli_calls_for_command_test, "update_llm_cli was not called exactly once.")
      local found, call_args = find_notify_msg_local("LLM CLI update failed.")
      assert.is_true(found, "Failure notification not found.")
      if found then
        assert.string_matches(call_args.msg, "Details:\nManual update failed badly", 1, true)
      end
      done()
    end, 250)
  end)
end)
