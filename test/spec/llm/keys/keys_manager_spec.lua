-- test/spec/llm/keys/keys_manager_spec.lua
local spy = require('luassert.spy')
local stub = require('luassert.stub')

describe("llm.keys.keys_manager", function()
  local keys_manager
  local mock_utils
  local mock_unified_manager
  local mock_api

  before_each(function()
    -- Mock dependencies
    mock_utils = {
      floating_input = spy.new(function(opts, on_confirm)
        -- Simulate immediate confirmation with predefined input
        if opts.prompt:match("custom key name") then
          on_confirm("test_custom_key")
        elseif opts.prompt:match("API key for") then
          on_confirm("test_api_value")
        end
      end)
    }
    package.loaded['llm.utils'] = mock_utils

    mock_unified_manager = {
      switch_view = spy.new(function() end)
    }
    package.loaded['llm.unified_manager'] = mock_unified_manager

    -- Mock vim.api for bufnr context if needed, though not directly used by set_key_under_cursor logic itself
    mock_api = {
      nvim_win_get_cursor = spy.new(function() return {1, 0} end), -- {row, col}
      nvim_buf_get_lines = spy.new(function() return {"[+] Add custom key"} end) -- Simulate line content
    }
    -- Replace actual vim.api if necessary, or ensure it's not called in a problematic way
    -- For this test, we primarily rely on get_provider_info_under_cursor being mocked or controlled

    -- Re-require the module under test to use mocked dependencies
    package.loaded['llm.keys.keys_manager'] = nil
    keys_manager = require('llm.keys.keys_manager')

    -- Spy on functions within keys_manager itself that are called by the tested function
    spy.on(keys_manager, "set_api_key")
    spy.on(keys_manager, "get_provider_info_under_cursor")
  end)

  after_each(function()
    spy.restore_all()
    package.loaded['llm.utils'] = nil
    package.loaded['llm.unified_manager'] = nil
    package.loaded['llm.keys.keys_manager'] = nil
  end)

  describe("M.set_key_under_cursor", function()
    it("should handle setting a predefined provider key", function()
      -- Arrange
      keys_manager.get_provider_info_under_cursor:returns("openai") -- Simulate cursor on 'openai'
      local bufnr = 1 -- Dummy bufnr

      -- Act
      keys_manager.set_key_under_cursor(bufnr)

      -- Assert
      -- Check that floating_input was called for the key value
      assert.spy(mock_utils.floating_input).was.called_with(
        sinon.match({ prompt = "Enter API key for openai:" }),
        sinon.match.func
      )
      -- Check that set_api_key was called with the correct arguments
      assert.spy(keys_manager.set_api_key).was.called_with("openai", "test_api_value")
      -- Check that the view was refreshed
      assert.spy(mock_unified_manager.switch_view).was.called_with("Keys")
    end)

    it("should handle setting a custom key", function()
      -- Arrange
      keys_manager.get_provider_info_under_cursor:returns("+") -- Simulate cursor on 'Add custom key'
      local bufnr = 1 -- Dummy bufnr

      -- Act
      keys_manager.set_key_under_cursor(bufnr)

      -- Assert
      -- Check that floating_input was called first for the custom key name
      assert.spy(mock_utils.floating_input).was.called_with(
        sinon.match({ prompt = "Enter custom key name:" }),
        sinon.match.func
      )
      -- Check that floating_input was called second for the API key value
      assert.spy(mock_utils.floating_input).was.called_with(
        sinon.match({ prompt = "Enter API key for test_custom_key:" }),
        sinon.match.func
      )
      -- Check that set_api_key was called with the custom name and value
      assert.spy(keys_manager.set_api_key).was.called_with("test_custom_key", "test_api_value")
      -- Check that the view was refreshed
      assert.spy(mock_unified_manager.switch_view).was.called_with("Keys")
    end)

    it("should do nothing if provider_name_or_action is nil", function()
      -- Arrange
      keys_manager.get_provider_info_under_cursor:returns(nil)
      local bufnr = 1

      -- Act
      keys_manager.set_key_under_cursor(bufnr)

      -- Assert
      assert.spy(mock_utils.floating_input).was.not_called()
      assert.spy(keys_manager.set_api_key).was.not_called()
      assert.spy(mock_unified_manager.switch_view).was.not_called()
    end)

    it("should handle cancellation of first input for custom key", function()
      -- Arrange
      mock_utils.floating_input = spy.new(function(opts, on_confirm)
        if opts.prompt:match("custom key name") then
          on_confirm(nil) -- Simulate user cancelling or entering nothing
        end
      end)
      package.loaded['llm.utils'] = mock_utils -- Re-apply mock
      package.loaded['llm.keys.keys_manager'] = nil
      keys_manager = require('llm.keys.keys_manager')
      spy.on(keys_manager, "set_api_key") -- Re-spy after re-require
      spy.on(keys_manager, "get_provider_info_under_cursor")
      keys_manager.get_provider_info_under_cursor:returns("+")

      -- Act
      keys_manager.set_key_under_cursor(1)

      -- Assert
      assert.spy(mock_utils.floating_input).was.called(1) -- Only the first input
      assert.spy(keys_manager.set_api_key).was.not_called()
      assert.spy(mock_unified_manager.switch_view).was.not_called()
    end)

    it("should handle cancellation of second input for custom key", function()
      -- Arrange
      local call_count = 0
      mock_utils.floating_input = spy.new(function(opts, on_confirm)
        call_count = call_count + 1
        if call_count == 1 then -- Custom key name
          on_confirm("my_custom_key_for_cancel_test")
        elseif call_count == 2 then -- API key value
          on_confirm(nil) -- Simulate user cancelling
        end
      end)
      package.loaded['llm.utils'] = mock_utils -- Re-apply mock
      package.loaded['llm.keys.keys_manager'] = nil
      keys_manager = require('llm.keys.keys_manager')
      spy.on(keys_manager, "set_api_key")
      spy.on(keys_manager, "get_provider_info_under_cursor")
      keys_manager.get_provider_info_under_cursor:returns("+")

      -- Act
      keys_manager.set_key_under_cursor(1)

      -- Assert
      assert.spy(mock_utils.floating_input).was.called(2) -- Both inputs
      assert.spy(keys_manager.set_api_key).was.not_called()
      assert.spy(mock_unified_manager.switch_view).was.not_called()
    end)
  end
end)
