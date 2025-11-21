local spy = require('luassert.spy')

describe('plugin/llm.lua', function()
  local command_handler_func
  local chat_mock
  local llm_mock
  local commands_mock
  local schemas_manager_mock
  local templates_manager_mock
  local shell_mock
  local config_mock

  before_each(function()
    -- The existing mock_vim doesn't use a .new() constructor.
    -- We load it and then add the specific spies we need for this test.
    _G.vim = require('tests.spec.mock_vim')
    _G.vim.g = {} -- For the if vim.g.loaded_llm check
    _G.vim.split = spy.new(function(str, _)
        if str == '' then return {} end
        local result = {}
        -- Simple space-based split for testing
        for s in str:gmatch("%S+") do
          table.insert(result, s)
        end
        return result
    end)

    command_handler_func = nil
    _G.vim.api.nvim_create_user_command = spy.new(function(name, handler, _)
      if name == 'LLM' then
        command_handler_func = handler
      end
    end)
    -- Add mocks for the functions called by chat.start_chat() -> ui.create_split_buffer()
    _G.vim.api.nvim_create_buf = spy.new(function() return 1 end) -- return a dummy buffer handle
    _G.vim.api.nvim_open_win = spy.new(function() return 1 end) -- return a dummy window handle

    chat_mock = { start_chat = spy.new() }
    llm_mock = {
      prompt = spy.new(),
      setup = spy.new()
    }
    commands_mock = {
      prompt = spy.new(),
      prompt_with_current_file = spy.new(),
      prompt_with_selection = spy.new(),
      explain_code = spy.new(),
    }
    schemas_manager_mock = { select_schema = spy.new() }
    templates_manager_mock = { select_template = spy.new() }
    shell_mock = {
      check_llm_installed = spy.new(function() return true end),
      update_llm_cli = spy.new(),
    }
    config_mock = { get = spy.new() }

    -- Use package.loaded for robust mocking
    package.loaded['llm'] = llm_mock
    package.loaded['llm.chat'] = chat_mock
    package.loaded['llm.commands'] = commands_mock
    package.loaded['llm.managers.schemas_manager'] = schemas_manager_mock
    package.loaded['llm.managers.templates_manager'] = templates_manager_mock
    package.loaded['llm.core.utils.shell'] = shell_mock
    package.loaded['llm.config'] = config_mock
    -- The chat module requires the ui module, so we need a mock for it.
    package.loaded['llm.core.utils.ui'] = { create_split_buffer = spy.new() }


    -- Sideload the plugin. This will call our mocked nvim_create_user_command
    -- which captures the handler function.
    package.loaded['plugin/llm'] = nil
    -- Using require is better than dofile as it interacts with package.loaded
    require('plugin/llm')
  end)

  after_each(function()
    -- Clean up mocks from package.loaded
    package.loaded['plugin/llm'] = nil
    package.loaded['llm'] = nil
    package.loaded['llm.chat'] = nil
    package.loaded['llm.commands'] = nil
    package.loaded['llm.managers.schemas_manager'] = nil
    package.loaded['llm.managers.templates_manager'] = nil
    package.loaded['llm.core.utils.shell'] = nil
    package.loaded['llm.config'] = nil
    package.loaded['llm.core.utils.ui'] = nil
    _G.vim = nil
  end)

  describe(':LLM command handler', function()
    it('should call chat.start_chat() when called with no arguments', function()
      assert.is_not_nil(command_handler_func)
      command_handler_func({ args = '', range = 0 })
      assert.spy(chat_mock.start_chat).was.called()
      assert.spy(llm_mock.prompt).was.not_called()
    end)

    it('should call commands.prompt() when called with a prompt', function()
      assert.is_not_nil(command_handler_func)
      command_handler_func({ args = 'hello world', range = 0 })
      assert.spy(commands_mock.prompt).was.called_with('hello world')
      assert.spy(chat_mock.start_chat).was.not_called()
    end)
  end)
end)
