require('spec_helper')

describe('llm.managers.schemas_manager', function()
  local schemas_manager
  local llm_cli

  before_each(function()
    vim.fn = {
      tempname = function() return '/tmp/test' end,
      stdpath = function() return '/tmp' end,
      json_decode = function() return {} end,
      json_encode = function() return '' end
    }
    package.loaded['llm.core.data.llm_cli'] = {
      run_llm_command = spy.new(function() return '[]' end)
    }
    llm_cli = require('llm.core.data.llm_cli')

    package.loaded['llm.managers.schemas_manager'] = nil
    schemas_manager = require('llm.managers.schemas_manager')
  end)

  describe('get_schemas()', function()
    it('should call llm_cli.run_llm_command with "schemas list --json"', function()
      schemas_manager.get_schemas()
      assert.spy(llm_cli.run_llm_command).was.called_with('schemas list --json')
    end)
  end)

  describe('get_schema()', function()
    it('should call llm_cli.run_llm_command with "schemas get <id> --json"', function()
      schemas_manager.get_schema('test_id')
      assert.spy(llm_cli.run_llm_command).was.called_with('schemas get test_id --json')
    end)
  end)
end)
