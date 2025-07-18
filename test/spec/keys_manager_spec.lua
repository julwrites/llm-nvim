-- test/spec/keys_manager_spec.lua

describe("keys_manager", function()
  local keys_manager
  local spy
  local mock_keys_view
  local mock_utils

  before_each(function()
    spy = require('luassert.spy')
    mock_keys_view = {
      get_custom_key_name = function(callback) callback("custom_key") end,
      get_api_key = function(provider, callback) callback("test_key") end,
      confirm_remove_key = function(provider, callback) callback() end,
    }
    mock_utils = {
        check_llm_installed = function() return true end,
        get_config_path = function() return "", "/tmp/keys.json" end,
    }
    package.loaded['llm.keys.keys_view'] = mock_keys_view
    package.loaded['llm.utils'] = mock_utils
    package.loaded['llm.unified_manager'] = {
        switch_view = function() end
    }

    -- Mock io functions
    io.open = function()
        return {
            read = function() return '{}' end,
            write = function() end,
            close = function() end,
        }
    end
    os.execute = function() end


    keys_manager = require('llm.keys.keys_manager')
    keys_manager.get_provider_info_under_cursor = function()
        return "openai", {}
    end
    vim.b = {
        [1] = {
            stored_keys_set = { openai = true }
        }
    }
  end)

  after_each(function()
    package.loaded['llm.keys.keys_view'] = nil
    package.loaded['llm.keys.keys_manager'] = nil
    package.loaded['llm.utils'] = nil
    package.loaded['llm.unified_manager'] = nil
    io.open = nil
    os.execute = nil
  end)

  it("should be a table", function()
    assert.is_table(keys_manager)
  end)

  describe("set_api_key", function()
    it("should set an API key", function()
      local set_spy = spy.on(keys_manager, 'set_api_key')
      keys_manager.set_key_under_cursor(1)
      assert.spy(set_spy).was.called_with("openai", "test_key")
    end)
  end)

  describe("remove_api_key", function()
    it("should remove an API key", function()
      local remove_spy = spy.on(keys_manager, 'remove_api_key')
      keys_manager.remove_key_under_cursor(1)
      assert.spy(remove_spy).was.called_with("openai")
    end)
  end)

  describe("add_new_custom_key_interactive", function()
    it("should add a new custom key", function()
        local set_spy = spy.on(keys_manager, 'set_api_key')
        keys_manager.add_new_custom_key_interactive(1)
        assert.spy(set_spy).was.called_with("custom_key", "test_key")
    end)
  end)
end)
