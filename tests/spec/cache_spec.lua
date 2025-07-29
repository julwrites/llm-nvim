-- tests/spec/core/data/cache_spec.lua

describe("llm.core.data.cache", function()
  local cache
  local mock_io
  local mock_json

  before_each(function()
    -- Mock io functions
    mock_io = {
      open = function()
        return {
          read = function() return "" end,
          write = function() end,
          close = function() end,
        }
      end,
    }
    package.loaded['io'] = mock_io

    -- Mock vim object
    _G.vim = {
      fn = {
        stdpath = function() return "/tmp" end,
        json_decode = function(str)
          if str == "" then return {} end
          return { test_key = "test_value" }
        end,
        json_encode = function() return "" end,
      },
    }

    -- Reload the cache module to use the mocks
    package.loaded['llm.core.data.cache'] = nil
    cache = require('llm.core.data.cache')
  end)

  after_each(function()
    -- Restore original modules
    package.loaded['io'] = nil
    package.loaded['llm.core.data.cache'] = nil
    _G.vim = nil
  end)

  it("should set a value in the cache", function()
    local key = "test_key"
    local value = "test_value"
    cache.set(key, value)
    assert.are.equal(value, cache.get(key))
  end)

  it("should get a value from the cache", function()
    local key = "test_key"
    local value = "test_value"
    cache.set(key, value)
    local retrieved_value = cache.get(key)
    assert.are.equal(value, retrieved_value)
  end)

  it("should invalidate a value in the cache", function()
    local key = "test_key"
    local value = "test_value"
    cache.set(key, value)
    cache.invalidate(key)
    assert.is_nil(cache.get(key))
  end)
end)
