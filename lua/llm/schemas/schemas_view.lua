-- llm/schemas/schemas_view.lua - UI functions for schema management
-- License: Apache 2.0

local M = {}

local utils = require('llm.utils')
local api = vim.api

function M.select_schema(schemas, callback)
  local schema_ids = {}
  local schema_descriptions = {}

  for id, description in pairs(schemas) do
    table.insert(schema_ids, id)
    schema_descriptions[id] = description
  end

  if #schema_ids == 0 then
    vim.notify("No schemas found", vim.log.levels.INFO)
    return
  end

  table.sort(schema_ids)

  vim.ui.select(schema_ids, {
    prompt = "Select a schema to run:",
    format_item = function(item)
      return item .. " - " .. (schema_descriptions[item] or "")
    end
  }, callback)
end

function M.get_schema_type(callback)
  vim.ui.select({
    "Regular schema",
    "Multi schema (array of items)"
  }, {
    prompt = "Schema type:"
  }, callback)
end

function M.get_input_source(callback)
  vim.ui.select({
    "Current buffer",
    "URL (will use curl)",
    "Enter text manually"
  }, {
    prompt = "Choose input source:"
  }, callback)
end

function M.get_url(callback)
  utils.floating_input({
    prompt = "Enter URL:",
    on_confirm = callback,
  })
end

function M.get_schema_name(callback)
  utils.floating_input({
    prompt = "Enter schema name:",
    on_confirm = callback,
  })
end

function M.get_schema_format(callback)
  utils.floating_confirm({
    prompt = "Select schema format:",
    options = { "JSON Schema", "DSL (simplified schema syntax)" },
    on_confirm = callback,
  })
end

function M.get_alias(current_alias, callback)
  local prompt_text = current_alias and "Enter new alias (current: " .. current_alias .. "): " or
      "Enter alias for schema: "
  utils.floating_input({
    prompt = prompt_text,
    default = current_alias or "",
    on_confirm = callback,
  })
end

function M.confirm_delete_alias(alias, callback)
  utils.floating_confirm({
    prompt = "Delete alias '" .. alias .. "'?",
    on_confirm = function(confirmed)
      callback(confirmed)
    end,
  })
end

function M.show_details(schema_id, schema, manager)
  local detail_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(detail_buf, "buftype", "nofile")
  api.nvim_buf_set_option(detail_buf, "bufhidden", "wipe")
  api.nvim_buf_set_option(detail_buf, "swapfile", false)
  api.nvim_buf_set_name(detail_buf, "Schema Details: " .. schema_id)

  local detail_win = utils.create_floating_window(detail_buf, 'LLM Schema Details: ' .. schema_id)

  local lines = { "# Schema: " .. schema_id, "" }
  if schema.name then
    table.insert(lines, "## Name: " .. schema.name); table.insert(lines, "")
  end
  table.insert(lines, "## Schema Definition:"); table.insert(lines, "")
  if schema.content then
    local success, parsed = pcall(vim.fn.json_decode, schema.content)
    if success then
      local formatted_json = vim.fn.json_encode(parsed)
      if formatted_json then
        local indent = "  "
        local current_indent = 0
        local formatted_lines = {}
        for line in formatted_json:gmatch("[^\r\n]+") do
          if line:match("}") or line:match("]") then
            current_indent = math.max(0, current_indent - 1)
          end
          table.insert(formatted_lines, string.rep(indent, current_indent) .. line)
          if line:match("{") or line:match("%[") then
            current_indent = current_indent + 1
          end
        end
        vim.list_extend(lines, formatted_lines)
      else
        for line in schema.content:gmatch("[^\r\n]+") do table.insert(lines, line) end
      end
    else
      for line in schema.content:gmatch("[^\r\n]+") do table.insert(lines, line) end
    end
  else
    table.insert(lines, "No schema content available")
  end
  table.insert(lines, ""); table.insert(lines, "Press [q]uit, [r]un schema, [e]dit schema, [a]dd alias, [d]elete alias")
  api.nvim_buf_set_lines(detail_buf, 0, -1, false, lines)

  local function set_detail_keymap(mode, lhs, rhs)
    api.nvim_buf_set_keymap(detail_buf, mode, lhs, rhs,
      { noremap = true, silent = true })
  end
  set_detail_keymap("n", "q", [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])
  set_detail_keymap("n", "<Esc>", [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]])
  set_detail_keymap("n", "r",
    string.format([[<Cmd>lua require('llm.schemas.schemas_manager').run_schema_from_details('%s')<CR>]], schema_id))
  set_detail_keymap("n", "e",
    string.format([[<Cmd>lua require('llm.schemas.schemas_manager').edit_schema_from_details('%s')<CR>]], schema_id))
  set_detail_keymap("n", "a",
    string.format([[<Cmd>lua require('llm.schemas.schemas_manager').set_alias_from_details('%s')<CR>]], schema_id))
  set_detail_keymap("n", "d",
    string.format([[<Cmd>lua require('llm.schemas.schemas_manager').delete_alias_from_details('%s')<CR>]], schema_id))

  require('llm.styles').setup_buffer_styling(detail_buf)
end

return M
