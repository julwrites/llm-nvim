local M = {}

function M.mock_io_open(filename_to_mock)
  local old_open = io.open
  io.open = function(filename, ...)
    if filename == filename_to_mock then
      return { write = function() end, close = function() end }
    else
      return old_open(filename, ...)
    end
  end

  return function()
    io.open = old_open
  end
end

return M
