-- tests/spec/managers/keys_manager_spec.lua
local mock_vim = require('tests.spec.mock_vim')
local mock = require('luassert.mock')
local stub = require('luassert.stub')

describe('llm.managers.keys_manager', function()
  local llm_cli
  local KeysManager
  local cache
  local config

  before_each(function()
    mock_vim.setup()
    llm_cli = require('llm.core.data.llm_cli')
    KeysManager = require('llm.managers.keys_manager')
    cache = require('llm.core.data.cache')
    config = require('llm.config')
    stub(cache, 'get', function() end)
    stub(cache, 'set', function() end)
    stub(cache, 'invalidate', function() end)
    stub(config, 'get', function() end)
  end)

  after_each(function()
    mock_vim.teardown()
    mock.revert(cache.get)
    mock.revert(cache.set)
    mock.revert(cache.invalidate)
    mock.revert(config.get)
  end)

  describe('get_stored_keys', function()
    it('should return a table of keys', function()
      local keys = KeysManager.get_stored_keys()
      assert.is_table(keys)
    end)
  end)

  describe('is_key_set', function()
    it('should return true if the key is in the list of stored keys', function()
        stub(KeysManager, 'get_stored_keys', function()
            return { { name = 'openai', is_set = true } }
        end)
        assert.is_true(KeysManager.is_key_set('openai'))
        mock.revert(KeysManager)
    end)

    it('should return false if the key is not in the list', function()
        stub(KeysManager, 'get_stored_keys', function()
            return {}
        end)
        assert.is_false(KeysManager.is_key_set('anthropic'))
        mock.revert(KeysManager)
    end)
  end)

  describe('set_api_key', function()
    it('should call `llm_cli.run_llm_command` with `\'keys set <key_name> <key_value>\'`', function()
      local llm_cli_spy = spy.on(llm_cli, 'run_llm_command')
      KeysManager.set_api_key('openai', 'sk-12345')
      assert.spy(llm_cli_spy).was_called_with('keys set openai sk-12345')
      llm_cli_spy:revert()
    end)
  end)

  describe('remove_api_key', function()
    it('should call `llm_cli.run_llm_command` with `\'keys remove <key_name>\'`', function()
      local llm_cli_spy = spy.on(llm_cli, 'run_llm_command')
      KeysManager.remove_api_key('openai')
      assert.spy(llm_cli_spy).was_called_with('keys remove openai')
      llm_cli_spy:revert()
    end)
  end)
end)
