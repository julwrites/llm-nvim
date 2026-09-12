local M = {}

function M.run(cmd, callbacks)
  local config = require('llm.config')

  if config.get('debug') then
    vim.notify("DEBUG: job.run() called with cmd: " .. vim.inspect(cmd), vim.log.levels.DEBUG)
  end

  -- Validate command
  if not cmd or type(cmd) ~= "table" or #cmd == 0 then
    vim.notify("Invalid command passed to job runner", vim.log.levels.ERROR)
    return nil
  end

  if config.get('debug') then
    local cmd_name = cmd and cmd[1] or "unknown"
    vim.notify("Starting job: " .. cmd_name, vim.log.levels.DEBUG)
  end

  local stdout_buffer = ""
  local stderr_buffer = ""

  local function process_output(data, event)
    if not data or #data == 0 then return end

    local handler = (event == "stdout" and callbacks.on_stdout) or (event == "stderr" and callbacks.on_stderr)
    if not handler then return end

    local buffer = (event == "stdout") and stdout_buffer or stderr_buffer

    -- Neovim passes split lines. The array always represents implicitly newline-terminated
    -- lines, except the last element which represents a partial line.

    -- Prepend existing buffer to the first element
    data[1] = buffer .. (data[1] or "")

    -- The last element is the new buffer (partial line)
    buffer = table.remove(data)

    -- data now contains only complete lines
    local lines = data
    for i, line in ipairs(lines) do
      if line:sub(-1) == '\r' then
        lines[i] = line:sub(1, -2)
      end
    end

    if event == "stdout" then
      stdout_buffer = buffer
    else
      stderr_buffer = buffer
    end

    -- Call handler with complete lines
    if #lines > 0 then
      handler(nil, lines)
    end
  end

  local options = {
    on_exit = function(j, exit_code)
      if config.get('debug') then
        vim.notify("Job exited with code: " .. tostring(exit_code), vim.log.levels.DEBUG)
      end

      -- Process any remaining buffered stdout before calling the final on_exit callback
      if #stdout_buffer > 0 then
        if callbacks.on_stdout then
          callbacks.on_stdout(nil, {stdout_buffer})
        end
        stdout_buffer = "" -- Clear buffer after processing
      end

      -- Process any remaining buffered stderr
      if #stderr_buffer > 0 then
        if callbacks.on_stderr then
          callbacks.on_stderr(nil, {stderr_buffer})
        end
        stderr_buffer = "" -- Clear buffer after processing
      end

      if callbacks.on_exit then callbacks.on_exit(j, exit_code) end
    end,
    on_stdout = function(j, data)
      process_output(data, "stdout")
    end,
    on_stderr = function(j, data)
      process_output(data, "stderr")
    end,
    stdout_buffered = false,
    stderr_buffered = false,
  }

  local job_id = vim.fn.jobstart(cmd, options)

  if config.get('debug') then
    vim.notify("DEBUG: vim.fn.jobstart() returned: " .. tostring(job_id), vim.log.levels.DEBUG)
  end

  if not job_id or job_id <= 0 then
    local cmd_name = cmd and cmd[1] or "unknown"
    vim.notify("Failed to start job: " .. cmd_name, vim.log.levels.ERROR)
    return nil
  else
    if config.get('debug') then
      vim.notify("DEBUG: Job started successfully with ID: " .. tostring(job_id), vim.log.levels.DEBUG)
    end
    return job_id
  end
end

return M
