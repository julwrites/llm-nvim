local api = require('llm.api')
local ui = require('llm.core.utils.ui')
local commands = require('llm.commands')

local M = {}

function M.start_chat()
  local bufnr = ui.create_chat_buffer()

  ui.append_to_buffer(bufnr, "Enter your prompt below and press <Enter> to submit\n", "LlmUserPrompt")
  ui.append_to_buffer(bufnr, "-----------\n", "LlmUserPrompt")
  ui.append_to_buffer(bufnr, "--- You ---\n", "LlmUserPrompt")
  ui.append_to_buffer(bufnr, ">  ", "LlmUserPrompt")

  -- Move cursor to the end of the buffer
  local num_lines = vim.api.nvim_buf_line_count(bufnr)
  vim.api.nvim_win_set_cursor(0, { num_lines, 3 })

  -- Switch to insert mode
  vim.cmd('startinsert')

  return bufnr
end

function M.start_chat_stream(bufnr, cmd_parts, prompt)
  local callbacks = {
    on_stdout = function(_, data) 
      local startup_patterns = {
        "^Chatting with ",
        "^Type 'exit' or 'quit' to exit",
        "^Type '!multi' to enter multiple lines, then '!end' to finish",
        "^Type '!edit' to open your default editor and modify the prompt",
        "^Type '!fragment ",
        "^>",
      }
      if data then
        for _, line in ipairs(data) do
          local is_startup_line = false
          for _, pattern in ipairs(startup_patterns) do
            if string.find(line, pattern) then
              is_startup_line = true
              break
            end
          end
          if not is_startup_line then
            ui.append_to_buffer(bufnr, line .. "\n", "LlmModelResponse")
          end
        end
      end
    end,
    on_stderr = function(_, data) 
      if data then
        for _, line in ipairs(data) do
          vim.notify("LLM stderr: " .. line, vim.log.levels.ERROR)
        end
      end
    end,
    on_exit = function(_, exit_code) 
      vim.notify("LLM command finished with exit code: " .. tostring(exit_code), vim.log.levels.INFO)
      -- After the model finishes, indicate user's turn
      ui.append_to_buffer(bufnr, "--- You ---", "LlmUserPrompt")
      ui.append_to_buffer(bufnr, ">  ", "LlmUserPrompt")

      -- Move cursor to the end of the buffer
      local num_lines = vim.api.nvim_buf_line_count(bufnr)
      vim.api.nvim_win_set_cursor(0, { num_lines, 3 })
      vim.cmd('startinsert') -- Re-enter insert mode
    end,
  }

  local job_id = api.run_streaming_command(cmd_parts, prompt, callbacks)
  return job_id
end

function M.send_prompt()
  vim.notify("DEBUG: send_prompt function called.", vim.log.levels.INFO)
  local bufnr = vim.api.nvim_get_current_buf()
  local current_cursor_line, _ = table.unpack(vim.api.nvim_win_get_cursor(0))    -- 1-indexed line number of cursor
  local all_buffer_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) -- 0-indexed table of all lines

  local you_marker_line_idx = -1                                           -- 0-indexed line number of "--- You ---"

  -- Search upwards from the line *before* the cursor to find "--- You ---"
  for i = current_cursor_line - 1, 0, -1 do
    if all_buffer_lines[i + 1] == "--- You ---" then -- Lua table is 1-indexed, so all_buffer_lines[i+1]
      you_marker_line_idx = i
      break
    end
  end

  if you_marker_line_idx == -1 then
    vim.notify("Error: '--- You ---' marker not found in buffer.", vim.log.levels.ERROR)
    return
  end

  -- Extract user prompt lines
  -- The prompt starts on the line *after* "--- You ---" and goes up to the current cursor line.
  -- In 0-indexed terms: from (you_marker_line_idx + 1) to (current_cursor_line - 1)
  local user_prompt_lines = {}
  for i = you_marker_line_idx + 1, current_cursor_line - 1 do
    table.insert(user_prompt_lines, all_buffer_lines[i + 1]) -- all_buffer_lines is 0-indexed, so all_buffer_lines[i+1]
  end
  local prompt = table.concat(user_prompt_lines, "\n")

  -- Clear only the user input area
  -- Clear from the line *after* "--- You ---" (0-indexed: you_marker_line_idx + 1) to the end of the buffer (-1)
  vim.api.nvim_buf_set_lines(bufnr, you_marker_line_idx + 1, -1, false, {})

  -- Append the prompt and response sections
  -- "--- You ---" is already in the buffer, just append the captured prompt
  ui.append_to_buffer(bufnr, prompt .. "\n", "LlmUserPrompt")
  ui.append_to_buffer(bufnr, "--- LLM ---\n", "LlmModelResponse")

  local cmd_parts = { commands.get_llm_executable_path(), prompt }
  vim.list_extend(cmd_parts, commands.get_model_arg())
  vim.list_extend(cmd_parts, commands.get_system_arg())

  M.start_chat_stream(bufnr, cmd_parts, prompt)
end

return M
