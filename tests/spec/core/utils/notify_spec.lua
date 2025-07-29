require('tests.spec.spec_helper')

local spy = require('luassert.spy')

describe('llm.core.utils.notify', function()
  local notify

  before_each(function()
    package.loaded['llm.core.utils.notify'] = nil
    notify = require('llm.core.utils.notify')
  end)

  it('should call vim.notify with the correct arguments', function()
    spy.on(vim, 'notify')
    notify.notify('test message', vim.log.levels.INFO, { title = 'Test' })
    assert.spy(vim.notify).was.called_with('test message', vim.log.levels.INFO, { title = 'Test' })
  end)

  it('should call vim.notify with an empty table if opts is nil', function()
    spy.on(vim, 'notify')
    notify.notify('test message', vim.log.levels.INFO)
    assert.spy(vim.notify).was.called_with('test message', vim.log.levels.INFO, {})
  end)
end)
