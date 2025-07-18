-- llm/templates/templates_view.lua - UI functions for template management
-- License: Apache 2.0

local M = {}

local utils = require('llm.utils')

function M.select_template(templates, callback)
    local template_names = {}
    local template_descriptions = {}

    for name, description in pairs(templates) do
        table.insert(template_names, name)
        template_descriptions[name] = description
    end

    if #template_names == 0 then
        vim.notify("No templates found", vim.log.levels.INFO)
        return
    end

    table.sort(template_names)

    vim.ui.select(template_names, {
        prompt = "Select a template to run:",
        format_item = function(item)
            return item .. " - " .. (template_descriptions[item] or "")
        end
    }, callback)
end

function M.get_user_input(prompt, default, callback)
    utils.floating_input({
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
    utils.floating_confirm({
        prompt = "Extract first code block from response?",
        options = { "Yes", "No" }
    }, function(choice)
        callback(choice == "Yes")
    end)
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
    for name, _ in pairs(schemas) do
        table.insert(schema_names, name)
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
    utils.floating_confirm({
        prompt = "Delete template '" .. template_name .. "'?",
        on_confirm = callback,
    })
end

return M
