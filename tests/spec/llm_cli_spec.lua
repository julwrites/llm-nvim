-- tests/spec/core/data/llm_cli_spec.lua

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
    assert.spy(spy).was.called_with("llm ")
  end)

  it("should handle a command with special characters", function()
    local spy = spy.on(shell, "safe_shell_command")
    local command = "prompt 'hello world'"
    llm_cli.run_llm_command(command)
    assert.spy(spy).was.called_with("llm " .. command)
  end)
end)
