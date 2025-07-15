-- test/spec/models_manager_spec.lua

describe("models_manager", function()
  local models_manager
  local mock_models_io

  before_each(function()
    -- Mock models_io
    mock_models_io = {
      get_models_from_cli = function() return "", nil end,
      get_default_model_from_cli = function() return "", nil end,
      set_default_model_in_cli = function(_) return "", nil end,
      get_aliases_from_cli = function() return "{}", nil end,
      set_alias_in_cli = function(_, _) return "", nil end,
      remove_alias_in_cli = function(_) return "", nil end,
    }

    -- Load models_manager with mocked dependencies
    package.loaded['llm.models.models_io'] = mock_models_io
    models_manager = require('llm.models.models_manager')
  end)

  after_each(function()
    package.loaded['llm.models.models_io'] = nil
    package.loaded['llm.models.models_manager'] = nil
  end)

  it("should be a table", function()
    assert.is_table(models_manager)
  end)

  describe("extract_model_name", function()
    it("should extract model name from standard format", function()
      local line = "OpenAI: gpt-3.5-turbo"
      local model_name = models_manager.extract_model_name(line)
      assert.are.equal("gpt-3.5-turbo", model_name)
    end)

    it("should extract model name with custom label", function()
      local line = "OpenAI: gpt-4 (custom)"
      local model_name = models_manager.extract_model_name(line)
      assert.are.equal("gpt-4", model_name)
    end)

    it("should extract model name from custom provider format", function()
      local line = "Custom OpenAI: my-custom-model"
      local model_name = models_manager.extract_model_name(line)
      assert.are.equal("my-custom-model", model_name)
    end)

    it("should handle extra whitespace", function()
      local line = "  Anthropic:   claude-2   "
      local model_name = models_manager.extract_model_name(line)
      assert.are.equal("claude-2", model_name)
    end)

    it("should handle model names with slashes", function()
      local line = "Anthropic Messages: anthropic/claude-3-opus-20240229"
      local model_name = models_manager.extract_model_name(line)
      assert.are.equal("anthropic/claude-3-opus-20240229", model_name)
    end)

    it("should return the full line if no pattern matches", function()
      local line = "my-special-model"
      local model_name = models_manager.extract_model_name(line)
      assert.are.equal("my-special-model", model_name)
    end)

    it("should return an empty string for an empty line", function()
      local line = ""
      local model_name = models_manager.extract_model_name(line)
      assert.are.equal("", model_name)
    end)

    it("should return an empty string for a nil line", function()
      local model_name = models_manager.extract_model_name(nil)
      assert.are.equal("", model_name)
    end)
  end)

  describe("get_available_models", function()
    local mock_custom_openai

    before_each(function()
      mock_custom_openai = {
        custom_openai_models = {},
        load_custom_openai_models = function() end,
        is_custom_openai_model_valid = function(_) return false end,
      }
      models_manager.set_custom_openai(mock_custom_openai)
    end)

    it("should return a list of models from the cli", function()
      mock_models_io.get_models_from_cli = function()
        return "OpenAI: gpt-3.5-turbo\nAnthropic: claude-2", nil
      end
      local models = models_manager.get_available_models()
      table.sort(models)
      assert.are.same({ "Anthropic: claude-2", "OpenAI: gpt-3.5-turbo" }, models)
    end)

    it("should include custom openai models", function()
      mock_models_io.get_models_from_cli = function()
        return "OpenAI: gpt-3.5-turbo", nil
      end
      mock_custom_openai.custom_openai_models = {
        ["my-custom-model"] = { model_id = "my-custom-model", model_name = "My Custom Model" }
      }
      local models = models_manager.get_available_models()
      table.sort(models)
      assert.are.same({ "Custom OpenAI: My Custom Model", "OpenAI: gpt-3.5-turbo" }, models)
    end)

    it("should not include duplicate standard openai models", function()
      mock_models_io.get_models_from_cli = function()
        return "OpenAI: gpt-3.5-turbo\nOpenAI: gpt-3.5-turbo-16k", nil
      end
      mock_custom_openai.custom_openai_models = {
        ["gpt-3.5-turbo"] = { model_id = "gpt-3.5-turbo", model_name = "My Custom GPT-3.5" }
      }
      local models = models_manager.get_available_models()
      table.sort(models)
      assert.are.same({ "Custom OpenAI: My Custom GPT-3.5", "OpenAI: gpt-3.5-turbo-16k" }, models)
    end)
  end)

  describe("get_model_aliases", function()
    it("should return a table of aliases from the cli", function()
      mock_models_io.get_aliases_from_cli = function()
        return '{"alias1": "model1", "alias2": "model2"}', nil
      end
      local aliases = models_manager.get_model_aliases()
      assert.are.same({ alias1 = "model1", alias2 = "model2" }, aliases)
    end)

    it("should return an empty table if the cli returns an empty json object", function()
      mock_models_io.get_aliases_from_cli = function()
        return "{}", nil
      end
      local aliases = models_manager.get_model_aliases()
      assert.are.same({}, aliases)
    end)

    it("should return an empty table if the cli returns an error", function()
      mock_models_io.get_aliases_from_cli = function()
        return nil, "some error"
      end
      local aliases = models_manager.get_model_aliases()
      assert.are.same({}, aliases)
    end)
  end)

  describe("set_default_model", function()
    it("should return false if model name is nil", function()
      assert.is_false(models_manager.set_default_model(nil))
    end)

    it("should return false if model name is empty", function()
      assert.is_false(models_manager.set_default_model(""))
    end)

    it("should call models_io.set_default_model_in_cli with the correct model name", function()
      local model_name = "gpt-3.5-turbo"
      local spy = require('luassert.spy').on(mock_models_io, "set_default_model_in_cli")
      models_manager.set_default_model(model_name)
      assert.spy(spy).was.called_with(model_name)
    end)

    it("should return true on success", function()
      mock_models_io.set_default_model_in_cli = function(_) return "success", nil end
      assert.is_true(models_manager.set_default_model("gpt-3.5-turbo"))
    end)

    it("should return false on failure", function()
      mock_models_io.set_default_model_in_cli = function(_) return nil, "error" end
      assert.is_false(models_manager.set_default_model("gpt-3.5-turbo"))
    end)
  end)

  describe("set_model_alias", function()
    it("should return false if alias is nil", function()
      assert.is_false(models_manager.set_model_alias(nil, "model"))
    end)

    it("should return false if alias is empty", function()
      assert.is_false(models_manager.set_model_alias("", "model"))
    end)

    it("should return false if model is nil", function()
      assert.is_false(models_manager.set_model_alias("alias", nil))
    end)

    it("should return false if model is empty", function()
      assert.is_false(models_manager.set_model_alias("alias", ""))
    end)

    it("should call models_io.set_alias_in_cli with the correct alias and model", function()
      local alias = "my-alias"
      local model = "gpt-3.5-turbo"
      local spy = require('luassert.spy').on(mock_models_io, "set_alias_in_cli")
      models_manager.set_model_alias(alias, model)
      assert.spy(spy).was.called_with(alias, model)
    end)

    it("should return true on success", function()
      mock_models_io.set_alias_in_cli = function(_, _) return "success", nil end
      assert.is_true(models_manager.set_model_alias("alias", "model"))
    end)

    it("should return false on failure", function()
      mock_models_io.set_alias_in_cli = function(_, _) return nil, "error" end
      assert.is_false(models_manager.set_model_alias("alias", "model"))
    end)
  end)

  describe("remove_model_alias", function()
    it("should return false if alias is nil", function()
      assert.is_false(models_manager.remove_model_alias(nil))
    end)

    it("should return false if alias is empty", function()
      assert.is_false(models_manager.remove_model_alias(""))
    end)

    it("should call models_io.remove_alias_in_cli with the correct alias", function()
      local alias = "my-alias"
      local spy = require('luassert.spy').on(mock_models_io, "remove_alias_in_cli")
      models_manager.remove_model_alias(alias)
      assert.spy(spy).was.called_with(alias)
    end)

    it("should return true on success", function()
      mock_models_io.remove_alias_in_cli = function(_) return "success", nil end
      assert.is_true(models_manager.remove_model_alias("alias"))
    end)

    it("should return false on failure when alias is not found", function()
        mock_models_io.remove_alias_in_cli = function(_) return nil, "error" end
        assert.is_false(models_manager.remove_model_alias("alias"))
    end)
  end)

  describe("set_default_model_logic", function()
    local original_is_model_available

    before_each(function()
        original_is_model_available = models_manager.is_model_available
    end)

    after_each(function()
        models_manager.is_model_available = original_is_model_available
    end)

    it("should return success when setting a new default model", function()
        local model_id = "gpt-4"
        local model_info = {
            model_name = "GPT-4",
            is_default = false,
            is_custom = false,
            full_line = "OpenAI: gpt-4"
        }
        mock_models_io.set_default_model_in_cli = function(_) return "success", nil end
        local result = models_manager.set_default_model_logic(model_id, model_info)
        assert.is_true(result.success)
        assert.are.equal("Default model set to: GPT-4", result.message)
    end)

    it("should return failure when model is already the default", function()
        local model_id = "gpt-4"
        local model_info = {
            model_name = "GPT-4",
            is_default = true,
            is_custom = false,
            full_line = "OpenAI: gpt-4"
        }
        local result = models_manager.set_default_model_logic(model_id, model_info)
        assert.is_false(result.success)
        assert.are.equal("Model 'GPT-4' is already the default", result.message)
    end)

    it("should return failure when model is not available", function()
        local model_id = "gpt-4"
        local model_info = {
            model_name = "GPT-4",
            is_default = false,
            is_custom = false,
            full_line = "OpenAI: gpt-4"
        }
        local spy = require('luassert.spy').on(models_manager, "is_model_available")
        spy.returns(false)
        local result = models_manager.set_default_model_logic(model_id, model_info)
        assert.is_false(result.success)
        assert.are.equal("Cannot set as default: OpenAI requirements not met (API key/plugin/config)", result.message)
        spy:revert()
    end)
  end)

  describe("is_model_available", function()
    local mock_keys_manager
    local mock_plugins_manager

    before_each(function()
        mock_keys_manager = {
            is_key_set = function(_) return false end,
        }
        mock_plugins_manager = {
            is_plugin_installed = function(_) return false end,
        }
        package.loaded['llm.keys.keys_manager'] = mock_keys_manager
        package.loaded['llm.plugins.plugins_manager'] = mock_plugins_manager
    end)

    it("should return true for local models", function()
        assert.is_true(models_manager.is_model_available("local-model"))
    end)

    it("should return true for OpenAI model when key is set", function()
        mock_keys_manager.is_key_set = function(provider) return provider == "openai" end
        assert.is_true(models_manager.is_model_available("OpenAI: gpt-3.5-turbo"))
    end)

    it("should return false for OpenAI model when key is not set", function()
        assert.is_false(models_manager.is_model_available("OpenAI: gpt-3.5-turbo"))
    end)

    it("should return true for Anthropic model when key is set", function()
        mock_keys_manager.is_key_set = function(provider) return provider == "anthropic" end
        assert.is_true(models_manager.is_model_available("Anthropic: claude-2"))
    end)

    it("should return false for Anthropic model when key is not set", function()
        assert.is_false(models_manager.is_model_available("Anthropic: claude-2"))
    end)

    it("should return true for Ollama model when plugin is installed", function()
        mock_plugins_manager.is_plugin_installed = function(plugin) return plugin == "llm-ollama" end
        assert.is_true(models_manager.is_model_available("ollama/llama2"))
    end)

    it("should return false for Ollama model when plugin is not installed", function()
        assert.is_false(models_manager.is_model_available("ollama/llama2"))
    end)
  end)
end)
