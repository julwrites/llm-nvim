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
        floating_confirm = function(opts) opts.on_confirm(true) end,
        create_buffer_with_content = function() end,
        get_visual_selection = function() return "" end,
        check_llm_installed = function() return true end,
        floating_input = function(_, cb) cb("test") end,
    }
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
    it("should call delete on the template", function()
        local schedule_spy = spy.on(vim, 'schedule')
        vim.b[1] = {
            line_to_template = { [1] = "template1" },
            template_data = { template1 = { start_line = 1, end_line = 1 } }
        }
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        vim.cmd('redraw')
        templates_manager.delete_template_under_cursor(1)
        schedule_spy.calls[1].refs[1]()
        assert.spy(mock_templates_loader.delete_template).was.called_with("template1")
        schedule_spy:revert()
    end)
  end)

  describe("create_template_from_manager", function()
    it("should create a new template", function()
      local schedule_spy = spy.on(vim, 'schedule')
      local create_template_spy = spy.on(templates_manager, 'create_template')
      templates_manager.create_template_from_manager(1)
      schedule_spy.calls[1].refs[1]()
      assert.spy(create_template_spy).was.called()
      schedule_spy:revert()
    end)
  end)

  describe("run_template_under_cursor", function()
    it("should run a template", function()
      local schedule_spy = spy.on(vim, 'schedule')
      local run_template_with_params_spy = spy.on(templates_manager, 'run_template_with_params')
        vim.b[1] = {
            line_to_template = { [1] = "template1" },
            template_data = { template1 = { start_line = 1, end_line = 1 } }
        }
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        vim.cmd('redraw')
      templates_manager.run_template_under_cursor(1)
      schedule_spy.calls[1].refs[1]()
      assert.spy(run_template_with_params_spy).was.called_with("template1")
      schedule_spy:revert()
    end)
  end)
end)
