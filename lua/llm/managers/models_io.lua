-- llm/managers/models_io.lua - I/O functions for model management
-- License: Apache 2.0

local M = {}

local llm_cli = require('llm.core.data.llm_cli')

function M.get_models_from_cli()
    return llm_cli.run_llm_command("models list --json")
end

function M.get_default_model_from_cli()
    return llm_cli.run_llm_command("default")
end

function M.set_default_model_in_cli(model_name)
    return llm_cli.run_llm_command(string.format('default %s', model_name))
end

function M.get_aliases_from_cli()
    return llm_cli.run_llm_command("aliases list --json")
end

function M.set_alias_in_cli(alias, model)
    return llm_cli.run_llm_command(string.format('aliases set %s %s', alias, model))
end

function M.remove_alias_in_cli(alias)
    local escaped_alias = string.format("'%s'", alias:gsub("'", "'\\''"))
    local cmd = string.format("aliases remove %s", escaped_alias)
    return llm_cli.run_llm_command(cmd)
end

return M
