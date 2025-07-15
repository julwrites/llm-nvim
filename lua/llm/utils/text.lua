local M = {}

-- Get selected text in visual mode
function M.get_visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local lines = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)

  if #lines == 0 then
    return ""
  end

  -- Handle single line selection
  if #lines == 1 then
    return string.sub(lines[1], start_pos[3], end_pos[3])
  end

  -- Handle multi-line selection
  lines[1] = string.sub(lines[1], start_pos[3])
  lines[#lines] = string.sub(lines[#lines], 1, end_pos[3])

  return table.concat(lines, "\n")
end

-- Escape special pattern characters in a string
-- Simple YAML Parser
-- Parses a subset of YAML (dictionaries, lists, basic scalars) into a Lua table.
-- Handles indentation for structure. Does not support complex types, anchors, etc.
function M.parse_simple_yaml(content)
  local config = require('llm.config')
  local debug_mode = config.get('debug')

  if debug_mode then
    vim.notify("Parsing YAML content", vim.log.levels.DEBUG)
  end

  local lines = {}
  for line in content:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end

  local data = nil -- Can be a table (list) or a map (dictionary)
  local stack = {} -- Stack to keep track of current nesting level and type (list/map)

  local function trim(s)
    return s:match("^%s*(.-)%s*$")
  end

  local function get_indent(line)
    return line:match("^(%s*)"):len()
  end

  local function parse_value(val_str)
    val_str = trim(val_str)
    -- Basic type detection (add more as needed: numbers, booleans)
    if val_str:match('^".*"$') or val_str:match("^'.*'$") then
      return val_str:sub(2, -2) -- Remove quotes
    end
    -- Add number/boolean parsing here if necessary
    return val_str -- Treat as string by default
  end

  for i, line in ipairs(lines) do
    print("Processing line " .. i .. ": " .. line)
    -- Skip empty lines and comments
    if line:match("^%s*$") or line:match("^%s*#") then
      goto continue
    end

    local indent = get_indent(line)
    local content = trim(line)

    -- Adjust stack based on indentation
    while #stack > 0 and indent < stack[#stack].indent do
      table.remove(stack) -- Pop elements with greater indentation
    end

    local current_level = #stack > 0 and stack[#stack] or nil
    local current_data = current_level and current_level.data or nil

    if not data then
        if content:match("^- ") then
            data = {}
            current_data = data
            table.insert(stack, { indent = indent, data = current_data, type = 'list' })
        else
            data = {}
            current_data = data
            table.insert(stack, { indent = indent, data = current_data, type = 'map' })
        end
        current_level = stack[#stack]
    end


    -- Detect list item
    if content:match("^- ") then
      local item_content = content:gsub("^-%s*", "")

        if current_level and current_level.type ~= 'list' then
            local parent_level = stack[#stack-1]
            if parent_level and parent_level.pending_key then
                parent_level.data[parent_level.pending_key] = {}
                current_data = parent_level.data[parent_level.pending_key]
                parent_level.pending_key = nil
                table.insert(stack, { indent = indent, data = current_data, type = 'list' })
                current_level = stack[#stack]
            end
        end

      -- Check for key-value pair within the list item
      local key, value = item_content:match("^([^:]+):%s*(.+)")
      if key then
        local item_map = {}
        item_map[trim(key)] = parse_value(value)
        table.insert(current_data, item_map)
        -- Push this new map onto the stack for potential nested properties
        table.insert(stack, { indent = indent + 2, data = item_map, type = 'map' })
      else
        -- Simple list value
        local simple_value = parse_value(item_content)
        table.insert(current_data, simple_value)
      end

      -- Detect key-value pair
    elseif content:match("^([^:]+):") then
      local key, value = content:match("^([^:]+):%s*(.*)")
      key = trim(key)
      value = trim(value)

        if current_level and current_level.type ~= 'map' then
            local parent_level = stack[#stack-1]
            if parent_level and parent_level.type == 'list' then
                local new_map = {}
                table.insert(parent_level.data, new_map)
                current_data = new_map
                table.insert(stack, { indent = indent, data = current_data, type = 'map' })
                current_level = stack[#stack]
            end
        end

      -- If value is present on the same line
      if value ~= "" then
        current_data[key] = parse_value(value)
      else
        -- Value is likely nested (map or list)
        -- Create a placeholder; next line's indent will determine type
        current_data[key] = nil -- Placeholder
        -- Push this key's context onto the stack, expecting nested data
        table.insert(stack, { indent = indent, data = current_data, type = 'map', pending_key = key })
      end
    end
    ::continue::
  end

  if debug_mode then
    vim.notify("Finished parsing YAML. Result: " .. vim.inspect(data), vim.log.levels.DEBUG)
  end

  return data
end

return M
