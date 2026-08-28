require('spec_helper')

describe('llm.commands', function() -- This is a new test suite for llm.commands
  local commands
  local api_mock
  local ui_mock

  before_each(function()
    -- Mock the llm.api module
    api_mock = {
      run_streaming_command = spy.new(function(cmd_parts, prompt, callbacks)
        api_mock.run_streaming_command.calls = { { cmd_parts, prompt, callbacks } }
      end),
    }
    package.loaded['llm.api'] = api_mock

    -- Mock the llm.core.utils.ui module
    ui_mock = {
      append_to_buffer = spy.new(function() end), -- Mock the append_to_buffer function
    }
    package.loaded['llm.core.utils.ui'] = ui_mock

    -- Mock the llm.config module
    package.loaded['llm.config'] = {
      get = spy.new(function(key)
        if key == 'llm_executable_path' then
          return '/usr/bin/llm'
        elseif key == 'model' then
          return 'test-model'
        elseif key == 'system_prompt' then
          return 'test-system-prompt'
        end
        return nil
      end),
    }

    -- Mock the llm.core.utils.text module
    local text_mock = { get_visual_selection = spy.new(function() return 'selected text' end) }
    package.loaded['llm.core.utils.text'] = text_mock

    -- Clear the commands module from package.loaded to ensure a fresh load
    package.loaded['llm.commands'] = nil
    commands = require('llm.commands')
  end)

  after_each(function()
    -- Clean up mocks after each test
    package.loaded['llm.api'] = nil
    package.loaded['llm.core.utils.ui'] = nil
  end)

  describe('get_system_fragment_args', function()
    it('should return empty table if system_fragment is nil', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'system_fragment' then return nil end
        return nil
      end)
      local result = commands.get_system_fragment_args()
      assert.same({}, result)
    end)

    it('should return --sf arguments if system_fragment is a string', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'system_fragment' then return 'sys_frag1' end
        return nil
      end)
      local result = commands.get_system_fragment_args()
      assert.same({ '--sf', 'sys_frag1' }, result)
    end)

    it('should return multiple --sf arguments if system_fragment is a table', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'system_fragment' then return { 'sys_frag1', 'sys_frag2' } end
        return nil
      end)
      local result = commands.get_system_fragment_args()
      assert.same({ '--sf', 'sys_frag1', '--sf', 'sys_frag2' }, result)
    end)
  end)

  describe('Query Option', function()
    it('get_query_arg should return empty if not set', function()
      package.loaded['llm.config'].get = spy.new(function(key) return nil end)
      assert.are.same({}, commands.get_query_arg())
    end)
    it('get_query_arg should return argument if set', function()
      package.loaded['llm.config'].get = spy.new(function(key) if key == 'query' then return 'test-query' end end)
      assert.are.same({"-q", "test-query"}, commands.get_query_arg())
    end)
  end)

  describe('Database Option', function()
    it('get_database_arg should return empty if not set', function()
      package.loaded['llm.config'].get = spy.new(function(key) return nil end)
      assert.are.same({}, commands.get_database_arg())
    end)
    it('get_database_arg should return argument if set', function()
      package.loaded['llm.config'].get = spy.new(function(key) if key == 'database' then return 'test.db' end end)
      assert.are.same({"-d", "test.db"}, commands.get_database_arg())
    end)
  end)

  describe('Logging Options', function()
    it('get_logging_args should return empty if neither is set', function()
      package.loaded['llm.config'].get = spy.new(function(key) return false end)
      assert.are.same({}, commands.get_logging_args())
    end)
    it('get_logging_args should return --no-log if set', function()
      package.loaded['llm.config'].get = spy.new(function(key) if key == 'no_log' then return true end return false end)
      assert.are.same({"--no-log"}, commands.get_logging_args())
    end)
    it('get_logging_args should return --log if set', function()
      package.loaded['llm.config'].get = spy.new(function(key) if key == 'log' then return true end return false end)
      assert.are.same({"--log"}, commands.get_logging_args())
    end)
  end)

  describe('Extended Tool Options', function()
    it('get_functions_arg should return empty if not set', function()
      package.loaded['llm.config'].get = spy.new(function(key) return nil end)
      assert.are.same({}, commands.get_functions_arg())
    end)
    it('get_functions_arg should return argument if set', function()
      package.loaded['llm.config'].get = spy.new(function(key) if key == 'functions' then return 'funcs.py' end end)
      assert.are.same({"--functions", "funcs.py"}, commands.get_functions_arg())
    end)

    it('get_tools_debug_arg should return empty if not set', function()
      package.loaded['llm.config'].get = spy.new(function(key) return nil end)
      assert.are.same({}, commands.get_tools_debug_arg())
    end)
    it('get_tools_debug_arg should return argument if set', function()
      package.loaded['llm.config'].get = spy.new(function(key) if key == 'tools_debug' then return true end end)
      assert.are.same({"--td"}, commands.get_tools_debug_arg())
    end)

    it('get_tools_approve_arg should return empty if not set', function()
      package.loaded['llm.config'].get = spy.new(function(key) return nil end)
      assert.are.same({}, commands.get_tools_approve_arg())
    end)
    it('get_tools_approve_arg should return argument if set', function()
      package.loaded['llm.config'].get = spy.new(function(key) if key == 'tools_approve' then return true end end)
      assert.are.same({"--ta"}, commands.get_tools_approve_arg())
    end)

    it('get_chain_limit_arg should return empty if not set', function()
      package.loaded['llm.config'].get = spy.new(function(key) return nil end)
      assert.are.same({}, commands.get_chain_limit_arg())
    end)
    it('get_chain_limit_arg should return argument if set', function()
      package.loaded['llm.config'].get = spy.new(function(key) if key == 'chain_limit' then return 3 end end)
      assert.are.same({"--cl", "3"}, commands.get_chain_limit_arg())
    end)
  end)

  describe('get_model_options_args', function()
    it('should return empty table if model_options is nil', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'model_options' then return nil end
        return nil
      end)
      local result = commands.get_model_options_args()
      assert.same({}, result)
    end)

    it('should return -o arguments if model_options is a table', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'model_options' then return { temperature = 0.8, top_p = 0.9 } end
        return nil
      end)
      local result = commands.get_model_options_args()
      -- Since pairs order is undefined, we need to check if both are present
      assert.is_true(#result == 6)

      local has_temp = false
      local has_topp = false
      for i = 1, #result, 3 do
        if result[i] == '-o' then
          if result[i+1] == 'temperature' and result[i+2] == '0.8' then
            has_temp = true
          elseif result[i+1] == 'top_p' and result[i+2] == '0.9' then
            has_topp = true
          end
        end
      end

      assert.is_true(has_temp)
      assert.is_true(has_topp)
    end)
  end)

  describe('get_template_params_args', function()
    it('should return empty table if template_params is nil', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'template_params' then return nil end
        return nil
      end)
      local result = commands.get_template_params_args()
      assert.same({}, result)
    end)

    it('should return -p arguments if template_params is a table', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'template_params' then return { name = 'World', age = 30 } end
        return nil
      end)
      local result = commands.get_template_params_args()
      assert.is_true(#result == 6)

      local has_name = false
      local has_age = false
      for i = 1, #result, 3 do
        if result[i] == '-p' then
          if result[i+1] == 'name' and result[i+2] == 'World' then
            has_name = true
          elseif result[i+1] == 'age' and result[i+2] == '30' then
            has_age = true
          end
        end
      end

      assert.is_true(has_name)
      assert.is_true(has_age)
    end)
  end)

  describe('get_template_arg', function()
    it('should return {-t, template_name} if template is set', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'template' then return 'my-template' end
        return nil
      end)
      local result = commands.get_template_arg()
      assert.same({ '-t', 'my-template' }, result)
    end)

    it('should return {} if template is not set', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'template' then return nil end
        return nil
      end)
      local result = commands.get_template_arg()
      assert.same({}, result)
    end)
  end)

  describe('get_no_stream_arg', function()
    it('get_no_stream_arg should return empty if not set', function()
      package.loaded['llm.config'].get = spy.new(function(key) return nil end)
      local result = commands.get_no_stream_arg()
      assert.are.same({}, result)
    end)

    it('get_no_stream_arg should return argument if set', function()
      package.loaded['llm.config'].get = spy.new(function(key) if key == 'no_stream' then return true end return nil end)
      local result = commands.get_no_stream_arg()
      assert.are.same({"--no-stream"}, result)
    end)
  end)

  describe('get_async_arg', function()
    it('get_async_arg should return empty if not set', function()
      package.loaded['llm.config'].get = spy.new(function(key) return nil end)
      local result = commands.get_async_arg()
      assert.are.same({}, result)
    end)

    it('get_async_arg should return argument if set', function()
      package.loaded['llm.config'].get = spy.new(function(key) if key == 'async' then return true end return nil end)
      local result = commands.get_async_arg()
      assert.are.same({"--async"}, result)
    end)
  end)

  describe('get_save_template_arg', function()
    it('should return {--save, template_name} if save is set', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'save' then return 'my-template' end
        return nil
      end)
      local result = commands.get_save_template_arg()
      assert.same({ '--save', 'my-template' }, result)
    end)

    it('should return {} if save is not set', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'save' then return nil end
        return nil
      end)
      local result = commands.get_save_template_arg()
      assert.same({}, result)
    end)
  end)

  describe('get_schema_args', function()
    it('should return {--schema, schema} if schema is set', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'schema' then return 'test-schema' end
        return nil
      end)
      local result = commands.get_schema_args()
      assert.same({ '--schema', 'test-schema' }, result)
    end)

    it('should return {--schema-multi, schema_multi} if schema_multi is set', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'schema_multi' then return 'test-schema-multi' end
        return nil
      end)
      local result = commands.get_schema_args()
      assert.same({ '--schema-multi', 'test-schema-multi' }, result)
    end)

    it('should return {} if neither are set', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        return nil
      end)
      local result = commands.get_schema_args()
      assert.same({}, result)
    end)
  end)

  describe('get_usage_arg', function()
    it('should return {-u} if usage is true', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'usage' then return true end
        return nil
      end)
      local result = commands.get_usage_arg()
      assert.same({ '-u' }, result)
    end)

    it('should return {} if usage is false', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'usage' then return false end
        return nil
      end)
      local result = commands.get_usage_arg()
      assert.same({}, result)
    end)
  end)

  describe('get_extract_arg', function()
    it('should return {-x} if extract is true', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'extract' then return true end
        return nil
      end)
      local result = commands.get_extract_arg()
      assert.same({ '-x' }, result)
    end)

    it('should return {} if extract is false', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'extract' then return false end
        return nil
      end)
      local result = commands.get_extract_arg()
      assert.same({}, result)
    end)
  end)

  describe('get_attachment_type_args', function()
    it('should return empty table if attachment_type is nil', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'attachment_type' then return nil end
        return nil
      end)
      local result = commands.get_attachment_type_args()
      assert.same({}, result)
    end)

    it('should return --at argument if attachment_type is a string', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'attachment_type' then return 'image/png' end
        return nil
      end)
      local result = commands.get_attachment_type_args()
      assert.same({ '--at', 'image/png' }, result)
    end)
  end)

  describe('get_attachment_args', function()
    it('should return empty table if attachment is nil', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'attachment' then return nil end
        return nil
      end)
      local result = commands.get_attachment_args()
      assert.same({}, result)
    end)

    it('should return -a arguments if attachment is a string', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'attachment' then return 'test_image.png' end
        return nil
      end)
      local result = commands.get_attachment_args()
      assert.same({ '-a', 'test_image.png' }, result)
    end)

    it('should return multiple -a arguments if attachment is a table', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'attachment' then return { 'image1.png', 'image2.png' } end
        return nil
      end)
      local result = commands.get_attachment_args()
      assert.same({ '-a', 'image1.png', '-a', 'image2.png' }, result)
    end)
  end)

  describe('get_conversation_args', function()
    it('should return {--cid, cid} if conversation_id is set', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'conversation_id' then return 'test-id' end
        return nil
      end)
      local result = commands.get_conversation_args()
      assert.same({ '--cid', 'test-id' }, result)
    end)

    it('should return {-c} if continue_conversation is true', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'continue_conversation' then return true end
        return nil
      end)
      local result = commands.get_conversation_args()
      assert.same({ '-c' }, result)
    end)

    it('should return {} if neither are set', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        return nil
      end)
      local result = commands.get_conversation_args()
      assert.same({}, result)
    end)
  end)

  describe('prompt', function()
    it('should call api.run_streaming_command with the correct arguments', function()
      commands.prompt('test prompt', {}, 1)

      assert.spy(api_mock.run_streaming_command).was.called()
      local call_args = api_mock.run_streaming_command.calls[1]
      assert.same({ '/usr/bin/llm', '-m', 'test-model', '-s', 'test-system-prompt' }, call_args[1])
      assert.are.equal('test prompt', call_args[2])
    end)

    it('should handle on_exit callback', function()
      local on_exit_spy = spy.new(function() end)
      commands.prompt('test prompt', {}, 1, on_exit_spy)

      assert.spy(api_mock.run_streaming_command).was.called()
      local call_args = api_mock.run_streaming_command.calls[1]
      local callbacks = call_args[3]

      callbacks.on_exit()
      assert.spy(on_exit_spy).was.called()
    end)

    it('should append data to the buffer on stdout', function()
      commands.prompt('test prompt', {}, 1)

      local call_args = api_mock.run_streaming_command.calls[1]
      local callbacks = call_args[3]
      callbacks.on_stdout(nil, { 'test output' })

      assert.spy(ui_mock.append_to_buffer).was.called_with(1, 'test output\n', 'LlmModelResponse')
    end)
  end)

  describe('prompt_with_current_file', function()
    it('should call api.run_streaming_command with the correct arguments', function()
      -- Mock vim.fn.expand to return a dummy file path
      vim.fn.expand = spy.new(function() return '/path/to/file.lua' end)

      commands.prompt_with_current_file('test prompt', {}, 1)

      assert.spy(api_mock.run_streaming_command).was.called()
      local call_args = api_mock.run_streaming_command.calls[1]
      assert.same({ '/usr/bin/llm', '-m', 'test-model', '-s', 'test-system-prompt', '-f', '/path/to/file.lua' }, call_args[1])
      assert.are.equal('test prompt', call_args[2])
    end)

    it('should append data to the buffer on stdout', function()
      -- Mock vim.fn.expand to return a dummy file path
      vim.fn.expand = spy.new(function() return '/path/to/file.lua' end)

      commands.prompt_with_current_file('test prompt', {}, 1)

      local call_args = api_mock.run_streaming_command.calls[1]
      local callbacks = call_args[3]
      callbacks.on_stdout(nil, { 'test output' })

      assert.spy(ui_mock.append_to_buffer).was.called_with(1, 'test output\n', 'LlmModelResponse')
    end)
  end)

  describe('prompt_with_selection', function()
    it('should return early if write_context_to_temp_file returns empty string', function()
      -- Mock dependencies
      commands.write_context_to_temp_file = spy.new(function() return '' end)

      commands.prompt_with_selection('test prompt', {}, true, 1)

      assert.spy(api_mock.run_streaming_command).was_not_called()
    end)

    it('should call api.run_streaming_command with the correct arguments', function()
      -- Mock dependencies
      commands.write_context_to_temp_file = spy.new(function() return '/tmp/temp_file' end)
      os.remove = spy.new(function() end)

      commands.prompt_with_selection('test prompt', {}, true, 1)

      assert.spy(api_mock.run_streaming_command).was.called()
      local call_args = api_mock.run_streaming_command.calls[1]
      assert.same({ '/usr/bin/llm', '-m', 'test-model', '-s', 'test-system-prompt', '-f', '/tmp/temp_file' }, call_args[1])
      assert.are.equal('test prompt', call_args[2])

      -- Test on_exit callback
      local callbacks = call_args[3]
      callbacks.on_exit()
      -- os.remove is no longer called manually
    end)
  end)
end)