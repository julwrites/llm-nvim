require('spec_helper')
local plugins_manager = require('llm.managers.plugins_manager')
local llm_cli = require('llm.core.data.llm_cli')
local cache = require('llm.core.data.cache')

describe('plugins_manager', function()
  before_each(function()
    cache.invalidate('available_plugins')
    cache.invalidate('installed_plugins')
  end)

  describe('get_available_plugins', function()
    it('should parse the HTML from the plugin directory URL', function()
      local mock_html = [[
        <section id="official-plugins">
          <h2>Official Plugins</h2>
          <ul>
            <li><a href="https://github.com/simonw/llm-plugin-1"><strong>llm-plugin-1</strong></a>: Description 1</li>
            <li><a href="https://github.com/simonw/llm-plugin-2"><strong>llm-plugin-2</strong></a>: Description 2</li>
          </ul>
        </section>
      ]]
      local old_system = vim.fn.system
      vim.fn.system = function()
        return mock_html
      end

      local plugins = plugins_manager.get_available_plugins()
      assert.same({
        { name = 'llm-plugin-1', url = 'https://github.com/simonw/llm-plugin-1', description = 'Description 1' },
        { name = 'llm-plugin-2', url = 'https://github.com/simonw/llm-plugin-2', description = 'Description 2' },
      }, plugins)

      vim.fn.system = old_system
    end)

    it('should handle a failed curl command gracefully', function()
      local old_system = vim.fn.system
      vim.fn.system = function()
        return ''
      end

      local plugins = plugins_manager.get_available_plugins()
      assert.same({}, plugins)

      vim.fn.system = old_system
    end)

    it('should cache the available plugins', function()
      local old_system = vim.fn.system
      local call_count = 0
      vim.fn.system = function()
        call_count = call_count + 1
        return [[
        <section id="official-plugins">
          <h2>Official Plugins</h2>
          <ul>
            <li><a href="https://github.com/simonw/llm-plugin-1"><strong>llm-plugin-1</strong></a>: Description 1</li>
          </ul>
        </section>
      ]]
      end

      plugins_manager.get_available_plugins()
      plugins_manager.get_available_plugins()

      assert.are.equal(1, call_count)

      vim.fn.system = old_system
    end)
  end)

  describe('get_installed_plugins', function()
    it('should parse the JSON output from llm_cli.run_llm_command', function()
      local mock_json = '[{"name": "llm-gpt4all"}]'
      local old_run_llm_command = llm_cli.run_llm_command
      llm_cli.run_llm_command = function()
        return mock_json
      end

      -- Mock json_decode to avoid issues in the test environment
      local old_json_decode = vim.fn.json_decode
      vim.fn.json_decode = function(json)
        if json == mock_json then
          return { { name = 'llm-gpt4all' } }
        end
        return {}
      end

      local plugins = plugins_manager.get_installed_plugins()
      assert.same({ { name = 'llm-gpt4all' } }, plugins)

      llm_cli.run_llm_command = old_run_llm_command
      vim.fn.json_decode = old_json_decode
    end)

    it('should cache the installed plugins', function()
      local call_count = 0
      local old_run_llm_command = llm_cli.run_llm_command
      llm_cli.run_llm_command = function()
        call_count = call_count + 1
        return '[]'
      end

      -- Mock json_decode to avoid issues in the test environment
      local old_json_decode = vim.fn.json_decode
      vim.fn.json_decode = function()
        return {}
      end

      plugins_manager.get_installed_plugins()
      plugins_manager.get_installed_plugins()

      assert.are.equal(1, call_count)

      llm_cli.run_llm_command = old_run_llm_command
      vim.fn.json_decode = old_json_decode
    end)
  end)

  describe('is_plugin_installed', function()
    it('should return true if the plugin is in the list of installed plugins', function()
      local mock_json = '[{"name": "llm-gpt4all"}]'
      local old_run_llm_command = llm_cli.run_llm_command
      llm_cli.run_llm_command = function()
        return mock_json
      end

      -- Mock json_decode to avoid issues in the test environment
      local old_json_decode = vim.fn.json_decode
      vim.fn.json_decode = function(json)
        if json == mock_json then
          return { { name = 'llm-gpt4all' } }
        end
        return {}
      end

      assert.is_true(plugins_manager.is_plugin_installed('llm-gpt4all'))

      llm_cli.run_llm_command = old_run_llm_command
      vim.fn.json_decode = old_json_decode
    end)

    it('should return false if the plugin is not in the list of installed plugins', function()
      local mock_json = '[{"name": "llm-gpt4all"}]'
      local old_run_llm_command = llm_cli.run_llm_command
      llm_cli.run_llm_command = function()
        return mock_json
      end

      -- Mock json_decode to avoid issues in the test environment
      local old_json_decode = vim.fn.json_decode
      vim.fn.json_decode = function(json)
        if json == mock_json then
          return { { name = 'llm-gpt4all' } }
        end
        return {}
      end

      assert.is_false(plugins_manager.is_plugin_installed('some-other-plugin'))

      llm_cli.run_llm_command = old_run_llm_command
      vim.fn.json_decode = old_json_decode
    end)
  end)

  describe('install_plugin', function()
    it('should call llm_cli.run_llm_command with the correct arguments', function()
      local old_run_llm_command = llm_cli.run_llm_command
      local command
      llm_cli.run_llm_command = function(c)
        command = c
      end

      plugins_manager.install_plugin('my-plugin')

      assert.are.equal('install my-plugin', command)

      llm_cli.run_llm_command = old_run_llm_command
    end)
  end)

  describe('uninstall_plugin', function()
    it('should call llm_cli.run_llm_command with the correct arguments', function()
      local old_run_llm_command = llm_cli.run_llm_command
      local command
      llm_cli.run_llm_command = function(c)
        command = c
      end

      plugins_manager.uninstall_plugin('my-plugin')

      assert.are.equal('uninstall my-plugin -y', command)

      llm_cli.run_llm_command = old_run_llm_command
    end)
  end)

  describe('populate_plugins_buffer', function()
    it('should handle no available plugins', function()
      local old_get_available = plugins_manager.get_available_plugins
      plugins_manager.get_available_plugins = function() return {} end

      local bufnr = 1
      local lines_set = false
      vim.api.nvim_buf_set_lines = function() lines_set = true end

      local line_to_plugin, plugin_data = plugins_manager.populate_plugins_buffer(bufnr)

      assert.is_true(lines_set)
      assert.same({}, line_to_plugin)
      assert.same({}, plugin_data)

      plugins_manager.get_available_plugins = old_get_available
    end)
  end)

  describe('setup_plugins_keymaps', function()
    it('should set keymaps for plugin actions', function()
      local bufnr = 1
      local keymaps_set = 0
      vim.api.nvim_buf_set_keymap = function() keymaps_set = keymaps_set + 1 end

      plugins_manager.setup_plugins_keymaps(bufnr)

      assert.are.equal(3, keymaps_set)
    end)
  end)

  describe('refresh_plugin_list', function()
    it('should trigger refresh_available_plugins', function()
      local old_refresh = plugins_manager.refresh_available_plugins
      local refreshed = false
      plugins_manager.refresh_available_plugins = function() refreshed = true end

      plugins_manager.refresh_plugin_list(1)

      assert.is_true(refreshed)

      plugins_manager.refresh_available_plugins = old_refresh
    end)
  end)

  describe('install_plugin_under_cursor', function()
    it('should notify if no plugin is selected', function()
      local old_get_info = plugins_manager.get_plugin_info_under_cursor
      plugins_manager.get_plugin_info_under_cursor = function() return nil, nil end
      local notify_called = false
      vim.notify = function() notify_called = true end

      plugins_manager.install_plugin_under_cursor(1)

      assert.is_true(notify_called)

      plugins_manager.get_plugin_info_under_cursor = old_get_info
    end)
  end)

  describe('uninstall_plugin_under_cursor', function()
    it('should notify if no plugin is selected', function()
      local old_get_info = plugins_manager.get_plugin_info_under_cursor
      plugins_manager.get_plugin_info_under_cursor = function() return nil, nil end
      local notify_called = false
      vim.notify = function() notify_called = true end

      plugins_manager.uninstall_plugin_under_cursor(1)

      assert.is_true(notify_called)

      plugins_manager.get_plugin_info_under_cursor = old_get_info
    end)
  end)

  describe('refresh_available_plugins', function()
    it('should invalidate cache and schedule fetch', function()
      local invalidated_count = 0
      local old_invalidate = cache.invalidate
      cache.invalidate = function() invalidated_count = invalidated_count + 1 end

      local deferred = false
      vim.defer_fn = function(fn) fn(); deferred = true end

      local callback_called = false
      plugins_manager.refresh_available_plugins(function() callback_called = true end)

      assert.are.equal(3, invalidated_count)
      assert.is_true(deferred)
      assert.is_true(callback_called)

      cache.invalidate = old_invalidate
    end)
  end)

  describe('get_plugin_info_under_cursor', function()
    it('should return nil if buffer data is missing', function()
      vim.api.nvim_win_get_cursor = function() return {1, 0} end
      vim.b = { [1] = {} } -- empty buffer data

      local name, info = plugins_manager.get_plugin_info_under_cursor(1)

      assert.is_nil(name)
      assert.is_nil(info)
    end)
  end)

  describe('manage_plugins', function()
    it('should open unified manager with Plugins view', function()
      local mock_unified = { open_specific_manager = function(view) assert.are.equal("Plugins", view) end }
      package.loaded['llm.ui.unified_manager'] = mock_unified

      plugins_manager.manage_plugins()

      package.loaded['llm.ui.unified_manager'] = nil
    end)
  end)
end)
