-- llm/core/loaders.lua - Data loaders for llm-nvim
-- License: Apache 2.0

local M = {}

local llm_cli = require('llm.core.data.llm_cli')
local cache = require('llm.core.data.cache')

function M.load_models()
  
  local models_output = llm_cli.run_llm_command('models list')
  
  if models_output then
    local models = {}
    for line in models_output:gmatch("[^\n]+") do
      if not line:match("^%-%-") and line ~= "" and not line:match("^Models:") and not line:match("^Default:") then
        local provider, model_id = line:match("([^:]+): (.*)")
        if provider and model_id then
          table.insert(models, { provider = provider, id = model_id, name = model_id })
        end
      end
    end
    cache.set('models', models)
  end
  
end

function M.load_available_plugins()
  
  local plugins_output = llm_cli.run_llm_command('plugins --all')
  
  if plugins_output then
    local plugins = {}
    for line in plugins_output:gmatch("[^\n]+") do
      local plugin_name, description = line:match("^(%S+)%s*-%s*(.*)")
      if plugin_name and description then
        table.insert(plugins, { name = plugin_name, description = description })
      end
    end
    cache.set('available_plugins', plugins)
  end
  
end

function M.load_keys()
  
  local keys_output = llm_cli.run_llm_command('keys list')
  
  if keys_output then
    local keys = {}
    for line in keys_output:gmatch("[^\n]+") do
      if line ~= "Stored keys:" and line ~= "------------------" and line ~= "" then
        table.insert(keys, { name = line })
      end
    end
    cache.set('keys', keys)
  end
  
end

function M.load_fragments()
  
  local fragments_output = llm_cli.run_llm_command('fragments list')
  
  if fragments_output then
    local fragments = {}
    local current_fragment = nil
    for line in fragments_output:gmatch("[^\n]+") do
      local hash = line:match("^%s*-%s+hash:%s+([0-9a-f]+)")
      if hash then
        if current_fragment then
          table.insert(fragments, current_fragment)
        end
        current_fragment = { hash = hash, aliases = {}, source = "", content = "", datetime = "" }
      else
        if current_fragment then
          local alias = line:match("^%s+-%s+(.+)")
          if alias then
            table.insert(current_fragment.aliases, alias)
          end
          local source = line:match("^%s+source:%s+(.+)")
          if source then
            current_fragment.source = source
          end
          local content = line:match("^%s+content:%s+(.+)")
          if content then
            current_fragment.content = content
          end
          local datetime = line:match("^%s+datetime:%s+(.+)")
          if datetime then
            current_fragment.datetime = datetime
          end
        end
      end
    end
    if current_fragment then
      table.insert(fragments, current_fragment)
    end
    cache.set('fragments', fragments)
  end
  
end

function M.load_templates()
  
  local templates_output = llm_cli.run_llm_command('templates list')
  
  if templates_output then
    local templates = {}
    for line in templates_output:gmatch("[^\n]+") do
      local name, description = line:match("^(%S+)%s*-%s*(.*)")
      if name and description then
        table.insert(templates, { name = name, description = description })
      end
    end
    cache.set('templates', templates)
  end
  
end

function M.load_schemas()
  
  local schemas_output = llm_cli.run_llm_command('schemas list')
  
  if schemas_output then
    local schemas = {}
    for line in schemas_output:gmatch("[^\n]+") do
      local id, description = line:match("^(%S+)%s*-%s*(.*)")
      if id and description then
        table.insert(schemas, { id = id, description = description })
      end
    end
    cache.set('schemas', schemas)
  end
  
end

function M.load_all()
  M.load_models()
  M.load_available_plugins()
  M.load_keys()
  M.load_fragments()
  M.load_templates()
  M.load_schemas()
end

return M
