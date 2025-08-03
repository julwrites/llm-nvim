local M = {}

function M.run(cmd, callbacks)
  vim.notify("job.lua: Attempting to run command: " .. table.concat(cmd, " "), vim.log.levels.INFO)

  local stdout_buffer = ""

  local function process_output(data, event)
    vim.notify("job.lua: process_output called for event: " .. event .. ", data: " .. vim.inspect(data),
      vim.log.levels.DEBUG)
    if not data then return end

    local handler = (event == "stdout" and callbacks.on_stdout) or (event == "stderr" and callbacks.on_stderr)
    if not handler then return end

    -- The data from jobstart is a table of strings.
    -- We concatenate them, assuming they might be chunked.
    local chunk = table.concat(data, "\n")
    vim.notify("job.lua: processing chunk for " .. event .. ", chunk length: " .. tostring(#chunk), vim.log.levels.DEBUG)

    -- For stdout, we buffer and split by lines
    if event == "stdout" then
      stdout_buffer = stdout_buffer .. chunk
      local lines = {}
      local i = 1
      while true do
        local j = stdout_buffer:find("\n", i)
        if not j then break end
        table.insert(lines, stdout_buffer:sub(i, j - 1))
        i = j + 1
      end
      -- Keep the incomplete part of the last line in the buffer
      stdout_buffer = stdout_buffer:sub(i)
      vim.notify(
        "job.lua: stdout_buffer remaining: " .. tostring(#stdout_buffer) .. ", lines to send: " .. tostring(#lines),
        vim.log.levels.DEBUG)

      if #lines > 0 then
        handler(nil, lines)
      end
    else
      -- For stderr, just send the chunk directly as a table
      handler(nil, data)
    end
  end

  local options = {
    on_exit = function(j, exit_code)
      vim.notify("job.lua: Job " .. tostring(j) .. " exited with code: " .. tostring(exit_code), vim.log.levels.INFO)
      -- Process any remaining buffered stdout before calling the final on_exit callback
      if #stdout_buffer > 0 then
        process_output({ stdout_buffer }, "stdout")
        stdout_buffer = "" -- Clear buffer after processing
      end
      if callbacks.on_exit then callbacks.on_exit(j, exit_code) end
    end,
    on_stdout = function(j, d, e) process_output(d, e) end,
    on_stderr = function(j, d, e) process_output(d, e) end,
    stdout_buffered = false,
    stderr_buffered = false,
    pty = true,
  }

  local job_id = vim.fn.jobstart(cmd, options)
  vim.notify("job.lua: jobstart returned ID: " .. tostring(job_id), vim.log.levels.INFO)

  if not job_id or job_id <= 0 then
    vim.notify("job.lua: Failed to start job for command: " .. cmd[1], vim.log.levels.ERROR)
    return nil
  else
    vim.notify("job.lua: Job started with ID: " .. tostring(job_id), vim.log.levels.INFO)
    return job_id
  end
end

return M
