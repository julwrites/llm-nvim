local spy = require('luassert.spy')

describe('llm.errors', function()
  local errors

  before_each(function()
    _G.vim = {
      notify = spy.new(function() end),
      tbl_deep_extend = function(_, ...)
        local result = {}
        for i = 1, select('#', ...) do
          local tbl = select(i, ...)
          for k, v in pairs(tbl) do
            result[k] = v
          end
        end
        return result
      end,
      log = {
        levels = {
          INFO = 1,
          WARN = 2,
          ERROR = 3,
        },
      },
      inspect = function(v) return tostring(v) end,
    }

    package.loaded['llm.errors'] = nil
    errors = require('llm.errors')
  end)

  after_each(function()
    package.loaded['llm.errors'] = nil
  end)

  describe('handle', function()
    it('should call vim.notify with a formatted message', function()
      local notify_spy = spy.new(function() end)
      errors.handle('category', 'message', nil, errors.levels.ERROR, notify_spy)
      assert.spy(notify_spy).was.called()
    end)
  end)

  describe('wrap', function()
    it('should return the function result on success', function()
      local func = function()
        return 'success'
      end
      local wrapped = errors.wrap(func)
      local result = wrapped()
      assert.are.equal('success', result)
    end)

    it('should call handle on failure', function()
      local error_message = 'test error'
      local func = function()
        error(error_message)
      end
      local handle_spy = spy.on(errors, 'handle')
      local wrapped = errors.wrap(func, 'Test Function')
      wrapped()
      assert.spy(handle_spy).was.called()
      handle_spy:revert()
    end)
  end)

  describe('shell_error', function()
    it('should call handle with a formatted shell error message', function()
      local handle_spy = spy.on(errors, 'handle')
      local command = 'ls -l'
      local code = 1
      local stdout = 'stdout'
      local stderr = 'stderr'
      errors.shell_error(command, code, stdout, stderr)
      assert.spy(handle_spy).was.called()
      handle_spy:revert()
    end)
  end)
end)
