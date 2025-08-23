require('spec_helper')

describe('llm.chat', function()
  local chat
  local api_mock
  local ui_mock
  local commands_mock

  before_each(function()
    -- Mock dependencies
    api_mock = {
      run_streaming_command = spy.new(function(cmd_parts, prompt, callbacks) 
        api_mock.run_streaming_command.calls = { { cmd_parts, prompt, callbacks } }
      end),
    }
    package.loaded['llm.api'] = api_mock

    ui_mock = {
      create_chat_buffer = spy.new(function() return 1 end),
      append_to_buffer = spy.new(function() end),
    }
    package.loaded['llm.core.utils.ui'] = ui_mock

    commands_mock = {
      get_llm_executable_path = spy.new(function() return '/usr/bin/llm' end),
      get_model_arg = spy.new(function() return { '-m', 'test-model' } end),
      get_system_arg = spy.new(function() return { '-s', 'test-system-prompt' } end),
    }
    package.loaded['llm.commands'] = commands_mock

    -- Mock vim functions
    vim.api.nvim_get_current_buf = spy.new(function() return 1 end)
    vim.api.nvim_win_get_cursor = spy.new(function() return { 3, 0 } end)
    vim.api.nvim_buf_get_lines = spy.new(function() return { '---', '--- You ---', '> test prompt' } end)
    vim.api.nvim_buf_line_count = spy.new(function() return 4 end)
    vim.api.nvim_win_set_cursor = spy.new(function() end)
    vim.api.nvim_buf_set_lines = spy.new(function() end)
    vim.cmd = spy.new(function() end)

    package.loaded['llm.chat'] = nil
    chat = require('llm.chat')
  end)

  after_each(function()
    package.loaded['llm.api'] = nil
    package.loaded['llm.core.utils.ui'] = nil
    package.loaded['llm.commands'] = nil
  end)

  describe('send_prompt', function()
    it('should call api.run_streaming_command with the correct arguments', function()
      chat.send_prompt()

      assert.spy(api_mock.run_streaming_command).was.called()
      local call_args = api_mock.run_streaming_command.calls[1]
      assert.same({ '/usr/bin/llm', '-m', 'test-model', '-s', 'test-system-prompt' }, call_args[1])
      assert.are.equal('> test prompt', call_args[2])
    end)

    it('should filter startup messages on stdout', function()
      chat.send_prompt()

      local call_args = api_mock.run_streaming_command.calls[1]
      local callbacks = call_args[3]
      callbacks.on_stdout(nil, { 'Chatting with test-model', 'test output' })

      assert.spy(ui_mock.append_to_buffer).was.called_with(1, 'test output\n', 'LlmModelResponse')
    end)

    it('should re-prompt on exit', function()
      chat.send_prompt()

      local call_args = api_mock.run_streaming_command.calls[1]
      local callbacks = call_args[3]
      callbacks.on_exit(nil, 0)

      assert.spy(ui_mock.append_to_buffer).was.called_with(1, ">  ", "LlmUserPrompt")
    end)
  end)
end)
