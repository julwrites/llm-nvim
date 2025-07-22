-- llm/core/data/llm_cli.lua - LLM CLI interaction
-- License: Apache 2.0

local M = {}

local shell = require('llm.core.utils.shell')

function M.run_llm_command(command)
    local full_command = 'llm ' .. command

    return shell.safe_shell_command(full_command)
end

function M.run_llm_command_async(command, on_exit)
    local full_command = 'llm ' .. command
    shell.run_async_shell_command(full_command, on_exit)
end

return M
