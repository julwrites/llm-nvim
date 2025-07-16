-- test/spec/templates_manager_spec.lua

describe("templates_manager", function()
  local templates_manager
  local mock_templates_loader
  local mock_file_utils
  local mock_shell

  before_each(function()
    mock_templates_loader = {
      load_templates = function() return {} end,
    }

    mock_file_utils = {
      save_json = function(_, _) end,
      get_config_dir = function() return "config_dir" end,
    }

    mock_shell = {
      run = function(_) end,
    }

    package.loaded['llm.templates.templates_loader'] = mock_templates_loader
    package.loaded['llm.utils.file_utils'] = mock_file_utils
    package.loaded['llm.utils.shell'] = mock_shell
    package.loaded['llm.unified_manager'] = {
      switch_view = function() end,
    }
    templates_manager = require('llm.templates.templates_manager')
    templates_manager.load = function() end
  end)

  after_each(function()
    package.loaded['llm.templates.templates_loader'] = nil
    package.loaded['llm.templates.templates_manager'] = nil
    package.loaded['llm.utils.file_utils'] = nil
    package.loaded['llm.utils.shell'] = nil
  end)

  it("should be a table", function()
    assert.is_table(templates_manager)
  end)

  describe("get_templates", function()
    it("should return the loaded templates", function()
      local fake_templates = { { name = "template1" }, { name = "template2" } }
      mock_templates_loader.load_templates = function() return fake_templates end
      templates_manager:load()
      assert.are.same(fake_templates, templates_manager:get_templates())
    end)
  end)

  describe("get_template", function()
    it("should return the correct template by name", function()
      local fake_templates = { { name = "template1" }, { name = "template2" } }
      mock_templates_loader.load_templates = function() return fake_templates end
      templates_manager:load()
      assert.are.same(fake_templates[1], templates_manager:get_template("template1"))
    end)

    it("should return nil if the template is not found", function()
      local fake_templates = { { name = "template1" }, { name = "template2" } }
      mock_templates_loader.load_templates = function() return fake_templates end
      templates_manager:load()
      assert.is_nil(templates_manager:get_template("non_existent_template"))
    end)
  end)

  describe("delete_template", function()
    it("should call delete on the template", function()
      local deleted = false
      local fake_template = { name = "template1", delete = function() deleted = true end }
      local fake_templates = { fake_template }
      mock_templates_loader.load_templates = function() return fake_templates end
      templates_manager:load()
      templates_manager:delete_template("template1")
      assert.is_true(deleted)
    end)
  end)

  describe("create_template", function()
    it("should create a new template", function()
      local saved_path, saved_data
      mock_file_utils.save_json = function(path, data)
        saved_path = path
        saved_data = data
      end
      templates_manager:load()
      templates_manager:create_template("my-template", "My Template")
      assert.are.equal("config_dir/templates/my-template.json", saved_path)
      assert.are.same({ name = "my-template", description = "My Template" }, saved_data)
    end)
  end)

  describe("edit_template", function()
    it("should save the edited template", function()
      local saved_path, saved_data
      mock_file_utils.save_json = function(path, data)
        saved_path = path
        saved_data = data
      end
      templates_manager:load()
      templates_manager:edit_template("my-template", "My Edited Template")
      assert.are.equal("config_dir/templates/my-template.json", saved_path)
      assert.are.same({ name = "my-template", description = "My Edited Template" }, saved_data)
    end)
  end)

  describe("run_template", function()
    it("should run a template", function()
      local command_run
      mock_shell.run = function(command)
        command_run = command
      end
      templates_manager:load()
      templates_manager:run_template("my-template")
      assert.are.equal("llm -t my-template", command_run)
    end)
  end)
end)
