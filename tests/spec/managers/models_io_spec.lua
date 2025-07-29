-- tests/spec/managers/models_io_spec.lua

require("spec_helper")

describe("llm.managers.models_io", function()
  local models_io
  local llm_cli

  before_each(function()
    _G.package = require('package')
    package.loaded["llm.managers.models_io"] = nil
    package.loaded["llm.core.data.llm_cli"] = nil

    llm_cli = require("llm.core.data.llm_cli")
    models_io = require("llm.managers.models_io")
  end)

  after_each(function()
    package.loaded["llm.managers.models_io"] = nil
    package.loaded["llm.core.data.llm_cli"] = nil
    _G.package = nil
  end)

  describe("get_models_from_cli()", function()
    it("should call llm_cli.run_llm_command with the correct command string", function()
      -- Mock llm_cli.run_llm_command
      local run_llm_command_spy = spy.on(llm_cli, "run_llm_command")

      -- Call the function
      models_io.get_models_from_cli()

      -- Assertions
      assert.spy(run_llm_command_spy).was.called_with("models list --json")
    end)
  end)

  describe("get_default_model_from_cli()", function()
    it("should call llm_cli.run_llm_command with the correct command string", function()
      -- Mock llm_cli.run_llm_command
      local run_llm_command_spy = spy.on(llm_cli, "run_llm_command")

      -- Call the function
      models_io.get_default_model_from_cli()

      -- Assertions
      assert.spy(run_llm_command_spy).was.called_with("default")
    end)
  end)

  describe("set_default_model_in_cli()", function()
    it("should call llm_cli.run_llm_command with the correct command string", function()
      -- Mock llm_cli.run_llm_command
      local run_llm_command_spy = spy.on(llm_cli, "run_llm_command")

      -- Call the function
      models_io.set_default_model_in_cli("test-model")

      -- Assertions
      assert.spy(run_llm_command_spy).was.called_with("default test-model")
    end)
  end)

  describe("get_aliases_from_cli()", function()
    it("should call llm_cli.run_llm_command with the correct command string", function()
      -- Mock llm_cli.run_llm_command
      local run_llm_command_spy = spy.on(llm_cli, "run_llm_command")

      -- Call the function
      models_io.get_aliases_from_cli()

      -- Assertions
      assert.spy(run_llm_command_spy).was.called_with("aliases list --json")
    end)
  end)

  describe("set_alias_in_cli()", function()
    it("should call llm_cli.run_llm_command with the correct command string", function()
      -- Mock llm_cli.run_llm_command
      local run_llm_command_spy = spy.on(llm_cli, "run_llm_command")

      -- Call the function
      models_io.set_alias_in_cli("test-alias", "test-model")

      -- Assertions
      assert.spy(run_llm_command_spy).was.called_with("aliases set test-alias test-model")
    end)
  end)

  describe("remove_alias_in_cli()", function()
    it("should call llm_cli.run_llm_command with the correct command string", function()
      -- Mock llm_cli.run_llm_command
      local run_llm_command_spy = spy.on(llm_cli, "run_llm_command")

      -- Call the function
      models_io.remove_alias_in_cli("test-alias")

      -- Assertions
      assert.spy(run_llm_command_spy).was.called_with("aliases remove 'test-alias'")
    end)
  end)
end)
