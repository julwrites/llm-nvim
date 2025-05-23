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
    local current_data = current_level and current_level.data or data

    -- Detect list item
    if content:match("^- ") then
      local item_content = content:gsub("^-%s*", "")
      local item_indent = indent + 2 -- Standard YAML list item content indent

      -- Ensure the parent is a list
      if not current_level or current_level.type ~= 'list' then
        -- If data is nil, start a new list at the root
        if data == nil then
          data = {}
          current_data = data
          table.insert(stack, { indent = indent, data = current_data, type = 'list' })
          current_level = stack[#stack]
          -- If parent exists but isn't a list, this might be an error or requires context
          -- For simplicity, we'll assume list items imply a list context
        elseif current_level and current_level.type == 'map' then
          -- This scenario is complex (list inside map without key).
          -- A simple parser might error or make assumptions.
          -- Let's assume the list starts here if the parent is a map.
          -- We need a key for the map though. This logic needs refinement for robust parsing.
          -- For now, let's focus on lists starting at root or nested under keys.
          if debug_mode then vim.notify(
            "YAML Parse Warning: List item found directly under map without key at line " .. i, vim.log.levels.WARN) end
          goto continue    -- Skip this line for now
        end
      end

      -- Check for key-value pair within the list item
      local key, value = item_content:match("^([^:]+):%s*(.+)")
      if key then
        local item_map = {}
        item_map[trim(key)] = parse_value(value)
        table.insert(current_data, item_map)
        -- Push this new map onto the stack for potential nested properties
        table.insert(stack, { indent = item_indent, data = item_map, type = 'map' })
      else
        -- Simple list value
        local simple_value = parse_value(item_content)
        table.insert(current_data, simple_value)
        -- Don't push simple values onto the stack
      end

      -- Detect key-value pair
    elseif content:match("^([^:]+):") then
      local key, value = content:match("^([^:]+):%s*(.*)")
      key = trim(key)
      value = trim(value)

      -- Ensure the parent is a map (or create root map)
      if not current_level or current_level.type ~= 'map' then
        if data == nil then
          data = {}
          current_data = data
          table.insert(stack, { indent = indent, data = current_data, type = 'map' })
          current_level = stack[#stack]
          -- If parent is a list, create a new map for the list item
        elseif current_level and current_level.type == 'list' then
          local new_map = {}
          table.insert(current_data, new_map)    -- Add map to the list
          current_data = new_map                 -- Work within the new map
          -- Replace the list entry on stack with this map? No, push map onto stack.
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
      -- Handle properties indented under a list item's map or a key expecting nested data
    elseif current_level and indent > current_level.indent then
      if current_level.type == 'map' then
        -- Check if it's nested under a key that expects data
        if current_level.pending_key then
          local parent_map = current_level.data
          local pending_key = current_level.pending_key
          -- Determine if nested item is list or map start
          if content:match("^- ") then                       -- Nested list starts
            parent_map[pending_key] = {}
            current_level.data = parent_map[pending_key]     -- Update stack entry's data target
            current_level.type = 'list'                      -- Change type on stack
            current_level.pending_key = nil                  -- Key resolved
            -- Re-process the line now that the list is created
            goto reprocess_line                              -- Need to handle the list item itself
          elseif content:match("^([^:]+):") then             -- Nested map starts
            parent_map[pending_key] = {}
            current_level.data = parent_map[pending_key]     -- Update stack entry's data target
            current_level.type = 'map'                       -- Still a map
            current_level.pending_key = nil                  -- Key resolved
            -- Re-process the line now that the map is created
            goto reprocess_line
          else
            if debug_mode then vim.notify(
              "YAML Parse Warning: Unexpected content under key '" .. pending_key .. "' at line " .. i,
                vim.log.levels.WARN) end
            -- Maybe treat as string continuation? Simple parser won't handle this well.
          end
          -- Handle property indented under a map (e.g., properties of a map within a list)
        elseif content:match("^([^:]+):") then
          local key, value = content:match("^([^:]+):%s*(.*)")
          current_data[trim(key)] = parse_value(value)
        end
      end
    end

    ::reprocess_line::
    ::continue::
  end

  if debug_mode then
    vim.notify("Finished parsing YAML. Result: " .. vim.inspect(data), vim.log.levels.DEBUG)
  end

  return data
end

return M
