
-- debug_plugins_manager.lua

-- Mock vim.api and vim.notify
_G.vim = {
  api = {
    nvim_buf_set_lines = function(bufnr, start_line, end_line, strict_indexing, lines)
      print("nvim_buf_set_lines called for bufnr " .. bufnr)
      print("Lines written:")
      for i, line in ipairs(lines) do
        print("  [" .. i .. "] " .. line)
      end
      _G.captured_lines = lines
    end,
    nvim_buf_add_highlight = function(bufnr, ns_id, hl_group, line, col_start, col_end)
      print(string.format("nvim_buf_add_highlight called for bufnr %d, hl_group %s, line %d, cols %d-%d", bufnr, hl_group, line, col_start, col_end))
      if not _G.captured_highlights then _G.captured_highlights = {} end
      table.insert(_G.captured_highlights, { hl_group = hl_group, line = line, col_start = col_start, col_end = col_end })
    end,
    nvim_win_get_cursor = function() return {1, 0} end, -- Mock cursor position
  },
  fn = {
    system = function(cmd)
      print("vim.fn.system called with: " .. cmd)
      if cmd:match("curl") then
        -- Mock HTML content for available plugins
        return [[
          <section id="local-models">
            <h2>Local models</h2>
            <ul class="simple">
              <li><strong><a href="https://github.com/simonw/llm-gguf">llm-gguf</a></strong>: description for gguf.</li>
              <li><strong><a href="https://github.com/simonw/llm-ollama">llm-ollama</a></strong>: description for ollama.</li>
            </ul>
          </section>
          <section id="remote-apis">
            <h2>Remote APIs</h2>
            <ul class="simple">
              <li><strong><a href="https://github.com/simonw/llm-gemini">llm-gemini</a></strong>: description for gemini.</li>
            </ul>
          </section>
        ]]
      end
      return ""
    end,
    getcwd = function() return "/Volumes/DevData/Git/julwrites/llm-nvim" end,
    bufexists = function() return 1 end,
    buflisted = function() return 1 end,
  },
  notify = function(msg, level, opts)
    local level_name = "INFO"
    if level == vim.log.levels.WARN then level_name = "WARN" end
    if level == vim.log.levels.ERROR then level_name = "ERROR" end
    if level == vim.log.levels.DEBUG then level_name = "DEBUG" end
    print(string.format("[NOTIFY][%s] %s", level_name, msg))
  end,
  schedule = function(fn) fn() end,
  defer_fn = function(fn, delay) fn() end,
  log = { levels = { INFO = 1, WARN = 2, ERROR = 3, DEBUG = 4 } },
  json = {
    decode = function(json_string)
      print("vim.json.decode called with: " .. json_string)
      if json_string:match("llm-installed-plugin") then
        return { { name = "llm-installed-plugin" } }
      end
      return {}
    end,
  },
}

-- Mock package.loaded for dependencies
package.loaded['llm.core.data.llm_cli'] = {
  run_llm_command = function(cmd)
    print("llm.core.data.llm_cli.run_llm_command called with: " .. cmd)
    if cmd == 'plugins' then
      -- Simulate JSON output for installed plugins
      return [[
        [
          {
            "name": "llm-installed-plugin",
            "version": "1.0"
          }
        ]
      ]]
    end
    return ""
  end,
}
package.loaded['llm.core.data.cache'] = {
  get = function(key) print("cache.get called for: " .. key); return nil end,
  set = function(key, value) print("cache.set called for: " .. key .. " with value of type " .. type(value)) end,
  invalidate = function(key) print("cache.invalidate called for: " .. key) end,
}
package.loaded['llm.ui.views.plugins_view'] = {
  confirm_uninstall = function(plugin_name, callback) print("confirm_uninstall called for: " .. plugin_name); callback(true) end,
}
package.loaded['llm.ui.styles'] = {
  setup_buffer_syntax = function(buf) print("styles.setup_buffer_syntax called for bufnr: " .. buf) end,
  setup_highlights = function() print("styles.setup_highlights called") end,
  highlights = {
    LLMInstalled = { fg = "#98c379", style = "bold" },
    LLMNotInstalled = { fg = "#e06c75", style = "bold" },
  },
}
package.loaded['llm.core.utils.shell'] = {
  safe_shell_command = function(cmd) print("shell.safe_shell_command called with: " .. cmd); return "", 0 end,
  check_llm_installed = function() return true end,
}
package.loaded['llm.ui.unified_manager'] = {
  switch_view = function(view) print("unified_manager.switch_view called with: " .. view) end,
  open_specific_manager = function(view) print("unified_manager.open_specific_manager called with: " .. view) end,
}

-- Load the module to be tested
local plugins_manager = require('llm.managers.plugins_manager')

-- Call the function under test
print("\n--- Running populate_plugins_buffer ---")
plugins_manager.populate_plugins_buffer(123) -- Use a dummy buffer number

-- You can add assertions here based on _G.captured_lines and _G.captured_highlights
-- For now, just printing the captured data will help debug.

print("\n--- Captured Lines ---")
if _G.captured_lines then
  for i, line in ipairs(_G.captured_lines) do
    print("Line " .. i .. ": " .. line)
  end
else
  print("No lines captured.")
end

print("\n--- Captured Highlights ---")
if _G.captured_highlights then
  for i, hl in ipairs(_G.captured_highlights) do
    print(string.format("Highlight %d: Group=%s, Line=%d, Cols=%d-%d", i, hl.hl_group, hl.line, hl.col_start, hl.col_end))
  end
else
  print("No highlights captured.")
end
