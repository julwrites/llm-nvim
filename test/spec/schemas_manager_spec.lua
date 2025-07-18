-- test/spec/schemas_manager_spec.lua

describe("schemas_manager", function()
  local schemas_manager
  local spy
  local mock_schemas_loader
  local mock_schemas_view

  before_each(function()
    spy = require('luassert.spy')
    mock_schemas_loader = {
      get_schemas = function()
        return {
          schema1 = 'description1',
          schema2 = 'description2',
        }
      end,
      get_schema = function(name)
        if name == 'schema1' then
          return { name = 'schema1', content = '{}' }
        else
          return nil
        end
      end,
      set_schema_alias = spy.new(function() return true end),
      remove_schema_alias = spy.new(function() return true end),
      save_schema = spy.new(function() return true end),
      run_schema = spy.new(function() return "{}" end),
      validate_json_schema = spy.new(function() return true end),
      create_schema_from_dsl = spy.new(function() return "{}" end)
    }

    mock_schemas_view = {
      select_schema = function(schemas, callback) callback("schema1") end,
      get_schema_type = function(callback) callback("Regular schema") end,
      get_input_source = function(callback) callback("Current buffer") end,
      get_url = function(callback) callback("http://example.com") end,
      get_schema_name = function(callback) callback("new_schema") end,
      get_schema_format = function(callback) callback("JSON Schema") end,
      get_alias = function(current_alias, callback) callback("new_alias") end,
      confirm_delete_alias = function(alias, callback) callback(true) end,
      show_details = spy.new(function() end),
    }

    package.loaded['llm.schemas.schemas_loader'] = mock_schemas_loader
    package.loaded['llm.schemas.schemas_view'] = mock_schemas_view
    package.loaded['llm.unified_manager'] = {
      switch_view = function() end,
      close = function() end,
      open_specific_manager = function() end,
    }
    package.loaded['llm.utils'] = {
        check_llm_installed = function() return true end,
        create_buffer_with_content = function() end,
        get_config_path = function() return "", "" end,
    }

    vim.schedule = function(fn) fn() end

    schemas_manager = require('llm.schemas.schemas_manager')

    -- Mock the get_schema_info_under_cursor function
    schemas_manager.get_schema_info_under_cursor = function()
        return 'id1', { name = 'schema1' }
    end
  end)

  after_each(function()
    package.loaded['llm.schemas.schemas_loader'] = nil
    package.loaded['llm.schemas.schemas_view'] = nil
    package.loaded['llm.schemas.schemas_manager'] = nil
    package.loaded['llm.unified_manager'] = nil
    package.loaded['llm.utils'] = nil
    vim.schedule = nil
  end)

  it("should be a table", function()
    assert.is_table(schemas_manager)
  end)

  describe("get_schemas", function()
    it("should return the loaded schemas", function()
      local schemas = schemas_manager.get_schemas()
      assert.are.same({
        schema1 = 'description1',
        schema2 = 'description2',
      }, schemas)
    end)
  end)

  describe("set_alias_for_schema_under_cursor", function()
      it("should set an alias for a schema", function()
          schemas_manager.set_alias_for_schema_under_cursor(1)
          assert.spy(mock_schemas_loader.set_schema_alias).was.called_with("id1", "new_alias")
      end)
  end)

  describe("delete_alias_for_schema_under_cursor", function()
    it("should delete an alias for a schema", function()
        schemas_manager.delete_alias_for_schema_under_cursor(1)
        assert.spy(mock_schemas_loader.remove_schema_alias).was.called_with("id1", "schema1")
    end)
  end)

  describe("create_schema_from_manager", function()
    it("should create a new schema", function()
      local create_schema_spy = spy.on(schemas_manager, 'create_schema')
      schemas_manager.create_schema_from_manager(1)
      assert.spy(create_schema_spy).was.called()
    end)
  end)

  describe("run_schema_under_cursor", function()
    it("should run a schema", function()
        local run_schema_with_input_source_spy = spy.on(schemas_manager, 'run_schema_with_input_source')
        schemas_manager.run_schema_under_cursor(1)
        assert.spy(run_schema_with_input_source_spy).was.called_with('id1')
    end)
  end)
end)
