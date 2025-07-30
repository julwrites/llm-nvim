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
      system = function(cmd)
        if type(cmd) == 'table' then
          cmd = table.concat(cmd, ' ')
        end
        if cmd:match('^llm templates save') then
          return 'Template saved'
        elseif cmd:match('^llm templates show') then
          local name = cmd:match('^llm templates show (.-) 2>&1')
          return '{"name": "' .. name .. '", "prompt": "Test prompt"}'
        elseif cmd:match('^llm templates delete') then
          return ''
        elseif cmd:match('^llm templates list --json') then
          return '[]'
        end
      end,
      executable = function() return 1 end,
      stdpath = function() return '/tmp' end,
      shellescape = function(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end,
    },
    o = {
      columns = 80,
      lines = 24,
    },
    api = {
      nvim_buf_set_keymap = function() end,
      nvim_win_close = function() end,
      nvim_buf_set_name = function() end,
      nvim_win_set_config = function() end,
      nvim_create_buf = function() return 1 end,
      nvim_buf_set_lines = function() end,
      nvim_win_get_cursor = function() return { 1, 1 } end,
      nvim_buf_set_option = function() end,
      nvim_open_win = function() return 1 end,
      nvim_buf_set_var = function() end,
      nvim_command = function() end,
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
    if not json or json == '[]' then return {} end
    local result = {}
    local text = json
    if json:sub(1, 1) == '[' then
      text = json:sub(2, -2)
    end
    for k, v in text:gmatch('"([^"]+)": ?"([^"]*)"') do
      result[k] = v
    end
    if json:sub(1, 1) == '[' then
      return { result }
    end
    return result
  end
end
