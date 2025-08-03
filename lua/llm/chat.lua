local api = require('llm.api')
local ui = require('llm.core.utils.ui')
local commands = require('llm.commands')

local M = {}

function M.start_chat()
    local bufnr = ui.create_chat_buffer()
    return bufnr
end

function M.send_prompt()
    vim.notify("DEBUG: send_prompt function called.", vim.log.levels.INFO)
    local bufnr = vim.api.nvim_get_current_buf()
    local prompt_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    -- Extract user prompt (from line 4 onwards)
    local user_prompt_lines = {}
    -- Iterate from the 4th line to the end of the buffer
    for i = 4, #prompt_lines do
        table.insert(user_prompt_lines, prompt_lines[i])
    end
    local prompt = table.concat(user_prompt_lines, "\n")

    -- Clear only the user input area (lines 4 onwards)
    vim.api.nvim_buf_set_lines(bufnr, 3, -1, false, {})

    -- Append the prompt and response sections
    ui.append_to_buffer(bufnr, "--- Prompt ---\n" .. prompt .. "\n")
    ui.append_to_buffer(bufnr, "--- Response ---\n")

    local cmd_parts = { commands.get_llm_executable_path(), "chat" }
    vim.list_extend(cmd_parts, commands.get_model_arg())
    vim.list_extend(cmd_parts, commands.get_system_arg())

    vim.notify("DEBUG: Final command string: " .. table.concat(cmd_parts, " "), vim.log.levels.INFO)

    local job_id = api.run_llm_command_streamed(cmd_parts, bufnr)
    if job_id then
      vim.fn.jobsend(job_id, prompt .. "\n")
    end
end




return M

