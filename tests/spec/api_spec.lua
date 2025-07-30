require('spec_helper')
local spy = require('luassert.spy')

describe('llm.api', function()
  local api
  local config_mock

  before_each(function()
    package.loaded['llm.config'] = nil

    config_mock = {
      setup = spy.new(function() end),
    }

    package.loaded['llm.config'] = config_mock

    api = require('llm.api')
  end)

  after_each(function()
    package.loaded['llm.config'] = nil
  end)

  it('should call config.setup with provided options', function()
    local opts = { model = 'test-model' }
    api.setup(opts)
    assert.spy(config_mock.setup).was.called_with(opts)
  end)

  describe('facade functions', function()
    local facade_mock

    before_each(function()
      facade_mock = {
        get_manager = spy.new(function() end),
        command = spy.new(function() end),
        prompt = spy.new(function() end),
        prompt_with_selection = spy.new(function() end),
        prompt_with_current_file = spy.new(function() end),
        toggle_unified_manager = spy.new(function() end),
      }
      package.loaded['llm.facade'] = facade_mock
      -- Rerequire api to get the mocked facade
      package.loaded['llm.api'] = nil
      api = require('llm.api')
    end)

    after_each(function()
      package.loaded['llm.facade'] = nil
    end)

    it('should expose all facade functions', function()
      for name, func in pairs(facade_mock) do
        assert.is_function(api[name], "Expected api." .. name .. " to be a function")
        api[name]("test_arg")
        assert.spy(func).was.called_with("test_arg")
      end
    end)
  end)
end)
