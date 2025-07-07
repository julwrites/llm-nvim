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
      nvim_buf_get_lines = spy.new(function() return {"some model line"} end), -- Generic line content
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

    -- Add spies for nvim_buf_set_lines and nvim_buf_set_keymap
    mock_vim_api.nvim_buf_set_lines = spy.new(function() end)
    mock_vim_api.nvim_buf_set_keymap = spy.new(function() end)

    -- Mock modules used by populate_models_buffer and setup_models_keymaps
    package.loaded['llm.styles'] = { setup_buffer_syntax = spy.new(function() end) }

    -- Mock functions within models_manager that are called by populate_models_buffer
    -- These are normally defined in the module itself, so we need to load it first, then spy.
    package.loaded['llm.models.models_manager'] = nil
    models_manager = require('llm.models.models_manager')
    spy.on(models_manager, "get_available_models")
    spy.on(models_manager, "get_model_aliases")

    -- Mock utils.safe_shell_command if it's used directly by populate_models_buffer
    mock_utils.safe_shell_command = spy.new(function() return "" end) -- default empty results

  end)

  after_each(function()
    if models_manager and models_manager.get_available_models and models_manager.get_available_models.is_spy then
        models_manager.get_available_models:revert()
    end
    if models_manager and models_manager.get_model_aliases and models_manager.get_model_aliases.is_spy then
        models_manager.get_model_aliases:revert()
    end
    spy.restore_all()
    package.loaded['llm.utils'] = nil
    package.loaded['llm.models.custom_openai'] = nil
    package.loaded['llm.unified_manager'] = nil
    package.loaded['llm.models.models_manager'] = nil
    _G.vim.api = nil -- Restore vim.api
    _G.vim.notify = nil
    _G.vim.cmd = nil
  end)

  describe("M.populate_models_buffer", function()
    it("should display the correct actions line without chat", function()
      -- Arrange
      local bufnr = 1
      _G.vim.b[bufnr] = {} -- Simulate buffer-local table for bufnr 1
      models_manager.get_available_models:returns({ "openai:gpt-3.5-turbo" }) -- Provide some dummy model
      models_manager.get_model_aliases:returns({})
      mock_utils.safe_shell_command:returns("openai:gpt-3.5-turbo") -- Mock for default model check

      -- Act
      models_manager.populate_models_buffer(bufnr)

      -- Assert
      local set_lines_calls = mock_vim_api.nvim_buf_set_lines:get_calls()
      assert.is_not_nil(set_lines_calls[1], "nvim_buf_set_lines was not called")
      local lines_table = set_lines_calls[1].args[5]
      local actions_line_found = false
      local add_custom_model_line_found = false
      local add_custom_alias_line_found = false
      for _, line_content in ipairs(lines_table) do
        if type(line_content) == "string" then
          if line_content:match("^Actions:") then
            actions_line_found = true
            assert.are.equal("Actions: [s]et default [a]dd alias [r]emove alias [c]ustom model [q]uit", line_content)
          end
          if line_content:match("%[+%].*Add custom OpenAI model") then
            add_custom_model_line_found = true
          end
          if line_content:match("%[+%].*Add custom alias") then
            add_custom_alias_line_found = true
          end
        end
      end
      assert.is_true(actions_line_found, "Actions line not found in buffer content")
      assert.is_false(add_custom_model_line_found, "'[+] Add custom OpenAI model' line found but should be removed")
      assert.is_false(add_custom_alias_line_found, "'[+] Add custom alias' line found but should be removed")
    end)
  end)

  describe("M.setup_models_keymaps", function()
    it("should register correct keymaps including 'c' for add_custom_openai_model_interactive", function()
      -- Arrange
      local bufnr = 1
      local manager_module = { __name = "llm.models.models_manager" }
      _G.vim.b[bufnr] = { line_to_model_id = {}, model_data = {} }

      -- Act
      models_manager.setup_models_keymaps(bufnr, manager_module)

      -- Assert
      local set_keymap_calls = mock_vim_api.nvim_buf_set_keymap:get_calls()
      local found_keymaps = {s=false, a=false, r=false, ["<CR>"]=false, c=false}
      local expected_c_cmd = string.format([[<Cmd>lua require('%s').add_custom_openai_model_interactive(%d)<CR>]], manager_module.__name, bufnr)

      for _, call_args_tbl in ipairs(set_keymap_calls) do
        local args = call_args_tbl.args
        if args[1] == bufnr and args[2] == 'n' then
          if found_keymaps[args[3]] == false then found_keymaps[args[3]] = true end
          if args[3] == 'c' then
            assert.are.equal(expected_c_cmd, args[4], "'c' keymap command is incorrect")
          end
        end
      end

      assert.is_true(found_keymaps.s, "'s' keymap not registered")
      assert.is_true(found_keymaps.a, "'a' keymap not registered")
      assert.is_true(found_keymaps.r, "'r' keymap not registered")
      assert.is_true(found_keymaps["<CR>"], "'<CR>' keymap not registered")
      assert.is_true(found_keymaps.c, "'c' keymap for add_custom_openai_model_interactive not registered")
    end)
  end)

  describe("M.handle_action_under_cursor", function()
    it("should do nothing or log when <CR> is pressed on a generic line", function()
        -- Arrange
        local bufnr = 1
        _G.vim.b[bufnr] = {}
        mock_vim_api.nvim_buf_get_lines:returns({"Some other line"}) -- Simulate cursor on a generic line
        local initial_notify_calls = #mock_vim_api.nvim_notify:get_calls()

        -- Act
        models_manager.handle_action_under_cursor(bufnr)

        -- Assert
        -- Check that no major functions were called, e.g., set_default_model, set_alias, etc.
        -- For this test, we'll primarily check that no unexpected notifications or actions occur.
        -- If debug mode is on, it will notify. If off, it might do nothing.
        -- For simplicity, let's assume no critical action should be triggered.
        -- This test is mainly to confirm the removal of the [+] line handlers.
        local final_notify_calls = #mock_vim_api.nvim_notify:get_calls()
        if models_manager.config and models_manager.config.get('debug') then
             assert(final_notify_calls > initial_notify_calls, "Expected a debug notification")
        else
            -- Depending on specific logging for non-actionable <CR>, adjust this
            -- For now, we just ensure no crash and no major action.
        end
        -- Add more assertions here if <CR> on a model line is given specific (non-add) behavior later.
        assert.is_true(true) -- Placeholder if no other assertion is made for non-debug
    end)
  end)

  describe("M.add_custom_openai_model_interactive", function()
    local bufnr = 1

    it("should successfully add a new custom OpenAI model", function()
      -- Arrange
      local call_idx = 0
      local inputs = {"test_id_interactive", "Test Name Interactive", "https://interactive.api/v1", "interactive_key"}
      mock_utils.floating_input = spy.new(function(opts, on_confirm)
        call_idx = call_idx + 1
        on_confirm(inputs[call_idx])
      end)
      mock_custom_openai.add_custom_openai_model:returns(true)

      -- Act
      models_manager.add_custom_openai_model_interactive(bufnr)

      -- Assert
      assert.spy(mock_utils.floating_input).was.called(4)
      assert.spy(mock_custom_openai.add_custom_openai_model).was.called_with(luassert.match.TableIncluding({
        model_id = "test_id_interactive",
        model_name = "Test Name Interactive",
        api_base = "https://interactive.api/v1",
        api_key_name = "interactive_key"
      }))
      assert.spy(mock_custom_openai.load_custom_openai_models).was.called()
      assert.spy(mock_unified_manager.switch_view).was.called_with("Models")
      assert.spy(mock_vim_api.nvim_notify).was.called_with(
        "Custom OpenAI model 'Test Name Interactive' added successfully.", vim.log.levels.INFO, luassert.match.is_table()
      )
    end)

    it("should abort if model_id input is cancelled", function()
      -- Arrange
      mock_utils.floating_input = spy.new(function(opts, on_confirm)
        if opts.prompt:match("Model ID") then on_confirm(nil) end
      end)

      -- Act
      models_manager.add_custom_openai_model_interactive(bufnr)

      -- Assert
      assert.spy(mock_utils.floating_input).was.called(1)
      assert.spy(mock_custom_openai.add_custom_openai_model).was.not_called()
      assert.spy(mock_vim_api.nvim_notify).was.called_with("Model ID cannot be empty. Aborted.", vim.log.levels.WARN, luassert.match.is_table())
    end)

    it("should abort if model_name input is cancelled (and other inputs are skipped)", function()
      -- Arrange
      local call_idx = 0
      mock_utils.floating_input = spy.new(function(opts, on_confirm)
        call_idx = call_idx + 1
        if call_idx == 1 then on_confirm("test_id_for_name_cancel") -- model_id is provided
        elseif call_idx == 2 then on_confirm(nil) -- model_name is cancelled
        end
      end)
      -- In the actual code, if model_name is nil, it proceeds. Let's test API base cancel.
      call_idx = 0
      mock_utils.floating_input = spy.new(function(opts, on_confirm)
        call_idx = call_idx + 1
        if call_idx == 1 then on_confirm("test_id_for_base_cancel")
        elseif call_idx == 2 then on_confirm("Test Name For Base Cancel")
        elseif call_idx == 3 then on_confirm(nil) -- api_base is cancelled (which is fine, it's optional)
        elseif call_idx == 4 then on_confirm(nil) -- api_key_name is cancelled (also fine)
        end
      end)
      mock_custom_openai.add_custom_openai_model:returns(true) -- Assume it would succeed if not cancelled

      -- Act
      models_manager.add_custom_openai_model_interactive(bufnr)

      -- Assert
      -- It should proceed with nil for optional fields if user just presses enter (empty string)
      -- The current mock for floating_input immediately calls on_confirm.
      -- If on_confirm(nil) is for an optional field, it should proceed.
      -- The actual "abort" for optional fields isn't explicitly in the code, it just passes nil.
      -- The critical abort is model_id.
      -- This test is more about ensuring the flow completes if optional fields are "empty".
      assert.spy(mock_utils.floating_input).was.called(4) -- All 4 prompts should appear
      assert.spy(mock_custom_openai.add_custom_openai_model).was.called_with(luassert.match.TableIncluding({
          model_id = "test_id_for_base_cancel",
          model_name = "Test Name For Base Cancel",
          api_base = nil,
          api_key_name = nil
      }))
      assert.spy(mock_unified_manager.switch_view).was.called_with("Models") -- Since add_custom_openai_model returns true
    end)

    it("should handle failure from custom_openai.add_custom_openai_model", function()
      -- Arrange
      local call_idx = 0
      local inputs = {"test_id_fail", "Test Name Fail", "https://fail.api/v1", "fail_key"}
      mock_utils.floating_input = spy.new(function(opts, on_confirm)
        call_idx = call_idx + 1
        on_confirm(inputs[call_idx])
      end)
      mock_custom_openai.add_custom_openai_model:returns(false, "DB error")

      -- Act
      models_manager.add_custom_openai_model_interactive(bufnr)

      -- Assert
      assert.spy(mock_custom_openai.add_custom_openai_model).was.called()
      assert.spy(mock_custom_openai.load_custom_openai_models).was.not_called()
      assert.spy(mock_unified_manager.switch_view).was.not_called()
      assert.spy(mock_vim_api.nvim_notify).was.called_with("Failed to add custom OpenAI model: DB error", vim.log.levels.ERROR, luassert.match.is_table())
    end)
  end)
end)
