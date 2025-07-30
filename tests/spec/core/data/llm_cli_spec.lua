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
      llm_cli.run_llm_command(command, on_stdout, on_stderr, on_exit)
      assert.spy(stream_mock.stream_command).was.called_with("llm " .. command, on_stdout, on_stderr, on_exit)
  end)

  it("should handle an empty command", function()
      llm_cli.run_llm_command("")
      assert.spy(stream_mock.stream_command).was.called_with("llm ", nil, nil, nil)
  end)

  it("should handle a command with special characters", function()
      local command = "prompt 'hello world'"
      llm_cli.run_llm_command(command)
      assert.spy(stream_mock.stream_command).was.called_with("llm " .. command, nil, nil, nil)
  end)
end)
