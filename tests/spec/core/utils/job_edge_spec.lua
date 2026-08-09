require('tests.spec.spec_helper')

describe('llm.core.utils.job edge cases', function()
  local job

  before_each(function()
    package.loaded['llm.core.utils.job'] = nil
    job = require('llm.core.utils.job')
  end)

  it('should handle partial lines appropriately for nvim jobstart', function()
    local on_stdout_spy = spy.new()
    local captured_job_callbacks
    vim.fn.jobstart = function(_, callbacks)
      captured_job_callbacks = callbacks
      return 1
    end

    job.run({ 'echo', 'test' }, { on_stdout = on_stdout_spy })

    -- Neovim jobstart on_stdout data format: array of strings.
    -- All elements except the last indicate a trailing newline.
    -- The last element is a partial line (or empty string if the line ended in a newline).
    captured_job_callbacks.on_stdout(0, { 'part', 'ial' }, 'stdout')

    -- This should result in 'part' being a full line, and 'ial' being buffered
    assert.spy(on_stdout_spy).was.called(1)
    assert.spy(on_stdout_spy).was.called_with(nil, {'part'})

    captured_job_callbacks.on_stdout(0, { ' is done', '' }, 'stdout')
    -- 'ial is done' should be a full line. '' means it ended in a newline.
    assert.spy(on_stdout_spy).was.called(2)
    assert.spy(on_stdout_spy).was.called_with(nil, {'ial is done'})
  end)

  it('should handle multiple chunks without newlines correctly', function()
    local on_stdout_spy = spy.new()
    local captured_job_callbacks
    vim.fn.jobstart = function(_, callbacks)
      captured_job_callbacks = callbacks
      return 1
    end

    job.run({ 'echo', 'test' }, { on_stdout = on_stdout_spy })
    captured_job_callbacks.on_stdout(0, { 'chunk1' }, 'stdout')
    captured_job_callbacks.on_stdout(0, { 'chunk2' }, 'stdout')
    captured_job_callbacks.on_stdout(0, { 'chunk3', '' }, 'stdout')

    assert.spy(on_stdout_spy).was.called_with(nil, {'chunk1chunk2chunk3'})
  end)
end)
