-- llm/api.lua - Public API surface for llm-nvim
-- License: Apache 2.0

local M = {}
local facade = require('llm.facade')
local config = require('llm.config')
local job = require('llm.core.utils.job')
local ui = require('llm.core.utils.ui')


--- Setup function for plugin configuration
-- @param opts table: Configuration options table
-- @return table: The API module
function M.setup(opts)
  config.setup(opts)
  return M
end

--- Get current plugin version
-- @return string: Version string
function M.version()
  return require('llm.config').version
end

-- Expose all facade functions through API
for name, fn in pairs(facade) do
  M[name] = function(...)
    return fn(...)
  end
end

--- A unified function for running LLM commands and handling streaming output.
-- @param command_parts table: The command and its arguments.
-- @param prompt string: The prompt to send to the command's stdin.
-- @param callbacks table: A table with on_stdout, on_stderr, and on_exit callbacks.
-- @return number: The job ID, or nil if the job failed to start.
function M.run_llm_command(command_parts, prompt, callbacks)
  local job_instance = job.run({
    command = command_parts,
    on_stdout = callbacks.on_stdout,
    on_stderr = callbacks.on_stderr,
    on_exit = callbacks.on_exit,
  })

  if job_instance and job_instance.id then
    vim.fn.jobsend(job_instance.id, prompt)
    return job_instance.id
  end

  return nil
end

--- Runs an LLM command with streaming output to a specified buffer.
-- @param cmd_parts table: The command and its arguments as a table.
-- @param bufnr number: The buffer number to stream output to.
-- @param opts table: Optional table with additional callbacks (on_stdout, on_stderr, on_exit).
-- @return number: The job ID if the job started successfully, otherwise nil.
function M.run_llm_command_streamed(cmd_parts, bufnr, opts)
  opts = opts or {}
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
      if opts.on_stdout then opts.on_stdout(_, data) end
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          vim.notify("LLM stderr: " .. line, vim.log.levels.ERROR)
          vim.notify("Error from llm: " .. line, vim.log.levels.ERROR)
        end
      end
      if opts.on_stderr then opts.on_stderr(_, data) end
    end,
    on_exit = function(_, exit_code)
      vim.notify("LLM command finished with exit code: " .. tostring(exit_code), vim.log.levels.INFO)
      vim.notify("LLM command finished.")
      -- After the model finishes, indicate user's turn
      ui.append_to_buffer(bufnr, "--- You ---", "LlmUserPrompt")
      ui.append_to_buffer(bufnr, ">  ", "LlmUserPrompt")

      -- Move cursor to the end of the buffer
      local num_lines = vim.api.nvim_buf_line_count(bufnr)
      vim.api.nvim_win_set_cursor(0, { num_lines, 3 })
      vim.cmd('startinsert') -- Re-enter insert mode
      if opts.on_exit then opts.on_exit(_, exit_code) end
    end,
  }
  vim.notify("api.lua: Callbacks prepared for job.run: " .. vim.inspect(callbacks), vim.log.levels.DEBUG)

  local job_id = job.run(cmd_parts, callbacks)
  return job_id
end

-- Add API documentation metadata
M.__name = 'llm.api'
M.__description = 'Public API surface for llm-nvim plugin'

return M
