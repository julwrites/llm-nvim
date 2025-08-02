local job = require('llm.core.utils.job')
local ui = require('llm.core.utils.ui')
local commands = require('llm.commands')

local M = {}

function M.start_chat()
    ui.create_chat_buffer()
end

function M.send_prompt()
    local bufnr = vim.api.nvim_get_current_buf()
    local prompt_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    -- The first line is the initial prompt, so we skip it.
    table.remove(prompt_lines, 1)
    local prompt = table.concat(prompt_lines, "\n")

    -- Clear the buffer
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

    -- Add the prompt and response sections
    ui.append_to_buffer(bufnr, "--- Prompt ---\n" .. prompt .. "\n")
    ui.append_to_buffer(bufnr, "--- Response ---\n")

    local cmd_parts = { "llm" }
    vim.list_extend(cmd_parts, commands.get_model_arg())
    vim.list_extend(cmd_parts, commands.get_system_arg())
    table.insert(cmd_parts, vim.fn.shellescape(prompt))

    local first_line = true
    local callbacks = {
        on_stdout = function(line)
            if first_line then
                ui.append_to_buffer(bufnr, line)
                first_line = false
            else
                ui.append_to_buffer(bufnr, "\n" .. line)
            end
        end,
        on_stderr = function(line)
            vim.notify("Error from llm: " .. line, vim.log.levels.ERROR)
        end,
        on_exit = function()
            vim.notify("LLM command finished.")
        end,
    }

    job.run(cmd_parts, callbacks)
end

return M
