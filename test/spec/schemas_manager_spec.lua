-- test/spec/schemas_manager_spec.lua

describe("schemas_manager", function()
  local schemas_manager
  local mock_schemas_loader
  local mock_file_utils

  before_each(function()
    mock_schemas_loader = {
      load_schemas = function() return {} end,
    }

    mock_file_utils = {
      save_json = function(_, _) end,
      get_config_dir = function() return "config_dir" end,
      delete_file = function(_) end,
    }

    package.loaded['llm.schemas.schemas_loader'] = mock_schemas_loader
    package.loaded['llm.utils.file_utils'] = mock_file_utils
    package.loaded['llm.unified_manager'] = {
      switch_view = function() end,
    }
    schemas_manager = require('llm.schemas.schemas_manager')
    schemas_manager.load = function() end
  end)

  after_each(function()
    package.loaded['llm.schemas.schemas_loader'] = nil
    package.loaded['llm.schemas.schemas_manager'] = nil
    package.loaded['llm.utils.file_utils'] = nil
  end)

  it("should be a table", function()
    assert.is_table(schemas_manager)
  end)

  describe("loading and getting schemas", function()
    local fake_schemas

    before_each(function()
      fake_schemas = { { name = "schema1" }, { name = "schema2" } }
      mock_schemas_loader.load_schemas = function() return fake_schemas end
      schemas_manager:load()
    end)

    it("should return the loaded schemas", function()
      assert.are.same(fake_schemas, schemas_manager.get_schemas())
    end)

    it("should return the correct schema by name", function()
      assert.are.same(fake_schemas[1], schemas_manager.get_schema("schema1"))
    end)

    it("should return nil if the schema is not found", function()
      assert.is_nil(schemas_manager.get_schema("non_existent_schema"))
    end)
  end)

  describe("managing schemas", function()
    it("should call delete on the schema", function()
        local deleted = false
        local fake_schema = { name = "schema1", delete = function() deleted = true end }
        local fake_schemas = { fake_schema }
        mock_schemas_loader.load_schemas = function() return fake_schemas end
        schemas_manager:load()
        schemas_manager.delete_schema("schema1")
        assert.is_true(deleted)
    end)

    it("should create a new schema", function()
        local saved_path, saved_data
        mock_file_utils.save_json = function(path, data)
            saved_path = path
            saved_data = data
        end
        schemas_manager:load()
        schemas_manager.create_schema("my-schema", "My Schema")
        assert.are.equal("config_dir/schemas/my-schema.json", saved_path)
        assert.are.same({ name = "my-schema", description = "My Schema" }, saved_data)
    end)

    it("should save the edited schema", function()
        local saved_path, saved_data
        mock_file_utils.save_json = function(path, data)
            saved_path = path
            saved_data = data
        end
        schemas_manager:load()
        schemas_manager.edit_schema("my-schema", "My Edited Schema")
        assert.are.equal("config_dir/schemas/my-schema.json", saved_path)
        assert.are.same({ name = "my-schema", description = "My Edited Schema" }, saved_data)
    end)

    it("should create an alias for a schema", function()
        local saved_path, saved_data
        mock_file_utils.save_json = function(path, data)
            saved_path = path
            saved_data = data
        end
        schemas_manager:load()
        schemas_manager.alias_schema("my-schema", "my-alias")
        assert.are.equal("config_dir/schemas/my-alias.json", saved_path)
        assert.are.same({ name = "my-alias", alias = "my-schema" }, saved_data)
    end)
  end)
end)
