-- tests/spec/chat_orchestrator_spec.lua

require('mock_vim')

describe("llm.chat orchestrator", function()
  local chat
  local mock_session_instance
  local mock_buffer_instance
  local session_new_called = false
  local buffer_new_called = false

  before_each(function()
    -- Mock Session and Buffer modules
    mock_session_instance = {
      send_prompt_called = false,
      send_prompt = function(self)
        self.send_prompt_called = true
        return { pid = 123 }
      end,
      is_ready = function() return true end,
    }
    mock_buffer_instance = {
        get_bufnr = function() return 1 end,
        get_user_input = function() return "user input" end,
        set_status_called_with = nil,
        set_status = function(self, status) self.set_status_called_with = status end,
        append_user_message_called_with = nil,
        append_user_message = function(self, message) self.append_user_message_called_with = message end,
        clear_input_called = false,
        clear_input = function(self) self.clear_input_called = true end,
    }

    local mock_session = {
      new = function()
        session_new_called = true
        return mock_session_instance
      end
    }
    local mock_buffer = {
      new = function()
        buffer_new_called = true
        return mock_buffer_instance
      end
    }

    package.loaded["llm.chat.session"] = mock_session
    package.loaded["llm.chat.buffer"] = mock_buffer

    -- Reload the chat module to use the mocks
    package.loaded["llm.chat"] = nil
    chat = require("llm.chat")

    session_new_called = false
    buffer_new_called = false
  end)

  after_each(function()
    package.loaded["llm.chat.session"] = nil
    package.loaded["llm.chat.buffer"] = nil
    package.loaded["llm.chat"] = nil
  end)

  it("should start a chat and send a message", function()
    -- Arrange
    vim.b[1] = {}

    -- Act
    chat.start_chat()
    chat.send_message()

    -- Assert
    assert.is_true(session_new_called)
    assert.is_true(buffer_new_called)
    assert.is_true(mock_session_instance.send_prompt_called)
    assert.are.same("Processing...", mock_buffer_instance.set_status_called_with)
    assert.are.same("user input", mock_buffer_instance.append_user_message_called_with)
    assert.is_true(mock_buffer_instance.clear_input_called)
  end)
end)
