-- tests/spec/facade_spec.lua
require('spec_helper')
local spy = require('luassert.spy')
local facade = require('llm.facade')

describe('llm.facade', function()
  local facade
  before_each(function()
    -- Reset the facade module to ensure isolation between tests
    package.loaded['llm.facade'] = nil
    facade = require('llm.facade')
  end)

  after_each(function()
    package.loaded['llm.facade'] = nil
  end)

  describe('get_manager', function()
    it('should return the correct manager instance for a valid name', function()
      local models_manager_mock = {}
      package.loaded['llm.managers.models_manager'] = models_manager_mock

      local manager = facade.get_manager('models')
      assert.are.same(models_manager_mock, manager)

      package.loaded['llm.managers.models_manager'] = nil
    end)

    it('should cache manager instances', function()
      vim.env.NVIM_LLM_TEST = 'true'
      -- We need to reload the facade module to expose the test function
      package.loaded['llm.facade'] = nil
      facade = require('llm.facade')

      local models_manager_mock = {}
      package.loaded['llm.managers.models_manager'] = models_manager_mock

      facade.get_manager('models')
      local managers = facade._get_managers()
      assert.are.same(models_manager_mock, managers.models)

      -- To verify caching, we'll check that the manager is already loaded
      -- without calling require again. We can't spy on require, so we'll
      -- just check that the object is the same.
      local manager1 = facade.get_manager('models')
      local manager2 = facade.get_manager('models')
      assert.are.same(manager1, manager2)

      package.loaded['llm.managers.models_manager'] = nil
      vim.env.NVIM_LLM_TEST = nil
    end)

    it('should return nil for an invalid manager name', function()
      local manager = facade.get_manager('invalid_manager')
      assert.is_nil(manager)
    end)
  end)

  describe('command', function()
    it('should call llm.commands.dispatch_command with the correct arguments', function()
      local commands_mock = {
        dispatch_command = spy.new(function() end),
      }
      package.loaded['llm.commands'] = commands_mock

      facade.command('test_subcmd', 'arg1', 'arg2')
      assert.spy(commands_mock.dispatch_command).was.called_with('test_subcmd', 'arg1', 'arg2')

      package.loaded['llm.commands'] = nil
    end)
  end)

  describe('prompt functions', function()
    local commands_mock

    before_each(function()
      commands_mock = {
        prompt = spy.new(function() end),
        prompt_with_selection = spy.new(function() end),
        prompt_with_current_file = spy.new(function() end),
      }
      package.loaded['llm.commands'] = commands_mock
    end)

    after_each(function()
      package.loaded['llm.commands'] = nil
    end)

    it('should call llm.commands.prompt with the correct arguments', function()
      facade.prompt('test_prompt', { 'frag1', 'frag2' })
      assert.spy(commands_mock.prompt).was.called_with('test_prompt', { 'frag1', 'frag2' })
    end)

    it('should call llm.commands.prompt_with_selection with the correct arguments', function()
      facade.prompt_with_selection('test_prompt', { 'frag1', 'frag2' })
      assert.spy(commands_mock.prompt_with_selection).was.called_with('test_prompt', { 'frag1', 'frag2' })
    end)

    it('should call llm.commands.prompt_with_current_file with the correct arguments', function()
      facade.prompt_with_current_file('test_prompt')
      assert.spy(commands_mock.prompt_with_current_file).was.called_with('test_prompt')
    end)
  end)

  describe('toggle_unified_manager', function()
    it('should call unified_manager.toggle with the correct initial view', function()
      local unified_manager_mock = {
        toggle = spy.new(function() end),
      }
      package.loaded['llm.ui.unified_manager'] = unified_manager_mock

      facade.toggle_unified_manager('test_view')
      assert.spy(unified_manager_mock.toggle).was.called_with('test_view')

      package.loaded['llm.ui.unified_manager'] = nil
    end)
  end)
end)
