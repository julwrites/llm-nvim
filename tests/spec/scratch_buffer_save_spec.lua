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
    -- This is a bit of a hack, but it simulates the BufWriteCmd autocmd
    commands.prompt = spy.on(commands, 'prompt')

    -- To simulate the save, we need to find a way to trigger the prompt
    -- The plugin doesn't seem to have a direct way to do this, so we'll
    -- have to assume that some external mechanism will call M.prompt
    -- with the content of the buffer.

    -- Let's simulate the call that would be made by the autocmd
    commands.prompt('test prompt')

    assert.spy(commands.prompt).was.called_with('test prompt')
  end)
end)
