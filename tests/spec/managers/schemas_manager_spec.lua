require('spec_helper')
local schemas_manager = require('llm.managers.schemas_manager')
local llm_cli = require('llm.core.data.llm_cli')
local cache = require('llm.core.data.cache')

describe('schemas_manager', function()
  before_each(function()
    cache.invalidate('schemas')
  end)

  describe('get_schemas', function()
    it('should parse JSON output from llm_cli.run_llm_command', function()
      local mock_json = '[{"id": "schema1", "name": "Schema 1"}]'
      local old_run_llm_command = llm_cli.run_llm_command
      llm_cli.run_llm_command = function()
        return mock_json
      end

      local old_json_decode = vim.fn.json_decode
      vim.fn.json_decode = function(json)
        if json == mock_json then
          return { { id = 'schema1', name = 'Schema 1' } }
        end
        return {}
      end

      local schemas = schemas_manager.get_schemas()
      assert.same({ { id = 'schema1', name = 'Schema 1' } }, schemas)

      llm_cli.run_llm_command = old_run_llm_command
      vim.fn.json_decode = old_json_decode
    end)

    it('should cache the schemas', function()
      local call_count = 0
      local old_run_llm_command = llm_cli.run_llm_command
      llm_cli.run_llm_command = function()
        call_count = call_count + 1
        return '[]'
      end

      local old_json_decode = vim.fn.json_decode
      vim.fn.json_decode = function()
        return {}
      end

      schemas_manager.get_schemas()
      schemas_manager.get_schemas()

      assert.are.equal(1, call_count)

      llm_cli.run_llm_command = old_run_llm_command
      vim.fn.json_decode = old_json_decode
    end)
  end)

  describe('get_schema', function()
    it('should parse JSON output from llm_cli.run_llm_command', function()
      local mock_json = '{"id": "schema1", "name": "Schema 1"}'
      local old_run_llm_command = llm_cli.run_llm_command
      llm_cli.run_llm_command = function(command)
        if command == 'schemas get schema1 --json' then
          return mock_json
        end
      end

      local old_json_decode = vim.fn.json_decode
      vim.fn.json_decode = function(json)
        if json == mock_json then
          return { id = 'schema1', name = 'Schema 1' }
        end
        return {}
      end

      local schema = schemas_manager.get_schema('schema1')
      assert.same({ id = 'schema1', name = 'Schema 1' }, schema)

      llm_cli.run_llm_command = old_run_llm_command
      vim.fn.json_decode = old_json_decode
    end)
  end)

  describe('save_schema', function()
    it('should call llm_cli.run_llm_command with the correct arguments', function()
      local old_run_llm_command = llm_cli.run_llm_command
      local command
      llm_cli.run_llm_command = function(c)
        command = c
      end

      local old_tempname = vim.fn.tempname
      vim.fn.tempname = function()
        return 'temp_file'
      end

      local command = schemas_manager.save_schema('my-schema', '{"type": "string"}', true)

      assert.are.equal('schemas save my-schema temp_file', command)

      vim.fn.tempname = old_tempname
    end)
  end)

  describe('run_schema', function()
    it('should call llm_cli.run_llm_command with the correct arguments', function()
      local old_tempname = vim.fn.tempname
      vim.fn.tempname = function()
        return 'temp_file'
      end

      local command = schemas_manager.run_schema('my-schema', 'my-input', false, true)
      assert.are.equal('schema my-schema temp_file', command)

      command = schemas_manager.run_schema('my-schema', 'my-input', true, true)
      assert.are.equal('schema my-schema temp_file --multi', command)

      vim.fn.tempname = old_tempname
    end)
  end)
end)
