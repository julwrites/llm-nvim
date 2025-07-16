-- test/spec/keys_manager_spec.lua

describe("keys_manager", function()
  local keys_manager
  local mock_fs

  before_each(function()
    mock_fs = {
      find = function(_, _) return {} end,
    }

    package.loaded['llm.utils.file_utils'] = mock_fs
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
        local mock_file_utils = {
            save_json = require('luassert.spy').create(),
            get_config_dir = function() return "config_dir" end,
        }
        package.loaded['llm.utils.file_utils'] = mock_file_utils
        keys_manager = require('llm.keys.keys_manager')

        keys_manager.save_key("new_provider", "new_key")
        assert.spy(mock_file_utils.save_json).was.called_with("config_dir/keys/new_provider.json", { key = "new_key" })
    end)

    it("should update an existing key", function()
        local mock_file_utils = {
            save_json = require('luassert.spy').create(),
            get_config_dir = function() return "config_dir" end,
        }
        package.loaded['llm.utils.file_utils'] = mock_file_utils
        keys_manager = require('llm.keys.keys_manager')

        keys_manager.save_key("existing_provider", "updated_key")
        assert.spy(mock_file_utils.save_json).was.called_with("config_dir/keys/existing_provider.json", { key = "updated_key" })
    end)
  end)

  describe("rename_key", function()
    it("should rename a key", function()
        local mock_file_utils = {
            rename_file = require('luassert.spy').create(),
            get_config_dir = function() return "config_dir" end,
        }
        package.loaded['llm.utils.file_utils'] = mock_file_utils
        keys_manager = require('llm.keys.keys_manager')

        keys_manager.rename_key("old_provider", "new_provider")
        assert.spy(mock_file_utils.rename_file).was.called_with("config_dir/keys/old_provider.json", "config_dir/keys/new_provider.json")
    end)
  end)

  describe("delete_key", function()
    it("should delete a key", function()
        local mock_file_utils = {
            delete_file = require('luassert.spy').create(),
            get_config_dir = function() return "config_dir" end,
        }
        package.loaded['llm.utils.file_utils'] = mock_file_utils
        keys_manager = require('llm.keys.keys_manager')

        keys_manager.delete_key("provider_to_delete")
        assert.spy(mock_file_utils.delete_file).was.called_with("config_dir/keys/provider_to_delete.json")
    end)
  end)
end)
