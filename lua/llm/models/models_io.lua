-- llm/models/models_io.lua - I/O functions for model management
-- License: Apache 2.0

local M = {}

local utils = require('llm.utils')

function M.get_models_from_cli()
    return utils.safe_shell_command("llm models")
end

function M.get_default_model_from_cli()
    return utils.safe_shell_command("llm models default")
end

function M.set_default_model_in_cli(model_name)
    return utils.safe_shell_command(string.format('llm models default %s', model_name))
end

function M.get_aliases_from_cli()
    return utils.safe_shell_command("llm aliases --json")
end

function M.set_alias_in_cli(alias, model)
    return utils.safe_shell_command(string.format('llm aliases set %s %s', alias, model))
end

function M.remove_alias_in_cli(alias)
    local escaped_alias = string.format("'%s'", alias:gsub("'", "'\\''"))
    local cmd = string.format("llm aliases remove %s", escaped_alias)
    return utils.safe_shell_command(cmd)
end

return M
