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

function M.run_llm_command_async(command, callback)
    local full_command_parts = vim.split('llm ' .. command, ' ')
    local stdout_data = {}
    local stdout_buffer = ""

    api.run_streaming_command(full_command_parts, nil, {
        on_stdout = function(_, data)
            if data and #data > 0 then
                data[1] = stdout_buffer .. (data[1] or "")
                stdout_buffer = table.remove(data)

                for _, line in ipairs(data) do
                    table.insert(stdout_data, line)
                end
            end
        end,
        on_exit = function(_, exit_code)
            if stdout_buffer and stdout_buffer ~= "" then
                table.insert(stdout_data, stdout_buffer)
            end

            if exit_code == 0 then
                callback(table.concat(stdout_data, '\n'))
            else
                callback(nil)
            end
        end
    })
end

return M
