-- test/mocks.lua
-- Centralized mock implementations for llm-nvim tests
-- License: Apache 2.0

local M = {}

-- Mock for the 'llm.utils.shell' module
M.mock_shell = {
  command_exists = function(cmd)
    return true -- Default mock
  end,
  get_last_update_timestamp = function()
    return 0 -- Default mock
  end,
  set_last_update_timestamp = function()
    -- No-op
  end,
  update_llm_cli = function()
    return { success = true, message = "Mocked update success" }
  end,
  capture_output_and_code = function(cmd)
    return "mocked output", 0
  end,
}

-- Mock for the 'llm.config' module
M.mock_config = {
  get = function(key)
    return nil -- Default mock
  end,
}

-- Mock for vim.notify
M.mock_notify = {
  calls = {},
  notify = function(msg, level, opts)
    table.insert(M.mock_notify.calls, { msg = msg, level = level, opts = opts })
  end,
  reset = function()
    M.mock_notify.calls = {}
  end,
  get_messages = function()
    local messages = {}
    for _, call in ipairs(M.mock_notify.calls) do
      table.insert(messages, call.msg)
    end
    return messages
  end,
}

-- Function to apply all mocks
function M.apply_mocks()
  -- Store originals
  M._original_vim_notify = vim.notify
  M._original_shell = require('llm.utils.shell')
  M._original_config = require('llm.config')

  -- Apply mocks
  vim.notify = M.mock_notify.notify
  require('llm.utils.shell').command_exists = M.mock_shell.command_exists
  require('llm.utils.shell').get_last_update_timestamp = M.mock_shell.get_last_update_timestamp
  require('llm.utils.shell').set_last_update_timestamp = M.mock_shell.set_last_update_timestamp
  require('llm.utils.shell').update_llm_cli = M.mock_shell.update_llm_cli
  require('llm.utils.shell').capture_output_and_code = M.mock_shell.capture_output_and_code
  require('llm.config').get = M.mock_config.get
end

-- Function to restore all mocks
function M.restore_mocks()
  vim.notify = M._original_vim_notify
  -- Restore module functions
  local shell = require('llm.utils.shell')
  for k, v in pairs(M._original_shell) do
    shell[k] = v
  end
  local config = require('llm.config')
  for k, v in pairs(M._original_config) do
    config[k] = v
  end

  M.mock_notify.reset()
end

return M
