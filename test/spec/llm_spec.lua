-- test/spec/llm_spec.lua

describe("llm.nvim", function()
  local original_functions = {}

  local function mock_function(tbl, func_name, mock_func)
    original_functions[func_name] = tbl[func_name]
    tbl[func_name] = mock_func
  end

  local function restore_functions()
    for func_name, original_func in pairs(original_functions) do
      if original_func then
        local tbl
        -- Determine which table the function belongs to
        if func_name == "dispatch_command" or func_name == "run_llm_command" or func_name == "create_response_buffer" or func_name == "execute_prompt_async" or func_name == "execute_prompt_with_file" or func_name == "llm_command_and_display_response" or func_name == "get_visual_selection" or func_name == "write_context_to_temp_file" or func_name == "explain_code" then
          tbl = require("llm.commands")
        elseif func_name == "nvim_buf_get_name" then
          tbl = vim.api
        elseif func_name == "tmpname" then
          tbl = os
        elseif func_name == "open" then
          tbl = io
        elseif func_name == "remove" then
          tbl = os
        end
        if tbl then
          tbl[func_name] = original_func
        end
      end
    end
    original_functions = {} -- Clear for the next test
  end

  after_each(function()
    restore_functions()
  end)

  it("should load the main module", function()
    local llm = require("llm")
    assert.is_table(llm)
  end)

  describe(":LLM command", function()
    local commands = require("llm.commands")
    local facade = require("llm.facade")

    it("should call commands.dispatch_command with the correct arguments", function()
      local called_args = {}
      mock_function(commands, "dispatch_command", function(subcmd, ...) 
        called_args = { subcmd, ... }
      end)

      facade.command("file", "test prompt")
      assert.are.same({"file", "test prompt"}, called_args)
    end)

    it("should send a basic prompt to llm and create a response buffer", function()
      local expected_llm_output = "Mocked LLM Response"
      local run_llm_command_called_with
      mock_function(commands, "run_llm_command", function(cmd)
        run_llm_command_called_with = cmd
        return expected_llm_output
      end)

      local create_response_buffer_called_with
      mock_function(commands, "create_response_buffer", function(content)
        create_response_buffer_called_with = content
      end)

      local test_prompt = "Write a short poem about Neovim"
      commands.prompt(test_prompt)

      assert.are.same("llm " .. vim.fn.shellescape(test_prompt), run_llm_command_called_with)
      assert.are.same(expected_llm_output, create_response_buffer_called_with)
    end)

    it("should send current file content with a prompt to llm", function()
      local dummy_filepath = "/path/to/test/file.lua"
      local test_prompt = "Summarize this code"

      local execute_prompt_with_file_called_with = {}
      mock_function(commands, "execute_prompt_with_file", function(buf, prompt, filepath, fragment_paths)
        execute_prompt_with_file_called_with = { buf, prompt, filepath, fragment_paths }
      end)

      mock_function(vim.api, "nvim_buf_get_name", function()
        return dummy_filepath
      end)

      -- Mock execute_prompt_async to immediately call execute_prompt_with_file
      mock_function(commands, "execute_prompt_async", function(source, prompt, filepath, fragment_paths, cleanup_callback)
        commands.execute_prompt_with_file(0, prompt, filepath, fragment_paths)
        if cleanup_callback then cleanup_callback() end
      end)

      commands.prompt_with_current_file(test_prompt)

      assert.are.same(0, execute_prompt_with_file_called_with[1]) -- buf
      assert.are.same(test_prompt, execute_prompt_with_file_called_with[2]) -- prompt
      assert.are.same(dummy_filepath, execute_prompt_with_file_called_with[3]) -- filepath
      assert.are.same(nil, execute_prompt_with_file_called_with[4]) -- fragment_paths (should be nil for this test)
    end)

    it("should send visual selection with a prompt to llm", function()
      local selected_text = "local function hello()\n  print(\"Hello\")\nend"
      local test_prompt = "Refactor this function"
      local dummy_temp_file = "/tmp/nvim_llm_temp_12345.lua"

      local execute_prompt_with_file_called_with = {}
      mock_function(commands, "execute_prompt_with_file", function(buf, prompt, filepath, fragment_paths)
        execute_prompt_with_file_called_with = { buf, prompt, filepath, fragment_paths }
      end)

      mock_function(require("llm.utils"), "get_visual_selection", function()
        return selected_text
      end)

      local file_content_written
      mock_function(commands, "write_context_to_temp_file", function(context)
        file_content_written = context
        return dummy_temp_file
      end)

      local os_remove_called_with
      mock_function(os, "remove", function(filepath)
        os_remove_called_with = filepath
      end)

      -- Mock execute_prompt_async to immediately call execute_prompt_with_file
      mock_function(commands, "execute_prompt_async", function(source, prompt, filepath, fragment_paths, cleanup_callback)
        commands.execute_prompt_with_file(0, prompt, filepath, fragment_paths)
        if cleanup_callback then cleanup_callback() end
      end)

      commands.prompt_with_selection(test_prompt, nil, true) -- true for from_visual_mode

      assert.are.same(selected_text, file_content_written)
      assert.are.same(0, execute_prompt_with_file_called_with[1]) -- buf
      assert.are.same(test_prompt, execute_prompt_with_file_called_with[2]) -- prompt
      assert.are.same(dummy_temp_file, execute_prompt_with_file_called_with[3]) -- filepath
      assert.are.same(nil, execute_prompt_with_file_called_with[4]) -- fragment_paths
      assert.are.same(dummy_temp_file, os_remove_called_with)
    end)

    it("should explain current buffer's code", function()
      local dummy_filepath = "/path/to/test/code.lua"
      local prompt_with_current_file_called_with = {}

      mock_function(commands, "prompt_with_current_file", function(prompt, fragment_paths)
        prompt_with_current_file_called_with = { prompt, fragment_paths }
      end)

      mock_function(vim.api, "nvim_buf_get_name", function()
        return dummy_filepath
      end)

      commands.explain_code()

      assert.are.same("Explain this code", prompt_with_current_file_called_with[1])
      assert.are.same(nil, prompt_with_current_file_called_with[2])
    end)
  end)
end)