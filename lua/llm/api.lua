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
  local job_id = job.run(command_parts, {
    on_stdout = callbacks.on_stdout,
    on_stderr = callbacks.on_stderr,
    on_exit = callbacks.on_exit,
  })

  if job_id then
    vim.fn.jobsend(job_id, prompt)
    vim.fn.jobclose(job_id, "stdin")
    return job_id
  end

  return nil
end

function M.run_streaming_command(command_parts, prompt, callbacks)
  callbacks = callbacks or {}
  local job_id = job.run(command_parts, {
    on_stdout = callbacks.on_stdout,
    on_stderr = callbacks.on_stderr,
    on_exit = callbacks.on_exit,
  })

  if job_id then
    if prompt and prompt ~= "" then
      vim.fn.jobsend(job_id, prompt)
    end
    vim.fn.jobclose(job_id, "stdin")
  end

  return job_id
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
      if data then
        for _, line in ipairs(data) do
          ui.append_to_buffer(bufnr, line .. "\n", "LlmModelResponse")
        end
      end
      if opts.on_stdout then opts.on_stdout(_, data) end
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          vim.notify("LLM stderr: " .. line, vim.log.levels.ERROR)
        end
      end
      if opts.on_stderr then opts.on_stderr(_, data) end
    end,
    on_exit = function(_, exit_code)
      vim.notify("LLM command finished with exit code: " .. tostring(exit_code), vim.log.levels.INFO)
      if opts.on_exit then opts.on_exit(_, exit_code) end
    end,
  }

  return M.run_streaming_command(cmd_parts, nil, callbacks)
end

-- Add API documentation metadata
M.__name = 'llm.api'
M.__description = 'Public API surface for llm-nvim plugin'

return M
