local M = {}

function M.run(cmd, callbacks)
  local buffer = ''
  local function on_stdout(_, data)
    if data == nil then
      return
    end
    buffer = buffer .. table.concat(data)
    local lines = vim.fn.split(buffer, '\n')
    buffer = table.remove(lines) or ''
    if #lines > 0 then
      for _, line in ipairs(lines) do
        if callbacks.on_stdout then
          callbacks.on_stdout(line)
        end
      end
    end
  end

  local options = {
    on_exit = callbacks.on_exit,
    on_stderr = callbacks.on_stderr,
    on_stdout = on_stdout,
    stdout_buffered = true,
    stderr_buffered = true,
  }

  vim.fn.jobstart(cmd, options)
end

return M
