-- tests/spec/mock_vim.lua

local M = {}

M.log = {
  levels = {
    INFO = 1,
    WARN = 2,
    ERROR = 3,
    DEBUG = 4,
  },
}

M.fn = {
  json_decode = function(s)
    -- A simple json decoder for testing purposes
    local success, result = pcall(function()
      return vim.json.decode(s)
    end)
    if success then
      return result
    else
      -- Fallback for tests, not a full implementation
      local obj = {}
      for k, v in s:gmatch('"([^"]+)": ?"([^"]+)"') do
        obj[k] = v
      end
      return obj
    end
  end,
  json_encode = function(tbl)
    return vim.json.encode(tbl)
  end,
  stdpath = function(type)
    if type == "config" then
      return "/fake/config"
    elseif type == "cache" then
      return "/fake/cache"
    else
      return "/fake/path"
    end
  end,
}

M.api = {
  nvim_buf_set_name = function() end,
  nvim_win_set_config = function() end,
  nvim_win_close = function() end,
}

M.tbl_isempty = function(tbl)
  return next(tbl) == nil
end

M.tbl_count = function(tbl)
  local count = 0
  for _ in pairs(tbl) do
    count = count + 1
  end
  return count
end

M.notify = function() end

function M.inspect(v)
  return tostring(v)
end


_G.vim = M

return M
