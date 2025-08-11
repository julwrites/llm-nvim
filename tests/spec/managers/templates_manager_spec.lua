package.preload['llm.core.data.llm_cli'] = function()
    return require('mock_llm_cli')
end

require('spec_helper')
local assert = require('luassert')
local templates_manager = require('llm.managers.templates_manager')
local llm_cli = require('llm.core.data.llm_cli')
local cache = require('llm.core.data.cache')

describe('llm.managers.templates_manager', function()
  before_each(function()
    cache.invalidate('templates')
    llm_cli.run_llm_command = function() return '[]' end
  end)

  describe('get_templates', function()
    it('should parse JSON output from llm_cli.run_llm_command', function()
      llm_cli.run_llm_command = function(cmd)
        if cmd == 'templates list --json' then
          return '[{"name": "test-template"}]'
        end
        return '[]'
      end
      local templates = templates_manager.get_templates()
      assert.same({ { name = "test-template" } }, templates)
    end)
  end)

  describe('get_template_details', function()
    it('should parse JSON output from llm_cli.run_llm_command', function()
      llm_cli.run_llm_command = function(cmd)
        if cmd == 'templates show test-template-details' then
          return '{"name": "test-template-details", "prompt": "Test prompt"}'
        end
        return '{}'
      end
      local template_details = templates_manager.get_template_details('test-template-details')
      assert.are.same('test-template-details', template_details.name)
      assert.are.same('Test prompt', template_details.prompt)
    end)
  end)

  describe('save_template', function()
    it('should construct the correct llm_cli.run_llm_command string', function()
        local spy = spy.on(llm_cli, 'run_llm_command')
        templates_manager.save_template('test-template-save', 'Test prompt', 'Test system', 'gpt-4', { temperature = 0.5 }, { 'fragment1' }, { 'system_fragment1' }, { param1 = 'default1' }, true, 'schema1')
        assert.spy(spy).was.called_with("templates save test-template-save --prompt 'Test prompt' --system 'Test system' --model gpt-4 -o temperature '0.5' -f fragment1 -sf system_fragment1 -d param1 'default1' --extract --schema schema1")
        spy:revert()
    end)
  end)

  describe('delete_template', function()
    it('should call llm_cli.run_llm_command with the correct arguments', function()
        local spy = spy.on(llm_cli, 'run_llm_command')
        templates_manager.delete_template('test-template-delete')
        assert.spy(spy).was.called_with("templates delete test-template-delete -y")
        spy:revert()
    end)
  end)

  describe('run_template', function()
    it('should construct the correct command table', function()
      local cmd = templates_manager.run_template('test-template', 'Test input', { param1 = 'value1' })
      assert.same({"/usr/bin/llm", "-t", "test-template", "'Test input'", "-p", "param1", "'value1'"}, cmd)
    end)
  end)

  describe('run_template_with_selection', function()
    it('should call api.run_llm_command_streamed with correct executable path', function()
        local api = require('llm.api')
        local old_run_llm_command_streamed = api.run_llm_command_streamed
        local was_called = false
        local call_args
        api.run_llm_command_streamed = function(...)
            was_called = true
            call_args = {...}
        end

        local old_get_template_details = templates_manager.get_template_details
        templates_manager.get_template_details = function() return { name = 'test', prompt = 'test' } end

        local old_create_floating_window = require('llm.core.utils.ui').create_floating_window
        require('llm.core.utils.ui').create_floating_window = function() end

        templates_manager.run_template_with_selection('test-template', 'my selection')

        assert.is_true(was_called)
        assert.is_not_nil(call_args)
        assert.are.equal('/usr/bin/llm', call_args[1][1])

        templates_manager.get_template_details = old_get_template_details
        require('llm.core.utils.ui').create_floating_window = old_create_floating_window
        api.run_llm_command_streamed = old_run_llm_command_streamed
    end)
  end)
end)
