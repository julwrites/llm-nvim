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

function M.send_prompt()
  vim.notify("DEBUG: send_prompt function called.", vim.log.levels.INFO)
  local bufnr = vim.api.nvim_get_current_buf()
  local current_cursor_line, _ = unpack(vim.api.nvim_win_get_cursor(0))    -- 1-indexed line number of cursor
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

  local job_id = api.run_llm_command_streamed(cmd_parts, bufnr)
  if job_id then
    vim.fn.jobsend(job_id, prompt .. "\n")
  end
end

return M
