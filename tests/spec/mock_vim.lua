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
  stdpath = function(type)
    if type == "config" then
      return "/fake/config"
    elseif type == "cache" then
      return "/fake/cache"
    else
      return "/fake/path"
    end
  end,
  json_encode = function(tbl)
    return M.json.encode(tbl)
  end,
  json_decode = function(s)
    return M.json.decode(s)
  end,
  shellescape = function(s) return s end,
  jobstart = function() return 1 end,
  expand = function(s) return s end,
}

M.api = {
  nvim_buf_set_name = function() end,
  nvim_win_set_config = function() end,
  nvim_win_close = function() end,
  nvim_win_get_cursor = function() return {1, 0} end,
  nvim_buf_get_name = function() return "buffer_name" end,
  nvim_get_current_buf = function() return 1 end,
  nvim_create_user_command = function() end,
  nvim_buf_set_option = function() end,
  nvim_buf_set_lines = function() end,
  nvim_create_buf = function() return 1 end,
  nvim_set_current_buf = function() end,
  nvim_buf_get_lines = function() return {} end,
  nvim_buf_is_valid = function() return true end,
  nvim_create_augroup = function() return 1 end,
  nvim_create_autocmd = function() end,
  nvim_open_win = function() return 1 end,
}

M.schedule = function(cb)
  cb()
end

M.list_extend = function(t1, t2)
  for _, v in ipairs(t2) do
    table.insert(t1, v)
  end
end

M.defer_fn = function(fn, _)
  fn()
end

M.wait = function() end

M.json = {
  encode = function(val)
    if type(val) == 'table' then
      local parts = {}
      -- Check if it's an array or a map
      local is_array = #val > 0 and val[1] ~= nil
      if is_array then
        for i = 1, #val do
          table.insert(parts, M.json.encode(val[i]))
        end
        return '[' .. table.concat(parts, ',') .. ']'
      else -- map
        for k, v in pairs(val) do
          table.insert(parts, string.format('"%s":%s', tostring(k), M.json.encode(v)))
        end
        return '{' .. table.concat(parts, ',') .. '}'
      end
    elseif type(val) == 'string' then
      return '"' .. val .. '"'
    else
      return tostring(val)
    end
  end,
  decode = function(s)
    if s == '[]' then return {} end
    if s == '[{"name": "test-template"}]' then
        return { { name = 'test-template' } }
    end
    if s == '[{"id": "schema1", "name": "Schema 1"}]' then
        return { { id = 'schema1', name = 'Schema 1' } }
    end
    if s == '{"id": "schema1", "name": "Schema 1"}' then
        return { id = 'schema1', name = 'Schema 1' }
    end
    if s == '{"name": "test-template-details", "prompt": "Test prompt"}' then
        return { name = 'test-template-details', prompt = 'Test prompt' }
    end
    return {}
  end,
}

M.cmd = function() end
M.env = {}
M.split = function(str, sep)
  local result = {}
  for s in string.gmatch(str, "([^" .. sep .. "]+)") do
    table.insert(result, s)
  end
  return result
end

M.tbl_deep_extend = function(a, b)
  for k, v in pairs(b) do
    if type(v) == "table" and type(a[k]) == "table" then
      a[k] = M.tbl_deep_extend(a[k], v)
    else
      a[k] = v
    end
  end
  return a
end

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

function M.system(cmd, opts, callback)
  return {
    wait = function()
      return {
        stdout = "",
        stderr = "",
        code = 0,
      }
    end,
  }
end


_G.vim = M

return M
