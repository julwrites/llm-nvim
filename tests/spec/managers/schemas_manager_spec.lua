require('spec_helper')

describe('llm.managers.schemas_manager', function()
  local schemas_manager
  local llm_cli
  local cache

  before_each(function()
    vim.fn = {
      tempname = function() return '/tmp/test' end,
      stdpath = function() return '/tmp' end,
      json_decode = function(s) if s == '[]' then return {} else return { s } end end,
      json_encode = function() return '' end
    }
    llm_cli = {
      run_llm_command = spy.new(function() return '[]' end),
      get_llm_executable_path = function() return 'llm' end
    }
    package.loaded['llm.core.data.llm_cli'] = llm_cli

    cache = {
      get = spy.new(function() return nil end),
      set = spy.new(function() end),
      invalidate = spy.new(function() end)
    }
    package.loaded['llm.core.data.cache'] = cache

    package.loaded['llm.managers.schemas_manager'] = nil
    schemas_manager = require('llm.managers.schemas_manager')
  end)

  describe('get_schemas()', function()
    it('should call llm_cli.run_llm_command with "schemas list --json" on cache miss', function()
      schemas_manager.get_schemas()
      assert.spy(cache.get).was.called_with('schemas')
      assert.spy(llm_cli.run_llm_command).was.called_with('schemas list --json')
      assert.spy(cache.set).was.called()
    end)

    it('should return cached schemas on cache hit', function()
      cache.get = spy.new(function(key)
        if key == 'schemas' then
          return { { id = 'cached_schema' } }
        end
      end)
      schemas_manager.get_schemas()
      assert.spy(cache.get).was.called_with('schemas')
      assert.spy(llm_cli.run_llm_command).was.not_called()
    end)
  end)

  describe('get_schema()', function()
    it('should call llm_cli.run_llm_command with "schemas get <id> --json"', function()
      schemas_manager.get_schema('test_id')
      assert.spy(llm_cli.run_llm_command).was.called_with('schemas get test_id --json')
    end)
  end)

  describe('save_schema()', function()
    local old_io_open, old_os_remove
    before_each(function()
      old_io_open = io.open
      old_os_remove = os.remove
    end)
    after_each(function()
      io.open = old_io_open
      os.remove = old_os_remove
    end)

    it('should return the correct command string in test mode', function()
      local command = schemas_manager.save_schema('test_schema', '{"type": "string"}', true)
      assert.are.equal('schemas save test_schema /tmp/test', command)
    end)

    it('should write to a temp file and call llm-cli', function()
      local file_mock = {
        write = spy.new(),
        close = spy.new(),
      }
      io.open = spy.new(function()
        return file_mock
      end)
      os.remove = spy.new()

      schemas_manager.save_schema('test_schema', '{"type": "string"}')
      assert.spy(io.open).was.called_with('/tmp/test', 'w')
      assert.spy(file_mock.write).was.called_with(file_mock, '{"type": "string"}')
      assert.spy(file_mock.close).was.called_with(file_mock)
      assert.spy(llm_cli.run_llm_command).was.called_with('schemas save test_schema /tmp/test')
      assert.spy(os.remove).was.called_with('/tmp/test')
      assert.spy(cache.invalidate).was.called_with('schemas')
    end)
  end)

  describe('run_schema()', function()
    local old_io_open
    local old_llm_api
    local api_mock

    before_each(function()
      old_io_open = io.open
      old_llm_api = package.loaded['llm.api']
      api_mock = { run_llm_command_streamed = spy.new() }
      package.loaded['llm.api'] = api_mock
      package.loaded['llm.managers.schemas_manager'] = nil
      schemas_manager = require('llm.managers.schemas_manager')
    end)

    after_each(function()
      io.open = old_io_open
      package.loaded['llm.api'] = old_llm_api
    end)

    it('should return the correct command string for a regular schema in test mode', function()
      local command = schemas_manager.run_schema('test_schema', 'input', false, nil, true)
      assert.are.equal('schema test_schema /tmp/test', command)
    end)

    it('should return the correct command string for a multi schema in test mode', function()
      local command = schemas_manager.run_schema('test_schema', 'input', true, nil, true)
      assert.are.equal('schema test_schema /tmp/test --multi', command)
    end)

    it('should write to a temp file and call streaming api', function()
      local file_mock = {
        write = spy.new(),
        close = spy.new(),
      }
      io.open = spy.new(function()
        return file_mock
      end)

      schemas_manager.run_schema('test_schema', 'my_input', false, 123)
      assert.spy(io.open).was.called_with('/tmp/test', 'w')
      assert.spy(file_mock.write).was.called_with(file_mock, 'my_input')
      assert.spy(file_mock.close).was.called_with(file_mock)
      assert.spy(api_mock.run_llm_command_streamed).was.called()
    end)
  end)

  describe('UI helper functions', function()
    it('should categorize schemas correctly', function()
      local all_schemas = {
        { id = 'schema1', name = 'Schema A' },
        { id = 'schema2' },
        { id = 'schema3', name = 'Schema C' },
        { id = 'schema4', name = 'Schema B' },
      }
      local named, unnamed = schemas_manager.categorize_schemas(all_schemas)
      assert.are.same({
        { id = 'schema1', name = 'Schema A' },
        { id = 'schema4', name = 'Schema B' },
        { id = 'schema3', name = 'Schema C' },
      }, named)
      assert.are.same({
        { id = 'schema2' },
      }, unnamed)
    end)

    it('should build buffer lines correctly', function()
        local schemas = {
            { id = 'schema1', name = 'Schema A', description = 'Description A' },
            { id = 'schema2', description = 'Description B' },
        }
        schemas_manager.get_schema = function(id)
            if id == 'schema1' or id == 'schema2' then
                return { content = '{"type": "string"}' }
            end
            return nil
        end

        local lines = schemas_manager.build_buffer_lines(schemas, true)
        assert.are.equal('# Schema Management', lines[1])
        assert.are.equal('Showing: Only named schemas', lines[7])
        assert.are.equal('Schema 1: schema1', lines[11])
        assert.are.equal('  Name: Schema A', lines[12])
        assert.are.equal('  Status: Valid', lines[13])
        assert.are.equal('  Description: Description A', lines[14])
    end)

    it('should build schema data correctly', function()
        local schemas = {
            { id = 'schema1', name = 'Schema A', description = 'Description A' },
        }
        schemas_manager.get_schema = function(id)
            if id == 'schema1' then
                return { content = '{"type": "string"}' }
            end
            return nil
        end

        local schema_data, line_to_schema = schemas_manager.build_schema_data(schemas, 11)
        assert.is_not_nil(schema_data['schema1'])
        assert.are.equal('Schema A', schema_data['schema1'].name)
        assert.are.equal(11, schema_data['schema1'].start_line)
        assert.are.equal('schema1', line_to_schema[11])
        assert.are.equal('schema1', line_to_schema[12])
        assert.are.equal('schema1', line_to_schema[13])
        assert.are.equal('schema1', line_to_schema[14])
    end)
  end)
end)
