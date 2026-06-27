-- tests/spec/managers/tools_manager_spec.lua
require('spec_helper')
local tools_manager = require('llm.managers.tools_manager')
local llm_cli = require('llm.core.data.llm_cli')
local mock_vim = require('mock_vim')

describe("tools_manager", function()
  before_each(function()
    _G.vim = mock_vim
    stub(llm_cli, "run_llm_command")

    -- Mock json_decode in vim.fn for these tests
    stub(vim.fn, "json_decode")
  end)

  after_each(function()
    llm_cli.run_llm_command:revert()
    vim.fn.json_decode:revert()
  end)

  it("get_tools parses JSON output correctly", function()
    local sample_json = [[{"tools": [{"name": "llm_time", "description": "Returns the current time", "plugin": "llm.default_plugins.default_tools"}]}]]
    llm_cli.run_llm_command.returns(sample_json)
    vim.fn.json_decode.returns({
      tools = {
        {
          name = "llm_time",
          description = "Returns the current time",
          plugin = "llm.default_plugins.default_tools"
        }
      }
    })

    local tools = tools_manager.get_tools()

    assert.spy(llm_cli.run_llm_command).was.called_with('tools list --json')
    assert.are.same(1, #tools)
    assert.are.same("llm_time", tools[1].name)
    assert.are.same("Returns the current time", tools[1].description)
  end)

  it("get_tools handles empty output gracefully", function()
    llm_cli.run_llm_command.returns("")
    local tools = tools_manager.get_tools()
    assert.are.same({}, tools)
  end)

  it("get_tools handles invalid JSON gracefully", function()
    llm_cli.run_llm_command.returns("invalid json output")
    vim.fn.json_decode.invokes(function() error("Invalid JSON") end)
    stub(vim, "notify")

    local tools = tools_manager.get_tools()

    assert.are.same({}, tools)
    assert.spy(vim.notify).was.called()
    vim.notify:revert()
  end)
end)
