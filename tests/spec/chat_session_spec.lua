-- tests/spec/chat_spec.lua
require('spec_helper')

describe("llm.chat.session", function()
  local Session
  local captured_args

  before_each(function()
    -- Mock config
    local config_mock = {
      get = function(key)
        if key == "llm_executable_path" then
          return "/usr/bin/llm"
        end
        return nil
      end,
    }
    package.loaded["llm.config"] = config_mock
    -- Mock vim.g
    vim = { g = {} }
    -- Mock the api.run function to capture its arguments
    local mock_api = {
      run = function(args, callbacks)
        captured_args = args
        if callbacks and callbacks.on_stdout then
          callbacks.on_stdout(nil, { "assistant response" })
        end
        if callbacks and callbacks.on_exit then
          callbacks.on_exit()
        end
        return { wait = function() end }
      end,
    }
    package.loaded["llm.api"] = mock_api

    -- Reload the session module to use the mock
    package.loaded["llm.chat.session"] = nil
    Session = require("llm.chat.session").ChatSession

    -- Reset captured args
    captured_args = nil
  end)

  after_each(function()
    package.loaded["llm.api"] = nil
    package.loaded["llm.chat.session"] = nil
  end)

  it("should send the correct command with model and system prompt on first call", function()
    -- Arrange
    local session = Session.new({ model = "test-model", system_prompt = "test-system" })
    local expected_prompt = "user prompt"

    -- Act
    session:send_prompt(expected_prompt, {})

    -- Assert
    assert.is_not_nil(captured_args)
    assert.are.same("/usr/bin/llm", captured_args[1])
    assert.are.same("prompt", captured_args[2])
    assert.are.same("-m", captured_args[3])
    assert.are.same("test-model", captured_args[4])
    assert.are.same("-s", captured_args[5])
    assert.are.same("test-system", captured_args[6])
    assert.are.same(expected_prompt, captured_args[7])
  end)

  it("should not send system prompt on subsequent calls", function()
    -- Arrange
    local session = Session.new({ model = "test-model", system_prompt = "test-system" })

    -- Act
    session:send_prompt("first prompt", {}) -- First call
    session:send_prompt("second prompt", {}) -- Second call

    -- Assert
    assert.is_not_nil(captured_args)
    -- System prompt should not be present
    local has_system = false
    for _, arg in ipairs(captured_args) do
        if arg == "-s" then
            has_system = true
            break
        end
    end
    assert.is_false(has_system)

    -- Continuation should be present
    local has_continuation = false
    for _, arg in ipairs(captured_args) do
        if arg == "-c" then
            has_continuation = true
            break
        end
    end
    assert.is_true(has_continuation)
    assert.are.same("second prompt", captured_args[#captured_args])
  end)
end)
