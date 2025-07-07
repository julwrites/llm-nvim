-- test/spec/llm/keys/keys_manager_spec.lua
local spy = require('luassert.spy')
local stub = require('luassert.stub')
local match = require('luassert.match') -- For sinon.match like behavior

describe("llm.keys.keys_manager", function()
  local keys_manager
  local mock_utils
  local mock_unified_manager
  local mock_vim_api
  local mock_styles -- for setup_buffer_syntax

  before_each(function()
    -- Initialize _G.vim and _G.vim.b
    _G.vim = _G.vim or {}
    _G.vim.b = _G.vim.b or {}
    _G.vim.b[1] = {} -- Simulate buffer variables for bufnr 1

    mock_utils = {
      floating_input = spy.new(function(opts, on_confirm)
        if opts.prompt:match("custom key name") then on_confirm("test_custom_key_name_from_input")
        elseif opts.prompt:match("API key for") then on_confirm("test_api_value_from_input")
        else on_confirm("generic_input_value")
        end
      end),
      floating_confirm = spy.new(function(opts, on_confirm_wrapper)
        -- Simulate user confirming "Yes"
        if on_confirm_wrapper and type(on_confirm_wrapper) == "function" then
             -- The actual on_confirm passed to floating_confirm is nested in keys_manager
             -- and expects no arguments, or handles the choice string internally.
             -- For this mock, we directly call the provided on_confirm logic.
            local confirm_logic = opts.on_confirm
            if confirm_logic then confirm_logic() end
        end
      end)
    }
    package.loaded['llm.utils'] = mock_utils

    mock_unified_manager = { switch_view = spy.new(function() end) }
    package.loaded['llm.unified_manager'] = mock_unified_manager

    mock_styles = { setup_buffer_syntax = spy.new(function() end) }
    package.loaded['llm.styles'] = mock_styles

    mock_vim_api = {
      nvim_win_get_cursor = spy.new(function() return {1, 0} end),
      nvim_buf_get_lines = spy.new(function() return {""} end), -- Default empty line
      nvim_buf_set_lines = spy.new(function(bufnr, start, end_idx, strict_idx, lines_tbl)
        -- Store lines for assertion if needed, though populate_keys_buffer tests will check vim.b
      end),
      nvim_buf_set_keymap = spy.new(function() end), -- Stub out keymap setting
      nvim_create_buf = spy.new(function() return 1 end), -- Dummy buf id
      nvim_open_win = spy.new(function() return 1 end), -- Dummy win id
      nvim_buf_set_option = spy.new(function() end),
      nvim_win_set_cursor = spy.new(function() end),
      nvim_win_close = spy.new(function() end),
      nvim_get_current_buf = spy.new(function() return 1 end),
      nvim_notify = spy.new(function() end)
    }
    _G.vim.api = mock_vim_api
    _G.vim.fn = { json_decode = spy.new(function() return {} end), json_encode = spy.new(function() return "" end) }


    package.loaded['llm.keys.keys_manager'] = nil
    keys_manager = require('llm.keys.keys_manager')

    spy.on(keys_manager, "set_api_key")
    spy.on(keys_manager, "remove_api_key")
    spy.on(keys_manager, "get_stored_keys") -- Mock this to control inputs for populate_keys_buffer
    -- We will let get_provider_info_under_cursor run its actual implementation as it reads from vim.b
  end)

  after_each(function()
    spy.restore_all()
    package.loaded['llm.utils'] = nil
    package.loaded['llm.unified_manager'] = nil
    package.loaded['llm.keys.keys_manager'] = nil
    package.loaded['llm.styles'] = nil
    _G.vim.api = nil
    _G.vim.b[1] = nil
    _G.vim.fn = nil
  end)

  describe("M.populate_keys_buffer", function()
    it("should display predefined and custom keys, and update buffer variables", function()
      -- Arrange
      keys_manager.get_stored_keys:returns({"openai", "my_custom_key", "anthropic", "another_custom_token"})
      local bufnr = 1
      _G.vim.b[bufnr] = {} -- Ensure clean buffer vars for this test

      -- Act
      keys_manager.populate_keys_buffer(bufnr)

      -- Assert
      -- Check captured lines by nvim_buf_set_lines
      local captured_lines_call = mock_vim_api.nvim_buf_set_lines:get_call(1) -- Assuming it's the first/only call
      assert.is_not_nil(captured_lines_call, "nvim_buf_set_lines was not called")
      local lines_table = captured_lines_call.args[5]

      local lines_str = table.concat(lines_table, "\n")
      assert.string_matches(lines_str, "%[✓%] openai")
      assert.string_matches(lines_str, "%[✓%] anthropic")
      assert.string_matches(lines_str, "## Custom Keys:")
      assert.string_matches(lines_str, "%[✓%] another_custom_token") -- Sorted
      assert.string_matches(lines_str, "%[✓%] my_custom_key")      -- Sorted
      assert.string_not_matches(lines_str, "%[+%].-Add custom key") -- Ensure '+' line is gone
      assert.string_matches(lines_str, "Actions:.*%[A%]dd custom") -- Check for new action help text


      -- Check buffer variables
      local vb = _G.vim.b[bufnr]
      assert.is_true(vb.stored_keys_set["openai"])
      assert.is_true(vb.stored_keys_set["my_custom_key"])
      assert.is_true(vb.stored_keys_set["another_custom_token"])

      assert.is_table(vb.key_data["my_custom_key"])
      assert.is_true(vb.key_data["my_custom_key"].is_set)
      local custom_key_line_num = vb.key_data["my_custom_key"].line
      assert.are.equal("my_custom_key", vb.line_to_provider[custom_key_line_num])

      assert.is_table(vb.key_data["another_custom_token"])
      assert.is_true(vb.key_data["another_custom_token"].is_set)
      local another_custom_key_line_num = vb.key_data["another_custom_token"].line
      assert.are.equal("another_custom_token", vb.line_to_provider[another_custom_key_line_num])
    end)
  end)

  describe("Actions on keys (M.set_key_under_cursor, M.remove_key_under_cursor)", function()
    local bufnr = 1
    local setup_buffer_for_custom_key_action = function(custom_key_name)
        _G.vim.b[bufnr] = {} -- Clear buffer specific vars
        keys_manager.get_stored_keys:returns({custom_key_name, "openai"})
        keys_manager.populate_keys_buffer(bufnr) -- Populate vim.b[bufnr]

        -- Find the line number for the custom key
        local target_line_num = -1
        for line_num, provider_name_in_map in pairs(_G.vim.b[bufnr].line_to_provider) do
            if provider_name_in_map == custom_key_name then
                target_line_num = line_num
                break
            end
        end
        assert(target_line_num > 0, "Custom key '" .. custom_key_name .. "' not found in line_to_provider map after populate.")
        mock_vim_api.nvim_win_get_cursor:returns({target_line_num, 0})
    end

    it("M.set_key_under_cursor: should handle setting (updating) an already listed custom key", function()
      -- Arrange
      local custom_key_to_update = "my_listed_custom_key"
      setup_buffer_for_custom_key_action(custom_key_to_update)

      -- Act
      keys_manager.set_key_under_cursor(bufnr)

      -- Assert
      assert.spy(mock_utils.floating_input).was.called_with(
        match.TableIncluding({ prompt = "Enter API key for " .. custom_key_to_update .. ":" }),
        match.is_function()
      )
      assert.spy(keys_manager.set_api_key).was.called_with(custom_key_to_update, "test_api_value_from_input")
      assert.spy(mock_unified_manager.switch_view).was.called_with("Keys")
    end)

    -- REMOVED: Test for "M.set_key_under_cursor: should handle setting a new custom key via '+' line"
    -- This functionality is now in M.add_new_custom_key_interactive

    it("M.remove_key_under_cursor: should handle removing a custom key", function()
      -- Arrange
      local custom_key_to_remove = "custom_to_delete"
      setup_buffer_for_custom_key_action(custom_key_to_remove)
      keys_manager.remove_api_key:returns(true) -- Simulate successful removal

      -- Act
      keys_manager.remove_key_under_cursor(bufnr)

      -- Assert
      assert.spy(mock_utils.floating_confirm).was.called()
      -- Check prompt of floating_confirm (its first arg is an opts table)
      local confirm_opts = mock_utils.floating_confirm:get_call(1).args[1]
      assert.are.equal("Remove key for '" .. custom_key_to_remove .. "'?", confirm_opts.prompt)

      assert.spy(keys_manager.remove_api_key).was.called_with(custom_key_to_remove)
      assert.spy(mock_unified_manager.switch_view).was.called_with("Keys")
    end)
  end

  describe("M.add_new_custom_key_interactive", function()
    local bufnr = 1

    it("should successfully add a new custom key", function()
      -- Arrange
      local nested_call_count = 0
      mock_utils.floating_input = spy.new(function(opts, on_confirm)
        nested_call_count = nested_call_count + 1
        if nested_call_count == 1 then -- Prompt for name
          on_confirm("new_custom_name")
        elseif nested_call_count == 2 then -- Prompt for value
          on_confirm("new_custom_value")
        end
      end)
      keys_manager.set_api_key:returns(true) -- Simulate successful key setting

      -- Act
      keys_manager.add_new_custom_key_interactive(bufnr)

      -- Assert
      assert.spy(mock_utils.floating_input).was.called(2) -- Both inputs called
      assert.spy(keys_manager.set_api_key).was.called_with("new_custom_name", "new_custom_value")
      assert.spy(mock_unified_manager.switch_view).was.called_with("Keys")
      assert.spy(mock_vim_api.nvim_notify).was.called_with("Successfully set key for 'new_custom_name'", vim.log.levels.INFO, match.is_table())
    end)

    it("should abort if custom key name input is cancelled", function()
      -- Arrange
      mock_utils.floating_input = spy.new(function(opts, on_confirm)
        if opts.prompt:match("custom key name") then
          on_confirm(nil) -- Simulate cancellation
        end
      end)

      -- Act
      keys_manager.add_new_custom_key_interactive(bufnr)

      -- Assert
      assert.spy(mock_utils.floating_input).was.called(1) -- Only first input
      assert.spy(keys_manager.set_api_key).was.not_called()
      assert.spy(mock_unified_manager.switch_view).was.not_called()
      assert.spy(mock_vim_api.nvim_notify).was.called_with("Custom key name cannot be empty. Aborted.", vim.log.levels.WARN, match.is_table())
    end)

    it("should abort if API key value input is cancelled", function()
      -- Arrange
      local nested_call_count = 0
      mock_utils.floating_input = spy.new(function(opts, on_confirm)
        nested_call_count = nested_call_count + 1
        if nested_call_count == 1 then -- Prompt for name
          on_confirm("new_custom_name_for_cancel_value_test")
        elseif nested_call_count == 2 then -- Prompt for value
          on_confirm(nil) -- Simulate cancellation
        end
      end)

      -- Act
      keys_manager.add_new_custom_key_interactive(bufnr)

      -- Assert
      assert.spy(mock_utils.floating_input).was.called(2) -- Both inputs called
      assert.spy(keys_manager.set_api_key).was.not_called()
      assert.spy(mock_unified_manager.switch_view).was.not_called()
      assert.spy(mock_vim_api.nvim_notify).was.called_with("API key value cannot be empty. Aborted.", vim.log.levels.WARN, match.is_table())
    end)

    it("should handle failure when M.set_api_key returns false", function()
      -- Arrange
      local nested_call_count = 0
      mock_utils.floating_input = spy.new(function(opts, on_confirm)
        nested_call_count = nested_call_count + 1
        if nested_call_count == 1 then on_confirm("failed_set_name")
        elseif nested_call_count == 2 then on_confirm("failed_set_value")
        end
      end)
      keys_manager.set_api_key:returns(false) -- Simulate failure

      -- Act
      keys_manager.add_new_custom_key_interactive(bufnr)

      -- Assert
      assert.spy(keys_manager.set_api_key).was.called_with("failed_set_name", "failed_set_value")
      assert.spy(mock_unified_manager.switch_view).was.not_called()
      assert.spy(mock_vim_api.nvim_notify).was.called_with("Failed to set key for 'failed_set_name'. See previous errors for details.", vim.log.levels.ERROR, match.is_table())
    end)
  end)

  describe("M.setup_keys_keymaps", function()
    it("should register an 'A' keymap to call add_new_custom_key_interactive", function()
      -- Arrange
      local bufnr = 1
      local manager_module_name = "llm.keys.keys_manager" -- as in the actual module

      -- Act
      keys_manager.setup_keys_keymaps(bufnr, { __name = manager_module_name }) -- Pass mock manager_module if needed

      -- Assert
      -- Find the call for the 'A' keymap
      local set_keymap_calls = mock_vim_api.nvim_buf_set_keymap:get_calls()
      local found_A_keymap = false
      for _, call in ipairs(set_keymap_calls) do
        if call.args[2] == 'n' and call.args[3] == 'A' then
          found_A_keymap = true
          assert.are.equal(string.format([[<Cmd>lua require('%s').add_new_custom_key_interactive(%d)<CR>]], manager_module_name, bufnr), call.args[4])
          break
        end
      end
      assert.is_true(found_A_keymap, "'A' keymap not registered or not correctly configured.")
    end)
  end)
end)
