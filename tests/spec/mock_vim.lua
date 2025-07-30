local spy = require('luassert.spy')

local M = {}

function M.setup()
  _G.vim = {
    fn = {
      shellescape = spy.new(function(str)
        return str
      end),
      stdpath = spy.new(function()
        return '/tmp'
      end),
      json_decode = spy.new(function(s)
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
      end),
      json_encode = spy.new(function(tbl)
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
      end),
      json_decode = spy.new(function(s)
        -- A simple json decoder for testing purposes
        local success, result = pcall(function()
          return vim.json.decode(s)
        end)
        if success then
          return result
        else
          -- Fallback for tests, not a full implementation
          if not s or s == '' or s == '[]' then return {} end
          local obj = {}
          for k, v in s:gmatch('"([^"]+)": ?"([^"]*)"') do
            obj[k] = v
          end
          if s:sub(1, 1) == '[' then
            return { obj }
          end
          return obj
        end
      end),
      system = spy.new(function() end)
    },
    api = {
      nvim_set_current_buf = spy.new(function() end),
      nvim_create_buf = spy.new(function() return 1 end),
      nvim_open_win = spy.new(function() end),
      nvim_buf_set_option = spy.new(function() end),
      nvim_buf_set_name = spy.new(function() end),
      nvim_buf_set_lines = spy.new(function() end),
      nvim_buf_get_lines = spy.new(function() return {} end),
      nvim_buf_set_keymap = spy.new(function() end),
    },
    log = {
      levels = {
        ERROR = 1,
        DEBUG = 4,
      },
    },
    notify = spy.new(function() end),
    schedule = spy.new(function(cb)
      cb()
    end),
    list_extend = function(t1, t2)
      for _, v in ipairs(t2) do
        table.insert(t1, v)
      end
    end,
    cmd = spy.new(function() end),
    defer_fn = spy.new(function(fn, _)
      fn()
    end),
    wait = spy.new(function() end),
    tbl_isempty = spy.new(function(tbl)
      return next(tbl) == nil
    end),
    tbl_deep_extend = spy.new(function(a, b)
      for k, v in pairs(b) do
        if type(v) == "table" and type(a[k]) == "table" then
          a[k] = vim.tbl_deep_extend(a[k], v)
        else
          a[k] = v
        end
      end
      return a
    end),
    loop = {
      spawn = spy.new(function(cmd, opts, on_exit)
        return {
          get_stdio_handle = spy.new(function(fd)
            return {
              read_start = spy.new(function(on_read)
              end),
            }
          end),
        }
      end),
      new_pipe = spy.new(function() end),
    },
  }
end

function M.teardown()
  _G.vim = nil
end

return M
