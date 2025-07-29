-- Mock the Neovim API
_G.vim = {
  g = {},
  env = {},
  log = {
    levels = {
      DEBUG = 0,
      INFO = 1,
      WARN = 2,
      ERROR = 3,
    },
  },
  notify = function() end,
  tbl_deep_extend = function(a, b)
    for k, v in pairs(b) do
      if type(v) == "table" and type(a[k]) == "table" then
        a[k] = _G.vim.tbl_deep_extend(a[k], v)
      else
        a[k] = v
      end
    end
    return a
  end,
  tbl_isempty = function(tbl)
    return next(tbl) == nil
  end,
  fn = {
    system = function() end,
    executable = function() return 1 end,
    stdpath = function() return '/tmp' end,
    json_encode = function(tbl)
      -- A simple json encoder for testing purposes
      local json = '{'
      local first = true
      for k, v in pairs(tbl) do
        if not first then
          json = json .. ','
        end
        first = false
        json = json .. '"' .. tostring(k) .. '":'
        if type(v) == 'string' then
          json = json .. '"' .. v .. '"'
        else
          json = json .. tostring(v)
        end
      end
      json = json .. '}'
      return json
    end,
    json_decode = function(json)
      -- A simple json decoder for testing purposes
      local tbl = {}
      for k, v in json:gmatch('"([^"]+)":"([^"]+)"') do
        tbl[k] = v
      end
      return tbl
    end,
  },
}
