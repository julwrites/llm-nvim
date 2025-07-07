-- Integration tests for llm-nvim
-- License: Apache 2.0

local test_helpers = require('test.init')

describe('llm-nvim integration', function()
  before_each(test_helpers.setup)
  after_each(test_helpers.teardown)

  it('should open the models manager window', function()
    -- Mock the shell command to return some models
    local shell = require('llm.utils.shell')
    shell.capture_output_and_code = function(cmd)
      if cmd == 'llm models' then
        return 'gpt-4o\nclaude-3-sonnet\n', 0
      end
      return '', 1
    end

    -- Open the models manager
    require('llm.models.models_manager').manage_models()

    -- Check that a floating window is opened
    local wins = vim.api.nvim_list_wins()
    local found_float = false
    for _, win in ipairs(wins) do
      if vim.api.nvim_win_get_config(win).relative ~= '' then
        found_float = true
        -- Check the buffer content
        local buf = vim.api.nvim_win_get_buf(win)
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        assert.are.equal('gpt-4o', lines[1])
        assert.are.equal('claude-3-sonnet', lines[2])
        break
      end
    end
    assert.is_true(found_float, "No floating window found for model manager")
  end)

  it('should send a prompt to the LLM and receive a response', function(done)
    -- Mock the shell command to simulate llm
    local shell = require('llm.utils.shell')
    shell.capture_output_and_code = function(cmd)
      if cmd:match('llm -m gpt-4o') then
        return 'Hello from the mock LLM!', 0
      end
      return '', 1
    end

    -- Set a model
    vim.g.llm_model = 'gpt-4o'

    -- Send a prompt
    require('llm.facade').prompt('Say hi')

    -- Wait for the response to be inserted into the buffer
    vim.defer_fn(function()
      local lines = vim.api.nvim_get_current_buf_get_lines(0, -1, false)
      local found_response = false
      for _, line in ipairs(lines) do
        if line:match('Hello from the mock LLM!') then
          found_response = true
          break
        end
      end
      assert.is_true(found_response, "Response from LLM not found in buffer")
      done()
    end, 500)
  end)
end)
