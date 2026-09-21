-- tests/spec/core/data/llm_cli_spec.lua
require('spec_helper')

describe("llm.core.data.llm_cli", function()
  local llm_cli
  local shell

  before_each(function()
    -- Create a mock for the shell module
    shell = {
      safe_shell_command = function() end,
    }
    package.loaded['llm.core.utils.shell'] = shell

    -- Reload the llm_cli module to use the mock
    package.loaded['llm.core.data.llm_cli'] = nil
    llm_cli = require('llm.core.data.llm_cli')
  end)

  after_each(function()
    -- Restore original modules
    package.loaded['llm.core.utils.shell'] = nil
    package.loaded['llm.core.data.llm_cli'] = nil
  end)

  it("should prepend 'llm ' to the command and call shell.safe_shell_command", function()
    -- Spy on the safe_shell_command function
    local spy = spy.on(shell, "safe_shell_command")

    -- Call the function to be tested
    local command = "models list"
    llm_cli.run_llm_command(command)

    -- Assert that the spy was called with the correct argument
    assert.spy(spy).was.called_with("llm " .. command)
  end)

  it("should handle an empty command", function()
    local spy = spy.on(shell, "safe_shell_command")
    llm_cli.run_llm_command("")
    assert.spy(spy).was.called_with("llm")
  end)

  it("should handle a command with special characters", function()
    local spy = spy.on(shell, "safe_shell_command")
    local command = "prompt 'hello world'"
    llm_cli.run_llm_command(command)
    assert.spy(spy).was.called_with("llm " .. command)
  end)

  describe("run_llm_command_async", function()
    local api

    before_each(function()
      api = {
        run_streaming_command = function() end,
      }
      package.loaded['llm.api'] = api
      package.loaded['llm.core.data.llm_cli'] = nil
      llm_cli = require('llm.core.data.llm_cli')
    end)

    after_each(function()
      package.loaded['llm.api'] = nil
      package.loaded['llm.core.data.llm_cli'] = nil
    end)

    it("should correctly buffer partial stdout data chunks", function()
      local command_ran = false
      api.run_streaming_command = function(_, _, callbacks)
        command_ran = true
        -- Send partial data stream
        callbacks.on_stdout(nil, { "first line", "second p" })
        callbacks.on_stdout(nil, { "artial", "third line", "" })

        callbacks.on_exit(nil, 0)
      end

      local callback_called = false
      local result_data = nil
      llm_cli.run_llm_command_async("test", function(data)
        callback_called = true
        result_data = data
      end)

      assert.is_true(command_ran)
      assert.is_true(callback_called)
      assert.are.equal("first line\nsecond partial\nthird line", result_data)
    end)

    it("should include any leftover buffer on exit", function()
      api.run_streaming_command = function(_, _, callbacks)
        callbacks.on_stdout(nil, { "first line", "partial end" })
        callbacks.on_exit(nil, 0)
      end

      local result_data = nil
      llm_cli.run_llm_command_async("test", function(data)
        result_data = data
      end)

      assert.are.equal("first line\npartial end", result_data)
    end)
  end)
end)
