local job = require('llm.core.utils.job')
local ui = require('llm.core.utils.ui')

local M = {}

function M.start_chat()
    ui.create_split_buffer()
end

function M.send_prompt()
    local bufnr = vim.api.nvim_get_current_buf()
    local prompt_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local prompt = table.concat(prompt_lines, "\n")

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

    ui.append_to_buffer(bufnr, "--- Prompt ---\n" .. prompt .. "\n")
    ui.append_to_buffer(bufnr, "--- Response ---\n")

    job.run('echo "hello"')
end

return M
