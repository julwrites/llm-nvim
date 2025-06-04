local M = {}

function M.notify(msg, level, opts)
  vim.notify(msg, level, opts or {})
end

return M