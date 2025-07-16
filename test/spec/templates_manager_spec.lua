-- test/spec/templates_manager_spec.lua

describe("templates_manager", function()
  local templates_manager
  local mock_templates_loader

  before_each(function()
    mock_templates_loader = {
      load_templates = function() return {} end,
    }

    package.loaded['llm.templates.templates_loader'] = mock_templates_loader
    templates_manager = require('llm.templates.templates_manager')
  end)

  after_each(function()
    package.loaded['llm.templates.templates_loader'] = nil
    package.loaded['llm.templates.templates_manager'] = nil
  end)

  it("should be a table", function()
    assert.is_table(templates_manager)
  end)

  describe("get_templates", function()
    it("should return the loaded templates", function()
      local fake_templates = { { name = "template1" }, { name = "template2" } }
      mock_templates_loader.load_templates = function() return fake_templates end
      templates_manager.load()
      assert.are.same(fake_templates, templates_manager.get_templates())
    end)
  end)

  describe("get_template", function()
    it("should return the correct template by name", function()
      local fake_templates = { { name = "template1" }, { name = "template2" } }
      mock_templates_loader.load_templates = function() return fake_templates end
      templates_manager.load()
      assert.are.same(fake_templates[1], templates_manager.get_template("template1"))
    end)

    it("should return nil if the template is not found", function()
      local fake_templates = { { name = "template1" }, { name = "template2" } }
      mock_templates_loader.load_templates = function() return fake_templates end
      templates_manager.load()
      assert.is_nil(templates_manager.get_template("non_existent_template"))
    end)
  end)

  describe("delete_template", function()
    it("should call delete on the template", function()
        local fake_template = { name = "template1", delete = require('luassert.spy').create() }
        local fake_templates = { fake_template }
        mock_templates_loader.load_templates = function() return fake_templates end
        templates_manager.load()
        templates_manager.delete_template("template1")
        assert.spy(fake_template.delete).was.called()
    end)
  end)

  describe("create_template", function()
    it("should create a new template", function()
        local mock_file_utils = {
            save_json = require('luassert.spy').create(),
            get_config_dir = function() return "config_dir" end,
        }
        package.loaded['llm.utils.file_utils'] = mock_file_utils
        templates_manager = require('llm.templates.templates_manager')

        templates_manager.create_template("my-template", "My Template")
        assert.spy(mock_file_utils.save_json).was.called_with("config_dir/templates/my-template.json", { name = "my-template", description = "My Template" })
    end)
  end)

  describe("edit_template", function()
    it("should save the edited template", function()
        local mock_file_utils = {
            save_json = require('luassert.spy').create(),
            get_config_dir = function() return "config_dir" end,
        }
        package.loaded['llm.utils.file_utils'] = mock_file_utils
        templates_manager = require('llm.templates.templates_manager')

        templates_manager.edit_template("my-template", "My Edited Template")
        assert.spy(mock_file_utils.save_json).was.called_with("config_dir/templates/my-template.json", { name = "my-template", description = "My Edited Template" })
    end)
  end)

  describe("run_template", function()
    it("should run a template", function()
        local mock_shell = {
            run = require('luassert.spy').create(),
        }
        package.loaded['llm.utils.shell'] = mock_shell
        templates_manager = require('llm.templates.templates_manager')

        templates_manager.run_template("my-template")
        assert.spy(mock_shell.run).was.called_with("llm -t my-template")
    end)
  end)
end)
