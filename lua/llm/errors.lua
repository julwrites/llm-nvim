-- llm/errors.lua - Centralized error handling system
-- License: Apache 2.0

local M = {}
local config = require('llm.config')
local notify_util = require('llm.core.utils.notify')

-- Error severity levels
M.levels = {
  INFO = 1,
  WARNING = 2,
  ERROR = 3,
  CRITICAL = 4
}

-- Error categories
M.categories = {
  CONFIG = 'config',
  MODEL = 'model',
  PLUGIN = 'plugin',
  KEY = 'key',
  FRAGMENT = 'fragment',
  TEMPLATE = 'template',
  SCHEMA = 'schema',
  INTERNAL = 'internal',
  SHELL = 'shell'
}

-- Format error message
local function format_message(category, message, details)
  return string.format('[%s] %s%s',
    category:upper(),
    message,
    details and ' | '..vim.inspect(details) or '')
end

-- Handle and report error
function M.handle(category, message, details, severity, notify_fn)
  local notify = notify_fn or vim.notify
  severity = severity or M.levels.ERROR
  category = category or M.categories.INTERNAL

  local formatted = format_message(category, message, details)

  -- Log based on severity
  if severity >= M.levels.ERROR then
    notify(formatted, vim.log.levels.ERROR)
  elseif severity == M.levels.WARNING then
    notify(formatted, vim.log.levels.WARN)
  else
    notify(formatted, vim.log.levels.INFO)
  end

  -- Return structured error for programmatic handling
  return {
    category = category,
    message = message,
    details = details,
    severity = severity,
    formatted = formatted
  }
end

-- Create error wrappers for common patterns
function M.wrap(fn, category)
  return function(...)
    local ok, result = pcall(fn, ...)
    if not ok then
      return M.handle(category, result)
    end
    return result
  end
end

-- Shell command specific handler
function M.shell_error(command, code, stdout, stderr)
  local output = stdout
  if stderr and #stderr > 0 then
    output = output .. "\n" .. stderr
  end
  return M.handle(
    'shell',
    string.format('Command failed: %s (exit code %d)', command, code),
    output,
    M.levels.ERROR
  )
end

return M