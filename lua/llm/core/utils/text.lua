-- llm/core/utils/text.lua - Text manipulation utilities for llm-nvim
-- License: Apache 2.0

local M = {}

-- Get visual selection
function M.get_visual_selection()
  local _, start_row, start_col, _ = unpack(vim.fn.getpos("'<"))
  local _, end_row, end_col, _ = unpack(vim.fn.getpos("'>"))
  local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)

  if #lines == 0 then
    return ""
  end

  if #lines == 1 then
    return string.sub(lines[1], start_col, end_col)
  end

  local selection = {}
  -- Add the first line, from the start column
  table.insert(selection, string.sub(lines[1], start_col))
  -- Add the lines in between
  for i = 2, #lines - 1 do
    table.insert(selection, lines[i])
  end
  -- Add the last line, up to the end column
  table.insert(selection, string.sub(lines[#lines], 1, end_col))

  return table.concat(selection, "\n")
end

-- Capitalize the first letter of a string
function M.capitalize(s)
  if not s or s == '' then return s end
  return s:sub(1, 1):upper() .. s:sub(2)
end

-- Escape special pattern characters in a string
function M.escape_pattern(s)
  -- Escape these special pattern characters: ^$()%.[]*+-?
  local escaped = string.gsub(s, "[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1")
  return escaped
end

-- Simple YAML Parser
-- Parses a subset of YAML (dictionaries, lists, basic scalars) into a Lua table.
-- Handles indentation for structure. Does not support complex types, anchors, etc.
function M.parse_simple_yaml(filepath)
  local config = require('llm.config')
  local debug_mode = config.get('debug')

  if debug_mode then
    vim.notify("Parsing YAML file: " .. filepath, vim.log.levels.DEBUG)
  end

  local file = io.open(filepath, "r")
  if not file then
    if debug_mode then
      vim.notify("YAML file not found or could not be opened: " .. filepath, vim.log.levels.WARN)
    end
    return nil -- Return nil if file cannot be opened
  end

  local lines = {}
  for line in file:lines() do
    table.insert(lines, line)
  end
  file:close()

  local data = {}
  local stack = { { data = data, indent = -1 } }

  local function trim(s)
    return s:match("^%s*(.-)%s*$")
  end

  for _, line in ipairs(lines) do
    if not line:match("^%s*$") and not line:match("^%s*#") then
      local indent = line:match("^(%s*)"):len()
      local content = trim(line)

      while indent <= stack[#stack].indent do
        table.remove(stack)
      end

      local parent = stack[#stack].data

      local key, val = content:match("([^:]+):%s*(.*)")
      if key then
        key = trim(key)
        val = trim(val)
        if val == "" then
          parent[key] = {}
          table.insert(stack, { data = parent[key], indent = indent })
        else
          parent[key] = val
        end
      else
        local item = content:match("^-%s*(.*)")
        if item then
          table.insert(parent, item)
        end
      end
    end
  end

  return data
end

return M
