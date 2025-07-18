-- test/spec/plugins_manager_spec.lua

describe("plugins_manager", function()
  local plugins_manager
  local spy
  local mock_utils
  local mock_plugins_view

  before_each(function()
    spy = require('luassert.spy')
    mock_utils = {
      safe_shell_command = spy.new(function() return "", 0 end),
      check_llm_installed = function() return true end,
    }
    mock_plugins_view = {
        confirm_uninstall = function(plugin_name, callback) callback(true) end
    }
    package.loaded['llm.utils'] = mock_utils
    package.loaded['llm.plugins.plugins_view'] = mock_plugins_view
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

    plugins_manager.get_plugin_info_under_cursor = function()
        return "plugin1", { installed = true }
    end

    vim.schedule = function(fn) fn() end
  end)

  after_each(function()
    package.loaded['llm.plugins.plugins_loader'] = nil
    package.loaded['llm.plugins.plugins_manager'] = nil
    package.loaded['llm.plugins.plugins_view'] = nil
    package.loaded['llm.utils'] = nil
    vim.schedule = nil
  end)

  it("should be a table", function()
    assert.is_table(plugins_manager)
  end)

  describe("is_plugin_installed", function()
    it("should return true if the plugin is installed", function()
      mock_utils.safe_shell_command = spy.new(function()
        return '[{"name": "plugin1"}]', 0
      end)
      assert.is_true(plugins_manager.is_plugin_installed("plugin1"))
    end)

    it("should return false if the plugin is not installed", function()
        mock_utils.safe_shell_command = spy.new(function()
            return '[{"name": "plugin2"}]', 0
        end)
      assert.is_false(plugins_manager.is_plugin_installed("plugin1"))
    end)
  end)

  describe("install_plugin", function()
    it("should call safe_shell_command with the correct arguments", function()
      plugins_manager.install_plugin("plugin1")
      assert.spy(mock_utils.safe_shell_command).was.called_with('llm install plugin1', 'Failed to install plugin: plugin1')
    end)
  end)

  describe("uninstall_plugin_under_cursor", function()
    it("should call safe_shell_command with the correct arguments", function()
        plugins_manager.uninstall_plugin_under_cursor(1)
        assert.spy(mock_utils.safe_shell_command).was.called_with('llm uninstall plugin1 -y', 'Failed to uninstall plugin: plugin1')
    end)
  end)
end)
