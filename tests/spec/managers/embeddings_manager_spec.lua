-- tests/spec/managers/embeddings_manager_spec.lua

require('spec_helper')
local mock_llm_cli = require('mock_llm_cli')
local spy = require('luassert.spy')
local assert = require('luassert')

describe("embeddings_manager", function()
  local embeddings_manager
  local llm_cli

  before_each(function()
    package.loaded['llm.core.data.llm_cli'] = mock_llm_cli

    embeddings_manager = require('llm.managers.embeddings_manager')
    llm_cli = require('llm.core.data.llm_cli')

    spy.on(llm_cli, 'run_llm_command')
  end)

  after_each(function()
    llm_cli.run_llm_command:revert()
  end)

  it("should generate embeddings with content", function()
    embeddings_manager.embed({ content = "Hello world" })
    assert.spy(llm_cli.run_llm_command).was_called_with("embed -c Hello world")
  end)

  it("should generate embeddings with all options", function()
    embeddings_manager.embed({
      collection = "my_collection",
      id = "my_id",
      model = "my_model",
      input = "file.txt",
      format = "json",
      store = true
    })
    assert.spy(llm_cli.run_llm_command).was_called_with("embed my_collection my_id -m my_model -i file.txt -f json --store")
  end)

  it("should handle string arguments", function()
    embeddings_manager.embed("-c 'Hello world'")
    assert.spy(llm_cli.run_llm_command).was_called_with("embed -c 'Hello world'")
  end)
end)
