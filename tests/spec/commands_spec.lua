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
      assert.spy(os.remove).was.called_with('/tmp/temp_file')
    end)
  end)
end)