-- Mock the Neovim API
if not _G.vim then
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
    },
  }
end

if not _G.vim.fn.json_encode or not _G.vim.fn.json_decode then
  _G.vim.fn.json_encode = function(tbl)
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
  end
  _G.vim.fn.json_decode = function(json)
    if not json then return {} end
    -- A simple json decoder for testing purposes
    local list = {}
    if type(json) == 'string' then
        for item in json:gmatch('{([^}]+)}') do
            local item_tbl = {}
            for k, v in item:gmatch('"([^"]+)":("([^"]+)"|true|false)') do
                if v == "true" then
                    item_tbl[k] = true
                elseif v == "false" then
                    item_tbl[k] = false
                else
                    item_tbl[k] = v
                end
            end
            for k, v in item:gmatch('"([^"]+)":true') do
                item_tbl[k] = true
            end
            for k, v in item:gmatch('"([^"]+)":false') do
                item_tbl[k] = false
            end
            table.insert(list, item_tbl)
        end
    end
    return list
  end
end
