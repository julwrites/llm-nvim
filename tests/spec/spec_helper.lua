-- Mock the Neovim API
_G.vim = {
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
  fn = {
    system = function() end,
    executable = function() return 1 end,
    stdpath = function() return '/tmp' end,
  },
}
