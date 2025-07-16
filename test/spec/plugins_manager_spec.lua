-- test/spec/plugins_manager_spec.lua

describe("plugins_manager", function()
  local plugins_manager
  local mock_plugins_loader

  before_each(function()
    mock_plugins_loader = {
      load_plugins = function() return {} end,
    }

    package.loaded['llm.plugins.plugins_loader'] = mock_plugins_loader
    package.loaded['llm.unified_manager'] = {
      switch_view = function() end,
    }
    plugins_manager = require('llm.plugins.plugins_manager')
    plugins_manager.load = function() end
  end)

  after_each(function()
    package.loaded['llm.plugins.plugins_loader'] = nil
    package.loaded['llm.plugins.plugins_manager'] = nil
  end)

  it("should be a table", function()
    assert.is_table(plugins_manager)
  end)

  describe("get_plugins", function()
    it("should return the loaded plugins", function()
      local fake_plugins = { { name = "plugin1" }, { name = "plugin2" } }
      mock_plugins_loader.load_plugins = function() return fake_plugins end
      plugins_manager.load()
      assert.are.same(fake_plugins, plugins_manager:get_plugins())
    end)
  end)

  describe("is_plugin_installed", function()
    it("should return true if the plugin is installed", function()
      local fake_plugins = { { name = "plugin1", installed = true }, { name = "plugin2" } }
      mock_plugins_loader.load_plugins = function() return fake_plugins end
      plugins_manager:load()
      assert.is_true(plugins_manager:is_plugin_installed("plugin1"))
    end)

    it("should return false if the plugin is not installed", function()
      local fake_plugins = { { name = "plugin1", installed = true }, { name = "plugin2" } }
      mock_plugins_loader.load_plugins = function() return fake_plugins end
      plugins_manager:load()
      assert.is_false(plugins_manager:is_plugin_installed("plugin2"))
    end)
  end)

  describe("install_plugin", function()
    it("should call install on the plugin", function()
      local installed = false
      local fake_plugin = { name = "plugin1", install = function() installed = true end }
      local fake_plugins = { fake_plugin }
      mock_plugins_loader.load_plugins = function() return fake_plugins end
      plugins_manager.load()
      plugins_manager.install_plugin("plugin1")
      assert.is_true(installed)
    end)

    it("should not call install on a non-existent plugin", function()
      local installed = false
      local fake_plugin = { name = "plugin1", install = function() installed = true end }
      local fake_plugins = { fake_plugin }
      mock_plugins_loader.load_plugins = function() return fake_plugins end
      plugins_manager.load()
      plugins_manager.install_plugin("non_existent_plugin")
      assert.is_false(installed)
    end)
  end)

  describe("uninstall_plugin", function()
    it("should call uninstall on the plugin", function()
      local uninstalled = false
      local fake_plugin = { name = "plugin1", uninstall = function() uninstalled = true end }
      local fake_plugins = { fake_plugin }
      mock_plugins_loader.load_plugins = function() return fake_plugins end
      plugins_manager.load()
      plugins_manager:uninstall_plugin("plugin1")
      assert.is_true(uninstalled)
    end)

    it("should not call uninstall on a non-existent plugin", function()
      local uninstalled = false
      local fake_plugin = { name = "plugin1", uninstall = function() uninstalled = true end }
      local fake_plugins = { fake_plugin }
      mock_plugins_loader.load_plugins = function() return fake_plugins end
      plugins_manager.load()
      plugins_manager:uninstall_plugin("plugin2")
      assert.is_false(uninstalled)
    end)
  end)
end)
