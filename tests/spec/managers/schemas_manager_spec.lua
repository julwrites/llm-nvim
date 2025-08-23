package.preload['llm.core.data.llm_cli'] = function()
    return require('mock_llm_cli')
end

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
    it('should return correct command string in test_mode', function()
      local old_tempname = vim.fn.tempname
      vim.fn.tempname = function()
        return 'temp_file'
      end

      local command = schemas_manager.run_schema('my-schema', 'my-input', false, nil, true)
      assert.are.equal('schema my-schema temp_file', command)

      command = schemas_manager.run_schema('my-schema', 'my-input', true, nil, true)
      assert.are.equal('schema my-schema temp_file --multi', command)

      vim.fn.tempname = old_tempname
    end)

    it('should call api.run_llm_command_streamed with correct executable path when not in test mode', function()
        -- spy on llm.api
        local streamed_cmd_parts
        package.preload['llm.api'] = function()
            return {
                run_llm_command_streamed = function(cmd_parts, _, _)
                    streamed_cmd_parts = cmd_parts
                    return 123 -- return a dummy job id
                end
            }
        end
        package.loaded['llm.api'] = nil

        local mock_helper = require('mock_helper')
        local revert_io_open = mock_helper.mock_io_open('temp_file')
        local old_tempname = vim.fn.tempname
        vim.fn.tempname = function() return 'temp_file' end
        local old_remove = os.remove
        os.remove = function() end

        -- Call the function
        schemas_manager.run_schema('my-schema', 'my-input', false, nil, false) -- test_mode is false

        -- Assertions
        assert.is_not_nil(streamed_cmd_parts)
        -- The mock returns "/usr/bin/llm"
        assert.are.equal('/usr/bin/llm', streamed_cmd_parts[1])
        assert.are.equal('schema my-schema temp_file', streamed_cmd_parts[2])

        -- Restore mocks
        vim.fn.tempname = old_tempname
        revert_io_open()
        os.remove = old_remove
        package.loaded['llm.api'] = nil
        package.preload['llm.api'] = nil
    end)
  end)
end)
