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