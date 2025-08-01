require('tests.spec.spec_helper')

describe('llm.chat', function()
  local chat
  local mock_job
  local mock_ui
  local mock_api

  before_each(function()
    -- Mock the job runner
    mock_job = {
      run = spy.new(function() end),
    }
    package.loaded['llm.core.utils.job'] = mock_job

    -- Mock the ui module
    mock_ui = {
      create_split_buffer = spy.new(function() end),
      append_to_buffer = spy.new(function() end),
    }
    package.loaded['llm.core.utils.ui'] = mock_ui

    -- Mock the vim api
    mock_api = {
      nvim_get_current_buf = spy.new(function()
        return 1
      end),
      nvim_buf_get_lines = spy.new(function()
        return { 'This is the user prompt' }
      end),
      nvim_buf_set_lines = spy.new(function() end),
    }
    vim.api = mock_api

    -- Load the chat module
    package.loaded['llm.chat'] = nil
    chat = require('llm.chat')
  end)

  after_each(function()
    package.loaded['llm.core.utils.job'] = nil
    package.loaded['llm.core.utils.ui'] = nil
  end)

  describe('start_chat', function()
    it('should create a split buffer', function()
      chat.start_chat()
      assert.spy(mock_ui.create_split_buffer).was.called()
    end)
  end)

  describe('send_prompt', function()
    it('should call job.run', function()
      chat.send_prompt()
      assert.spy(mock_job.run).was.called()
    end)

    it('should add visual separators', function()
      chat.send_prompt()
      assert.spy(mock_api.nvim_buf_set_lines).was.called_with(1, 0, -1, false, {})
      assert.spy(mock_ui.append_to_buffer).was.called_with(1, "--- Prompt ---\nThis is the user prompt\n")
      assert.spy(mock_ui.append_to_buffer).was.called_with(1, "--- Response ---\n")
    end)
  end)
end)
