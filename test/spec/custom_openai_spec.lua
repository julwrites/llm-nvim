-- test/spec/custom_openai_spec.lua

describe("custom_openai", function()
  local custom_openai
  local spy
  local mock_utils
  local mock_keys_manager

  before_each(function()
    spy = require('luassert.spy')
    mock_utils = {
      get_config_path = function() return "", "/tmp/extra-openai-models.yaml" end,
      parse_simple_yaml = function() return {} end,
    }
    mock_keys_manager = {
      is_key_set = function() return true end,
    }
    package.loaded['llm.core.utils'] = mock_utils
    package.loaded['llm.managers.keys_manager'] = mock_keys_manager
    custom_openai = require('llm.managers.custom_openai')

    -- Mock io functions
    io.open = function()
        return {
            read = function() return '' end,
            write = function() end,
            close = function() end,
        }
    end
    os.rename = function() end
    vim.notify = function() end
  end)

  after_each(function()
    package.loaded['llm.utils'] = nil
    package.loaded['llm.keys.keys_manager'] = nil
    package.loaded['llm.models.custom_openai'] = nil
    io.open = nil
    os.rename = nil
    vim.notify = nil
  end)

  it("should be a table", function()
    assert.is_table(custom_openai)
  end)

  describe("load_custom_openai_models", function()
    it("should load custom models from a yaml file", function()
      mock_utils.parse_simple_yaml = function()
        return {
          {
            model_id = "my-custom-model",
            model_name = "My Custom Model",
            api_base = "http://localhost:8080",
            api_key_name = "custom_key",
          }
        }
      end
      io.open = function()
        return {
            read = function() return "- model_id: my-custom-model" end,
            close = function() end,
        }
      end
      custom_openai.load_custom_openai_models()
      local models = custom_openai.get_custom_openai_models()
      assert.is_table(models)
      assert.is_not_nil(models["my-custom-model"])
      assert.are.equal("My Custom Model", models["my-custom-model"].model_name)
    end)
  end)

  describe("is_custom_openai_model_valid", function()
    it("should return true for a valid model", function()
        custom_openai.custom_openai_models = {
            ["my-custom-model"] = {
                model_id = "my-custom-model",
                api_key_name = "custom_key",
                needs_auth = true,
            }
        }
      assert.is_true(custom_openai.is_custom_openai_model_valid("my-custom-model"))
    end)

    it("should return false for an invalid model", function()
        mock_keys_manager.is_key_set = function() return false end
        custom_openai.custom_openai_models = {
            ["my-custom-model"] = {
                model_id = "my-custom-model",
                api_key_name = "custom_key",
                needs_auth = true,
            }
        }
      assert.is_false(custom_openai.is_custom_openai_model_valid("my-custom-model"))
    end)
  end)

  describe("add_custom_openai_model", function()
    it("should add a new custom model to the yaml file", function()
      local write_spy = spy.new(function() end)
      io.open = function()
        return {
            read = function() return '' end,
            write = write_spy,
            close = function() end,
        }
      end
      custom_openai.add_custom_openai_model({
        model_id = "my-new-model",
        model_name = "My New Model",
      })
      assert.spy(write_spy).was.called()
    end)
  end)

  describe("delete_custom_openai_model", function()
    it("should delete a custom model from the yaml file", function()
        mock_utils.parse_simple_yaml = function()
            return {
                {
                    model_id = "my-custom-model",
                    model_name = "My Custom Model",
                }
            }
        end
      local write_spy = spy.new(function() end)
      io.open = function()
        return {
            read = function() return '' end,
            write = write_spy,
            close = function() end,
        }
      end
      custom_openai.delete_custom_openai_model("my-custom-model")
      assert.spy(write_spy).was.called()
    end)
  end)
end)
