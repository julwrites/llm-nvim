require('spec_helper')
local spy = require('luassert.spy')

describe('llm.api', function()
  local api
  local config_mock

  before_each(function()
    package.loaded['llm.config'] = nil

    config_mock = {
      setup = spy.new(function() end),
    }

    package.loaded['llm.config'] = config_mock

    api = require('llm.api')
  end)

  after_each(function()
    package.loaded['llm.config'] = nil
  end)

  it('should call config.setup with provided options', function()
    local opts = { model = 'test-model' }
    api.setup(opts)
    assert.spy(config_mock.setup).was.called_with(opts)
  end)

  describe('facade functions', function()
    local facade_mock

    before_each(function()
      facade_mock = {
        get_manager = spy.new(function() end),
        command = spy.new(function() end),
        prompt = spy.new(function() end),
        prompt_with_selection = spy.new(function() end),
        prompt_with_current_file = spy.new(function() end),
        toggle_unified_manager = spy.new(function() end),
      }
      package.loaded['llm.facade'] = facade_mock
      -- Rerequire api to get the mocked facade
      package.loaded['llm.api'] = nil
      api = require('llm.api')
    end)

    after_each(function()
      package.loaded['llm.facade'] = nil
    end)

    it('should expose all facade functions', function()
      for name, func in pairs(facade_mock) do
        assert.is_function(api[name], "Expected api." .. name .. " to be a function")
        api[name]("test_arg")
        assert.spy(func).was.called_with("test_arg")
      end
    end)
  end)

  describe('run_llm_command', function()
    local job_mock
    local vim_fn_mock

    before_each(function()
      job_mock = {
        run = spy.new(function()
          return { id = 1 }
        end),
      }
      vim_fn_mock = {
        jobsend = spy.new(function() end),
      }
      package.loaded['llm.core.utils.job'] = job_mock
      -- Rerequire api to get the mocked job
      package.loaded['llm.api'] = nil
      api = require('llm.api')
      vim.fn = vim_fn_mock
    end)

    after_each(function()
      package.loaded['llm.core.utils.job'] = nil
    end)

    it('should call job.run with the correct arguments', function()
      local command_parts = { 'llm', 'prompt' }
      local prompt = 'test prompt'
      local callbacks = {
        on_stdout = function() end,
        on_stderr = function() end,
        on_exit = function() end,
      }
      api.run_llm_command(command_parts, prompt, callbacks)
      assert.spy(job_mock.run).was.called_with({
        command = command_parts,
        on_stdout = callbacks.on_stdout,
        on_stderr = callbacks.on_stderr,
        on_exit = callbacks.on_exit,
      })
    end)

    it('should call vim.fn.jobsend with the correct prompt', function()
      local command_parts = { 'llm', 'prompt' }
      local prompt = 'test prompt'
      local callbacks = {
        on_stdout = function() end,
        on_stderr = function() end,
        on_exit = function() end,
      }
      api.run_llm_command(command_parts, prompt, callbacks)
      assert.spy(vim.fn.jobsend).was.called_with(1, prompt)
    end)

    it('should pass callbacks to job.run', function()
      local command_parts = { 'llm', 'prompt' }
      local prompt = 'test prompt'
      local on_stdout_spy = spy.new(function() end)
      local on_stderr_spy = spy.new(function() end)
      local on_exit_spy = spy.new(function() end)

      local callbacks = {
        on_stdout = on_stdout_spy,
        on_stderr = on_stderr_spy,
        on_exit = on_exit_spy,
      }

      local captured_callbacks
      job_mock.run = spy.new(function(args)
        captured_callbacks = args
        return { id = 1 }
      end)

      api.run_llm_command(command_parts, prompt, callbacks)

      captured_callbacks.on_stdout(nil, { 'data' })
      assert.spy(on_stdout_spy).was.called_with(nil, { 'data' })

      captured_callbacks.on_stderr(nil, { 'error' })
      assert.spy(on_stderr_spy).was.called_with(nil, { 'error' })

      captured_callbacks.on_exit(nil, 0)
      assert.spy(on_exit_spy).was.called_with(nil, 0)
    end)
  end)
end)
