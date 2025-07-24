-- test/spec/schemas_manager_spec.lua

describe("schemas_manager", function()
  local schemas_manager
  local spy
  local mock_schemas_loader
  local mock_schemas_view

  before_each(function()
    spy = require('luassert.spy')

    local mock_llm_cli = {
      run_llm_command = spy.new(function(command)
        if command == 'schemas list --json' then
          return vim.fn.json_encode({
            { id = 'id1', name = 'schema1', description = 'description1' },
            { id = 'id2', name = 'schema2', description = 'description2' },
          })
        elseif command == 'schemas get id1' then
          return vim.fn.json_encode({ id = 'id1', name = 'schema1', content = '{}' })
        elseif command == 'schemas alias set id1 new_alias' then
          return "Alias set"
        elseif command == 'schemas alias remove schema1' then
          return "Alias removed"
        end
        return ""
      end)
    }

    local mock_cache = {
      get = spy.new(function() return nil end),
      set = spy.new(function() end),
      invalidate = spy.new(function() end),
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

    package.loaded['llm.core.data.llm_cli'] = mock_llm_cli
    package.loaded['llm.core.data.cache'] = mock_cache
    package.loaded['llm.ui.views.schemas_view'] = mock_schemas_view
    package.loaded['llm.ui.unified_manager'] = {
      switch_view = function() end,
      close = function() end,
      open_specific_manager = function() end,
    }
    package.loaded['llm.core.utils'] = {
        check_llm_installed = function() return true end,
        create_buffer_with_content = function() end,
        get_config_path = function() return "", "" end,
    }

    vim.schedule = function(fn) fn() end

    schemas_manager = require('llm.managers.schemas_manager')

    -- Mock the get_schema_info_under_cursor function
    schemas_manager.get_schema_info_under_cursor = function()
        return 'id1', { name = 'schema1' }
    end
  end)

  after_each(function()
    package.loaded['llm.core.data.llm_cli'] = nil
    package.loaded['llm.core.data.cache'] = nil
    package.loaded['llm.ui.views.schemas_view'] = nil
    package.loaded['llm.managers.schemas_manager'] = nil
    package.loaded['llm.ui.unified_manager'] = nil
    package.loaded['llm.core.utils'] = nil
    vim.schedule = nil
  end)

  it("should be a table", function()
    assert.is_table(schemas_manager)
  end)

  describe("get_schemas", function()
    it("should return the loaded schemas", function()
      local schemas = schemas_manager.get_schemas()
      assert.spy(package.loaded['llm.core.data.llm_cli'].run_llm_command).was.called_with('schemas list --json')
      assert.are.same({
        { id = 'id1', name = 'schema1', description = 'description1' },
        { id = 'id2', name = 'schema2', description = 'description2' },
      }, schemas)
    end)
  end)

  describe("set_alias_for_schema_under_cursor", function()
      it("should set an alias for a schema", function()
          schemas_manager.set_alias_for_schema_under_cursor(1)
          assert.spy(package.loaded['llm.core.data.llm_cli'].run_llm_command).was.called_with('schemas alias set id1 new_alias')
      end)
  end)

  describe("delete_alias_for_schema_under_cursor", function()
    it("should delete an alias for a schema", function()
        schemas_manager.delete_alias_for_schema_under_cursor(1)
        assert.spy(package.loaded['llm.core.data.llm_cli'].run_llm_command).was.called_with('schemas alias remove schema1')
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
