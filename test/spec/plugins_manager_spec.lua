-- test/spec/plugins_manager_spec.lua

describe("plugins_manager", function()
  local plugins_manager
  local spy

  before_each(function()
    spy = require('luassert.spy')
    package.loaded['llm.plugins.plugins_loader'] = {
      get_all_plugin_names = function() return { 'plugin1', 'plugin2' } end,
      get_plugins_with_descriptions = function()
        return {
          plugin1 = { description = 'description1' },
          plugin2 = { description = 'description2' },
        }
      end,
      get_plugins_by_category = function()
        return {
          category1 = { 'plugin1' },
          category2 = { 'plugin2' },
        }
      end,
      refresh_plugins_cache = function() end,
    }
    package.loaded['llm.unified_manager'] = {
      switch_view = function() end,
    }
    plugins_manager = require('llm.plugins.plugins_manager')
  end)

  after_each(function()
    package.loaded['llm.plugins.plugins_loader'] = nil
    package.loaded['llm.plugins.plugins_manager'] = nil
    package.loaded['llm.utils'] = nil
  end)

  it("should be a table", function()
    assert.is_table(plugins_manager)
  end)

  describe("is_plugin_installed", function()
    it("should return true if the plugin is installed", function()
      local mock_utils = require('llm.utils')
      mock_utils.safe_shell_command = spy.new(function()
        return '[{"name": "plugin1"}]'
      end)
      package.loaded['llm.utils'] = mock_utils
      plugins_manager = require('llm.plugins.plugins_manager')
      assert.is_true(plugins_manager.is_plugin_installed("plugin1"))
    end)

    it("should return false if the plugin is not installed", function()
      local mock_utils = require('llm.utils')
      mock_utils.safe_shell_command = spy.new(function()
        return '[{"name": "plugin2"}]'
      end)
      package.loaded['llm.utils'] = mock_utils
      plugins_manager = require('llm.plugins.plugins_manager')
      assert.is_false(plugins_manager.is_plugin_installed("plugin1"))
    end)
  end)

  describe("install_plugin", function()
    it("should call safe_shell_command with the correct arguments", function()
      local mock_utils = require('llm.utils')
      local safe_shell_command_spy = spy.on(mock_utils, 'safe_shell_command')
      package.loaded['llm.utils'] = mock_utils
      plugins_manager = require('llm.plugins.plugins_manager')
      plugins_manager.install_plugin("plugin1")
      assert.spy(safe_shell_command_spy).was.called_with('llm install plugin1', 'Failed to install plugin: plugin1')
    end)
  end)

  describe("uninstall_plugin", function()
    it("should call safe_shell_command with the correct arguments", function()
        local mock_utils = require('llm.utils')
        local safe_shell_command_spy = spy.on(mock_utils, 'safe_shell_command')
        package.loaded['llm.utils'] = mock_utils
        plugins_manager = require('llm.plugins.plugins_manager')
        plugins_manager.uninstall_plugin("plugin1")
        assert.spy(safe_shell_command_spy).was.called_with('llm uninstall plugin1 -y', 'Failed to uninstall plugin: plugin1')
    end)
  end)
end)
