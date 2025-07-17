-- test/spec/templates_manager_spec.lua

describe("templates_manager", function()
  local templates_manager
  local spy
  local mock_templates_loader

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
        else
          return nil
        end
      end,
      delete_template = spy.new(function() return true end),
      run_template = spy.new(function() return "result" end),
      create_template = spy.new(function() return true end),
    }

    package.loaded['llm.utils'] = {
        get_config_path = function() return "" end,
        floating_confirm = function(opts, cb)
            if opts.on_confirm then
                opts.on_confirm(true) -- Simulate "yes"
            elseif cb then
                cb(true)
            end
        end,
        create_buffer_with_content = function() end,
        get_visual_selection = function() return "" end,
        check_llm_installed = function() return true end,
        floating_input = function(opts, cb)
            if cb then
                cb("test")
            end
        end,
    }

    vim.ui.select = function(items, opts, on_choice)
        if on_choice then
            on_choice(items[1]) -- Automatically select the first item
        end
    end

    vim.ui.input = function(opts, on_confirm)
        if on_confirm then
            on_confirm("test") -- Simulate some input
        end
    end

    -- Mock vim.notify to prevent it from printing during tests
    vim.notify = function() end

    package.loaded['llm.templates.templates_loader'] = mock_templates_loader
    package.loaded['llm.unified_manager'] = {
      switch_view = function() end,
      close = function() end,
    }

    templates_manager = require('llm.templates.templates_manager')
  end)

  after_each(function()
    package.loaded['llm.templates.templates_loader'] = nil
    package.loaded['llm.templates.templates_manager'] = nil
    package.loaded['llm.unified_manager'] = nil
    package.loaded['llm.utils'] = nil
    vim.ui.select = nil
    vim.ui.input = nil
    vim.notify = nil
  end)

  it("should be a table", function()
    assert.is_table(templates_manager)
  end)

  describe("get_templates", function()
    it("should return the loaded templates", function()
      local templates = templates_manager.get_templates()
      assert.are.same({
        template1 = 'description1',
        template2 = 'description2',
      }, templates)
    end)
  end)

  describe("delete_template_under_cursor", function()
    it("should call delete on the template after confirmation", function()
        spy.on(templates_manager, 'get_template_info_under_cursor', function()
            return "template1", { start_line = 1, end_line = 1 }
        end)

        local scheduled_function
        vim.schedule = function(fn)
            scheduled_function = fn
        end

        package.loaded['llm.utils'].floating_confirm = function(opts)
            opts.on_confirm(true)
        end

        templates_manager.delete_template_under_cursor(1)

        scheduled_function()

        assert.spy(mock_templates_loader.delete_template).was.called_with("template1")
    end)
  end)

  describe("create_template_from_manager", function()
    it("should call create_template", function()
      local create_template_spy = spy.on(templates_manager, 'create_template')
      local schedule_spy = spy.on(vim, 'schedule')
      templates_manager.create_template_from_manager(1)
      schedule_spy.calls[1].refs[1]()
      assert.spy(create_template_spy).was.called()
      schedule_spy:revert()
    end)
  end)

  describe("run_template_under_cursor", function()
    it("should run a regular template", function()
        spy.on(templates_manager, 'get_template_info_under_cursor', function()
            return "template1", { is_loader = false }
        end)
      local run_template_with_params_spy = spy.on(templates_manager, 'run_template_with_params')
      local scheduled_function
      vim.schedule = function(fn)
        scheduled_function = fn
      end
      templates_manager.run_template_under_cursor(1)
      scheduled_function(templates_manager)
      assert.spy(run_template_with_params_spy).was.called_with("template1")
    end)

    it("should handle template loaders", function()
        spy.on(templates_manager, 'get_template_info_under_cursor', function()
            return "loader:test_loader", { is_loader = true, prefix = "test_loader" }
        end)
        mock_templates_loader.get_template_details = spy.new(function() return { prompt = "test" } end)

        local floating_input_cb
        package.loaded['llm.utils'].floating_input = function(opts, cb)
            floating_input_cb = cb
        end

        templates_manager.run_template_under_cursor(1)
        floating_input_cb("owner/repo/template")

        assert.spy(mock_templates_loader.get_template_details).was.called_with("test_loader:owner/repo/template")
    end)
  end)

  describe("create_template", function()
    it("should create a basic template with a regular prompt", function()
      local floating_input_spy = spy.on(package.loaded['llm.utils'], 'floating_input')
      local ui_select_spy = spy.on(vim.ui, 'select')

      templates_manager.create_template()

      -- Step 1: Template name
      package.loaded['llm.utils'].floating_input = function(opts, cb) cb("my_template") end
      -- Step 2: Template type
      vim.ui.select = function(items, opts, on_choice) on_choice("Regular prompt") end
      -- Step 3: Prompt
      package.loaded['llm.utils'].floating_input = function(opts, cb) cb("My prompt with $input") end
      -- Step 4: Model
      vim.ui.select = function(items, opts, on_choice) on_choice("Use default model") end
      -- Step 5: Fragments
      vim.ui.select = function(items, opts, on_choice) on_choice("No fragments") end
      -- Step 6: Options
      vim.ui.select = function(items, opts, on_choice) on_choice("No options") end
      -- Step 7: Parameters (should be skipped)
      -- Step 8: Extract
      package.loaded['llm.utils'].floating_confirm = function(opts, cb) cb("Yes") end
      -- Step 9: Schema
      vim.ui.select = function(items, opts, on_choice) on_choice("No schema") end

      templates_manager.create_template()

      -- Final call to create_template
      assert.spy(mock_templates_loader.create_template).was.called()
    end)

    it("should create a template with system prompt and model", function()
        package.loaded['llm.models.models_manager'] = {
            get_available_models = function() return {"model1"} end,
            extract_model_name = function(m) return m end,
        }
      -- Step 1: Template name
      package.loaded['llm.utils'].floating_input = function(opts, cb) cb("sys_template") end
      -- Step 2: Template type
      vim.ui.select = function(items, opts, on_choice) on_choice("Both system and regular prompt") end
      -- Step 3: System prompt
      vim.ui.input = function(opts, on_confirm) on_confirm("System prompt") end
      -- Step 3b: Regular prompt
      package.loaded['llm.utils'].floating_input = function(opts, cb) cb("Regular prompt") end
      -- Step 4: Model
      vim.ui.select = function(items, opts, on_choice) on_choice("Select specific model") end
      vim.ui.select = function(items, opts, on_choice) on_choice("model1") end
      -- Step 5: Fragments
      vim.ui.select = function(items, opts, on_choice) on_choice("No fragments") end
      -- Step 6: Options
      vim.ui.select = function(items, opts, on_choice) on_choice("No options") end
      -- Step 8: Extract
      package.loaded['llm.utils'].floating_confirm = function(opts, cb) cb("No") end
      -- Step 9: Schema
      vim.ui.select = function(items, opts, on_choice) on_choice("No schema") end

      templates_manager.create_template()

      assert.spy(mock_templates_loader.create_template).was.called()
    end)
  end)
end)
