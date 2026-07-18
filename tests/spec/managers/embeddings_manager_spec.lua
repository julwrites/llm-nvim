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

  it("should run embed_multi command with string", function()
    embeddings_manager.embed_multi("my_collection data.json --format json")
    assert.spy(llm_cli.run_llm_command).was_called_with("embed-multi my_collection data.json --format json")
  end)

  it("should run embed_multi command with opts", function()
    embeddings_manager.embed_multi({ collection = "my_collection", input_path = "data.json", format = "json" })
    assert.spy(llm_cli.run_llm_command).was_called_with("embed-multi my_collection data.json --format json")
  end)

  it("should run similar command with string", function()
    embeddings_manager.similar("my_collection 1234 -n 5")
    assert.spy(llm_cli.run_llm_command).was_called_with("similar my_collection 1234 -n 5")
  end)

  it("should run similar command with opts", function()
    embeddings_manager.similar({ collection = "my_collection", id = "1234", number = 5 })
    assert.spy(llm_cli.run_llm_command).was_called_with("similar my_collection 1234 -n 5")
  end)

  it("should run collections command", function()
    embeddings_manager.collections({ subcommand = "list" })
    assert.spy(llm_cli.run_llm_command).was_called_with("collections list")
  end)

  it("should run aliases command", function()
    embeddings_manager.aliases({ subcommand = "list" })
    assert.spy(llm_cli.run_llm_command).was_called_with("aliases list")
  end)
end)
