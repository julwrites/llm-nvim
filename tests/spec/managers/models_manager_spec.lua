-- tests/spec/managers/models_manager_spec.lua
require('spec_helper')
local models_manager = require('llm.managers.models_manager')
local llm_cli = require('llm.core.data.llm_cli')
local cache = require('llm.core.data.cache')
local models_io = require('llm.managers.models_io')

describe('models_manager', function()
  describe('get_available_models', function()
    it('should parse the output from llm-cli correctly', function()
      -- Mock the llm_cli.run_llm_command function
      llm_cli.run_llm_command = function()
        return 'gpt-4\ngpt-3.5-turbo'
      end

      local models = models_manager.get_available_models()

      -- Assert that the models are parsed correctly
      local expected_models = {
        { provider = 'Other', id = 'gpt-4', name = 'gpt-4' },
        { provider = 'Other', id = 'gpt-3.5-turbo', name = 'gpt-3.5-turbo' },
      }
      assert.are.same(expected_models, models)
    end)

    it('should cache the models', function()
      -- Mock the llm_cli.run_llm_command and cache.get/cache.set functions
      local llm_cli_call_count = 0
      llm_cli.run_llm_command = function()
        llm_cli_call_count = llm_cli_call_count + 1
        return 'gpt-4\ngpt-3.5-turbo'
      end

      local cache_data = nil
      cache.get = function()
        return cache_data
      end
      cache.set = function(key, value)
        cache_data = value
      end

      -- Call get_available_models twice
      models_manager.get_available_models()
      models_manager.get_available_models()

      -- Assert that llm_cli.run_llm_command was only called once
      assert.are.equal(1, llm_cli_call_count)
    end)
  end)

  describe('is_model_available', function()
    it('should return true for an available model', function()
      -- Mock get_available_providers to return a table indicating that the provider is available
      local original_get_available_providers = models_manager.get_available_providers
      models_manager.get_available_providers = function()
        return {
          OpenAI = true,
        }
      end

      local result = models_manager.is_model_available('OpenAI Chat: gpt-4')
      assert.is_true(result)

      -- Restore the original function
      models_manager.get_available_providers = original_get_available_providers
    end)

    it('should return false for an unavailable model', function()
      -- Mock get_available_providers to return a table indicating that the provider is not available
      local original_get_available_providers = models_manager.get_available_providers
      models_manager.get_available_providers = function()
        return {
          OpenAI = false,
        }
      end

      local result = models_manager.is_model_available('OpenAI Chat: gpt-4')
      assert.is_false(result)

      -- Restore the original function
      models_manager.get_available_providers = original_get_available_providers
    end)
  end)

  describe('delegation to models_io', function()
    it('should call set_default_model_in_cli in models_io', function()
      -- Mock the models_io.set_default_model_in_cli function
      local models_io_call_args
      models_io.set_default_model_in_cli = function(model_name)
        models_io_call_args = { model_name = model_name }
        return true
      end

      models_manager.set_default_model('gpt-4')
      assert.are.same({ model_name = 'gpt-4' }, models_io_call_args)
    end)

    it('should call set_alias_in_cli in models_io', function()
      -- Mock the models_io.set_alias_in_cli function
      local models_io_call_args
      models_io.set_alias_in_cli = function(alias, model)
        models_io_call_args = { alias = alias, model = model }
        return true
      end

      models_manager.set_model_alias('my-alias', 'gpt-4')
      assert.are.same({ alias = 'my-alias', model = 'gpt-4' }, models_io_call_args)
    end)

    it('should call remove_alias_in_cli in models_io', function()
      -- Mock the models_io.remove_alias_in_cli function
      local models_io_call_args
      models_io.remove_alias_in_cli = function(alias)
        models_io_call_args = { alias = alias }
        return true
      end

      models_manager.remove_model_alias('my-alias')
      assert.are.same({ alias = 'my-alias' }, models_io_call_args)
    end)
  end)
end)
