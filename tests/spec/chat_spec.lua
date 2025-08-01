require('tests.spec.spec_helper')

describe('llm.chat', function()
  local chat
  local mock_job
  local mock_api

  before_each(function()
    -- Mock the job runner
    mock_job = {
      run = spy.new(function() end),
    }
    package.loaded['llm.core.utils.job'] = mock_job

    -- Mock the vim api for getting buffer content
    local mock_api = {
      nvim_get_current_buf = spy.new(function()
        return 1
      end),
      nvim_buf_get_lines = spy.new(function()
        return { 'This is the user prompt' }
      end),
    }
    vim.api = mock_api

    -- Load the chat module
    package.loaded['llm.chat'] = nil
    chat = require('llm.chat')
  end)

  after_each(function()
    package.loaded['llm.core.utils.job'] = nil
  end)

  describe('send_prompt', function()
    it('should call job.run', function()
      chat.send_prompt()
      assert.spy(mock_job.run).was.called()
    end)
  end)
end)
