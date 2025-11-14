local M = {}

function M.run(cmd, callbacks)
  local config = require('llm.config')
  if config.get('debug') then
    vim.notify("Starting job: " .. cmd[1], vim.log.levels.DEBUG)
  end

  local stdout_buffer = ""
  local stderr_buffer = ""

  local function process_output(data, event)
    if not data then return end

    local handler = (event == "stdout" and callbacks.on_stdout) or (event == "stderr" and callbacks.on_stderr)
    if not handler then return end
    
    local buffer = (event == "stdout") and stdout_buffer or stderr_buffer
    
    for _, chunk in ipairs(data) do
      -- Accumulate chunk into buffer
      buffer = buffer .. chunk
      
      -- Split buffer on newlines
      local lines = {}
      while true do
        local newline_pos = buffer:find('\n')
        if not newline_pos then break end
        
        -- Extract line without the newline
        local line = buffer:sub(1, newline_pos - 1)
        table.insert(lines, line)
        
        -- Remove processed line from buffer
        buffer = buffer:sub(newline_pos + 1)
      end
      
      -- Update the appropriate buffer
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
    on_stdout = function(j, d, e) process_output(d, e) end,
    on_stderr = function(j, d, e) process_output(d, e) end,
    stdout_buffered = false,
    stderr_buffered = false,
  }

  local job_id = vim.fn.jobstart(cmd, options)

  if not job_id or job_id <= 0 then
    vim.notify("Failed to start job: " .. cmd[1], vim.log.levels.ERROR)
    return nil
  else
    return job_id
  end
end

return M
