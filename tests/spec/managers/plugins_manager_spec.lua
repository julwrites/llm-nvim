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
end)
