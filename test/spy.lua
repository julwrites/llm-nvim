local spy = {}
spy.__index = spy

function spy.on(object, method_name)
  local original_method = object[method_name]
  local s = {
    object = object,
    method_name = method_name,
    original_method = original_method,
    calls = {},
  }

  object[method_name] = function(...)
    table.insert(s.calls, { ... })
    return s.return_value
  end

  return setmetatable(s, spy)
end

function spy:revert()
  self.object[self.method_name] = self.original_method
end

function spy:was_called()
  return #self.calls > 0
end

function spy:was_called_with(...)
  for _, call in ipairs(self.calls) do
    if #call == select('#', ...) then
      local match = true
      for i = 1, #call do
        if call[i] ~= select(i, ...) then
          match = false
          break
        end
      end
      if match then
        return true
      end
    end
  end
  return false
end

function spy:and_return(value)
  self.return_value = value
  return self
end

return spy
