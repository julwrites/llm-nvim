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
      -- Reset the custom_openai module's data
      local custom_openai = require('llm.models.custom_openai')
      custom_openai.custom_openai_models = {}

      mock_custom_openai = {
        custom_openai_models = {},
        load_custom_openai_models = function() end,
        is_custom_openai_model_valid = function(_) return false end,
      }
      package.loaded['llm.models.custom_openai'] = mock_custom_openai
    end)

    after_each(function()
      package.loaded['llm.models.custom_openai'] = nil
    end)

    it("should return a list of models from the cli", function()
      mock_models_io.get_models_from_cli = function()
        return "OpenAI: gpt-3.5-turbo\nAnthropic: claude-2", nil
      end
      local models = models_manager.get_available_models()
      assert.are.same({ "OpenAI: gpt-3.5-turbo", "Anthropic: claude-2" }, models)
    end)

    it("should include custom openai models", function()
      mock_models_io.get_models_from_cli = function()
        return "OpenAI: gpt-3.5-turbo", nil
      end
      mock_custom_openai.custom_openai_models = {
        ["my-custom-model"] = { model_id = "my-custom-model", model_name = "My Custom Model" }
      }
      local models = models_manager.get_available_models()
      assert.are.same({ "OpenAI: gpt-3.5-turbo", "Custom OpenAI: My Custom Model" }, models)
    end)

    it("should not include duplicate standard openai models", function()
      mock_models_io.get_models_from_cli = function()
        return "OpenAI: gpt-3.5-turbo\nOpenAI: gpt-3.5-turbo-16k", nil
      end
      mock_custom_openai.custom_openai_models = {
        ["gpt-3.5-turbo"] = { model_id = "gpt-3.5-turbo", model_name = "My Custom GPT-3.5" }
      }
      local models = models_manager.get_available_models()
      assert.are.same({ "OpenAI: gpt-3.5-turbo-16k", "Custom OpenAI: My Custom GPT-3.5" }, models)
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
end)
