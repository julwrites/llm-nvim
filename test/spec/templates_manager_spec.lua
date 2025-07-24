-- test/spec/templates_manager_spec.lua

describe("templates_manager", function()
  local templates_manager
  local spy
  local mock_templates_loader
  local mock_templates_view
  local mock_utils

  before_each(function()
    spy = require('luassert.spy')
    mock_templates_loader = {
      get_templates = function()
        return {
          template1 = 'description1',
          template2 = 'description2',
        }
      end,
      get_template_details = function(name)
        if name == 'template1' then
          return { name = 'template1', prompt = 'prompt1' }
        elseif name == 'test_loader:owner/repo/template' then
          return { name = 'test_loader:owner/repo/template', prompt = 'prompt1' }
        else
          return nil
        end
      end,
      delete_template = function() return true end,
      run_template = function() return "result" end,
      create_template = function() return true end,
    }

    mock_templates_view = {
      select_template = function(templates, callback) callback("template1") end,
      get_user_input = function(prompt, default, callback) callback("test") end,
      get_input_source = function(callback) callback("Current selection") end,
      get_template_type = function(callback) callback("Regular prompt") end,
      get_model_choice = function(callback) callback("Use default model") end,
      select_model = function(models, callback) callback("model1") end,
      get_fragment_choice = function(callback) callback("No fragments") end,
      get_add_fragment_choice = function(callback) callback("Done adding fragments") end,
      get_option_choice = function(callback) callback("No options") end,
      confirm_extract = function(callback) callback(true) end,
      get_schema_choice = function(callback) callback("No schema") end,
      select_schema = function(schemas, callback) callback("schema1") end,
      confirm_delete = function(template_name, callback) callback(true) end,
    }

    mock_utils = {
        get_config_path = function() return "" end,
        create_buffer_with_content = function() end,
        get_visual_selection = function() return "" end,
        check_llm_installed = function() return true end,
        safe_shell_command = function() return "" end,
    }

    vim.notify = function() end

    package.loaded['llm.core.loaders'] = mock_templates_loader
    package.loaded['llm.ui.views.templates_view'] = mock_templates_view
    package.loaded['llm.ui.unified_manager'] = {
      switch_view = function() end,
      close = function() end,
    }
    package.loaded['llm.core.utils'] = mock_utils

    templates_manager = require('llm.managers.templates_manager')
  end)

  after_each(function()
    package.loaded['llm.templates.templates_loader'] = nil
    package.loaded['llm.templates.templates_view'] = nil
    package.loaded['llm.templates.templates_manager'] = nil
    package.loaded['llm.unified_manager'] = nil
    package.loaded['llm.utils'] = nil
    vim.notify = nil
  end)

  it("should be a table", function()
    assert.is_table(templates_manager)
  end)

  describe("get_templates", function()
    it("should return the loaded templates", function()
      local templates = templates_manager.get_templates()
      table.sort(templates, function(a, b) return a.name < b.name end)
      assert.are.same({
        { name = 'template1', description = 'description1' },
        { name = 'template2', description = 'description2' },
      }, templates)
    end)
  end)

  describe("delete_template_under_cursor", function()
    it("should call delete on the template after confirmation", function(done)
        spy.on(templates_manager, 'get_template_info_under_cursor', function()
            return "template1", { start_line = 1, end_line = 1 }
        end)
        local delete_spy = spy.on(mock_templates_loader, 'delete_template')

        mock_templates_view.confirm_delete = function(name, cb)
          cb(true)
        end

        templates_manager.delete_template_under_cursor(1)

        vim.defer_fn(function()
            assert.spy(delete_spy).was.called_with("template1")
            done()
        end, 10)
    end)
  end)

  describe("create_template_from_manager", function()
    it("should call create_template", function(done)
      local create_template_spy = spy.on(templates_manager, 'create_template')
      templates_manager.create_template_from_manager(1)
      vim.defer_fn(function()
        assert.spy(create_template_spy).was.called()
        done()
      end, 10)
    end)
  end)

  describe("run_template_under_cursor", function()
    it("should run a regular template", function(done)
        spy.on(templates_manager, 'get_template_info_under_cursor', function()
            return "template1", { is_loader = false }
        end)
      local run_template_with_params_spy = spy.on(templates_manager, 'run_template_with_params')
      templates_manager.run_template_under_cursor(1)
      vim.defer_fn(function()
        assert.spy(run_template_with_params_spy).was.called_with("template1")
        done()
      end, 10)
    end)

    it("should handle template loaders", function(done)
        spy.on(templates_manager, 'get_template_info_under_cursor', function()
            return "loader:test_loader", { is_loader = true, prefix = "test_loader" }
        end)
        local run_template_with_params_spy = spy.on(templates_manager, 'run_template_with_params')

        local get_user_input_cb
        mock_templates_view.get_user_input = function(prompt, default, cb)
            get_user_input_cb = cb
        end

        templates_manager.run_template_under_cursor(1)
        if get_user_input_cb then
            get_user_input_cb("owner/repo/template")
        end

        vim.defer_fn(function()
            assert.spy(run_template_with_params_spy).was.called_with("test_loader:owner/repo/template")
            done()
        end, 10)
    end)
  end)

  describe("create_template", function()
    it("should create a basic template with a regular prompt", function()
      local create_spy = spy.on(mock_templates_loader, 'create_template')
      mock_templates_view.get_user_input = function(prompt, default, callback)
        if prompt == "Enter template name:" then
          callback("my_template")
        elseif prompt == "Enter prompt (use $input for user input):" then
          callback("My prompt with $input")
        end
      end
      mock_templates_view.get_template_type = function(callback) callback("Regular prompt") end
      mock_templates_view.get_model_choice = function(callback) callback("Use default model") end
      mock_templates_view.get_fragment_choice = function(callback) callback("No fragments") end
      mock_templates_view.get_option_choice = function(callback) callback("No options") end
      mock_templates_view.confirm_extract = function(callback) callback(true) end
      mock_templates_view.get_schema_choice = function(_, callback)
          -- This is the key to breaking the recursion
          if callback then callback("No schema") end
      end

      templates_manager.create_template()

      assert.spy(create_spy).was.called()
    end)

    it("should create a template with system prompt and model", function()
        package.loaded['llm.models.models_manager'] = {
            get_available_models = function() return {"model1"} end,
            extract_model_name = function(m) return m end,
        }
        local create_spy = spy.on(mock_templates_loader, 'create_template')

      mock_templates_view.get_user_input = function(prompt, default, callback)
        if prompt == "Enter template name:" then
          callback("sys_template")
        elseif prompt == "Enter system prompt:" then
          callback("System prompt")
        elseif prompt == "Enter regular prompt (use $input for user input):" then
          callback("Regular prompt")
        end
      end
      mock_templates_view.get_template_type = function(callback) callback("Both system and regular prompt") end
      mock_templates_view.get_model_choice = function(callback) callback("Select specific model") end
      mock_templates_view.select_model = function(models, callback) callback("model1") end
      mock_templates_view.get_fragment_choice = function(callback) callback("No fragments") end
      mock_templates_view.get_option_choice = function(callback) callback("No options") end
      mock_templates_view.confirm_extract = function(callback) callback(false) end
      mock_templates_view.get_schema_choice = function(_, callback)
          -- This is the key to breaking the recursion
          if callback then callback("No schema") end
      end

      templates_manager.create_template()

      assert.spy(create_spy).was.called()
    end)
  end)
end)
