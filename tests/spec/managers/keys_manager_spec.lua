-- tests/spec/managers/keys_manager_spec.lua
require('spec_helper')
local mock = require('luassert.mock')
local stub = require('luassert.stub')

local llm_cli = require('llm.core.data.llm_cli')
local KeysManager = require('llm.managers.keys_manager')
local cache = require('llm.core.data.cache')
local config = require('llm.config')

describe('llm.managers.keys_manager', function()
  before_each(function()
    stub(cache, 'get')
    stub(cache, 'set')
    stub(cache, 'invalidate')
    stub(config, 'get')
  end)

  after_each(function()
    mock.revert(cache)
    mock.revert(config)
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
    it('should call `llm_cli.run_llm_command` with `\'keys set <key_name> --value <key_value>\'`', function()
      local llm_cli_spy = spy.on(llm_cli, 'run_llm_command')
      KeysManager.set_api_key('openai', 'sk-12345')
      assert.spy(llm_cli_spy).was_called_with('keys set openai --value sk-12345')
      llm_cli_spy:revert()
    end)
  end)

  describe('remove_api_key', function()
    it('should call `llm_cli.run_llm_command` with `\'keys path\'`', function()
      local llm_cli_spy = spy.on(llm_cli, 'run_llm_command')
      -- Mock the file operations to avoid actual file I/O in tests
      local mock_file = {
        read = function() return '{"openai": "test-key"}' end,
        close = function() end
      }
      stub(io, 'open', function(path, mode)
        if mode == "r" then
          return mock_file
        else
          return { write = function() end, close = function() end }
        end
      end)
      stub(vim.fn, 'json_decode', function() return { openai = "test-key" } end)
      stub(vim.fn, 'json_encode', function() return '{}' end)

      KeysManager.remove_api_key('openai')
      assert.spy(llm_cli_spy).was_called_with('keys path')

      llm_cli_spy:revert()
      mock.revert(io)
      mock.revert(vim.fn)
    end)
  end)
end)
