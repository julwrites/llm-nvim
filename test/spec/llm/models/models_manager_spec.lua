-- test/spec/llm/models/models_manager_spec.lua
local spy = require('luassert.spy')
local stub = require('luassert.stub')

describe("llm.models.models_manager", function()
  local models_manager
  local mock_utils
  local mock_custom_openai
  local mock_unified_manager
  local mock_vim_api

  before_each(function()
    mock_utils = {
      floating_input = spy.new(function(opts, on_confirm)
        -- Simulate user input based on prompt
        if opts.prompt:match("Model ID") then on_confirm("test_model_id")
        elseif opts.prompt:match("Model Name") then on_confirm("Test Model Name")
        elseif opts.prompt:match("API Base URL") then on_confirm("https://api.example.com/v1")
        elseif opts.prompt:match("API Key Name") then on_confirm("test_api_key")
        elseif opts.prompt:match("Custom Headers.*JSON") then on_confirm('{"X-Test": "HeaderValue"}')
        elseif opts.prompt:match("Needs Authentication") then on_confirm("true")
        elseif opts.prompt:match("Supports Functions") then on_confirm("true")
        elseif opts.prompt:match("Supports System Prompt") then on_confirm("false")
        else on_confirm("some_default_value") -- Fallback for other inputs
        end
      end)
    }
    package.loaded['llm.utils'] = mock_utils

    mock_custom_openai = {
      add_custom_openai_model = spy.new(function() return true end), -- Simulate success
      load_custom_openai_models = spy.new(function() end)
    }
    package.loaded['llm.models.custom_openai'] = mock_custom_openai

    mock_unified_manager = {
      switch_view = spy.new(function() end)
    }
    package.loaded['llm.unified_manager'] = mock_unified_manager

    mock_vim_api = {
      nvim_win_get_cursor = spy.new(function() return {1,0} end),
      nvim_buf_get_lines = spy.new(function() return {"[+] Add custom OpenAI model"} end),
      nvim_get_current_win = spy.new(function() return 1 end), -- Dummy window ID
      nvim_win_is_valid = spy.new(function() return true end),
      nvim_set_current_win = spy.new(function() end),
      nvim_notify = spy.new(function() end) -- Stub out notifications
    }
    -- Stub global vim.api
    _G.vim = _G.vim or {}
    _G.vim.api = mock_vim_api
    _G.vim.notify = mock_vim_api.nvim_notify -- Also common to stub directly
    _G.vim.cmd = spy.new(function() end) -- Stub vim.cmd

    package.loaded['llm.models.models_manager'] = nil
    models_manager = require('llm.models.models_manager')
  end)

  after_each(function()
    spy.restore_all()
    package.loaded['llm.utils'] = nil
    package.loaded['llm.models.custom_openai'] = nil
    package.loaded['llm.unified_manager'] = nil
    package.loaded['llm.models.models_manager'] = nil
    _G.vim.api = nil -- Restore vim.api
    _G.vim.notify = nil
    _G.vim.cmd = nil
  end)

  describe("M.handle_action_under_cursor for Add Custom OpenAI Model", function()
    it("should correctly process all inputs and call custom_openai functions", function()
      -- Arrange
      local bufnr = 1 -- Dummy bufnr
      -- Simulate cursor being on the "[+] Add custom OpenAI model" line (done in before_each mock_vim_api)

      -- Act
      models_manager.handle_action_under_cursor(bufnr)

      -- Assert
      -- Check floating_input calls (simplified check for sequence)
      assert.spy(mock_utils.floating_input).was.called_with(sinon.match({prompt = "Enter Model ID (e.g., gpt-3.5-turbo-custom):"}), sinon.match.func)
      assert.spy(mock_utils.floating_input).was.called_with(sinon.match({prompt = "Enter Model Name (display name, e.g., My Custom GPT-3.5):"}), sinon.match.func)
      assert.spy(mock_utils.floating_input).was.called_with(sinon.match({prompt = "Enter API Base URL (optional, press Enter to skip):"}), sinon.match.func)
      assert.spy(mock_utils.floating_input).was.called_with(sinon.match({prompt = "Enter API Key Name (optional, e.g., MY_CUSTOM_KEY, press Enter to skip):"}), sinon.match.func)
      -- Add more specific checks for the new fields if the mock_utils.floating_input is made more sophisticated
      -- For now, we rely on the order and the final call to add_custom_openai_model

      -- Check that add_custom_openai_model was called with the correct arguments
      local expected_model_details = {
        model_id = "test_model_id",
        model_name = "Test Model Name",
        api_base = "https://api.example.com/v1",
        api_key_name = "test_api_key",
        -- The mock for floating_input needs to be more granular to test these accurately
        -- For now, this part of the test assumes the values are passed through.
        -- In a real scenario, the floating_input mock would need to simulate different inputs for each prompt.
        -- For the purpose of this generation, we'll assume they are passed as mocked.
        headers = '{"X-Test": "HeaderValue"}', -- Assuming floating_input for headers provides this
        needs_auth = true,                     -- Assuming floating_input provides "true" converted to boolean
        supports_functions = true,             -- Assuming "true" converted to boolean
        supports_system_prompt = false         -- Assuming "false" converted to boolean
      }
      assert.spy(mock_custom_openai.add_custom_openai_model).was.called_with(sinon.match(expected_model_details))

      -- Check that load_custom_openai_models was called
      assert.spy(mock_custom_openai.load_custom_openai_models).was.called()

      -- Check that the view was refreshed
      assert.spy(mock_unified_manager.switch_view).was.called_with("Models")
    end)

    it("should abort if model_id is not provided", function()
      -- Arrange
      mock_utils.floating_input = spy.new(function(opts, on_confirm)
        if opts.prompt:match("Model ID") then
          on_confirm(nil) -- Simulate user providing no model_id
        end
      end)
      package.loaded['llm.utils'] = mock_utils -- Re-apply mock
      package.loaded['llm.models.models_manager'] = nil
      models_manager = require('llm.models.models_manager') -- Re-require

      local bufnr = 1

      -- Act
      models_manager.handle_action_under_cursor(bufnr)

      -- Assert
      assert.spy(mock_utils.floating_input).was.called(1) -- Only the first input for model_id
      assert.spy(mock_custom_openai.add_custom_openai_model).was.not_called()
      assert.spy(mock_custom_openai.load_custom_openai_models).was.not_called()
      assert.spy(mock_unified_manager.switch_view).was.not_called()
      assert.spy(mock_vim_api.nvim_notify).was.called_with("Model ID cannot be empty.", vim.log.levels.WARN, sinon.match.any)
    end)

    it("should handle failure from add_custom_openai_model", function()
        -- Arrange
        mock_custom_openai.add_custom_openai_model = spy.new(function() return false, "Simulated error" end)
        package.loaded['llm.models.custom_openai'] = mock_custom_openai
        package.loaded['llm.models.models_manager'] = nil
        models_manager = require('llm.models.models_manager') -- Re-require

        local bufnr = 1

        -- Act
        models_manager.handle_action_under_cursor(bufnr)

        -- Assert
        assert.spy(mock_custom_openai.add_custom_openai_model).was.called()
        assert.spy(mock_custom_openai.load_custom_openai_models).was.not_called()
        assert.spy(mock_unified_manager.switch_view).was.not_called()
        assert.spy(mock_vim_api.nvim_notify).was.called_with("Failed to add custom OpenAI model: Simulated error", vim.log.levels.ERROR, sinon.match.any)
    end)

  end
end)
