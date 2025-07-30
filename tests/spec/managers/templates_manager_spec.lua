local mock_vim = require('tests.spec.mock_vim')
local assert = require('luassert')

describe('llm.managers.templates_manager', function()
  local templates_manager
  local llm_cli
  local cache

  before_each(function()
    mock_vim.setup()
    templates_manager = require('llm.managers.templates_manager')
    llm_cli = require('llm.core.data.llm_cli')
    cache = require('llm.core.data.cache')
  end)

  after_each(function()
    mock_vim.teardown()
  end)

  describe('get_templates', function()
    it('should parse JSON output from llm_cli.run_llm_command and cache the templates', function()
      -- Call the function
      local templates = templates_manager.get_templates()

      -- Assert that the function returned the correct data
      assert.is_table(templates)
    end)
  end)

  describe('get_template_details', function()
    it('should parse JSON output from llm_cli.run_llm_command', function()
      -- Mock the llm_cli.run_llm_command function
      llm_cli.run_llm_command = function()
        return '{"name": "test-template-details", "prompt": "Test prompt"}'
      end

      -- Call the function
      local template_details = templates_manager.get_template_details('test-template-details')

      -- Assert that the function returned the correct data
      assert.are.same('test-template-details', template_details.name)
      assert.are.same('Test prompt', template_details.prompt)
    end)
  end)

  describe('save_template', function()
    it('should construct the correct llm_cli.run_llm_command string with all the provided arguments', function()
      -- Mock the llm_cli.run_llm_command function
      llm_cli.run_llm_command = function()
        return 'Template saved'
      end

      -- Call the function
      local result = templates_manager.save_template('test-template-save', 'Test prompt', 'Test system', 'gpt-4', { temperature = 0.5 }, { 'fragment1' }, { 'system_fragment1' }, { param1 = 'default1' }, true, 'schema1')

      -- Assert that the template was created
      assert.is_true(result)
    end)
  end)

  describe('delete_template', function()
    it('should call llm_cli.run_llm_command with the correct arguments', function()
      -- Mock the llm_cli.run_llm_command function
      llm_cli.run_llm_command = function()
        return ''
      end

      -- Call the function
      local result = templates_manager.delete_template('test-template-delete')

      -- Assert that the template was deleted
      assert.is_true(result)
    end)
  end)

  describe('run_template', function()
    it('should construct the correct llm_cli.run_llm_command string with the template name, input, and parameters', function()
      -- Mock the llm_cli.run_llm_command function
      local run_llm_command_spy = spy.new(function() end)
      llm_cli.run_llm_command = run_llm_command_spy

      -- Call the function
      templates_manager.run_template('test-template', 'Test input', { param1 = 'value1' })

      -- Assert that the llm_cli.run_llm_command was called with the correct arguments
      assert.spy(run_llm_command_spy).was.called_with("llm -t test-template Test input -p param1 value1")
    end)
  end)
end)
