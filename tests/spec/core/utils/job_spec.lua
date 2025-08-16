require('tests.spec.spec_helper')

describe('llm.core.utils.job', function()
  local job

  before_each(function()
    -- Fresh module for each test
    package.loaded['llm.core.utils.job'] = nil
    job = require('llm.core.utils.job')
  end)

  describe('on_stdout handling', function()
    it('should handle multiple lines in one chunk', function()
      -- Given
      local on_stdout_spy = spy.new()
      local captured_job_callbacks
      vim.fn.jobstart = function(_, callbacks)
        captured_job_callbacks = callbacks
        return 1
      end

      -- When
      job.run({ 'echo', 'line1\nline2' }, { on_stdout = on_stdout_spy })
      captured_job_callbacks.on_stdout(0, { 'line1\nline2\n' }, 'stdout')

      -- Then
      assert.spy(on_stdout_spy).was.called(1)
      assert.spy(on_stdout_spy).was.called_with(nil, {'line1', 'line2'})
    end)

    it('should handle partial lines', function()
      -- Given
      local on_stdout_spy = spy.new()
      local captured_job_callbacks
      vim.fn.jobstart = function(_, callbacks)
        captured_job_callbacks = callbacks
        return 1
      end

      -- When
      job.run({ 'echo', 'partial' }, { on_stdout = on_stdout_spy })
      captured_job_callbacks.on_stdout(0, { 'part' }, 'stdout')
      captured_job_callbacks.on_stdout(0, { 'ial\n' }, 'stdout')

      -- Then
      assert.spy(on_stdout_spy).was.called(1)
      assert.spy(on_stdout_spy).was.called_with(nil, {'partial'})
    end)

    it('should handle empty lines', function()
      -- Given
      local on_stdout_spy = spy.new()
      local captured_job_callbacks
      vim.fn.jobstart = function(_, callbacks)
        captured_job_callbacks = callbacks
        return 1
      end

      -- When
      job.run({ 'echo', '\n' }, { on_stdout = on_stdout_spy })
      captured_job_callbacks.on_stdout(0, { '\n' }, 'stdout')

      -- Then
      assert.spy(on_stdout_spy).was.called(1)
      assert.spy(on_stdout_spy).was.called_with(nil, {''})
    end)
  end)
end)
