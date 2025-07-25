-- test/spec/plugins_manager_spec.lua

describe("plugins_manager", function()
  local plugins_manager
  local spy
  local mock_llm_cli
  local mock_cache
  local mock_plugins_view
  local mock_styles
  local mock_shell

  before_each(function()
    spy = require('luassert.spy')

    mock_llm_cli = {
      run_llm_command = spy.new(function() return "", 0 end),
    }
    mock_cache = {
      get = spy.new(function() return nil end),
      set = spy.new(function() end),
      invalidate = spy.new(function() end),
    }
    mock_plugins_view = {
      confirm_uninstall = spy.new(function(plugin_name, callback) callback(true) end)
    }
    mock_styles = {
      setup_buffer_syntax = spy.new(function() end),
      setup_highlights = spy.new(function() end),
    }
    mock_shell = {
      safe_shell_command = spy.new(function() return "", 0 end),
      check_llm_installed = spy.new(function() return true end),
    }
    local mock_unified_manager = {
      switch_view = spy.new(function() end),
      open_specific_manager = spy.new(function() end),
    }

    package.loaded['llm.core.data.llm_cli'] = mock_llm_cli
    package.loaded['llm.core.data.cache'] = mock_cache
    package.loaded['llm.ui.views.plugins_view'] = mock_plugins_view
    package.loaded['llm.ui.styles'] = mock_styles
    package.loaded['llm.core.utils.shell'] = mock_shell
    package.loaded['llm.ui.unified_manager'] = mock_unified_manager

    -- Mock vim.api functions used by plugins_manager
    vim.api.nvim_buf_set_lines = spy.new(function() end)
    vim.api.nvim_buf_add_highlight = spy.new(function() end)
    vim.api.nvim_win_get_cursor = spy.new(function() return {1, 0} end)

    -- Mock vim.fn functions used by plugins_manager
    vim.fn.system = spy.new(function() return "" end)
    vim.fn.bufexists = spy.new(function() return 0 end)
    vim.fn.buflisted = spy.new(function() return 0 end)

    -- Mock vim.notify
    vim.notify = spy.new(function() end)

    -- Mock vim.schedule and vim.defer_fn
    vim.schedule = function(fn) fn() end
    vim.defer_fn = function(fn, delay) fn() end

    -- Load the actual module after setting up mocks
    plugins_manager = require('llm.managers.plugins_manager')

    -- Override get_plugin_info_under_cursor for specific tests
    plugins_manager.get_plugin_info_under_cursor = function()
      return "plugin1", { installed = true }
    end
  end)

  after_each(function()
    package.loaded['llm.managers.plugins_manager'] = nil
    package.loaded['llm.core.data.llm_cli'] = nil
    package.loaded['llm.core.data.cache'] = nil
    package.loaded['llm.ui.views.plugins_view'] = nil
    package.loaded['llm.ui.styles'] = nil
    package.loaded['llm.core.utils.shell'] = nil
    package.loaded['llm.ui.unified_manager'] = nil

    -- Clean up vim mocks
    vim.api.nvim_buf_set_lines = nil
    vim.api.nvim_buf_add_highlight = nil
    vim.api.nvim_win_get_cursor = nil
    vim.fn.system = nil
    vim.fn.bufexists = nil
    vim.fn.buflisted = nil
    vim.notify = nil
    vim.schedule = nil
    vim.defer_fn = nil
  end)

  it("should be a table", function()
    assert.is_table(plugins_manager)
  end)

  describe("is_plugin_installed", function()
    it("should return true if the plugin is installed", function()
      mock_llm_cli.run_llm_command = spy.new(function()
        return '[{"name": "plugin1"}]', 0
      end)
      assert.is_true(plugins_manager.is_plugin_installed("plugin1"))
    end)

    it("should return false if the plugin is not installed", function()
        mock_llm_cli.run_llm_command = spy.new(function()
            return '[{"name": "plugin2"}]', 0
        end)
      assert.is_false(plugins_manager.is_plugin_installed("plugin1"))
    end)
  end)

  describe("install_plugin", function()
    it("should call safe_shell_command with the correct arguments", function()
      plugins_manager.install_plugin("plugin1")
      assert.spy(mock_llm_cli.run_llm_command).was.called_with('install plugin1')
    end)
  end)

  describe("uninstall_plugin_under_cursor", function()
    it("should call safe_shell_command with the correct arguments", function()
        plugins_manager.uninstall_plugin_under_cursor(1)
        assert.spy(mock_llm_cli.run_llm_command).was.called_with('uninstall plugin1 -y')
    end)
  end)

  describe("populate_plugins_buffer", function()
    it("should correctly display installed and uninstalled plugins", function()
      mock_llm_cli.run_llm_command = spy.new(function(cmd)
        if cmd == 'plugins list --json' then
          return '[{"name": "llm-installed-plugin"}]', 0
        end
        return "", 0
      end)

      plugins_manager.get_available_plugins = function()
        return {
          { name = "llm-installed-plugin", description = "An installed plugin" },
          { name = "llm-uninstalled-plugin", description = "An uninstalled plugin" },
        }
      end

      plugins_manager.populate_plugins_buffer(1)

      assert.spy(vim.api.nvim_buf_set_lines).was.called()
      local lines = vim.api.nvim_buf_set_lines.calls[1].refs[5]

      local lines_str = table.concat(lines, "\n")
      assert.truthy(string.find(lines_str, "[✓] llm-installed-plugin - An installed plugin"))
      assert.truthy(string.find(lines_str, "[ ] llm-uninstalled-plugin - An uninstalled plugin"))
    end)
  end)
end)
