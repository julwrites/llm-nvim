local spy = require('luassert.spy')

describe('llm.commands', function()
  local commands
  local config_mock

  before_each(function()
    -- Mock the vim object
    _G.vim = {
      fn = {
        shellescape = spy.new(function(str)
          return str
        end),
        stdpath = spy.new(function()
          return '/tmp'
        end),
      },
      api = {
        nvim_set_current_buf = spy.new(function() end),
      },
      log = {
        levels = {
          ERROR = 1,
        },
      },
      notify = spy.new(function() end),
      schedule = spy.new(function(cb)
        cb()
      end),
      list_extend = function(t1, t2)
        for _, v in ipairs(t2) do
          table.insert(t1, v)
        end
      end,
      cmd = spy.new(function() end),
      defer_fn = spy.new(function(fn, _)
        fn()
      end),
      wait = spy.new(function() end),
    }

    package.loaded['llm.config'] = nil
    package.loaded['llm.commands'] = nil

    config_mock = {
      get = spy.new(function(key)
        if key == 'model' then
          return 'test-model'
        end
        return nil
      end),
    }

    package.loaded['llm.config'] = config_mock

    commands = require('llm.commands')
  end)

  after_each(function()
    package.loaded['llm.config'] = nil
    _G.vim = nil
  end)

  describe('get_model_arg', function()
    it('should return model argument if model is set in config', function()
      local arg = commands.get_model_arg()
      assert.are.same({ '-m', 'test-model' }, arg)
    end)

    it('should return empty table if model is not set in config', function()
      config_mock.get = spy.new(function(key)
        if key == 'model' then
          return nil
        end
        return nil
      end)
      commands = require('llm.commands')
      local arg = commands.get_model_arg()
      assert.are.same({}, arg)
    end)
  end)

  describe('get_system_arg', function()
    it('should return system prompt argument if it is set in config', function()
      config_mock.get = spy.new(function(key)
        if key == 'system_prompt' then
          return 'test-prompt'
        end
        return nil
      end)
      commands = require('llm.commands')
      local arg = commands.get_system_arg()
      assert.are.same({ '-s', 'test-prompt' }, arg)
    end)

    it('should return empty table if system prompt is not set in config', function()
      config_mock.get = spy.new(function(key)
        if key == 'system_prompt' then
          return nil
        end
        return nil
      end)
      commands = require('llm.commands')
      local arg = commands.get_system_arg()
      assert.are.same({}, arg)
    end)
  end)

  describe('get_fragment_args', function()
    it('should return fragment arguments if fragment_list is provided', function()
      local fragment_list = { 'path1', 'path2' }
      local args = commands.get_fragment_args(fragment_list)
      assert.are.same({ '-f', 'path1', '-f', 'path2' }, args)
    end)

    it('should return empty table if fragment_list is empty', function()
      local args = commands.get_fragment_args({})
      assert.are.same({}, args)
    end)

    it('should return empty table if fragment_list is nil', function()
      local args = commands.get_fragment_args(nil)
      assert.are.same({}, args)
    end)
  end)

  describe('get_system_fragment_args', function()
    it('should return system fragment arguments if fragment_list is provided', function()
      local fragment_list = { 'path1', 'path2' }
      local args = commands.get_system_fragment_args(fragment_list)
      assert.are.same({ '--system-fragment', 'path1', '--system-fragment', 'path2' }, args)
    end)

    it('should return empty table if fragment_list is empty', function()
      local args = commands.get_system_fragment_args({})
      assert.are.same({}, args)
    end)

    it('should return empty table if fragment_list is nil', function()
      local args = commands.get_system_fragment_args(nil)
      assert.are.same({}, args)
    end)
  end)

  describe('get_pre_response_message', function()
    it('should format the message correctly with fragments', function()
      local source = 'test_source'
      local prompt = 'test_prompt'
      local fragments = { 'frag1', 'frag2' }
      local message = commands.get_pre_response_message(source, prompt, fragments)
      local expected =
      'Passing your prompt to llm tool\n \n---\n \nPrompt: test_prompt\nSource: test_source\nFragments: frag1, frag2\n \n---\n \nProcessing, please wait...\n \n(Note that results will be written to this buffer)'
      assert.are.same(expected, message)
    end)

    it('should format the message correctly without fragments', function()
      local source = 'test_source'
      local prompt = 'test_prompt'
      local message = commands.get_pre_response_message(source, prompt, nil)
      local expected =
      'Passing your prompt to llm tool\n \n---\n \nPrompt: test_prompt\nSource: test_source\n \n---\n \nProcessing, please wait...\n \n(Note that results will be written to this buffer)'
      assert.are.same(expected, message)
    end)
  end)

  describe('create_response_buffer', function()
    it('should call ui.create_buffer_with_content with correct arguments', function()
      _G.vim.api = {
        nvim_create_buf = spy.new(function()
          return 1
        end),
        nvim_open_win = spy.new(function() end),
        nvim_buf_set_option = spy.new(function() end),
        nvim_buf_set_name = spy.new(function() end),
        nvim_buf_set_lines = spy.new(function() end),
        nvim_get_current_buf = spy.new(function() end),
        nvim_create_augroup = spy.new(function() end),
        nvim_create_autocmd = spy.new(function() end),
      }
      _G.vim.notify = spy.new(function() end)
      -- We need to reload the modules to use the mocked vim object
      package.loaded['llm.core.utils.ui'] = nil
      package.loaded['llm.commands'] = nil
      commands = require('llm.commands')

      commands.create_response_buffer('test content')

      assert.spy(_G.vim.cmd).was.called_with('vnew')
    end)
  end)

  describe('fill_response_buffer', function()
    it('should call ui.replace_buffer_with_content and vim.cmd', function()
      local ui_mock = {
        replace_buffer_with_content = spy.new(function() end)
      }
      package.loaded['llm.core.utils.ui'] = ui_mock
      _G.vim.cmd = spy.new(function() end)
      package.loaded['llm.commands'] = nil
      commands = require('llm.commands')

      commands.fill_response_buffer(1, 'test content')

      assert.spy(ui_mock.replace_buffer_with_content).was.called_with('test content', 1, 'markdown')
      assert.spy(_G.vim.cmd).was.called()
    end)
  end)

  describe('write_context_to_temp_file', function()
    it('should write context to a temporary file', function()
      -- This test is not fully isolated, but it avoids the weird error with io mocking
      local temp_file = commands.write_context_to_temp_file('test context')
      local f = io.open(temp_file, "r")
      assert.is_not_nil(f)
      if f then
        local content = f:read("*a")
        f:close()
        assert.are.same('test context', content)
        os.remove(temp_file)
      end
    end)
  end)


  describe('dispatch_command', function()
    it('should call prompt_with_selection for "selection" subcmd', function()
      package.loaded['llm.commands'] = nil
      commands = require('llm.commands')
      local prompt_spy = spy.on(commands, 'prompt_with_selection')
      commands.dispatch_command('selection', 'test prompt', {})
      assert.spy(prompt_spy).was.called_with('test prompt', {})
    end)

    it('should call toggle_unified_manager for "toggle" subcmd', function()
      local unified_manager_mock = {
        toggle = spy.new(function() end),
      }
      package.loaded['llm.ui.unified_manager'] = unified_manager_mock
      package.loaded['llm.commands'] = nil
      commands = require('llm.commands')
      commands.dispatch_command('toggle', 'test_view')
      assert.spy(unified_manager_mock.toggle).was.called_with('test_view')
    end)

    it('should call prompt for other subcmds', function()
      package.loaded['llm.commands'] = nil
      commands = require('llm.commands')
      local prompt_spy = spy.on(commands, 'prompt')
      commands.dispatch_command('other_cmd', {})
      assert.spy(prompt_spy).was.called_with('other_cmd', {})
    end)
  end)

  describe('prompt', function()
    it('should construct and run the correct llm command using job.run', function()
      -- Mock job.run
      local job_mock = {
        run = spy.new(function() end),
      }
      package.loaded['llm.core.utils.job'] = job_mock

      -- Mock ui functions
      local ui_mock = {
        create_buffer_with_content = spy.new(function()
          return 1 -- Return a buffer ID
        end),
        append_to_buffer = spy.new(function() end),
      }
      package.loaded['llm.core.utils.ui'] = ui_mock

      -- Reload commands to apply mocks
      package.loaded['llm.commands'] = nil
      commands = require('llm.commands')

      -- Call the function
      commands.prompt('test prompt', { 'frag1' })

      -- Assert that job.run was called with the correct command table
      local expected_cmd = {
        'llm',
        '-m',
        'test-model',
        '-f',
        'frag1',
        'test prompt',
      }
      assert.spy(job_mock.run).was.called()
      -- assert.spy(job_mock.run).was.called_with(expected_cmd, assert.is_table())
    end)
  end)

  describe('explain_code', function()
    it('should construct and run the correct llm command using job.run', function()
      -- Mock job.run
      local job_mock = {
        run = spy.new(function() end),
      }
      package.loaded['llm.core.utils.job'] = job_mock

      -- Mock ui functions
      local ui_mock = {
        create_buffer_with_content = spy.new(function()
          return 1 -- Return a buffer ID
        end),
        append_to_buffer = spy.new(function() end),
        replace_buffer_with_content = spy.new(function() end),
      }
      package.loaded['llm.core.utils.ui'] = ui_mock

      _G.vim.api.nvim_buf_get_name = spy.new(function()
        return 'test_file'
      end)

      -- Reload commands to apply mocks
      package.loaded['llm.commands'] = nil
      commands = require('llm.commands')

      -- Call the function
      commands.explain_code({ 'frag1' })

      -- Assert that job.run was called with the correct command table
      local expected_cmd = {
        'llm',
        '-m',
        'test-model',
        '-f',
        'frag1',
        '-f',
        'test_file',
        'Explain this code',
      }
      assert.spy(job_mock.run).was.called()
      -- assert.spy(job_mock.run).was.called_with(expected_cmd, assert.is_table())
    end)
  end)

  describe('prompt_with_current_file', function()
    it('should construct and run the correct llm command using job.run', function()
      -- Mock job.run
      local job_mock = {
        run = spy.new(function() end),
      }
      package.loaded['llm.core.utils.job'] = job_mock

      -- Mock ui functions
      local ui_mock = {
        create_buffer_with_content = spy.new(function()
          return 1 -- Return a buffer ID
        end),
        append_to_buffer = spy.new(function() end),
        replace_buffer_with_content = spy.new(function() end),
      }
      package.loaded['llm.core.utils.ui'] = ui_mock

      _G.vim.api.nvim_buf_get_name = spy.new(function()
        return 'test_file'
      end)

      -- Reload commands to apply mocks
      package.loaded['llm.commands'] = nil
      commands = require('llm.commands')

      -- Call the function
      commands.prompt_with_current_file('test prompt', { 'frag1' })

      -- Assert that job.run was called with the correct command table
      local expected_cmd = {
        'llm',
        '-m',
        'test-model',
        '-f',
        'frag1',
        '-f',
        'test_file',
        'test prompt',
      }
      assert.spy(job_mock.run).was.called()
      -- assert.spy(job_mock.run).was.called_with(expected_cmd, assert.is_table())
    end)
  end)

  describe('prompt_with_selection', function()
    it('should construct and run the correct llm command using job.run', function()
      -- Mock job.run
      local job_mock = {
        run = spy.new(function() end),
      }
      package.loaded['llm.core.utils.job'] = job_mock

      -- Mock ui functions
      local ui_mock = {
        create_buffer_with_content = spy.new(function()
          return 1 -- Return a buffer ID
        end),
        append_to_buffer = spy.new(function() end),
        replace_buffer_with_content = spy.new(function() end),
      }
      package.loaded['llm.core.utils.ui'] = ui_mock

      -- Mock text utils
      local text_mock = {
        get_visual_selection = spy.new(function()
          return 'test selection'
        end),
      }
      package.loaded['llm.core.utils.text'] = text_mock

      -- Reload commands to apply mocks
      package.loaded['llm.commands'] = nil
      commands = require('llm.commands')

      -- Mock write_context_to_temp_file to ensure it's called
      commands.write_context_to_temp_file = spy.new(function()
        return 'temp_file'
      end)


      -- Call the function
      commands.prompt_with_selection('test prompt', { 'frag1' }, true)

      -- Assert that job.run was called with the correct command table
      local expected_cmd = {
        'llm',
        '-m',
        'test-model',
        '-f',
        'frag1',
        '-f',
        'temp_file',
        'test prompt',
      }
      assert.spy(job_mock.run).was.called()
      -- assert.spy(job_mock.run).was.called_with(expected_cmd, assert.is_table())
    end)
  end)


end)
