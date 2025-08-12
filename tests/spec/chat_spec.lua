require('tests.spec.spec_helper')
local spy = require('luassert.spy')

describe('llm.chat', function()
  local chat
  local mock_job
  local mock_ui
  local mock_commands

  local job_run_calls
  local append_to_buffer_calls

  before_each(function()
    job_run_calls = {} -- Reset calls for each test
    append_to_buffer_calls = {}

    -- Mock the job runner
    mock_job = {
      run = function(cmd_parts, callbacks)
        table.insert(job_run_calls, { cmd_parts = cmd_parts, callbacks = callbacks })
      end,
    }
    package.loaded['llm.core.utils.job'] = mock_job

    -- Mock the ui module
    mock_ui = {
      create_chat_buffer = spy.new(function() end),
      append_to_buffer = function(...)
        table.insert(append_to_buffer_calls, { ... })
      end,
    }
    package.loaded['llm.core.utils.ui'] = mock_ui

    -- Mock the vim api
    local mock_api_extensions = {
      nvim_get_current_buf = spy.new(function()
        return 1
      end),
      nvim_buf_get_lines = function()
        return {
          "--- Some other line ---",
          "--- You ---",
          "This is the user prompt",
        }
      end,
      nvim_buf_set_lines = spy.new(function() end),
      nvim_win_get_cursor = function() return { 3, 0 } end,
    }
    for k, v in pairs(mock_api_extensions) do
      vim.api[k] = v
    end
    vim.fn = {
        shellescape = function(s) return "'" .. s .. "'" end
    }
    vim.list_extend = function(t1, t2)
        for _, v in ipairs(t2) do
            table.insert(t1, v)
        end
        return t1
    end
    vim.list_contains = function(list, value)
        for _, v in ipairs(list) do
            if v == value then
                return true
            end
        end
        return false
    end

    -- Mock the commands module
    mock_commands = {
      get_llm_executable_path = spy.new(function() return 'llm' end),
      get_model_arg = spy.new(function() return {} end),
      get_system_arg = spy.new(function() return {} end),
    }
    package.loaded['llm.commands'] = mock_commands


    -- Load the chat module
    package.loaded['llm.chat'] = nil
    chat = require('llm.chat')
  end)

  after_each(function()
    package.loaded['llm.core.utils.job'] = nil
    package.loaded['llm.core.utils.ui'] = nil
    package.loaded['llm.commands'] = nil
  end)

  describe('send_prompt', function()
    it('should extract the prompt correctly and call job.run', function()
      chat.send_prompt()
      assert.is_not_nil(job_run_calls[1])
      local job_args = job_run_calls[1].cmd_parts
      assert.is_true(vim.list_contains(job_args, "This is the user prompt"))
    end)

    it('should stream response to buffer via on_stdout callback', function()
      chat.send_prompt()
      assert.is_not_nil(job_run_calls[1])
      local callbacks = job_run_calls[1].callbacks
      assert.is_not_nil(callbacks.on_stdout)

      callbacks.on_stdout(nil, {"First line of response"})
      local last_call = append_to_buffer_calls[#append_to_buffer_calls]
      assert.are.same({1, "First line of response\n", "LlmModelResponse"}, last_call)

      callbacks.on_stdout(nil, {"Second line of response"})
      last_call = append_to_buffer_calls[#append_to_buffer_calls]
      assert.are.same({1, "Second line of response\n", "LlmModelResponse"}, last_call)
    end)
  end)
end)