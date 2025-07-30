-- tests/spec/core/data/llm_cli_spec.lua
local mock_vim = require('tests.spec.mock_vim')

describe("llm.core.data.llm_cli", function()
  local llm_cli
  local stream_mock

  before_each(function()
    mock_vim.setup()

    stream_mock = {
      stream_command = spy.new(function() end),
    }
    package.loaded['llm.core.utils.stream'] = stream_mock

    -- Reload the llm_cli module to use the mock
    package.loaded['llm.core.data.llm_cli'] = nil
    llm_cli = require('llm.core.data.llm_cli')
  end)

  after_each(function()
    mock_vim.teardown()
    package.loaded['llm.core.utils.stream'] = nil
    package.loaded['llm.core.data.llm_cli'] = nil
  end)

  it("should prepend 'llm ' to the command and call stream.stream_command", function()
      local command = "models list"
      local on_stdout = function() end
      local on_stderr = function() end
      local on_exit = function() end
      llm_cli.stream_llm_command(command, on_stdout, on_stderr, on_exit)
      assert.spy(stream_mock.stream_command).was.called_with("llm " .. command, on_stdout, on_stderr, on_exit)
  end)

  it("should prepend 'llm ' to the command and call shell.safe_shell_command", function()
    -- Spy on the safe_shell_command function
    local shell_mock = {
        safe_shell_command = spy.new(function() end)
    }
    package.loaded['llm.core.utils.shell'] = shell_mock
    package.loaded['llm.core.data.llm_cli'] = nil
    llm_cli = require('llm.core.data.llm_cli')
    -- Call the function to be tested
    local command = "models list"
    llm_cli.run_llm_command(command)

    -- Assert that the spy was called with the correct argument
    assert.spy(shell_mock.safe_shell_command).was.called_with("llm " .. command)
  end)
end)
