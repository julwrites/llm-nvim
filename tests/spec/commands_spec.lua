require('spec_helper')

describe('llm.commands', function() -- This is a new test suite for llm.commands
  local commands
  local api_mock
  local ui_mock

  before_each(function()
    -- Mock the llm.api module
    api_mock = {
      run_streaming_command = spy.new(function() end), -- Mock the streaming command function
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
      local run_streaming_command_spy = spy.on(api_mock, 'run_streaming_command')
      commands.prompt('test prompt', {}, 1, '/usr/bin/llm', 'test-model', 'test-system-prompt')

      assert.spy(run_streaming_command_spy).was.called()
      local call_args = run_streaming_command_spy.calls[1]
      assert.same({ '/usr/bin/llm', '-m', 'test-model', '-s', 'test-system-prompt' }, call_args[1])
      assert.are.equal('test prompt', call_args[2])
    end)

    it('should append data to the buffer on stdout', function()
      local run_streaming_command_spy = spy.on(api_mock, 'run_streaming_command')
      commands.prompt('test prompt', {}, 1, '/usr/bin/llm', 'test-model', 'test-system-prompt')

      local call_args = run_streaming_command_spy.calls[1]
      local callbacks = call_args[3]
      callbacks.on_stdout(nil, { 'test output' })

      assert.spy(ui_mock.append_to_buffer).was.called_with(1, 'test output\n', 'LlmModelResponse')
    end)
  end)
end)