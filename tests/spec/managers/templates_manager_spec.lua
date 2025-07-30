require('spec_helper')
local assert = require('luassert')
local templates_manager = require('llm.managers.templates_manager')
local llm_cli = require('llm.core.data.llm_cli')
local cache = require('llm.core.data.cache')

describe('llm.managers.templates_manager', function()
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
      -- Create a template to get details for
      local result = templates_manager.save_template('test-template-details', 'Test prompt', nil, nil, {}, {}, {}, {}, nil, nil)
      assert.is_true(result)

      -- Call the function
      local template_details = templates_manager.get_template_details('test-template-details')

      -- Assert that the function returned the correct data
      assert.are.same('test-template-details', template_details.name)
      assert.are.same('Test prompt', template_details.prompt)

      -- Clean up the created template
      templates_manager.delete_template('test-template-details')
    end)
  end)

  describe('save_template', function()
    it('should construct the correct llm_cli.run_llm_command string with all the provided arguments', function()
      -- Call the function
      local result = templates_manager.save_template('test-template-save', 'Test prompt', 'Test system', 'gpt-4', { temperature = 0.5 }, { 'fragment1' }, { 'system_fragment1' }, { param1 = 'default1' }, true, 'schema1')

      -- Assert that the template was created
      assert.is_true(result)

      -- Clean up the created template
      templates_manager.delete_template('test-template-save')
    end)
  end)

  describe('delete_template', function()
    it('should call llm_cli.run_llm_command with the correct arguments', function()
      -- Create a template to delete
      templates_manager.save_template('test-template-delete', 'Test prompt', nil, nil, {}, {}, {}, {}, nil, nil)

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
      assert.spy(run_llm_command_spy).was.called_with("llm -t test-template 'Test input' -p param1 'value1'")
    end)
  end)
end)
