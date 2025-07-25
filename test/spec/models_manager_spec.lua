-- test/spec/models_manager_spec.lua

describe("models_manager", function()
  local models_manager
  local spy
  local mock_models_io
  local mock_custom_openai
  local mock_keys_manager
  local mock_plugins_manager
  local mock_models_view
  local mock_utils
  local mock_unified_manager

  before_each(function()
    spy = require('luassert.spy')
    -- Mock models_io
    mock_models_io = {
      get_models_from_cli = function() return '[{"id": "gpt-3.5-turbo", "provider": "OpenAI"}, {"id": "claude-2", "provider": "Anthropic"}]', nil end,
      get_default_model_from_cli = function() return "gpt-3.5-turbo", nil end,
      set_default_model_in_cli = spy.new(function(_) return "success", nil end),
      get_aliases_from_cli = function() return '{"alias1": "model1", "alias2": "model2"}', nil end,
      set_alias_in_cli = spy.new(function(_, _) return "success", nil end),
      remove_alias_in_cli = spy.new(function(_) return "success", nil end),
    }

    mock_custom_openai = {
      custom_openai_models = {},
      load_custom_openai_models = function() end,
      is_custom_openai_model_valid = function(_) return false end,
      add_custom_openai_model = spy.new(function() return true end),
      remove = function() end,
      load = function() end,
    }

    mock_keys_manager = {
        is_key_set = function(_) return false end,
    }
    mock_plugins_manager = {
        is_plugin_installed = function(_) return false end,
    }

    mock_models_view = {
        select_model = function(models, callback)
            callback("OpenAI: gpt-3.5-turbo")
        end,
        get_alias = function(name, callback)
            callback("my-alias")
        end,
        select_alias_to_remove = function(aliases, callback)
            callback("alias1")
        end,
        confirm_remove_alias = function(alias, callback)
            callback()
        end,
        get_custom_model_details = function(callback)
            callback({
                model_id = "my-custom-model",
                model_name = "My Custom Model",
                api_base = "http://localhost:8080",
                api_key_name = "custom_key"
            })
        end
    }
    vim.ui.select = function(items, opts, on_choice)
        on_choice("alias1")
    end

    mock_utils = {
        check_llm_installed = function() return true end,
    }

    mock_unified_manager = {
        switch_view = spy.new(function() end)
    }

    -- Load models_manager with mocked dependencies
    package.loaded['llm.models.models_io'] = mock_models_io
    package.loaded['llm.models.custom_openai'] = mock_custom_openai
    package.loaded['llm.keys.keys_manager'] = mock_keys_manager
    package.loaded['llm.plugins.plugins_manager'] = mock_plugins_manager
    package.loaded['llm.models.models_view'] = mock_models_view
    package.loaded['llm.utils'] = mock_utils
    package.loaded['llm.unified_manager'] = mock_unified_manager


    models_manager = require('llm.managers.models_manager')
    models_manager.get_model_info_under_cursor = function()
        return "OpenAI: gpt-3.5-turbo", { model_name = "gpt-3.5-turbo", aliases = { "my-alias" } }
    end

    vim.b = {
        [1] = {
            line_to_model_id = { [1] = "gpt-3.5-turbo" },
            model_data = { ["gpt-3.5-turbo"] = { model_name = "gpt-3.5-turbo", aliases = { "alias1" } } },
        }
    }
    vim.api.nvim_win_get_cursor = function() return {1, 0} end
    vim.notify = function() end
  end)

  after_each(function()
    package.loaded['llm.models.models_io'] = nil
    package.loaded['llm.models.models_manager'] = nil
    package.loaded['llm.models.custom_openai'] = nil
    package.loaded['llm.keys.keys_manager'] = nil
    package.loaded['llm.plugins.plugins_manager'] = nil
    package.loaded['llm.models.models_view'] = nil
    package.loaded['llm.utils'] = nil
    package.loaded['llm.unified_manager'] = nil
    vim.b = nil
    vim.api.nvim_win_get_cursor = nil
    vim.notify = nil
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
  end)

  describe("get_available_models", function()
    it("should return a list of models from the cli", function()
      local models = models_manager.get_available_models()
      assert.are.same({ "gpt-3.5-turbo", "claude-2" }, models)
    end)
  end)

  describe("get_model_aliases", function()
    it("should return a table of aliases from the cli", function()
      local aliases = models_manager.get_model_aliases()
      assert.are.equal({ alias1 = "model1", alias2 = "model2" }, aliases)
    end)
  end)

  describe("set_default_model", function()
    it("should call models_io.set_default_model_in_cli with the correct model name", function()
      models_manager.set_default_model(1)
      assert.spy(mock_models_io.set_default_model_in_cli).was.called_with("gpt-3.5-turbo")
    end)
  end)

  describe("set_alias_for_model_under_cursor", function()
    it("should call set_model_alias with the correct alias and model", function()
        models_manager.set_alias_for_model_under_cursor(1)
        assert.spy(mock_models_io.set_alias_in_cli).was.called_with("my-alias", "gpt-3.5-turbo")
    end)
  end)

  describe("remove_alias_for_model_under_cursor", function()
    it("should call remove_model_alias with the correct alias", function()
        models_manager.remove_alias_for_model_under_cursor(1)
        assert.spy(mock_models_io.remove_alias_in_cli).was.called_with("alias1")
    end)
  end)

  describe("add_custom_openai_model_interactive", function()
    it("should call custom_openai.add_custom_openai_model with the correct details", function()
        models_manager.add_custom_openai_model_interactive(1)
        assert.spy(mock_custom_openai.add_custom_openai_model).was.called_with({
            model_id = "my-custom-model",
            model_name = "My Custom Model",
            api_base = "http://localhost:8080",
            api_key_name = "custom_key"
        })
    end)
  end)
end)
