-- test/spec/keys_manager_spec.lua

describe("keys_manager", function()
  local keys_manager
  local mock_utils

  before_each(function()
    keys_manager = require('llm.keys.keys_manager')
  end)

  after_each(function()
    package.loaded['llm.keys.keys_manager'] = nil
  end)

  it("should be a table", function()
    assert.is_table(keys_manager)
  end)

  describe("set_api_key", function()
    it("should set an API key", function()
      keys_manager.set_api_key("openai", "test_key")
      local keys = {}
      local attempts = 0
      while not vim.tbl_contains(keys, "openai") and attempts < 10 do
        vim.wait(100)
        keys = keys_manager.get_stored_keys()
        attempts = attempts + 1
      end
      assert.is_true(vim.tbl_contains(keys, "openai"))
    end)
  end)

  describe("remove_api_key", function()
    it("should remove an API key", function()
      keys_manager.set_api_key("openai", "test_key")
      local keys = {}
      local attempts = 0
      while not vim.tbl_contains(keys, "openai") and attempts < 10 do
        vim.wait(100)
        keys = keys_manager.get_stored_keys()
        attempts = attempts + 1
      end
      keys_manager.remove_api_key("openai")
      attempts = 0
      while vim.tbl_contains(keys, "openai") and attempts < 10 do
        vim.wait(100)
        keys = keys_manager.get_stored_keys()
        attempts = attempts + 1
      end
      assert.is_false(vim.tbl_contains(keys, "openai"))
    end)
  end)
end)
