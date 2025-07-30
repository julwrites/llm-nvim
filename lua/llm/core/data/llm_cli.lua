-- llm/core/data/llm_cli.lua - LLM CLI interaction
-- License: Apache 2.0

local M = {}

local stream = require('llm.core.utils.stream')

function M.run_llm_command(command, on_stdout, on_stderr, on_exit)
    local full_command = 'llm ' .. command
    stream.stream_command(full_command, on_stdout, on_stderr, on_exit)
end

return M
