-- llm/utils/validate.lua - Type validation and conversion utilities
-- License: Apache 2.0

local M = {}

-- Type conversion functions
function M.convert(value, target_type)
  if type(value) == target_type then
    return value
  end

  if target_type == "boolean" then
    if type(value) == "string" then
      return value:lower() == "true"
    elseif type(value) == "number" then
      return value ~= 0
    end
  elseif target_type == "number" then
    if type(value) == "string" then
      return tonumber(value) or 0
    elseif type(value) == "boolean" then
      return value and 1 or 0
    end
  elseif target_type == "string" then
    return tostring(value)
  end

  -- Fallback to default for target type
  if target_type == "boolean" then
    return false
  elseif target_type == "number" then
    return 0
  elseif target_type == "string" then
    return ""
  elseif target_type == "table" then
    return {}
  end

  return nil
end

-- Validate value against type
function M.validate(value, expected_type)
  if expected_type == "any" then
    return true
  end
  
  local actual_type = type(value)
  
  -- Special case for nil which we'll consider valid for all types
  if value == nil then
    return true
  end
  
  -- Handle table type checks
  if expected_type == "table" and actual_type == "table" then
    return true
  end
  
  -- Handle other type matches
  return actual_type == expected_type
end

return M