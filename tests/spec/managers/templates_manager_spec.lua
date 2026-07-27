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
        templates_manager.save_template('test-template-save', 'Test prompt', 'Test system', 'gpt-4', { temperature = 0.5 }, { 'fragment1' }, { param1 = 'default1' }, true, 'schema1')
        assert.spy(spy).was.called_with("templates save test-template-save --prompt 'Test prompt' --system 'Test system' --model gpt-4 -o temperature '0.5' -f fragment1 -d param1 'default1' --extract --schema schema1")
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

  describe('select_template', function()
    it('should select template and run with params if no selection', function()
      local templates_view = require('llm.ui.views.templates_view')
      local old_select_template = templates_view.select_template
      local api = require('llm.api')
      local old_nvim_get_mode = api.nvim_get_mode
      api.nvim_get_mode = function() return { mode = 'n' } end

      local run_called = false
      local old_run = templates_manager.run_template_with_params
      templates_manager.run_template_with_params = function(name)
        run_called = true
        assert.are.equal('test-template', name)
      end

      templates_view.select_template = function(templates, cb)
        cb({ name = 'test-template' })
      end

      templates_manager.select_template()
      assert.is_true(run_called)

      templates_view.select_template = old_select_template
      api.nvim_get_mode = old_nvim_get_mode
      templates_manager.run_template_with_params = old_run
    end)
  end)

  describe('run_template_with_params', function()
    it('should run template with no params if template has none', function()
      local old_get_template_details = templates_manager.get_template_details
      templates_manager.get_template_details = function() return { prompt = 'No params' } end

      local run_called = false
      local old_run = templates_manager.run_template_with_input
      templates_manager.run_template_with_input = function(name, params)
        run_called = true
        assert.are.equal('test-template', name)
      end

      templates_manager.run_template_with_params('test-template')
      assert.is_true(run_called)

      templates_manager.get_template_details = old_get_template_details
      templates_manager.run_template_with_input = old_run
    end)
  end)

  describe('collect_params_and_run', function()
    it('should collect params and call callback', function()
      local templates_view = require('llm.ui.views.templates_view')
      local old_get_input = templates_view.get_user_input

      templates_view.get_user_input = function(prompt, default, cb)
        cb('test_val')
      end

      local cb_called = false
      templates_manager.collect_params_and_run('test-template', nil, {'param1'}, {}, function(params)
        cb_called = true
        assert.are.same({param1 = 'test_val'}, params)
      end)
      assert.is_true(cb_called)

      templates_view.get_user_input = old_get_input
    end)
  end)

  describe('run_template_with_input', function()
    it('should run template with selection', function()
      local templates_view = require('llm.ui.views.templates_view')
      local old_get_source = templates_view.get_input_source
      templates_view.get_input_source = function(cb) cb('Current selection') end

      local text = require('llm.core.utils.text')
      local old_get_sel = text.get_visual_selection
      text.get_visual_selection = function() return 'my selection' end

      local api = require('llm.api')
      local run_called = false
      local old_run = api.run_llm_command_streamed
      api.run_llm_command_streamed = function() run_called = true end

      local ui = require('llm.core.utils.ui')
      local old_create_win = ui.create_floating_window
      ui.create_floating_window = function() end

      templates_manager.run_template_with_input('test-template', {})
      assert.is_true(run_called)

      templates_view.get_input_source = old_get_source
      text.get_visual_selection = old_get_sel
      api.run_llm_command_streamed = old_run
      ui.create_floating_window = old_create_win
    end)
  end)

  describe('create_template_guided', function()
    it('should start template creation flow', function()
        local templates_view = require('llm.ui.views.templates_view')
        local old_get_input = templates_view.get_user_input
        local old_continue = templates_manager.continue_template_creation_type

        local continue_called = false
        templates_view.get_user_input = function(prompt, default, cb)
            cb('new-template')
        end
        templates_manager.continue_template_creation_type = function(template)
            continue_called = true
            assert.are.equal('new-template', template.name)
        end

        templates_manager.create_template_guided()
        assert.is_true(continue_called)

        templates_view.get_user_input = old_get_input
        templates_manager.continue_template_creation_type = old_continue
    end)
  end)

  describe('continue_template_creation_type', function()
    it('should handle Regular prompt', function()
        local templates_view = require('llm.ui.views.templates_view')
        local old_get_type = templates_view.get_template_type
        local old_get_input = templates_view.get_user_input
        local old_continue = templates_manager.continue_template_creation_model

        templates_view.get_template_type = function(cb) cb('Regular prompt') end
        templates_view.get_user_input = function(p, d, cb) cb('test prompt') end

        local called = false
        templates_manager.continue_template_creation_model = function(template)
            called = true
            assert.are.equal('test prompt', template.prompt)
        end

        templates_manager.continue_template_creation_type({})
        assert.is_true(called)

        templates_view.get_template_type = old_get_type
        templates_view.get_user_input = old_get_input
        templates_manager.continue_template_creation_model = old_continue
    end)

    it('should handle System prompt only', function()
        local templates_view = require('llm.ui.views.templates_view')
        local old_get_type = templates_view.get_template_type
        local old_get_input = templates_view.get_user_input
        local old_continue = templates_manager.continue_template_creation_model

        templates_view.get_template_type = function(cb) cb('System prompt only') end
        templates_view.get_user_input = function(p, d, cb) cb('test system') end

        local called = false
        templates_manager.continue_template_creation_model = function(template)
            called = true
            assert.are.equal('test system', template.system)
        end

        templates_manager.continue_template_creation_type({})
        assert.is_true(called)

        templates_view.get_template_type = old_get_type
        templates_view.get_user_input = old_get_input
        templates_manager.continue_template_creation_model = old_continue
    end)
  end)

  describe('continue_template_creation_model', function()
    it('should handle No specific model', function()
        local templates_view = require('llm.ui.views.templates_view')
        local old_get = templates_view.get_model_choice
        local old_continue = templates_manager.continue_template_creation_fragments

        templates_view.get_model_choice = function(cb) cb('Use default model') end

        local called = false
        templates_manager.continue_template_creation_fragments = function() called = true end

        templates_manager.continue_template_creation_model({})
        assert.is_true(called)

        templates_view.get_model_choice = old_get
        templates_manager.continue_template_creation_fragments = old_continue
    end)
  end)

  describe('buffer management', function()
    it('should build buffer data correctly', function()
      local templates = {{name = "test1", description = "desc1"}}
      local lines, data, line_to_template = templates_manager.build_buffer_data(templates)
      assert.is_not_nil(lines)
      assert.is_not_nil(data["test1"])
      assert.are.equal("test1", line_to_template[data["test1"].start_line])
    end)

    it('should populate buffer', function()
      local old_get = templates_manager.get_templates
      templates_manager.get_templates = function() return {{name = "test1"}} end
      local api = require('llm.api')
      local styles = require('llm.ui.styles')
      local old_setup = styles.setup_highlights
      local old_syntax = styles.setup_buffer_syntax
      styles.setup_highlights = function() end
      styles.setup_buffer_syntax = function() end
      local old_set = vim.api.nvim_buf_set_lines
      vim.api.nvim_buf_set_lines = function() end

      _G.vim.b = { [1] = {} }
      templates_manager.populate_templates_buffer(1)
      assert.is_not_nil(_G.vim.b[1].template_data)

      templates_manager.get_templates = old_get
      styles.setup_highlights = old_setup
      styles.setup_buffer_syntax = old_syntax
      vim.api.nvim_buf_set_lines = old_set
      _G.vim.b = nil
    end)
  end)

  describe('cursor operations', function()
    local old_cursor
    local old_vim_b
    before_each(function()
        old_vim_b = _G.vim.b
        _G.vim.b = { [1] = {
                template_data = {
                    ["test1"] = { start_line = 5, end_line = 7 }
                },
                line_to_template = {
                    [5] = "test1", [6] = "test1", [7] = "test1"
                }
            }}
        old_cursor = vim.api.nvim_win_get_cursor
        vim.api.nvim_win_get_cursor = function() return {6, 0} end
    end)
    after_each(function()
        _G.vim.b = old_vim_b
        vim.api.nvim_win_get_cursor = old_cursor
    end)
    after_each(function()
        _G.vim.b = nil
        vim.api.nvim_win_get_cursor = old_cursor
    end)
    after_each(function()
        _G.vim.b = nil
    end)

    it('should get template info under cursor', function()
        local name, data = templates_manager.get_template_info_under_cursor(1)
        assert.are.equal("test1", name)
        assert.is_not_nil(data)
    end)
  end)

  describe('continue_template_creation_fragments', function()
    it('should add fragments', function()
        local templates_view = require('llm.ui.views.templates_view')
        local old_get = templates_view.get_fragment_choice
        templates_view.get_fragment_choice = function(cb) cb('Add fragments') end

        local old_loop = templates_manager.add_fragments_loop
        local called = false
        templates_manager.add_fragments_loop = function(t, type, cb)
            called = true
            cb()
        end
        local old_continue = templates_manager.continue_template_creation_options
        local next_called = false
        templates_manager.continue_template_creation_options = function() next_called = true end

        templates_manager.continue_template_creation_fragments({})
        assert.is_true(called)
        assert.is_true(next_called)

        templates_view.get_fragment_choice = old_get
        templates_manager.add_fragments_loop = old_loop
        templates_manager.continue_template_creation_options = old_continue
    end)
  end)

  describe('add_fragments_loop', function()
    it('should handle enter path', function()
        local templates_view = require('llm.ui.views.templates_view')
        local old_get_choice = templates_view.get_add_fragment_choice
        local old_get_input = templates_view.get_user_input

        local choice_called = 0
        templates_view.get_add_fragment_choice = function(cb)
            if choice_called == 0 then
                choice_called = 1
                cb('Enter fragment path/URL')
            else
                cb('Done adding fragments')
            end
        end

        templates_view.get_user_input = function(p, d, cb) cb('test/path') end

        local done_called = false
        local template = {fragments = {}}
        templates_manager.add_fragments_loop(template, 'fragments', function() done_called = true end)

        assert.is_true(done_called)
        assert.are.equal('test/path', template.fragments[1])

        templates_view.get_add_fragment_choice = old_get_choice
        templates_view.get_user_input = old_get_input
    end)
  end)

  describe('continue_template_creation_options', function()
    it('should add options loop', function()
        local templates_view = require('llm.ui.views.templates_view')
        local old_get = templates_view.get_option_choice
        templates_view.get_option_choice = function(cb) cb('Add options') end

        local old_loop = templates_manager.add_options_loop
        local called = false
        templates_manager.add_options_loop = function(t, cb) called = true; cb() end

        local old_continue = templates_manager.continue_template_creation_params
        local next_called = false
        templates_manager.continue_template_creation_params = function() next_called = true end

        templates_manager.continue_template_creation_options({})
        assert.is_true(called)
        assert.is_true(next_called)

        templates_view.get_option_choice = old_get
        templates_manager.add_options_loop = old_loop
        templates_manager.continue_template_creation_params = old_continue
    end)
  end)

  describe('add_options_loop', function()
    it('should add options', function()
        local templates_view = require('llm.ui.views.templates_view')
        local old_get_input = templates_view.get_user_input

        local call_count = 0
        templates_view.get_user_input = function(p, d, cb)
            if call_count == 0 then
                call_count = 1
                cb('temp')
            elseif call_count == 1 then
                call_count = 2
                cb('0.5')
            else
                cb('')
            end
        end

        local template = {options = {}}
        local done_called = false
        templates_manager.add_options_loop(template, function() done_called = true end)

        assert.is_true(done_called)
        assert.are.equal('0.5', template.options['temp'])

        templates_view.get_user_input = old_get_input
    end)
  end)

  describe('continue_template_creation_params', function()
    it('should setup param defaults', function()
        local old_extract = templates_manager.extract_params
        templates_manager.extract_params = function() return {'p1'} end

        local config = require('llm.config')
        local old_get = config.get
        config.get = function(key) return true end

        local old_loop = templates_manager.set_param_defaults_loop
        local called = false
        templates_manager.set_param_defaults_loop = function(t, p, i, cb) called = true; cb() end

        local old_continue = templates_manager.continue_template_creation_extract
        local next_called = false
        templates_manager.continue_template_creation_extract = function() next_called = true end

        templates_manager.continue_template_creation_params({})
        assert.is_true(called)
        assert.is_true(next_called)

        templates_manager.extract_params = old_extract
        config.get = old_get
        templates_manager.set_param_defaults_loop = old_loop
        templates_manager.continue_template_creation_extract = old_continue
    end)
  end)

  describe('set_param_defaults_loop', function()
    it('should set defaults', function()
        local templates_view = require('llm.ui.views.templates_view')
        local old_get_input = templates_view.get_user_input
        templates_view.get_user_input = function(p, d, cb) cb('default_val') end

        local template = {defaults = {}}
        local done_called = false
        templates_manager.set_param_defaults_loop(template, {'p1'}, 1, function() done_called = true end)

        assert.is_true(done_called)
        assert.are.equal('default_val', template.defaults['p1'])

        templates_view.get_user_input = old_get_input
    end)
  end)

  describe('continue_template_creation_extract', function()
    it('should confirm extract', function()
        local templates_view = require('llm.ui.views.templates_view')
        local old_confirm = templates_view.confirm_extract
        templates_view.confirm_extract = function(cb) cb(true) end

        local old_continue = templates_manager.continue_template_creation_schema
        local called = false
        templates_manager.continue_template_creation_schema = function(template)
            called = true
            assert.is_true(template.extract)
        end

        templates_manager.continue_template_creation_extract({})
        assert.is_true(called)

        templates_view.confirm_extract = old_confirm
        templates_manager.continue_template_creation_schema = old_continue
    end)
  end)

  describe('continue_template_creation_schema', function()
    it('should handle schema', function()
        local templates_view = require('llm.ui.views.templates_view')
        local old_get = templates_view.get_schema_choice
        templates_view.get_schema_choice = function(cb) cb('Select schema') end
        local old_select = templates_view.select_schema
        templates_view.select_schema = function(schemas, cb) cb('schema1') end

        local schemas_manager = require('llm.managers.schemas_manager')
        local old_get_schemas = schemas_manager.get_schemas
        schemas_manager.get_schemas = function() return {} end

        local old_finalize = templates_manager.finalize_template_creation
        local called = false
        templates_manager.finalize_template_creation = function(template)
            called = true
            assert.are.equal('schema1', template.schema)
        end

        templates_manager.continue_template_creation_schema({})
        assert.is_true(called)

        templates_view.get_schema_choice = old_get
        templates_view.select_schema = old_select
        schemas_manager.get_schemas = old_get_schemas
        templates_manager.finalize_template_creation = old_finalize
    end)
  end)

  describe('finalize_template_creation', function()
    it('should handle success', function()
        local old_save = templates_manager.save_template
        templates_manager.save_template = function() return true end

        local deferred_called = false
        local old_defer = _G.vim.defer_fn
        _G.vim.defer_fn = function(cb, time) deferred_called = true; cb() end

        local old_manage = templates_manager.manage_templates
        local manage_called = false
        templates_manager.manage_templates = function() manage_called = true end

        templates_manager.finalize_template_creation({name = "test"})
        assert.is_true(deferred_called)
        assert.is_true(manage_called)

        templates_manager.save_template = old_save
        _G.vim.defer_fn = old_defer
        templates_manager.manage_templates = old_manage
    end)
  end)

  describe('setup_templates_keymaps', function()
    it('should setup keymaps', function()
        local old_set = vim.api.nvim_buf_set_keymap
        local call_count = 0
        vim.api.nvim_buf_set_keymap = function() call_count = call_count + 1 end

        templates_manager.setup_templates_keymaps(1)
        assert.are.equal(5, call_count)

        vim.api.nvim_buf_set_keymap = old_set
    end)
  end)

  describe('create_template_from_manager', function()
    it('should call create_template', function()
        local unified = require('llm.ui.unified_manager')
        local old_close = unified.close
        unified.close = function() end

        local old_create = templates_manager.create_template
        local called = false
        templates_manager.create_template = function() called = true end

        local old_schedule = _G.vim.schedule
        _G.vim.schedule = function(cb) cb() end

        templates_manager.create_template_from_manager(1)
        assert.is_true(called)

        unified.close = old_close
        templates_manager.create_template = old_create
        _G.vim.schedule = old_schedule
    end)
  end)

  describe('run_template_under_cursor', function()
    it('should run template', function()
        local old_info = templates_manager.get_template_info_under_cursor
        templates_manager.get_template_info_under_cursor = function() return 'test1', {} end

        local unified = require('llm.ui.unified_manager')
        local old_close = unified.close
        unified.close = function() end

        local old_run = templates_manager.run_template_with_params
        local called = false
        templates_manager.run_template_with_params = function(name) called = true; assert.are.equal('test1', name) end

        local old_schedule = _G.vim.schedule
        _G.vim.schedule = function(cb) cb() end

        templates_manager.run_template_under_cursor(1)
        assert.is_true(called)

        templates_manager.get_template_info_under_cursor = old_info
        unified.close = old_close
        templates_manager.run_template_with_params = old_run
        _G.vim.schedule = old_schedule
    end)
  end)

  describe('edit_template_under_cursor', function()
    it('should edit template', function()
        local old_info = templates_manager.get_template_info_under_cursor
        templates_manager.get_template_info_under_cursor = function() return 'test1', {} end

        local unified = require('llm.ui.unified_manager')
        local old_close = unified.close
        unified.close = function() end

        local old_edit = templates_manager.edit_template
        local called = false
        templates_manager.edit_template = function(name) called = true; assert.are.equal('test1', name) end

        local old_schedule = _G.vim.schedule
        _G.vim.schedule = function(cb) cb() end

        templates_manager.edit_template_under_cursor(1)
        assert.is_true(called)

        templates_manager.get_template_info_under_cursor = old_info
        unified.close = old_close
        templates_manager.edit_template = old_edit
        _G.vim.schedule = old_schedule
    end)
  end)

  describe('delete_template_under_cursor', function()
    it('should delete template', function()
        local old_info = templates_manager.get_template_info_under_cursor
        templates_manager.get_template_info_under_cursor = function() return 'test1', {} end

        local templates_view = require('llm.ui.views.templates_view')
        local old_confirm = templates_view.confirm_delete
        templates_view.confirm_delete = function(name, cb) cb(true) end

        local old_delete = templates_manager.delete_template
        templates_manager.delete_template = function() return true end

        local unified = require('llm.ui.unified_manager')
        local old_switch = unified.switch_view
        local called = false
        unified.switch_view = function(view) called = true; assert.are.equal('Templates', view) end

        local old_schedule = _G.vim.schedule
        _G.vim.schedule = function(cb) cb() end

        templates_manager.delete_template_under_cursor(1)
        assert.is_true(called)

        templates_manager.get_template_info_under_cursor = old_info
        templates_view.confirm_delete = old_confirm
        templates_manager.delete_template = old_delete
        unified.switch_view = old_switch
        _G.vim.schedule = old_schedule
    end)
  end)

  describe('view_template_details_under_cursor', function()
    it('should view template details', function()
        local old_info = templates_manager.get_template_info_under_cursor
        templates_manager.get_template_info_under_cursor = function() return 'test1', {} end

        local old_details = templates_manager.get_template_details
        templates_manager.get_template_details = function() return {name='test1'} end

        local unified = require('llm.ui.unified_manager')
        local old_close = unified.close
        unified.close = function() end

        local old_show = templates_manager.show_template_details
        local called = false
        templates_manager.show_template_details = function(name, t) called = true; assert.are.equal('test1', name) end

        local old_schedule = _G.vim.schedule
        _G.vim.schedule = function(cb) cb() end

        templates_manager.view_template_details_under_cursor(1)
        assert.is_true(called)

        templates_manager.get_template_info_under_cursor = old_info
        templates_manager.get_template_details = old_details
        unified.close = old_close
        templates_manager.show_template_details = old_show
        _G.vim.schedule = old_schedule
    end)
  end)

  describe('show_template_details', function()
    it('should show details buffer', function()
        local ui = require('llm.core.utils.ui')
        local old_create = ui.create_floating_window
        ui.create_floating_window = function() end

        local old_create_buf = vim.api.nvim_create_buf
        vim.api.nvim_create_buf = function() return 1 end

        local old_set_opt = vim.api.nvim_buf_set_option
        vim.api.nvim_buf_set_option = function() end

        local old_set_name = vim.api.nvim_buf_set_name
        vim.api.nvim_buf_set_name = function() end

        local old_set_lines = vim.api.nvim_buf_set_lines
        vim.api.nvim_buf_set_lines = function() end

        local old_set_keymap = vim.api.nvim_buf_set_keymap
        vim.api.nvim_buf_set_keymap = function() end

        local styles = require('llm.ui.styles')
        local old_setup = styles.setup_buffer_styling
        styles.setup_buffer_styling = function() end

        templates_manager.show_template_details('test', {system = 's', prompt = 'p', model = 'm', extract = true, schema = 'sch'})

        ui.create_floating_window = old_create
        vim.api.nvim_create_buf = old_create_buf
        vim.api.nvim_buf_set_option = old_set_opt
        vim.api.nvim_buf_set_name = old_set_name
        vim.api.nvim_buf_set_lines = old_set_lines
        vim.api.nvim_buf_set_keymap = old_set_keymap
        styles.setup_buffer_styling = old_setup
    end)
  end)

  describe('run_template_by_name', function()
    it('should run template by name', function()
        local old_get = templates_manager.get_templates
        templates_manager.get_templates = function() return {{name = 'test1'}} end

        local unified = require('llm.ui.unified_manager')
        local old_close = unified.close
        unified.close = function() end

        local old_run = templates_manager.run_template_with_params
        local called = false
        templates_manager.run_template_with_params = function(name) called = true; assert.are.equal('test1', name) end

        local old_schedule = _G.vim.schedule
        _G.vim.schedule = function(cb) cb() end

        templates_manager.run_template_by_name('test1')
        assert.is_true(called)

        templates_manager.get_templates = old_get
        unified.close = old_close
        templates_manager.run_template_with_params = old_run
        _G.vim.schedule = old_schedule
    end)
  end)

  describe('edit_template_from_details', function()
    it('should close window and edit template', function()
        local old_close = vim.api.nvim_win_close
        local close_called = false
        vim.api.nvim_win_close = function() close_called = true end

        local old_edit = templates_manager.edit_template
        local edit_called = false
        templates_manager.edit_template = function(name) edit_called = true; assert.are.equal('test', name) end

        local old_schedule = _G.vim.schedule
        _G.vim.schedule = function(cb) cb() end

        templates_manager.edit_template_from_details('test')
        assert.is_true(close_called)
        assert.is_true(edit_called)

        vim.api.nvim_win_close = old_close
        templates_manager.edit_template = old_edit
        _G.vim.schedule = old_schedule
    end)
  end)

  describe('manage_templates', function()
    it('should open unified manager for templates', function()
        local unified = require('llm.ui.unified_manager')
        local old_open = unified.open_specific_manager
        local called = false
        unified.open_specific_manager = function(view) called = true; assert.are.equal('Templates', view) end

        templates_manager.manage_templates()
        assert.is_true(called)

        unified.open_specific_manager = old_open
    end)
  end)

  describe('run_template_with_input missing blocks', function()
    it('should handle Current buffer choice', function()
        local old_vim_b = _G.vim.b
        _G.vim.b = { [0] = {} }
        local templates_view = require('llm.ui.views.templates_view')
        local old_source = templates_view.get_input_source
        templates_view.get_input_source = function(cb) cb('Current buffer') end

        local old_get_lines = vim.api.nvim_buf_get_lines
        vim.api.nvim_buf_get_lines = function() return {'line1', 'line2'} end

        local ui = require('llm.core.utils.ui')
        local old_create_win = ui.create_floating_window
        ui.create_floating_window = function() end

        local api = require('llm.api')
        local old_run_cmd = api.run_llm_command_streamed
        local called = false
        api.run_llm_command_streamed = function() called = true end

        templates_manager.run_template_with_input('test', {})
        assert.is_true(called)

        templates_view.get_input_source = old_source
        vim.api.nvim_buf_get_lines = old_get_lines
        ui.create_floating_window = old_create_win
        api.run_llm_command_streamed = old_run_cmd
        _G.vim.b = old_vim_b
    end)

    it('should handle URL choice', function()
        local templates_view = require('llm.ui.views.templates_view')
        local old_source = templates_view.get_input_source
        templates_view.get_input_source = function(cb) cb('URL (will use curl)') end

        local old_input = templates_view.get_user_input
        templates_view.get_user_input = function(prompt, default, cb) cb('http://test.com') end

        local ui = require('llm.core.utils.ui')
        local old_create_buf = ui.create_buffer_with_content
        local called = false
        ui.create_buffer_with_content = function() called = true end

        templates_manager.run_template_with_input('test', {})
        assert.is_true(called)

        templates_view.get_input_source = old_source
        templates_view.get_user_input = old_input
        ui.create_buffer_with_content = old_create_buf
    end)
  end)

  describe('continue_template_creation_model branches', function()
    it('should handle Select specific model choice', function()
        local templates_view = require('llm.ui.views.templates_view')
        local old_choice = templates_view.get_model_choice
        templates_view.get_model_choice = function(cb) cb('Select specific model') end

        local models_manager = require('llm.managers.models_manager')
        local old_get_models = models_manager.get_available_models
        models_manager.get_available_models = function() return {} end
        local old_extract = models_manager.extract_model_name
        models_manager.extract_model_name = function(m) return m end

        local old_select = templates_view.select_model
        templates_view.select_model = function(models, cb) cb('gpt-4') end

        local old_continue = templates_manager.continue_template_creation_fragments
        local called = false
        templates_manager.continue_template_creation_fragments = function(t)
            called = true
            assert.are.equal('gpt-4', t.model)
        end

        templates_manager.continue_template_creation_model({})
        assert.is_true(called)

        templates_view.get_model_choice = old_choice
        models_manager.get_available_models = old_get_models
        models_manager.extract_model_name = old_extract
        templates_view.select_model = old_select
        templates_manager.continue_template_creation_fragments = old_continue
    end)
  end)

  describe('add_fragments_loop file browser', function()
    it('should select from file browser', function()
        local templates_view = require('llm.ui.views.templates_view')
        local old_choice = templates_view.get_add_fragment_choice

        local count = 0
        templates_view.get_add_fragment_choice = function(cb)
            if count == 0 then
                count = 1
                cb('Select from file browser')
            else
                cb('Done adding fragments')
            end
        end

        local fragments_manager = require('llm.managers.fragments_manager')
        local old_select = fragments_manager.select_file_as_fragment
        fragments_manager.select_file_as_fragment = function(cb) cb('file1.txt') end

        local template = {fragments = {}}
        local done_called = false
        templates_manager.add_fragments_loop(template, 'fragments', function() done_called = true end)

        assert.is_true(done_called)
        assert.are.equal('file1.txt', template.fragments[1])

        templates_view.get_add_fragment_choice = old_choice
        fragments_manager.select_file_as_fragment = old_select
    end)
  end)

  describe('continue_template_creation_type Both branch', function()
    it('should handle Both choice', function()
        local templates_view = require('llm.ui.views.templates_view')
        local old_type = templates_view.get_template_type
        templates_view.get_template_type = function(cb) cb('Both') end

        local count = 0
        local old_input = templates_view.get_user_input
        templates_view.get_user_input = function(p, d, cb)
            if count == 0 then
                count = 1
                cb('system test')
            else
                cb('prompt test')
            end
        end

        local old_continue = templates_manager.continue_template_creation_model
        local called = false
        templates_manager.continue_template_creation_model = function(t)
            called = true
            assert.are.equal('system test', t.system)
            assert.are.equal('prompt test', t.prompt)
        end

        templates_manager.continue_template_creation_type({})
        assert.is_true(called)

        templates_view.get_template_type = old_type
        templates_view.get_user_input = old_input
        templates_manager.continue_template_creation_model = old_continue
    end)
  end)
end)
