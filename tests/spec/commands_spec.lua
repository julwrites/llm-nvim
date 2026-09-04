require('spec_helper')

describe('llm.commands', function() -- This is a new test suite for llm.commands
  local commands
  local api_mock
  local ui_mock

  before_each(function()
    -- Mock the llm.api module
    api_mock = {
      run_streaming_command = spy.new(function(cmd_parts, prompt, callbacks)
        api_mock.run_streaming_command.calls = { { cmd_parts, prompt, callbacks } }
      end),
    }
    package.loaded['llm.api'] = api_mock

    -- Mock the llm.core.utils.ui module
    ui_mock = {
      append_to_buffer = spy.new(function() end), -- Mock the append_to_buffer function
    }
    package.loaded['llm.core.utils.ui'] = ui_mock

    -- Mock the llm.config module
    package.loaded['llm.config'] = {
      get = spy.new(function(key)
        if key == 'llm_executable_path' then
          return '/usr/bin/llm'
        elseif key == 'model' then
          return 'test-model'
        elseif key == 'system_prompt' then
          return 'test-system-prompt'
        end
        return nil
      end),
    }

    -- Mock the llm.core.utils.text module
    local text_mock = { get_visual_selection = spy.new(function() return 'selected text' end) }
    package.loaded['llm.core.utils.text'] = text_mock

    -- Clear the commands module from package.loaded to ensure a fresh load
    package.loaded['llm.commands'] = nil
    commands = require('llm.commands')
  end)

  after_each(function()
    -- Clean up mocks after each test
    package.loaded['llm.api'] = nil
    package.loaded['llm.core.utils.ui'] = nil
  end)

  describe('get_system_fragment_args', function()
    it('should return empty table if system_fragment is nil', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'system_fragment' then return nil end
        return nil
      end)
      local result = commands.get_system_fragment_args()
      assert.same({}, result)
    end)

    it('should return --sf arguments if system_fragment is a string', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'system_fragment' then return 'sys_frag1' end
        return nil
      end)
      local result = commands.get_system_fragment_args()
      assert.same({ '--sf', 'sys_frag1' }, result)
    end)

    it('should return multiple --sf arguments if system_fragment is a table', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'system_fragment' then return { 'sys_frag1', 'sys_frag2' } end
        return nil
      end)
      local result = commands.get_system_fragment_args()
      assert.same({ '--sf', 'sys_frag1', '--sf', 'sys_frag2' }, result)
    end)
  end)

  describe('Query Option', function()
    it('get_query_arg should return empty if not set', function()
      package.loaded['llm.config'].get = spy.new(function(key) return nil end)
      assert.are.same({}, commands.get_query_arg())
    end)
    it('get_query_arg should return argument if set', function()
      package.loaded['llm.config'].get = spy.new(function(key) if key == 'query' then return 'test-query' end end)
      assert.are.same({"-q", "test-query"}, commands.get_query_arg())
    end)
  end)

  describe('Database Option', function()
    it('get_database_arg should return empty if not set', function()
      package.loaded['llm.config'].get = spy.new(function(key) return nil end)
      assert.are.same({}, commands.get_database_arg())
    end)
    it('get_database_arg should return argument if set', function()
      package.loaded['llm.config'].get = spy.new(function(key) if key == 'database' then return 'test.db' end end)
      assert.are.same({"-d", "test.db"}, commands.get_database_arg())
    end)
  end)

  describe('Logging Options', function()
    it('get_logging_args should return empty if neither is set', function()
      package.loaded['llm.config'].get = spy.new(function(key) return false end)
      assert.are.same({}, commands.get_logging_args())
    end)
    it('get_logging_args should return --no-log if set', function()
      package.loaded['llm.config'].get = spy.new(function(key) if key == 'no_log' then return true end return false end)
      assert.are.same({"--no-log"}, commands.get_logging_args())
    end)
    it('get_logging_args should return --log if set', function()
      package.loaded['llm.config'].get = spy.new(function(key) if key == 'log' then return true end return false end)
      assert.are.same({"--log"}, commands.get_logging_args())
    end)
  end)

  describe('Extended Tool Options', function()
    it('get_functions_arg should return empty if not set', function()
      package.loaded['llm.config'].get = spy.new(function(key) return nil end)
      assert.are.same({}, commands.get_functions_arg())
    end)
    it('get_functions_arg should return argument if set', function()
      package.loaded['llm.config'].get = spy.new(function(key) if key == 'functions' then return 'funcs.py' end end)
      assert.are.same({"--functions", "funcs.py"}, commands.get_functions_arg())
    end)

    it('get_tools_debug_arg should return empty if not set', function()
      package.loaded['llm.config'].get = spy.new(function(key) return nil end)
      assert.are.same({}, commands.get_tools_debug_arg())
    end)
    it('get_tools_debug_arg should return argument if set', function()
      package.loaded['llm.config'].get = spy.new(function(key) if key == 'tools_debug' then return true end end)
      assert.are.same({"--td"}, commands.get_tools_debug_arg())
    end)

    it('get_tools_approve_arg should return empty if not set', function()
      package.loaded['llm.config'].get = spy.new(function(key) return nil end)
      assert.are.same({}, commands.get_tools_approve_arg())
    end)
    it('get_tools_approve_arg should return argument if set', function()
      package.loaded['llm.config'].get = spy.new(function(key) if key == 'tools_approve' then return true end end)
      assert.are.same({"--ta"}, commands.get_tools_approve_arg())
    end)

    it('get_chain_limit_arg should return empty if not set', function()
      package.loaded['llm.config'].get = spy.new(function(key) return nil end)
      assert.are.same({}, commands.get_chain_limit_arg())
    end)
    it('get_chain_limit_arg should return argument if set', function()
      package.loaded['llm.config'].get = spy.new(function(key) if key == 'chain_limit' then return 3 end end)
      assert.are.same({"--cl", "3"}, commands.get_chain_limit_arg())
    end)
  end)

  describe('get_model_options_args', function()
    it('should return empty table if model_options is nil', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'model_options' then return nil end
        return nil
      end)
      local result = commands.get_model_options_args()
      assert.same({}, result)
    end)

    it('should return -o arguments if model_options is a table', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'model_options' then return { temperature = 0.8, top_p = 0.9 } end
        return nil
      end)
      local result = commands.get_model_options_args()
      -- Since pairs order is undefined, we need to check if both are present
      assert.is_true(#result == 6)

      local has_temp = false
      local has_topp = false
      for i = 1, #result, 3 do
        if result[i] == '-o' then
          if result[i+1] == 'temperature' and result[i+2] == '0.8' then
            has_temp = true
          elseif result[i+1] == 'top_p' and result[i+2] == '0.9' then
            has_topp = true
          end
        end
      end

      assert.is_true(has_temp)
      assert.is_true(has_topp)
    end)
  end)

  describe('get_template_params_args', function()
    it('should return empty table if template_params is nil', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'template_params' then return nil end
        return nil
      end)
      local result = commands.get_template_params_args()
      assert.same({}, result)
    end)

    it('should return -p arguments if template_params is a table', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'template_params' then return { name = 'World', age = 30 } end
        return nil
      end)
      local result = commands.get_template_params_args()
      assert.is_true(#result == 6)

      local has_name = false
      local has_age = false
      for i = 1, #result, 3 do
        if result[i] == '-p' then
          if result[i+1] == 'name' and result[i+2] == 'World' then
            has_name = true
          elseif result[i+1] == 'age' and result[i+2] == '30' then
            has_age = true
          end
        end
      end

      assert.is_true(has_name)
      assert.is_true(has_age)
    end)
  end)

  describe('get_template_arg', function()
    it('should return {-t, template_name} if template is set', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'template' then return 'my-template' end
        return nil
      end)
      local result = commands.get_template_arg()
      assert.same({ '-t', 'my-template' }, result)
    end)

    it('should return {} if template is not set', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'template' then return nil end
        return nil
      end)
      local result = commands.get_template_arg()
      assert.same({}, result)
    end)
  end)

  describe('get_hide_reasoning_arg', function()
    it('should return {-R} if hide_reasoning is true', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'hide_reasoning' then return true end
        return nil
      end)
      local result = commands.get_hide_reasoning_arg()
      assert.same({ '-R' }, result)
    end)

    it('should return {} if hide_reasoning is false', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'hide_reasoning' then return false end
        return nil
      end)
      local result = commands.get_hide_reasoning_arg()
      assert.same({}, result)
    end)
  end)

  describe('get_no_stream_arg', function()
    it('get_no_stream_arg should return empty if not set', function()
      package.loaded['llm.config'].get = spy.new(function(key) return nil end)
      local result = commands.get_no_stream_arg()
      assert.are.same({}, result)
    end)

    it('get_no_stream_arg should return argument if set', function()
      package.loaded['llm.config'].get = spy.new(function(key) if key == 'no_stream' then return true end return nil end)
      local result = commands.get_no_stream_arg()
      assert.are.same({"--no-stream"}, result)
    end)
  end)

  describe('get_async_arg', function()
    it('get_async_arg should return empty if not set', function()
      package.loaded['llm.config'].get = spy.new(function(key) return nil end)
      local result = commands.get_async_arg()
      assert.are.same({}, result)
    end)

    it('get_async_arg should return argument if set', function()
      package.loaded['llm.config'].get = spy.new(function(key) if key == 'async' then return true end return nil end)
      local result = commands.get_async_arg()
      assert.are.same({"--async"}, result)
    end)
  end)

  describe('get_save_template_arg', function()
    it('should return {--save, template_name} if save is set', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'save' then return 'my-template' end
        return nil
      end)
      local result = commands.get_save_template_arg()
      assert.same({ '--save', 'my-template' }, result)
    end)

    it('should return {} if save is not set', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'save' then return nil end
        return nil
      end)
      local result = commands.get_save_template_arg()
      assert.same({}, result)
    end)
  end)

  describe('get_schema_args', function()
    it('should return {--schema, schema} if schema is set', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'schema' then return 'test-schema' end
        return nil
      end)
      local result = commands.get_schema_args()
      assert.same({ '--schema', 'test-schema' }, result)
    end)

    it('should return {--schema-multi, schema_multi} if schema_multi is set', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'schema_multi' then return 'test-schema-multi' end
        return nil
      end)
      local result = commands.get_schema_args()
      assert.same({ '--schema-multi', 'test-schema-multi' }, result)
    end)

    it('should return {} if neither are set', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        return nil
      end)
      local result = commands.get_schema_args()
      assert.same({}, result)
    end)
  end)

  describe('get_usage_arg', function()
    it('should return {-u} if usage is true', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'usage' then return true end
        return nil
      end)
      local result = commands.get_usage_arg()
      assert.same({ '-u' }, result)
    end)

    it('should return {} if usage is false', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'usage' then return false end
        return nil
      end)
      local result = commands.get_usage_arg()
      assert.same({}, result)
    end)
  end)


  describe('get_json_arg', function()
    it('should return {--json} if json is true', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'json' then return true end
        return nil
      end)
      local result = commands.get_json_arg()
      assert.same({ '--json' }, result)
    end)

    it('should return {} if json is false', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'json' then return false end
        return nil
      end)
      local result = commands.get_json_arg()
      assert.same({}, result)
    end)
  end)

  describe('get_extract_arg', function()
    it('should return {-x} if extract is true', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'extract' then return true end
        return nil
      end)
      local result = commands.get_extract_arg()
      assert.same({ '-x' }, result)
    end)

    it('should return {} if extract is false', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'extract' then return false end
        return nil
      end)
      local result = commands.get_extract_arg()
      assert.same({}, result)
    end)
  end)

  describe('get_extract_last_arg', function()
    it('should return {--xl} if extract_last is true', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'extract_last' then return true end
        return nil
      end)
      local result = commands.get_extract_last_arg()
      assert.same({ '--xl' }, result)
    end)

    it('should return {} if extract_last is false', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'extract_last' then return false end
        return nil
      end)
      local result = commands.get_extract_last_arg()
      assert.same({}, result)
    end)
  end)

  describe('get_attachment_type_args', function()
    it('should return empty table if attachment_type is nil', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'attachment_type' then return nil end
        return nil
      end)
      local result = commands.get_attachment_type_args()
      assert.same({}, result)
    end)

    it('should return --at argument if attachment_type is a string', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'attachment_type' then return 'image/png' end
        return nil
      end)
      local result = commands.get_attachment_type_args()
      assert.same({ '--at', 'image/png' }, result)
    end)
  end)

  describe('get_attachment_args', function()
    it('should return empty table if attachment is nil', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'attachment' then return nil end
        return nil
      end)
      local result = commands.get_attachment_args()
      assert.same({}, result)
    end)

    it('should return -a arguments if attachment is a string', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'attachment' then return 'test_image.png' end
        return nil
      end)
      local result = commands.get_attachment_args()
      assert.same({ '-a', 'test_image.png' }, result)
    end)

    it('should return multiple -a arguments if attachment is a table', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'attachment' then return { 'image1.png', 'image2.png' } end
        return nil
      end)
      local result = commands.get_attachment_args()
      assert.same({ '-a', 'image1.png', '-a', 'image2.png' }, result)
    end)
  end)

  describe('get_conversation_args', function()
    it('should return {--cid, cid} if conversation_id is set', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'conversation_id' then return 'test-id' end
        return nil
      end)
      local result = commands.get_conversation_args()
      assert.same({ '--cid', 'test-id' }, result)
    end)

    it('should return {-c} if continue_conversation is true', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        if key == 'continue_conversation' then return true end
        return nil
      end)
      local result = commands.get_conversation_args()
      assert.same({ '-c' }, result)
    end)

    it('should return {} if neither are set', function()
      package.loaded['llm.config'].get = spy.new(function(key)
        return nil
      end)
      local result = commands.get_conversation_args()
      assert.same({}, result)
    end)
  end)

  describe('prompt', function()
    it('should call api.run_streaming_command with the correct arguments', function()
      commands.prompt('test prompt', {}, 1)

      assert.spy(api_mock.run_streaming_command).was.called()
      local call_args = api_mock.run_streaming_command.calls[1]
      assert.same({ '/usr/bin/llm', '-m', 'test-model', '-s', 'test-system-prompt' }, call_args[1])
      assert.are.equal('test prompt', call_args[2])
    end)

    it('should handle on_exit callback', function()
      local on_exit_spy = spy.new(function() end)
      commands.prompt('test prompt', {}, 1, on_exit_spy)

      assert.spy(api_mock.run_streaming_command).was.called()
      local call_args = api_mock.run_streaming_command.calls[1]
      local callbacks = call_args[3]

      callbacks.on_exit()
      assert.spy(on_exit_spy).was.called()
    end)

    it('should append data to the buffer on stdout', function()
      commands.prompt('test prompt', {}, 1)

      local call_args = api_mock.run_streaming_command.calls[1]
      local callbacks = call_args[3]
      callbacks.on_stdout(nil, { 'test output' })

      assert.spy(ui_mock.append_to_buffer).was.called_with(1, 'test output\n', 'LlmModelResponse')
    end)
  end)

  describe('prompt_with_current_file', function()
    it('should call api.run_streaming_command with the correct arguments', function()
      -- Mock vim.fn.expand to return a dummy file path
      vim.fn.expand = spy.new(function() return '/path/to/file.lua' end)

      commands.prompt_with_current_file('test prompt', {}, 1)

      assert.spy(api_mock.run_streaming_command).was.called()
      local call_args = api_mock.run_streaming_command.calls[1]
      assert.same({ '/usr/bin/llm', '-m', 'test-model', '-s', 'test-system-prompt', '-f', '/path/to/file.lua' }, call_args[1])
      assert.are.equal('test prompt', call_args[2])
    end)

    it('should append data to the buffer on stdout', function()
      -- Mock vim.fn.expand to return a dummy file path
      vim.fn.expand = spy.new(function() return '/path/to/file.lua' end)

      commands.prompt_with_current_file('test prompt', {}, 1)

      local call_args = api_mock.run_streaming_command.calls[1]
      local callbacks = call_args[3]
      callbacks.on_stdout(nil, { 'test output' })

      assert.spy(ui_mock.append_to_buffer).was.called_with(1, 'test output\n', 'LlmModelResponse')
    end)
  end)

  describe('prompt_with_selection', function()
    it('should return early if write_context_to_temp_file returns empty string', function()
      -- Mock dependencies
      commands.write_context_to_temp_file = spy.new(function() return '' end)

      commands.prompt_with_selection('test prompt', {}, true, 1)

      assert.spy(api_mock.run_streaming_command).was_not_called()
    end)

    it('should call api.run_streaming_command with the correct arguments', function()
      -- Mock dependencies
      commands.write_context_to_temp_file = spy.new(function() return '/tmp/temp_file' end)
      os.remove = spy.new(function() end)

      commands.prompt_with_selection('test prompt', {}, true, 1)

      assert.spy(api_mock.run_streaming_command).was.called()
      local call_args = api_mock.run_streaming_command.calls[1]
      assert.same({ '/usr/bin/llm', '-m', 'test-model', '-s', 'test-system-prompt', '-f', '/tmp/temp_file' }, call_args[1])
      assert.are.equal('test prompt', call_args[2])

      -- Test on_exit callback
      local callbacks = call_args[3]
      callbacks.on_exit()
      -- os.remove is no longer called manually
    end)
  end)

  describe('interactive_prompt_with_fragments', function()
    local text_mock
    local fragments_manager_mock

    local original_vim_ui_select
    local original_vim_ui_input
    local original_vim_notify
    local original_vim_fn_tempname
    local original_commands_prompt
    local original_io_open
    local original_vim_schedule

    before_each(function()
      original_vim_ui_select = vim.ui and vim.ui.select
      original_vim_ui_input = vim.ui and vim.ui.input
      original_vim_notify = vim.notify
      original_vim_fn_tempname = vim.fn.tempname
      original_commands_prompt = commands.prompt
      original_io_open = io.open
      original_vim_schedule = vim.schedule

      if not vim.ui then vim.ui = {} end

      text_mock = require('llm.core.utils.text')
      text_mock.get_visual_selection = spy.new(function() return nil end)

      fragments_manager_mock = require('llm.managers.fragments_manager')
      fragments_manager_mock.add_file_fragment = spy.new(function() end)
      fragments_manager_mock.add_github_fragment_from_manager = spy.new(function() end)

      vim.ui.select = spy.new(function(items, opts, on_choice)
        on_choice(nil)
      end)
      vim.ui.input = spy.new(function(opts, on_confirm)
        on_confirm(nil)
      end)
      vim.notify = spy.new(function() end)
      commands.prompt = spy.new(function() end)
      vim.schedule = spy.new(function(cb) cb() end)

      package.loaded['llm.managers.fragments_manager'] = fragments_manager_mock
    end)

    after_each(function()
      vim.ui.select = original_vim_ui_select
      vim.ui.input = original_vim_ui_input
      vim.notify = original_vim_notify
      vim.fn.tempname = original_vim_fn_tempname
      commands.prompt = original_commands_prompt
      io.open = original_io_open
      vim.schedule = original_vim_schedule
    end)

    it('should handle missing options and cancel selection', function()
      commands.interactive_prompt_with_fragments()
      assert.spy(vim.ui.select).was.called()
    end)

    it('should add visual selection if provided and valid', function()
      text_mock.get_visual_selection = spy.new(function() return "test selection" end)
      local mock_tempname = "/tmp/visual_selection"
      vim.fn.tempname = spy.new(function() return mock_tempname end)

      local mock_file = {
        write = spy.new(function() end),
        close = spy.new(function() end)
      }
      io.open = spy.new(function() return mock_file end)

      commands.interactive_prompt_with_fragments({ range = 1 })

      assert.spy(text_mock.get_visual_selection).was.called()
      assert.spy(vim.fn.tempname).was.called()
      assert.spy(io.open).was.called_with(mock_tempname, "w")
      assert.spy(mock_file.write).was.called_with(mock_file, "test selection")
      assert.spy(mock_file.close).was.called_with(mock_file)
      assert.spy(vim.notify).was.called_with("Added visual selection as fragment source.", vim.log.levels.INFO)
    end)

    it('should add visual selection error when temp file creation fails', function()
      text_mock.get_visual_selection = spy.new(function() return "test selection" end)
      local mock_tempname = "/tmp/visual_selection"
      vim.fn.tempname = spy.new(function() return mock_tempname end)

      io.open = spy.new(function() return nil end)

      commands.interactive_prompt_with_fragments({ range = 1 })

      assert.spy(vim.notify).was.called_with("Failed to create temporary file for visual selection.", vim.log.levels.ERROR)
    end)

    it('should select file as fragment', function()
      local call_count = 0
      vim.ui.select = spy.new(function(items, opts, on_choice)
        call_count = call_count + 1
        if call_count > 1 then
          on_choice(nil)
        else
          on_choice("Select file as fragment")
        end
      end)

      commands.interactive_prompt_with_fragments()
      assert.spy(fragments_manager_mock.add_file_fragment).was.called()
    end)

    it('should select github repo as fragment', function()
      local call_count = 0
      vim.ui.select = spy.new(function(items, opts, on_choice)
        call_count = call_count + 1
        if call_count > 1 then
          on_choice(nil)
        else
          on_choice("Use GitHub repository")
        end
      end)

      commands.interactive_prompt_with_fragments()
      assert.spy(fragments_manager_mock.add_github_fragment_from_manager).was.called()
    end)

    it('should handle enter fragment path/URL', function()
      local call_count = 0
      vim.ui.select = spy.new(function(items, opts, on_choice)
        call_count = call_count + 1
        if call_count > 1 then
          on_choice(nil)
        else
          on_choice("Enter fragment path/URL")
        end
      end)
      vim.ui.input = spy.new(function(opts, on_confirm)
        on_confirm("http://test.url")
      end)

      commands.interactive_prompt_with_fragments()
      assert.spy(vim.ui.input).was.called()
      assert.spy(vim.notify).was.called_with("Added fragment: http://test.url", vim.log.levels.INFO)
    end)

    it('should complete with prompt when fragments selected', function()
      local call_count = 0
      vim.ui.select = spy.new(function(items, opts, on_choice)
        call_count = call_count + 1
        if call_count == 1 then
          on_choice("Enter fragment path/URL")
        elseif call_count == 2 then
          on_choice("Done - continue with prompt")
        else
          on_choice(nil)
        end
      end)
      vim.ui.input = spy.new(function(opts, on_confirm)
        if opts.prompt == "Enter fragment path/URL: " then
          on_confirm("http://test.url")
        elseif opts.prompt == "Enter prompt: " then
          on_confirm("test prompt text")
        end
      end)

      commands.interactive_prompt_with_fragments()
      assert.spy(commands.prompt).was.called_with("test prompt text", { "http://test.url" }, nil, match.is_nil())
    end)

    it('should abort if prompt is empty', function()
      local call_count = 0
      vim.ui.select = spy.new(function(items, opts, on_choice)
        call_count = call_count + 1
        if call_count == 1 then
          on_choice("Enter fragment path/URL")
        elseif call_count == 2 then
          on_choice("Done - continue with prompt")
        else
          on_choice(nil)
        end
      end)
      vim.ui.input = spy.new(function(opts, on_confirm)
        if opts.prompt == "Enter fragment path/URL: " then
          on_confirm("http://test.url")
        elseif opts.prompt == "Enter prompt: " then
          on_confirm("")
        end
      end)

      commands.interactive_prompt_with_fragments()
      assert.spy(vim.notify).was.called_with("Prompt cannot be empty.", vim.log.levels.ERROR)
      assert.spy(commands.prompt).was_not.called()
    end)

    it('should notify and exit if done selected with no fragments', function()
      local call_count = 0
      vim.ui.select = spy.new(function(items, opts, on_choice)
        call_count = call_count + 1
        if call_count > 1 then
          on_choice(nil)
        else
          on_choice("Done - continue with prompt")
        end
      end)

      commands.interactive_prompt_with_fragments()
      assert.spy(vim.notify).was.called_with("No fragments selected.", vim.log.levels.WARN)
    end)
  end)
end)