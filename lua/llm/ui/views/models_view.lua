-- llm/ui/views/models_view.lua - UI functions for model management
-- License: Apache 2.0

local M = {}

local ui = require('llm.core.utils.ui')
local api = vim.api

function M.select_model(models, callback)
  vim.ui.select(models, {
    prompt = "Select LLM model:",
    format_item = function(item)
      return item.id
    end
  }, callback)
end

function M.get_alias(model_display_name, callback)
    ui.floating_input({ prompt = "Enter alias for model '" .. model_display_name .. "': " }, callback)
end

function M.select_alias_to_remove(aliases, callback)
    vim.ui.select(aliases, {
        prompt = "Select alias to remove:",
        format_item = function(item) return item end
    }, callback)
end

function M.confirm_remove_alias(alias, callback)
    ui.floating_confirm({
        prompt = "Remove alias '" .. alias .. "'?",
        on_confirm = function(choice)
            if choice == "Yes" then
                callback()
            end
        end
    })
end

function M.get_custom_model_details(callback)
    local details = {}
    ui.floating_input({ prompt = "Enter Model ID (e.g., gpt-3.5-turbo-custom):" }, function(model_id)
        if not model_id or model_id == "" then
            vim.notify("Model ID cannot be empty. Aborted.", vim.log.levels.WARN)
            return
        end
        details.model_id = model_id

        ui.floating_input({ prompt = "Enter Model Name (display name, optional):" }, function(model_name)
            details.model_name = (model_name and model_name ~= "") and model_name or nil

            ui.floating_input({ prompt = "Enter API Base URL (optional):" }, function(api_base)
                details.api_base = (api_base and api_base ~= "") and api_base or nil

                ui.floating_input({ prompt = "Enter API Key Name (optional, from keys.json):" }, function(api_key_name)
                    details.api_key_name = (api_key_name and api_key_name ~= "") and api_key_name or nil
                    callback(details)
                end)
            end)
        end)
    end)
end

return M
