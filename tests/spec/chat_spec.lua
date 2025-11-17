require('spec_helper')

describe('llm.chat', function()
  local chat
  local ChatSession
  local ChatBuffer
  local config_mock

  before_each(function()
    -- Mock config
    config_mock = {
      get = spy.new(function(key)
        if key == "model" then return "test-model" end
        if key == "system_prompt" then return "test-system-prompt" end
        if key == "llm_executable_path" then return "/usr/bin/llm" end
        if key == "debug" then return false end
        return nil
      end),
    }
    package.loaded['llm.config'] = config_mock

    -- Mock shell module
    local shell_mock = {
      run = spy.new(function(cmd)
        -- Mock llm logs response
        return '[{"conversation_id": "test-conv-123"}]'
      end),
    }
    package.loaded['llm.core.utils.shell'] = shell_mock

    -- Mock job module
    local job_mock = {
      run = spy.new(function(cmd, callbacks)
        -- Return a mock job ID
        return 12345
      end),
    }
    package.loaded['llm.core.utils.job'] = job_mock

    -- Mock vim functions
    vim.api.nvim_get_current_buf = spy.new(function() return 1 end)
    vim.api.nvim_create_buf = spy.new(function() return 1 end)
    vim.api.nvim_buf_set_option = spy.new(function() end)
    vim.api.nvim_buf_set_name = spy.new(function() end)
    vim.api.nvim_buf_set_lines = spy.new(function() end)
    vim.api.nvim_buf_get_lines = spy.new(function()
      return {
        "╭──────────────────────╮",
        "│ Status: Ready        │",
        "╰──────────────────────╯",
        "",
        "┌─ Conversation History ──┐",
        "│ No messages yet         │",
        "└─────────────────────────┘",
        "",
        "┌─ Your Message (Press <C-CR> to send) ──┐",
        "│ Test message                            │",
        "└─────────────────────────────────────────┘",
      }
    end)
    vim.api.nvim_buf_add_highlight = spy.new(function() end)
    vim.api.nvim_buf_set_keymap = spy.new(function() end)
    vim.api.nvim_win_get_cursor = spy.new(function() return { 10, 0 } end)
    vim.api.nvim_win_set_cursor = spy.new(function() end)
    vim.api.nvim_buf_line_count = spy.new(function() return 11 end)
    vim.api.nvim_set_hl = spy.new(function() end)
    vim.api.nvim_create_autocmd = spy.new(function() end)
    vim.cmd = spy.new(function() end)
    vim.fn.jobstart = spy.new(function() return 12345 end)
    vim.fn.jobstop = spy.new(function() end)
    vim.fn.chansend = spy.new(function() end)
    vim.fn.chanclose = spy.new(function() end)
    vim.fn.mode = spy.new(function() return 'n' end)
    
    -- Mock vim.b with proper metatable for indexing
    local b_storage = {}
    vim.b = setmetatable({}, {
      __index = function(t, k)
        if not b_storage[k] then
          b_storage[k] = {}
        end
        return b_storage[k]
      end,
      __newindex = function(t, k, v)
        b_storage[k] = v
      end
    })
    
    -- Mock notify
    vim.notify = spy.new(function() end)

    -- Reload modules to pick up mocks
    package.loaded['llm.chat.session'] = nil
    package.loaded['llm.chat.buffer'] = nil
    package.loaded['llm.chat'] = nil
    
    ChatSession = require('llm.chat.session').ChatSession
    ChatBuffer = require('llm.chat.buffer').ChatBuffer
    chat = require('llm.chat')
  end)

  after_each(function()
    package.loaded['llm.config'] = nil
    package.loaded['llm.core.utils.shell'] = nil
    package.loaded['llm.core.utils.job'] = nil
    package.loaded['llm.chat.session'] = nil
    package.loaded['llm.chat.buffer'] = nil
    package.loaded['llm.chat'] = nil
  end)

  describe('ChatSession', function()
    it('should create a new session with default options', function()
      local session = ChatSession.new()
      
      assert.is_not_nil(session)
      assert.is_nil(session.conversation_id)
      assert.are.equal('ready', session.state)
    end)

    it('should create a new session with custom options', function()
      local session = ChatSession.new({
        model = "custom-model",
        system_prompt = "custom-prompt",
        fragments = { "/path/to/file.txt" },
      })
      
      assert.are.equal("custom-model", session.model)
      assert.are.equal("custom-prompt", session.system_prompt)
      assert.are.same({ "/path/to/file.txt" }, session.fragments)
    end)

    it('should build command for first message', function()
      local session = ChatSession.new({
        model = "gpt-4",
        system_prompt = "You are helpful",
      })
      
      local cmd = session:build_command("Hello")
      
      assert.are.same({
        "/usr/bin/llm", "prompt",
        "-m", "gpt-4",
        "-s", "You are helpful",
      }, cmd)
    end)

    it('should build command for continuation', function()
      local session = ChatSession.new({
        model = "gpt-4",
        system_prompt = "You are helpful",
      })
      session.conversation_id = "conv-123"
      
      local cmd = session:build_command("Follow up")
      
      assert.are.same({
        "/usr/bin/llm", "prompt",
        "-m", "gpt-4",
        "-c", "conv-123",
      }, cmd)
    end)

    it('should extract conversation ID from output', function()
      local session = ChatSession.new()
      
      local output = "Some response text\n\nConversation ID: abc123def\n"
      local id = session:extract_conversation_id(output)
      
      assert.are.equal("abc123def", id)
    end)

    it('should send prompt and update state', function()
      local session = ChatSession.new()
      
      local callbacks = {
        on_stdout = spy.new(function() end),
        on_stderr = spy.new(function() end),
        on_exit = spy.new(function() end),
      }
      
      local job_id = session:send_prompt("Test prompt", callbacks)
      
      assert.are.equal(12345, job_id)
      assert.are.equal('processing', session.state)
      assert.are.equal(12345, session.current_job_id)
    end)

    it('should check if session is ready', function()
      local session = ChatSession.new()
      
      assert.is_true(session:is_ready())
      
      session.state = 'processing'
      assert.is_false(session:is_ready())
      
      session.state = 'error'
      assert.is_false(session:is_ready())
    end)
  end)

  describe('ChatBuffer', function()
    it('should create a new buffer', function()
      local buffer = ChatBuffer.new()
      
      assert.is_not_nil(buffer)
      assert.are.equal(1, buffer.bufnr)
      assert.spy(vim.api.nvim_buf_set_option).was.called()
      assert.spy(vim.api.nvim_buf_set_keymap).was.called()
    end)

    it('should initialize layout with sections', function()
      local buffer = ChatBuffer.new()
      
      assert.spy(vim.api.nvim_buf_set_lines).was.called()
      assert.is_number(buffer.history_start_line)
      assert.is_number(buffer.history_end_line)
      assert.is_number(buffer.input_start_line)
      assert.is_number(buffer.input_end_line)
    end)

    it('should set status message', function()
      local buffer = ChatBuffer.new()
      
      buffer:set_status("Processing...")
      
      assert.spy(vim.api.nvim_buf_set_lines).was.called()
    end)

    it('should update conversation ID', function()
      local buffer = ChatBuffer.new()
      
      buffer:update_conversation_id("new-conv-123")
      
      assert.are.equal("new-conv-123", buffer.conversation_id)
      assert.spy(vim.api.nvim_buf_set_name).was.called()
    end)

    it('should append user message to history', function()
      local buffer = ChatBuffer.new()
      
      buffer:append_user_message("Hello, LLM!")
      
      assert.spy(vim.api.nvim_buf_set_lines).was.called()
      assert.spy(vim.api.nvim_buf_add_highlight).was.called()
    end)

    it('should append LLM message to history', function()
      local buffer = ChatBuffer.new()
      
      buffer:append_llm_message("Hello, user!")
      
      assert.spy(vim.api.nvim_buf_set_lines).was.called()
      assert.spy(vim.api.nvim_buf_add_highlight).was.called()
    end)

    it('should get user input from input area', function()
      local buffer = ChatBuffer.new()
      
      local input = buffer:get_user_input()
      
      -- Should extract "Test message" from the mocked buffer lines
      assert.is_string(input)
    end)

    it('should clear input area', function()
      local buffer = ChatBuffer.new()
      
      buffer:clear_input()
      
      assert.spy(vim.api.nvim_buf_set_lines).was.called()
    end)

    it('should focus input area', function()
      local buffer = ChatBuffer.new()
      
      buffer:focus_input()
      
      assert.spy(vim.api.nvim_win_set_cursor).was.called()
      assert.spy(vim.cmd).was.called_with('startinsert')
    end)
  end)

  describe('chat orchestration', function()
    local _session, _buffer, _bufnr
    
    before_each(function()
      local result = chat.start_chat({
        model = "gpt-4",
        system_prompt = "Test prompt",
      })
      _session = result.session
      _buffer = result.buffer
      _bufnr = _buffer:get_bufnr()
      
      -- Ensure vim.b is correctly set for the mocked buffer
      vim.b[_bufnr].llm_chat_bufnr = _bufnr
      
      -- Mock vim.api.nvim_get_current_buf to return the chat buffer
      vim.api.nvim_get_current_buf = spy.new(function() return _bufnr end)
    end)
    it('should start a new chat session', function()
      local result = chat.start_chat({
        model = "gpt-4",
        system_prompt = "Test prompt",
      })
      
      assert.is_not_nil(result)
      assert.is_not_nil(result.session)
      assert.is_not_nil(result.buffer)
      
      local bufnr = result.buffer:get_bufnr()
      assert.is_not_nil(vim.b[bufnr].llm_chat_bufnr)
      assert.are.equal(bufnr, vim.b[bufnr].llm_chat_bufnr)
      
      local retrieved_chat_data = chat.get_session(bufnr)
      assert.is_not_nil(retrieved_chat_data)
      assert.are.equal(result.session, retrieved_chat_data.session)
      assert.are.equal(result.buffer, retrieved_chat_data.buffer)
    end)

    it('should send message from chat buffer', function()
      -- Mock get_user_input to return a message
      _buffer.get_user_input = spy.new(function() return "Test message" end)
      _buffer.set_status = spy.new(function() end)
      _buffer.append_user_message = spy.new(function() end)
      _buffer.clear_input = spy.new(function() end)
      _buffer.append_llm_message = spy.new(function() end)
      _buffer.update_conversation_id = spy.new(function() end)
      _buffer.focus_input = spy.new(function() end)
      
      chat.send_message()
      
      assert.spy(_buffer.get_user_input).was.called()
      assert.spy(_buffer.set_status).was.called_with(match._, "Processing...")
      assert.spy(_buffer.append_user_message).was.called()
      assert.spy(_buffer.clear_input).was.called()
    end)

    it('should not send empty message', function()
      _buffer.get_user_input = spy.new(function() return "" end)
      
      chat.send_message()
      
      assert.spy(vim.notify).was.called_with("Cannot send empty message", vim.log.levels.WARN)
    end)

    it('should not send when session is processing', function()
      _session.state = 'processing'
      
      chat.send_message()
      
      assert.spy(vim.notify).was.called_with("Chat is processing, please wait", vim.log.levels.WARN)
    end)

    it('should handle new message command', function()
      local result = chat.start_chat()
      vim.b[1] = { llm_chat_session = result }
      
      result.buffer.clear_input = spy.new(function() end)
      result.buffer.focus_input = spy.new(function() end)
      
      chat.new_message()
      
      assert.spy(result.buffer.clear_input).was.called()
      assert.spy(result.buffer.focus_input).was.called()
    end)

    it('should get active session for buffer', function()
      local result = chat.start_chat()
      
      local session = chat.get_session(1)
      
      assert.is_not_nil(session)
      assert.are.equal(result.session, session.session)
      assert.are.equal(result.buffer, session.buffer)
    end)

    it('should stop current job', function()
      local result = chat.start_chat()
      vim.b[1] = { llm_chat_session = result }
      
      result.session.current_job_id = 12345
      result.session.stop_current_job = spy.new(function()
        result.session.current_job_id = nil
        result.session.state = 'ready'
      end)
      result.buffer.set_status = spy.new(function() end)
      
      chat.stop_current_job()
      
      assert.spy(result.session.stop_current_job).was.called()
      assert.spy(result.buffer.set_status).was.called_with(match._, "Stopped")
    end)
  end)

  describe('error handling', function()
    it('should handle send_message on non-chat buffer', function()
      vim.b[1] = nil
      
      chat.send_message()
      
      assert.spy(vim.notify).was.called_with("Not a chat buffer", vim.log.levels.ERROR)
    end)

    it('should handle new_message on non-chat buffer', function()
      vim.b[1] = nil
      
      chat.new_message()
      
      assert.spy(vim.notify).was.called_with("Not a chat buffer", vim.log.levels.ERROR)
    end)

    it('should handle stop_current_job on non-chat buffer', function()
      vim.b[1] = nil
      
      chat.stop_current_job()
      
      assert.spy(vim.notify).was.called_with("Not a chat buffer", vim.log.levels.ERROR)
    end)
  end)
end)
