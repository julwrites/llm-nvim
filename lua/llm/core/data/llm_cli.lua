-- llm/core/data/llm_cli.lua - LLM CLI interaction
-- License: Apache 2.0

local M = {}

local shell = require('llm.core.utils.shell')
local api = require('llm.api') -- Added for streaming

function M.run_llm_command(command, bufnr)
    local full_command_parts = vim.split('llm ' .. command, ' ')

    if bufnr then
        return api.run_llm_command_streamed(full_command_parts, bufnr)
    else
        return shell.safe_shell_command(table.concat(full_command_parts, ' '))
    end
end

return M
