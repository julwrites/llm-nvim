require('tests.spec.spec_helper')

describe('llm.commands', function()
  local commands
  local config_mock
  local job_mock

  before_each(function()
    -- Mock the vim object
    _G.vim = {
      fn = {
        shellescape = spy.new(function(str)
          return str
        end),
        stdpath = spy.new(function()
            return "/tmp"
        end),
      },
      api = {
        nvim_buf_get_lines = spy.new(function()
          return { 'test prompt' }
        end),
        nvim_get_current_buf = spy.new(function()
          return 1
        end),
        nvim_buf_get_name = spy.new(function()
          return 'LLM_Scratch'
        end),
        nvim_buf_is_valid = spy.new(function()
          return true
        end),
        nvim_buf_set_lines = spy.new(function() end),
        nvim_create_augroup = spy.new(function() end),
        nvim_create_autocmd = spy.new(function() end),
        nvim_buf_set_option = spy.new(function() end),
        nvim_buf_set_name = spy.new(function() end),
        nvim_create_buf = spy.new(function() end),
        nvim_open_win = spy.new(function() end),
      },
      notify = spy.new(function() end),
      cmd = spy.new(function() end),
      list_extend = function(t1, t2)
        for _, v in ipairs(t2) do
          table.insert(t1, v)
        end
      end,
    }

    config_mock = {
      get = spy.new(function(key)
        if key == 'model' then
          return 'test-model'
        end
        return nil
      end),
    }
    package.loaded['llm.config'] = config_mock

    job_mock = {
      run = spy.new(function() end),
    }
    package.loaded['llm.core.utils.job'] = job_mock

    package.loaded['llm.commands'] = nil
    commands = require('llm.commands')
  end)

  after_each(function()
    package.loaded['llm.config'] = nil
    package.loaded['llm.core.utils.job'] = nil
    _G.vim = nil
  end)

  it('should call llm with buffer content on BufWriteCmd', function()
    local get_lines_spy = spy.new(function()
        return { "Enter your prompt here and then save and close the buffer to continue.", "test prompt" }
    end)
    _G.vim.api.nvim_buf_get_lines = get_lines_spy

    local prompt_spy = spy.on(commands, 'prompt')

    -- To simulate the save, we need to get the callback from the autocmd
    local create_autocmd_spy = spy.new(function(event, opts)
        opts.callback()
    end)
    _G.vim.api.nvim_create_autocmd = create_autocmd_spy

    local ui_utils = require('llm.core.utils.ui')
    ui_utils.create_prompt_buffer()

    assert.spy(prompt_spy).was.called_with('test prompt')
  end)
end)
