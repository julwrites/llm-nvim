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
function M.escape_pattern(text)
  return text:gsub("([%^$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

function M.parse_simple_yaml(file_path)
    local file = io.open(file_path, "r")
    if not file then
        return nil, "File not found"
    end
    local content = file:read("*a")
    file:close()

    local data = {}
    local lines = {}
    for line in content:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    local current_key
    for _, line in ipairs(lines) do
        -- Skip comments and empty lines
        if not line:match("^%s*#") and not line:match("^%s*$") then
            local key, value = line:match("^(%S+):%s*(.*)")
            if key then
                -- It's a key-value pair
                current_key = key
                if value and value ~= "" then
                    data[key] = value
                else
                    data[key] = {}
                end
            else
                -- It's a list item
                local item = line:match("^%s*-%s*(.*)")
                if item and current_key and type(data[current_key]) == "table" then
                    table.insert(data[current_key], item)
                end
            end
        end
    end

    return data
end

return M
