-- llm/core/loaders.lua - Data loaders for llm-nvim
-- License: Apache 2.0

local M = {}

local llm_cli = require('llm.core.data.llm_cli')
local cache = require('llm.core.data.cache')

function M.load_models()
    local models_json = llm_cli.run_llm_command('models list --json')
    if models_json then
        local models = vim.fn.json_decode(models_json)
        cache.set('models', models)
    end
end

function M.load_plugins()
    local plugins_json = llm_cli.run_llm_command('plugins list --json')
    if plugins_json then
        local plugins = vim.fn.json_decode(plugins_json)
        cache.set('installed_plugins', plugins)
    end
end

function M.load_available_plugins()
    local plugins_json = llm_cli.run_llm_command('plugins --all --json')
    if plugins_json then
        local plugins = vim.fn.json_decode(plugins_json)
        cache.set('available_plugins', plugins)
    end
end

function M.load_keys()
    local keys_json = llm_cli.run_llm_command('keys list --json')
    if keys_json then
        local keys = vim.fn.json_decode(keys_json)
        cache.set('keys', keys)
    end
end

function M.load_fragments()
    local fragments_json = llm_cli.run_llm_command('fragments list --json')
    if fragments_json then
        local fragments = vim.fn.json_decode(fragments_json)
        cache.set('fragments', fragments)
    end
end

function M.load_templates()
    local templates_json = llm_cli.run_llm_command('templates list --json')
    if templates_json then
        local templates = vim.fn.json_decode(templates_json)
        cache.set('templates', templates)
    end
end

function M.load_schemas()
    local schemas_json = llm_cli.run_llm_command('schemas list --json')
    if schemas_json then
        local schemas = vim.fn.json_decode(schemas_json)
        cache.set('schemas', schemas)
    end
end

function M.load_all()
    M.load_models()
    M.load_plugins()
    M.load_available_plugins()
    M.load_keys()
    M.load_fragments()
    M.load_templates()
    M.load_schemas()
end

return M
