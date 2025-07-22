-- llm/core/data/llm_cli.lua - LLM CLI interaction
-- License: Apache 2.0

local M = {}

local shell = require('llm.core.utils.shell')

function M.run_llm_command(command)
    local full_command = 'llm ' .. command

    return shell.safe_shell_command(full_command)
end

return M
