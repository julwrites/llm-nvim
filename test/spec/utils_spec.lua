-- test/spec/utils_spec.lua
local spy = require('spy')

describe("llm.utils.validate", function()
  local validate = require("llm.utils.validate")

  describe("convert", function()
    it("should convert string to boolean", function()
      assert.are.same(true, validate.convert("true", "boolean"))
      assert.are.same(false, validate.convert("false", "boolean"))
    end)

    it("should convert number to boolean", function()
      assert.are.same(true, validate.convert(1, "boolean"))
      assert.are.same(false, validate.convert(0, "boolean"))
    end)

    it("should convert string to number", function()
      assert.are.same(123, validate.convert("123", "number"))
      assert.are.same(0, validate.convert("abc", "number"))
    end)

    it("should convert boolean to number", function()
      assert.are.same(1, validate.convert(true, "number"))
      assert.are.same(0, validate.convert(false, "number"))
    end)

    it("should convert to string", function()
      assert.are.same("123", validate.convert(123, "string"))
      assert.are.same("true", validate.convert(true, "string"))
    end)
  end)

  describe("validate", function()
    it("should validate basic types", function()
      assert.is_true(validate.validate("hello", "string"))
      assert.is_false(validate.validate(123, "string"))
      assert.is_true(validate.validate(123, "number"))
      assert.is_true(validate.validate(true, "boolean"))
      assert.is_true(validate.validate({}, "table"))
    end)

    it("should handle nil values", function()
      assert.is_true(validate.validate(nil, "string"))
    end)

    it("should handle 'any' type", function()
      assert.is_true(validate.validate("hello", "any"))
      assert.is_true(validate.validate(123, "any"))
    end)
  end)
end)


-- describe("llm.utils.text", function()
describe("llm.utils.text", function()
  local text = require("llm.utils.text")

  describe("get_visual_selection", function()
    it("should return the visual selection", function()
      vim.fn.setpos("'<", { 0, 1, 1, 0 })
      vim.fn.setpos("'>", { 0, 1, 5, 0 })
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello world" })
      local selection = text.get_visual_selection()
      assert.are.equal("hello", selection)
    end)
  end)

  describe("escape_pattern", function()
    it("should escape special characters", function()
      local escaped = text.escape_pattern("hello.world^$()%")
      assert.are.equal("hello%.world%^%$%(%)%%", escaped)
    end)
  end)

  describe("parse_simple_yaml", function()
    it("should parse a simple yaml file", function()
      local file = io.open("test.yaml", "w")
      file:write("key: value\n")
      file:write("list:\n")
      file:write("  - item1\n")
      file:write("  - item2\n")
      file:close()
      local data = text.parse_simple_yaml("test.yaml")
      assert.are.same({ key = "value", list = { "item1", "item2" } }, data)
      os.remove("test.yaml")
    end)
  end)
end)

describe("llm.utils.shell", function()
  local shell = require("llm.utils.shell")

  describe("safe_shell_command", function()
    it("should return the result of the command", function()
      local result, err = shell.safe_shell_command("echo 'hello'")
      assert.are.equal("hello", result)
      assert.is_nil(err)
    end)

    it("should return an error if the command fails", function()
      local result, err = shell.safe_shell_command("invalid_command")
      assert.is_not_nil(result)
      assert.is_nil(err)
    end)
  end)

  describe("command_exists", function()
    it("should return true if the command exists", function()
      assert.is_true(shell.command_exists("echo"))
    end)

    it("should return false if the command does not exist", function()
      assert.is_false(shell.command_exists("invalid_command"))
    end)
  end)

  describe("check_llm_installed", function()
    it("should return true if llm is installed", function()
      local original_command_exists = shell.command_exists
      shell.command_exists = function() return true end
      assert.is_true(shell.check_llm_installed())
      shell.command_exists = original_command_exists
    end)

    it("should return false if llm is not installed", function()
      local original_command_exists = shell.command_exists
      shell.command_exists = function() return false end
      assert.is_false(shell.check_llm_installed())
      shell.command_exists = original_command_exists
    end)
  end)
end)

describe("llm.utils.notify", function()
  local notify = require("llm.utils.notify")

  it("should call vim.notify with the correct parameters", function()
    local spy = spy.on(vim, "notify")
    notify.notify("test message", "INFO", { title = "Test" })
    assert.spy(spy).was.called_with("test message", "INFO", { title = "Test" })
    spy:revert()
  end)
end)

describe("llm.utils.ui", function()
  local ui = require("llm.utils.ui")
  local api = vim.api

  describe("create_split_buffer", function()
    it("should create a new split buffer", function()
      local create_buf_spy = spy.on(api, "nvim_create_buf")
      local open_win_spy = spy.on(api, "nvim_open_win")
      ui.create_split_buffer()
      assert.spy(create_buf_spy).was.called()
      assert.spy(open_win_spy).was.called()
      create_buf_spy:revert()
      open_win_spy:revert()
    end)
  end)

  describe("create_buffer_with_content", function()
    it("should create a new buffer with content", function()
      local create_split_buffer_spy = spy.on(ui, "create_split_buffer")
      local get_current_buf_spy = spy.on(api, "nvim_get_current_buf")
      local configure_buffer_spy = spy.on(ui, "configure_buffer")

      ui.create_buffer_with_content("test content", "test_buffer", "markdown")

      assert.spy(create_split_buffer_spy).was.called()
      assert.spy(get_current_buf_spy).was.called()
      assert.spy(configure_buffer_spy).was.called()

      create_split_buffer_spy:revert()
      get_current_buf_spy:revert()
      configure_buffer_spy:revert()
    end)
  end)

  describe("replace_buffer_with_content", function()
    it("should replace the content of a buffer", function()
      local configure_buffer_spy = spy.on(ui, "configure_buffer")
      ui.replace_buffer_with_content("new content", 1, "markdown")
      assert.spy(configure_buffer_spy).was.called()
      configure_buffer_spy:revert()
    end)
  end)

  describe("create_floating_window", function()
    it("should create a new floating window", function()
      local open_win_spy = spy.on(api, "nvim_open_win")
      ui.create_floating_window(1, "test_window")
      assert.spy(open_win_spy).was.called()
      open_win_spy:revert()
    end)
  end)

  describe("floating_input", function()
    it("should create a floating input window", function()
      local create_buf_spy = spy.on(api, "nvim_create_buf")
      local open_win_spy = spy.on(api, "nvim_open_win")
      local set_keymap_spy = spy.on(api, "nvim_buf_set_keymap")
      local set_var_spy = spy.on(api, "nvim_buf_set_var")

      ui.floating_input({ prompt = "test prompt" }, function() end)

      assert.spy(create_buf_spy).was.called()
      assert.spy(open_win_spy).was.called()
      assert.spy(set_keymap_spy).was.called()
      assert.spy(set_var_spy).was.called()

      create_buf_spy:revert()
      open_win_spy:revert()
      set_keymap_spy:revert()
      set_var_spy:revert()
    end)
  end)

  describe("floating_confirm", function()
    it("should create a floating confirmation dialog", function()
      local create_buf_spy = spy.on(api, "nvim_create_buf")
      local open_win_spy = spy.on(api, "nvim_open_win")
      local set_keymap_spy = spy.on(api, "nvim_buf_set_keymap")
      local set_var_spy = spy.on(api, "nvim_buf_set_var")

      ui.floating_confirm({ prompt = "test prompt" }, function() end)

      assert.spy(create_buf_spy).was.called()
      assert.spy(open_win_spy).was.called()
      assert.spy(set_keymap_spy).was.called()
      assert.spy(set_var_spy).was.called()

      create_buf_spy:revert()
      open_win_spy:revert()
      set_keymap_spy:revert()
      set_var_spy:revert()
    end)
  end)
end)

describe("llm.utils.file_utils", function()
  local file_utils = require("llm.utils.file_utils")

  describe("ensure_config_dir_exists", function()
    it("should create a directory if it does not exist", function()
      local dir = "./test_dir"
      os.remove(dir)
      local original_io_open = io.open
      io.open = function() return nil end
      local original_pcall = pcall
      pcall = function() return true, 0 end
      assert.is_true(file_utils.ensure_config_dir_exists(dir))
      pcall = original_pcall
      io.open = original_io_open
    end)

    it("should not fail if the directory already exists", function()
      local dir = "./test_dir"
      os.execute("mkdir -p " .. dir)
      assert.is_true(file_utils.ensure_config_dir_exists(dir))
      assert.is_true(vim.fn.isdirectory(dir) == 1)
      os.remove(dir)
    end)
  end)

  describe("get_config_path", function()
    before_each(function()
      package.loaded['llm.utils.file_utils'] = nil
      file_utils = require("llm.utils.file_utils")
    end)

    it("should return the config path", function()
      local shell = require("llm.utils.shell")
      local original_safe_shell_command = shell.safe_shell_command
      shell.safe_shell_command = function(cmd, _)
        if cmd == "llm logs path" then
          return "/tmp/llm/logs.db"
        elseif cmd == "dirname '/tmp/llm/logs.db'" then
          return "/tmp/llm"
        end
      end
      file_utils.ensure_config_dir_exists = function() return true end

      local config_dir, config_path = file_utils.get_config_path("test.json")
      assert.are.equal("/tmp/llm", config_dir)
      assert.are.equal("/tmp/llm/test.json", config_path)

      shell.safe_shell_command = original_safe_shell_command
    end)
  end)
end)
