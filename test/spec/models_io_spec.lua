-- test/spec/models_io_spec.lua

describe("models_io", function()
  local models_io
  local spy
  local mock_utils

  before_each(function()
    spy = require('luassert.spy')
    mock_utils = {
      safe_shell_command = spy.new(function() return "", 0 end)
    }
    package.loaded['llm.core.utils'] = mock_utils
    models_io = require('llm.managers.models_io')
  end)

  after_each(function()
    package.loaded['llm.core.utils'] = nil
    package.loaded['llm.managers.models_io'] = nil
  end)

  it("should be a table", function()
    assert.is_table(models_io)
  end)

  describe("get_models_from_cli", function()
    it("should call safe_shell_command with the correct arguments", function()
      models_io.get_models_from_cli()
      assert.spy(mock_utils.safe_shell_command).was.called_with("llm models")
    end)
  end)

  describe("get_default_model_from_cli", function()
    it("should call safe_shell_command with the correct arguments", function()
      models_io.get_default_model_from_cli()
      assert.spy(mock_utils.safe_shell_command).was.called_with("llm models default")
    end)
  end)

  describe("set_default_model_in_cli", function()
    it("should call safe_shell_command with the correct arguments", function()
      models_io.set_default_model_in_cli("gpt-3.5-turbo")
      assert.spy(mock_utils.safe_shell_command).was.called_with("llm models default gpt-3.5-turbo")
    end)
  end)

  describe("get_aliases_from_cli", function()
    it("should call safe_shell_command with the correct arguments", function()
      models_io.get_aliases_from_cli()
      assert.spy(mock_utils.safe_shell_command).was.called_with("llm aliases --json")
    end)
  end)

  describe("set_alias_in_cli", function()
    it("should call safe_shell_command with the correct arguments", function()
      models_io.set_alias_in_cli("alias1", "model1")
      assert.spy(mock_utils.safe_shell_command).was.called_with("llm aliases set alias1 model1")
    end)
  end)

  describe("remove_alias_in_cli", function()
    it("should call safe_shell_command with the correct arguments", function()
      models_io.remove_alias_in_cli("alias1")
      assert.spy(mock_utils.safe_shell_command).was.called_with("llm aliases remove 'alias1'")
    end)
  end)
end)
