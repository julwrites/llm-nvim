-- tests/spec/chat_orchestrator_spec.lua

require('mock_vim')

describe("llm.chat orchestrator", function()
  local chat
  local mock_session_instance
  local mock_buffer_instance

  before_each(function()
    -- Mock Session and Buffer modules
    mock_session_instance = {
      send_prompt = spy.new(function(self)
        return { pid = 123 }
      end),
      is_ready = function() return true end,
    }
    mock_buffer_instance = {
        get_bufnr = function() return 1 end,
        get_user_input = function() return "user input" end,
        append_user_message = spy.new(function() end),
        add_llm_header = spy.new(function() end),
    }

    local mock_session = {
      ChatSession = {
        new = spy.new(function()
          return mock_session_instance
        end),
      },
    }
    local mock_buffer = {
      ChatBuffer = {
        new = spy.new(function()
          return mock_buffer_instance
        end),
      },
    }

    package.loaded["llm.chat.session"] = mock_session
    package.loaded["llm.chat.buffer"] = mock_buffer

    -- Reload the chat module to use the mocks
    package.loaded["llm.chat"] = nil
    chat = require("llm.chat")
  end)

  after_each(function()
    package.loaded["llm.chat.session"] = nil
    package.loaded["llm.chat.buffer"] = nil
    package.loaded["llm.chat"] = nil
  end)

  it("should start a chat and send a message", function()
    -- Arrange
    vim.b[1] = {}
    local result = chat.start_chat()
    -- Manually insert into the internal active_sessions table for testing
    local active_sessions = chat.get_session(1)
    active_sessions.session = mock_session_instance
    active_sessions.buffer = mock_buffer_instance
    vim.api.nvim_get_current_buf = spy.new(function() return 1 end)

    -- Act
    chat.send_message()

    -- Assert
    assert.spy(require("llm.chat.session").ChatSession.new).was.called()
    assert.spy(require("llm.chat.buffer").ChatBuffer.new).was.called()
    assert.spy(mock_session_instance.send_prompt).was.called()
    assert.spy(mock_buffer_instance.append_user_message).was.called_with(mock_buffer_instance, "user input")
    assert.spy(mock_buffer_instance.add_llm_header).was.called()
  end)
end)
