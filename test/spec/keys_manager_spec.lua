-- test/spec/keys_manager_spec.lua

describe("keys_manager", function()
  local keys_manager
  local mock_fs
  local mock_file_utils

  before_each(function()
    mock_fs = {
      find = function(_, _) return {} end,
    }

    mock_file_utils = {
      save_json = function(_, _) end,
      get_config_dir = function() return "config_dir" end,
      rename_file = function(_, _) end,
      delete_file = function(_) end,
    }

    package.loaded['llm.utils.file_utils'] = mock_file_utils
    package.loaded['llm.keys.keys_manager'] = require('llm.keys.keys_manager')
    keys_manager = require('llm.keys.keys_manager')
  end)

  after_each(function()
    package.loaded['llm.utils.file_utils'] = nil
    package.loaded['llm.keys.keys_manager'] = nil
  end)

  it("should be a table", function()
    assert.is_table(keys_manager)
  end)

  describe("is_key_set", function()
    it("should return true if a key is found", function()
      mock_fs.find = function(_, _) return { "some/path/keys.json" } end
      assert.is_true(keys_manager.is_key_set("openai"))
    end)

    it("should return false if no key is found", function()
      assert.is_false(keys_manager.is_key_set("openai"))
    end)

    it("should return false for a nil provider", function()
      assert.is_false(keys_manager.is_key_set(nil))
    end)
  end)

  describe("get_keys", function()
    it("should return a list of available keys", function()
      mock_fs.find = function(_, _) return { "some/path/openai.json", "some/path/anthropic.json" } end
      local keys = keys_manager.get_keys()
      assert.are.same({ "anthropic", "openai" }, keys)
    end)

    it("should return an empty list if no keys are found", function()
      local keys = keys_manager.get_keys()
      assert.are.same({}, keys)
    end)
  end)

  describe("save_key", function()
    it("should create a new key", function()
      local saved_path, saved_data
      mock_file_utils.save_json = function(path, data)
        saved_path = path
        saved_data = data
      end
      keys_manager.save_key("new_provider", "new_key")
      assert.are.equal("config_dir/keys/new_provider.json", saved_path)
      assert.are.same({ key = "new_key" }, saved_data)
    end)

    it("should update an existing key", function()
      local saved_path, saved_data
      mock_file_utils.save_json = function(path, data)
        saved_path = path
        saved_data = data
      end
      keys_manager.save_key("existing_provider", "updated_key")
      assert.are.equal("config_dir/keys/existing_provider.json", saved_path)
      assert.are.same({ key = "updated_key" }, saved_data)
    end)
  end)

  describe("rename_key", function()
    it("should rename a key", function()
      local old_path, new_path
      mock_file_utils.rename_file = function(old, new)
        old_path = old
        new_path = new
      end
      keys_manager.rename_key("old_provider", "new_provider")
      assert.are.equal("config_dir/keys/old_provider.json", old_path)
      assert.are.equal("config_dir/keys/new_provider.json", new_path)
    end)
  end)

  describe("delete_key", function()
    it("should delete a key", function()
      local deleted_path
      mock_file_utils.delete_file = function(path)
        deleted_path = path
      end
      keys_manager.delete_key("provider_to_delete")
      assert.are.equal("config_dir/keys/provider_to_delete.json", deleted_path)
    end)
  end)
end)
