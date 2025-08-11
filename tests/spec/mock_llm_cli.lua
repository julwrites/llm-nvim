local M = {}

function M.get_llm_executable_path()
    return "/usr/bin/llm"
end

function M.run_llm_command(command)
    if command == 'schemas list --json' then
        return '[]'
    end
    return ''
end

return M
