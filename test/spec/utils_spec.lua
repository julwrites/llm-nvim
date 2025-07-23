-- test/spec/utils_spec.lua

describe("llm.core.utils.validate", function()
  local validate = require("llm.core.utils.validate")

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
describe("llm.core.utils.text", function()
  local text = require("llm.core.utils.text")

  describe("capitalize", function()
    it("should capitalize the first letter of a string", function()
      assert.are.equal("Hello", text.capitalize("hello"))
    end)

    it("should return an empty string if the input is empty", function()
      assert.are.equal("", text.capitalize(""))
    end)

    it("should return the same string if the first letter is already capitalized", function()
      assert.are.equal("Hello", text.capitalize("Hello"))
    end)
  end)

  describe("get_visual_selection", function()
    it("should return the visual selection", function()
      vim.fn.setpos("'<", { 0, 1, 1, 0 })
      vim.fn.setpos("'>", { 0, 1, 5, 0 })
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello world" })
      local selection = text.get_visual_selection()
      assert.are.equal("hello", selection)
    end)

    it("should return the visual selection for multiline", function()
      vim.fn.setpos("'<", { 0, 1, 1, 0 })
      vim.fn.setpos("'>", { 0, 2, 5, 0 })
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello world", "goodbye world" })
      local selection = text.get_visual_selection()
      assert.are.equal("hello world\ngoodb", selection)
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
      file:close()
      local data = text.parse_simple_yaml("test.yaml")
      assert.are.same({ key = "value" }, data)
      os.remove("test.yaml")
    end)
  end)
end)

describe("llm.core.utils.shell", function()
  local shell = require("llm.core.utils.shell")

  describe("safe_shell_command", function()
    it("should return the result of the command", function()
      local result, err = shell.safe_shell_command("echo 'hello'")
      assert.are.equal("hello", result)
      assert.is_nil(err)
    end)

    it("should return an error if the command fails", function()
      local original_system = vim.fn.system
      vim.fn.system = function() return "" end
      vim.v = { shell_error = 1 }
      local result, err = shell.safe_shell_command("invalid_command", "Command failed")
      assert.is_nil(result)
      assert.is_not_nil(err)
      vim.fn.system = original_system
      vim.v = nil
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
      local original_notify_error = rawget(shell, "notify_error")
      rawset(shell, "notify_error", function() end)
      assert.is_false(shell.check_llm_installed())
      shell.command_exists = original_command_exists
      rawset(shell, "notify_error", original_notify_error)
    end)
  end)

  describe("update_llm_cli", function()
    it("should return a success message if the command succeeds", function()
      local original_command_exists = shell.command_exists
      shell.command_exists = function() return true end
      local original_run_update_command = shell.run_update_command
      shell.run_update_command = function()
        return "Successfully installed llm", 0
      end
      local result = shell.update_llm_cli()
      assert.is_true(result.success)
      assert.is_not_nil(result.message)
      shell.command_exists = original_command_exists
      shell.run_update_command = original_run_update_command
    end)

    it("should return an error message if the command fails", function()
      local original_command_exists = shell.command_exists
      shell.command_exists = function() return true end
      local original_run_update_command = shell.run_update_command
      shell.run_update_command = function()
        return "Failed to install llm", 1
      end
      local result = shell.update_llm_cli()
      assert.is_false(result.success)
      assert.is_not_nil(result.message)
      shell.command_exists = original_command_exists
      shell.run_update_command = original_run_update_command
    end)
  end)

  describe("get_last_update_timestamp", function()
    it("should return a timestamp", function()
      local timestamp = shell.get_last_update_timestamp()
      assert.is_number(timestamp)
    end)
  end)

  describe("set_last_update_timestamp", function()
    it("should set the timestamp", function()
      shell.set_last_update_timestamp()
      local timestamp = shell.get_last_update_timestamp()
      assert.is_number(timestamp)
      assert.is_true(timestamp > 0)
    end)
  end)
end)


describe("llm.core.utils.file_utils", function()
  local file_utils = require("llm.core.utils.file_utils")
  local shell = require("llm.core.utils.shell")

  describe("ensure_config_dir_exists", function()
    it("should not fail if the directory already exists", function()
      local dir = "./test_dir"
      os.execute("mkdir -p " .. dir)
      assert.is_true(file_utils.ensure_config_dir_exists(dir))
      os.execute("rm -rf " .. dir)
    end)
  end)

  describe("get_config_path", function()
    local original_safe_shell_command

    before_each(function()
      original_safe_shell_command = shell.safe_shell_command
      -- Reset cache
      package.loaded['llm.core.utils.file_utils'] = nil
      file_utils = require("llm.core.utils.file_utils")
    end)

    after_each(function()
      shell.safe_shell_command = original_safe_shell_command
    end)

    it("should return the config path", function()
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
    end)

    it("should handle trailing whitespace in paths", function()
      shell.safe_shell_command = function(cmd, _)
        if cmd == "llm logs path" then
          return "/tmp/llm/logs.db  "
        elseif cmd == "dirname '/tmp/llm/logs.db'" then
          return "/tmp/llm  "
        end
      end
      file_utils.ensure_config_dir_exists = function() return true end

      local config_dir, config_path = file_utils.get_config_path("test.json")
      assert.are.equal("/tmp/llm", config_dir)
      assert.are.equal("/tmp/llm/test.json", config_path)
    end)
  end)
end)
