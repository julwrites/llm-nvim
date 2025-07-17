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
        -- Mock get_template_info_under_cursor to return a template
        spy.on(templates_manager, 'get_template_info_under_cursor', function()
            return "template1", { start_line = 1, end_line = 1 }
        end)

        -- Mock floating_confirm to simulate user confirmation
        local floating_confirm_spy = spy.on(package.loaded['llm.utils'], 'floating_confirm')

        templates_manager.delete_template_under_cursor(1)

        -- Simulate the callback from floating_confirm
        floating_confirm_spy.calls[1].refs[1].on_confirm(true)

        -- Check that delete_template was called
        assert.spy(mock_templates_loader.delete_template).was.called_with("template1")
    end)
  end)

  describe("create_template_from_manager", function()
    it("should call create_template", function()
      local create_template_spy = spy.on(templates_manager, 'create_template')
      templates_manager.create_template_from_manager(1)
      vim.defer_fn(function() end, 0) -- Simulate the scheduler
      assert.spy(create_template_spy).was.called()
    end)
  end)

  describe("run_template_under_cursor", function()
    it("should run a regular template", function()
        spy.on(templates_manager, 'get_template_info_under_cursor', function()
            return "template1", { is_loader = false }
        end)
      local run_template_with_params_spy = spy.on(templates_manager, 'run_template_with_params')

      templates_manager.run_template_under_cursor(1)
      vim.defer_fn(function() end, 0) -- Simulate the scheduler

      assert.spy(run_template_with_params_spy).was.called_with("template1")
    end)

    it("should handle template loaders", function()
        spy.on(templates_manager, 'get_template_info_under_cursor', function()
            return "loader:test_loader", { is_loader = true, prefix = "test_loader" }
        end)
        local floating_input_spy = spy.on(package.loaded['llm.utils'], 'floating_input')
        mock_templates_loader.get_template_details = function() return { prompt = "test" } end

        templates_manager.run_template_under_cursor(1)

        -- Simulate user providing a path
        floating_input_spy.calls[1].refs[2]("owner/repo/template")

        -- We can't easily test the rest of the flow due to nested callbacks
        -- But we can assert that we tried to get template details for the full path
        assert.spy(mock_templates_loader.get_template_details).was.called_with("test_loader:owner/repo/template")
    end)
  end)

  describe("create_template", function()
    it("should create a basic template with a regular prompt", function()
      local floating_input_spy = spy.on(package.loaded['llm.utils'], 'floating_input')
      local ui_select_spy = spy.on(vim.ui, 'select')

      templates_manager.create_template()

      -- Step 1: Template name
      floating_input_spy.calls[1].refs[2]("my_template")
      -- Step 2: Template type
      ui_select_spy.calls[1].refs[3]("Regular prompt")
      -- Step 3: Prompt
      floating_input_spy.calls[2].refs[2]("My prompt with $input")
      -- Step 4: Model
      ui_select_spy.calls[2].refs[3]("Use default model")
      -- Step 5: Fragments
      ui_select_spy.calls[3].refs[3]("No fragments")
      -- Step 6: Options
      ui_select_spy.calls[4].refs[3]("No options")
      -- Step 7: Parameters (should be skipped)
      -- Step 8: Extract
      package.loaded['llm.utils'].floating_confirm({ on_confirm = function(c) c(true) end })
      -- Step 9: Schema
      ui_select_spy.calls[5].refs[3]("No schema")

      -- Final call to create_template
      assert.spy(mock_templates_loader.create_template).was.called_with(
        "my_template", "My prompt with $input", "", nil, {}, {}, {}, {}, true, nil
      )
    end)

    it("should create a template with system prompt and model", function()
        local floating_input_spy = spy.on(package.loaded['llm.utils'], 'floating_input')
        local ui_select_spy = spy.on(vim.ui, 'select')
        local ui_input_spy = spy.on(vim.ui, 'input')
        spy.on(require('llm.models.models_manager'), 'get_available_models', function() return {"model1"} end)

        templates_manager.create_template()

        -- Step 1: Name
        floating_input_spy.calls[1].refs[2]("sys_template")
        -- Step 2: Type
        ui_select_spy.calls[1].refs[3]("Both system and regular prompt")
        -- Step 3: System prompt
        ui_input_spy.calls[1].refs[2]("System prompt")
        -- Step 3b: Regular prompt
        floating_input_spy.calls[2].refs[2]("Regular prompt")
        -- Step 4: Model
        ui_select_spy.calls[2].refs[3]("Select specific model")
        ui_select_spy.calls[3].refs[3]("model1")
        -- Step 5: Fragments
        ui_select_spy.calls[4].refs[3]("No fragments")
        -- Step 6: Options
        ui_select_spy.calls[5].refs[3]("No options")
        -- Step 8: Extract
        package.loaded['llm.utils'].floating_confirm({ on_confirm = function(c) c(false) end })
        -- Step 9: Schema
        ui_select_spy.calls[6].refs[3]("No schema")

        assert.spy(mock_templates_loader.create_template).was.called_with(
            "sys_template", "Regular prompt", "System prompt", "model1", {}, {}, {}, {}, false, nil
        )
    end)
  end)
end)
