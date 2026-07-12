-- tests/spec/managers/custom_openai_spec.lua

require("spec_helper")

describe("llm.managers.custom_openai", function()
  local custom_openai
  local file_utils
  local text_utils
  local keys_manager
  local config

  before_each(function()
    _G.io_open = io.open
    package.loaded["llm.managers.custom_openai"] = nil
    package.loaded["llm.core.utils.file_utils"] = nil
    package.loaded["llm.core.utils.text"] = nil
    package.loaded["llm.managers.keys_manager"] = nil
    package.loaded["llm.config"] = nil

    -- Mock config
    package.loaded["llm.config"] = {
      get = function() return false end
    }
    config = package.loaded["llm.config"]

    file_utils = require("llm.core.utils.file_utils")
    text_utils = require("llm.core.utils.text")
    keys_manager = require("llm.managers.keys_manager")
    custom_openai = require("llm.managers.custom_openai")
  end)

  after_each(function()
    package.loaded["llm.managers.custom_openai"] = nil
    package.loaded["llm.core.utils.file_utils"] = nil
    package.loaded["llm.core.utils.text"] = nil
    package.loaded["llm.managers.keys_manager"] = nil
    io.open = _G.io_open
  end)

  describe("load_custom_openai_models()", function()
    before_each(function()
      local template_file = io.open("tests/templates/extra-openai-models.yaml.template", "r")
      local content = template_file:read("*a")
      template_file:close()
      local temp_file = io.open("tests/spec/extra-openai-models.yaml", "w")
      temp_file:write(content)
      temp_file:close()
    end)

    after_each(function()
      os.remove("tests/spec/extra-openai-models.yaml")
    end)

    it("should load models from a valid YAML file", function()
      -- Mock dependencies
      file_utils.get_config_path = function() return "tests/spec", "tests/spec/extra-openai-models.yaml" end
      text_utils.parse_simple_yaml = function()
        return {
          { model_id = "test-model-1", model_name = "Test Model 1", needs_auth = true, api_key_name = "test_key_1" },
          { model_id = "test-model-2", model_name = "Test Model 2", needs_auth = false }
        }
      end
      keys_manager.is_key_set = function(key)
        return key == "test_key_1"
      end

      -- Call the function
      local models = custom_openai.load_custom_openai_models()

      -- Assertions
      assert.is_not_nil(models["test-model-1"])
      assert.are.equal("Test Model 1", models["test-model-1"].model_name)
      assert.is_true(models["test-model-1"].is_valid)

      assert.is_not_nil(models["test-model-2"])
      assert.are.equal("Test Model 2", models["test-model-2"].model_name)
      assert.is_true(models["test-model-2"].is_valid)
    end)

    it("should handle a missing or empty YAML file", function()
      -- Mock dependencies
      file_utils.get_config_path = function() return nil, "/fake/path/extra-openai-models.yaml" end
      io.open = function() return nil end

      -- Call the function
      local models = custom_openai.load_custom_openai_models()

      -- Assertions
      assert.is_true(vim.tbl_isempty(models))
    end)

    it("should handle an invalid YAML file", function()
      -- Mock dependencies
      file_utils.get_config_path = function() return "tests/spec", "tests/spec/extra-openai-models.yaml" end
      local temp_file = io.open("tests/spec/extra-openai-models.yaml", "w")
      temp_file:write("invalid: yaml:")
      temp_file:close()
      text_utils.parse_simple_yaml = function() return nil end
      os.rename = function() end

      -- Call the function
      local models = custom_openai.load_custom_openai_models()

      -- Assertions
      assert.is_true(vim.tbl_isempty(models))
    end)
  end)

  describe("is_custom_openai_model_valid()", function()
    it("should return true for a valid model with an API key", function()
      -- Mock dependencies
      keys_manager.is_key_set = function() return true end

      -- Call the function
      local is_valid = custom_openai.is_custom_openai_model_valid({
        needs_auth = true,
        api_key_name = "test_key"
      })

      -- Assertions
      assert.is_true(is_valid)
    end)

    it("should return false for a valid model without an API key", function()
      -- Mock dependencies
      keys_manager.is_key_set = function() return false end

      -- Call the function
      local is_valid = custom_openai.is_custom_openai_model_valid({
        needs_auth = true,
        api_key_name = "test_key"
      })

      -- Assertions
      assert.is_false(is_valid)
    end)

    it("should return true for a model that does not require auth", function()
      -- Call the function
      local is_valid = custom_openai.is_custom_openai_model_valid({
        needs_auth = false
      })

      -- Assertions
      assert.is_true(is_valid)
    end)
  end)

  describe("debug_custom_openai_models()", function()
    it("should print debug information for custom models", function()
      file_utils.get_config_path = function() return "tests/spec", "tests/spec/extra-openai-models.yaml" end
      local io_open_orig = io.open
      io.open = function(path, mode)
        if string.find(path, "yaml") then
          return { read = function() return "" end, close = function() end }
        end
        return io_open_orig(path, mode)
      end
      local notify_called = false
      vim.notify = function() notify_called = true end

      custom_openai.debug_custom_openai_models()

      assert.is_true(notify_called)
      io.open = io_open_orig
    end)
  end)

  describe("create_sample_yaml_file()", function()
    it("should return false if config directory is not found", function()
      file_utils.get_config_path = function() return nil, nil end
      local result = custom_openai.create_sample_yaml_file()
      assert.is_false(result)
    end)

    it("should write a sample file and return true", function()
      file_utils.get_config_path = function() return "tests/spec", "tests/spec/extra-openai-models.yaml.sample" end
      local io_open_orig = io.open
      local write_called = false
      io.open = function(path, mode)
        if string.find(path, "yaml") then
          return { write = function() write_called = true end, close = function() end }
        end
        return io_open_orig(path, mode)
      end

      local result = custom_openai.create_sample_yaml_file()
      assert.is_true(result)
      assert.is_true(write_called)
      io.open = io_open_orig
    end)
  end)

  describe("serialize_to_yaml()", function()
    it("should serialize an empty list to empty string", function()
      local result = custom_openai.serialize_to_yaml({})
      assert.are.equal("", result)
    end)

    it("should serialize valid models", function()
      local models = {
        { model_id = "test", model_name = "Test", needs_auth = false, supports_functions = true, supports_system_prompt = false }
      }
      local result = custom_openai.serialize_to_yaml(models)
      assert.is_true(string.find(result, "model_id: test") ~= nil)
      assert.is_true(string.find(result, "needs_auth: false") ~= nil)
    end)
  end)

  describe("add_custom_openai_model()", function()
    it("should return false if model_id is missing", function()
      local result, err = custom_openai.add_custom_openai_model({})
      assert.is_false(result)
    end)
  end)

  describe("delete_custom_openai_model()", function()
    it("should return false if model_id is missing", function()
      local result, err = custom_openai.delete_custom_openai_model(nil)
      assert.is_false(result)
    end)
  end)
end)
