-- llm/ui/views/templates_view.lua - UI functions for template management
-- License: Apache 2.0

local M = {}

local ui = require('llm.core.utils.ui')

function M.select_template(templates, callback)
    local template_items = {}

    for _, template in ipairs(templates) do
        table.insert(template_items, template)
    end

    if #template_items == 0 then
        vim.notify("No templates found", vim.log.levels.INFO)
        return
    end

    table.sort(template_items, function(a,b) return a.name < b.name end)

    vim.ui.select(template_items, {
        prompt = "Select a template to run:",
        format_item = function(item)
            return item.name .. " - " .. (item.description or "")
        end
    }, callback)
end

function M.get_user_input(prompt, default, callback)
    ui.floating_input({
        prompt = prompt,
        default = default,
    }, callback)
end

function M.get_input_source(callback)
    vim.ui.select({
        "Current selection",
        "Current buffer",
        "URL (will use curl)"
    }, {
        prompt = "Choose input source:"
    }, callback)
end

function M.get_template_type(callback)
    vim.ui.select({
        "Regular prompt",
        "System prompt only",
        "Both system and regular prompt"
    }, {
        prompt = "Choose template type:"
    }, callback)
end

function M.get_model_choice(callback)
    vim.ui.select({
        "Use default model",
        "Select specific model"
    }, {
        prompt = "Model selection:"
    }, callback)
end

function M.select_model(models, callback)
    vim.ui.select(models, {
        prompt = "Select model for this template:"
    }, callback)
end

function M.get_fragment_choice(callback)
    vim.ui.select({
        "No fragments",
        "Add fragments",
        "Add system fragments"
    }, {
        prompt = "Do you want to add fragments?"
    }, callback)
end

function M.get_add_fragment_choice(callback)
    vim.ui.select({
        "Select from file browser",
        "Enter fragment path/URL",
        "Done adding fragments"
    }, {
        prompt = "Add fragment:"
    }, callback)
end

function M.get_add_system_fragment_choice(callback)
    vim.ui.select({
        "Select from file browser",
        "Enter fragment path/URL",
        "Done adding system fragments"
    }, {
        prompt = "Add system fragment:"
    }, callback)
end

function M.get_option_choice(callback)
    vim.ui.select({
        "No options",
        "Add options"
    }, {
        prompt = "Do you want to add model options (like temperature)?"
    }, callback)
end

function M.confirm_extract(callback)
    ui.floating_confirm({
        prompt = "Extract first code block from response?",
        on_confirm = function(choice)
            callback(choice == "Yes")
        end
    })
end

function M.get_schema_choice(callback)
    vim.ui.select({
        "No schema",
        "Select existing schema"
    }, {
        prompt = "Do you want to add a schema?"
    }, callback)
end

function M.select_schema(schemas, callback)
    local schema_names = {}
    for _, schema in ipairs(schemas) do
        table.insert(schema_names, schema.name)
    end
    table.sort(schema_names)

    if #schema_names == 0 then
        vim.notify("No schemas found", vim.log.levels.INFO)
        callback(nil)
        return
    end

    vim.ui.select(schema_names, {
        prompt = "Select schema:"
    }, callback)
end

function M.confirm_delete(template_name, callback)
    ui.floating_confirm({
        prompt = "Delete template '" .. template_name .. "'?",
        on_confirm = function(choice)
            if choice == "Yes" then
                callback()
            end
        end
    })
end

return M
