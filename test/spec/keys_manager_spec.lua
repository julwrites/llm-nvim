-- test/spec/keys_manager_spec.lua

describe("keys_manager", function()
  local keys_manager
  local spy

  before_each(function()
    spy = require('luassert.spy')
    package.loaded['llm.utils'] = {
      safe_shell_command = spy.new(function() return "", 0 end)
    }
    keys_manager = require('llm.keys.keys_manager')
  end)

  after_each(function()
    package.loaded['llm.keys.keys_manager'] = nil
    package.loaded['llm.utils'] = nil
  end)

  it("should be a table", function()
    assert.is_table(keys_manager)
  end)

  describe("set_api_key", function()
    it("should set an API key", function()
      keys_manager.set_api_key("openai", "test_key")
      assert.spy(package.loaded['llm.utils'].safe_shell_command).was.called_with('llm keys set openai -v "test_key"')
    end)
  end)

  describe("remove_api_key", function()
    it("should remove an API key", function()
      keys_manager.remove_api_key("openai")
      assert.spy(package.loaded['llm.utils'].safe_shell_command).was.called_with("llm keys set openai --remove")
    end)
  end)
end)
