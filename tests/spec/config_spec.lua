-- tests/spec/config_spec.lua

local spy = require('luassert.spy')

describe('llm.config', function()
  local config

  before_each(function()
    -- Mock the vim object
    _G.vim = {
      tbl_deep_extend = function(_, ...)
        local result = {}
        for _, tbl in ipairs({...}) do
          for k, v in pairs(tbl) do
            result[k] = v
          end
        end
        return result
      end,
    }

    -- Reset the module to ensure a clean state for each test
    package.loaded['llm.config'] = nil
    config = require('llm.config')
  end)

  after_each(function()
    _G.vim = nil
  end)

  describe('setup()', function()
    it('should merge user options with defaults', function()
      local user_opts = {
        model = 'test-model',
        debug = true,
      }
      config.setup(user_opts)
      assert.are.same('test-model', config.get('model'))
      assert.are.same(true, config.get('debug'))
      -- Check a default value was not overwritten
      assert.are.same('You are a helpful assistant.', config.get('system_prompt'))
    end)

    it('should notify listeners on change', function()
      local listener_spy = spy.new(function() end)
      config.on_change(listener_spy)

      local user_opts = { model = 'new-model' }
      config.setup(user_opts)

      assert.spy(listener_spy).was.called()
    end)
  end)

  describe('get()', function()
    it('should return the value for a single key', function()
      config.setup({ model = 'get-test' })
      assert.are.same('get-test', config.get('model'))
    end)

    it('should return the default value if a key is not set', function()
      assert.are.same(false, config.get('debug'))
    end)

    it('should return a table of all values if no key is provided', function()
      config.setup({ model = 'all-values-test', debug = true })
      local all_opts = config.get()
      assert.are.same('all-values-test', all_opts.model)
      assert.are.same(true, all_opts.debug)
      assert.are.same('You are a helpful assistant.', all_opts.system_prompt)
    end)
  end)

  describe('reset()', function()
    it('should restore the configuration to its default state', function()
      config.setup({ model = 'reset-test', debug = true })
      config.reset()
      assert.are.same(nil, config.get('model'))
      assert.are.same(false, config.get('debug'))
      assert.are.same('You are a helpful assistant.', config.get('system_prompt'))
    end)
  end)
end)
