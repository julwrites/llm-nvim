-- llm/init.lua - Entry point for lazy.nvim integration
-- License: Apache 2.0

-- Create module
local M = {}

-- Set up the module
local api = vim.api
local fn = vim.fn

-- Forward declaration of config module
local config

-- Check if llm is installed
local function check_llm_installed()
  local handle = io.popen("which llm 2>/dev/null")
  local result = handle:read("*a")
  handle:close()
  
  if result == "" then
    api.nvim_err_writeln("llm CLI tool not found. Please install it with 'pip install llm' or 'brew install llm'")
    return false
  end
  return true
end
-- Expose for testing
_G.check_llm_installed = check_llm_installed

-- Get available models from llm CLI
function M.get_available_models()
  if not check_llm_installed() then
    return {}
  end
  
  local handle = io.popen("llm models")
  local result = handle:read("*a")
  handle:close()
  
  local models = {}
  for line in result:gmatch("[^\r\n]+") do
    -- Skip header lines and empty lines
    if not line:match("^%-%-") and line ~= "" and not line:match("^Models:") then
      -- Extract model name (first column) and provider (second column)
      local model, provider = line:match("^([^%s]+)%s+(.+)")
      if model and provider then
        table.insert(models, model)
      end
    end
  end
  
  return models
end
-- Expose for testing
_G.get_available_models = function()
  return M.get_available_models()
end

-- Get the model argument if specified
local function get_model_arg()
  local model = config.get("model")
  if model and model ~= "" then
    return "-m " .. model
  end
  return ""
end
-- Expose for testing
_G.get_model_arg = get_model_arg

-- Get the system prompt argument if specified
local function get_system_arg()
  local system = config.get("system_prompt")
  if system ~= "" then
    return "-s \"" .. system .. "\""
  end
  return ""
end
-- Expose for testing
_G.get_system_arg = get_system_arg

-- Run an llm command and return the result
local function run_llm_command(cmd)
  if not check_llm_installed() then
    return ""
  end
  
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  handle:close()
  
  return result
end
-- Expose for testing
_G.run_llm_command = run_llm_command

-- Create a new buffer with the LLM response
local function create_response_buffer(content)
  -- Create a new split
  api.nvim_command('new')
  local buf = api.nvim_get_current_buf()
  
  -- Set buffer options
  api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(buf, 'swapfile', false)
  api.nvim_buf_set_name(buf, 'LLM Response')
  
  -- Set the content
  local lines = {}
  for line in content:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  
  -- Set filetype for syntax highlighting
  api.nvim_buf_set_option(buf, 'filetype', 'markdown')
  
  return buf
end

-- Get selected text in visual mode
local function get_visual_selection()
  local start_pos = fn.getpos("'<")
  local end_pos = fn.getpos("'>")
  local lines = api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)
  
  if #lines == 0 then
    return ""
  end
  
  -- Handle single line selection
  if #lines == 1 then
    return string.sub(lines[1], start_pos[3], end_pos[3])
  end
  
  -- Handle multi-line selection
  lines[1] = string.sub(lines[1], start_pos[3])
  lines[#lines] = string.sub(lines[#lines], 1, end_pos[3])
  
  return table.concat(lines, "\n")
end

-- Send a prompt to llm
function M.prompt(prompt)
  local model_arg = get_model_arg()
  local system_arg = get_system_arg()
  
  local cmd = string.format('llm %s %s "%s"', model_arg, system_arg, prompt)
  local result = run_llm_command(cmd)
  
  create_response_buffer(result)
end

-- Send selected text with a prompt to llm
function M.prompt_with_selection(prompt)
  local selection = get_visual_selection()
  if selection == "" then
    api.nvim_err_writeln("No text selected")
    return
  end
  
  -- Create a temporary file with the selection
  local temp_file = os.tmpname()
  local file = io.open(temp_file, "w")
  file:write(selection)
  file:close()
  
  local model_arg = get_model_arg()
  local system_arg = get_system_arg()
  local prompt_arg = prompt ~= "" and '"' .. prompt .. '"' or ""
  
  local cmd = string.format('cat %s | llm %s %s %s', temp_file, model_arg, system_arg, prompt_arg)
  local result = run_llm_command(cmd)
  
  -- Clean up temp file
  os.remove(temp_file)
  
  create_response_buffer(result)
end

-- Explain the current buffer or selection
function M.explain_code()
  local current_buf = api.nvim_get_current_buf()
  local lines = api.nvim_buf_get_lines(current_buf, 0, -1, false)
  local content = table.concat(lines, "\n")
  
  -- Create a temporary file with the content
  local temp_file = os.tmpname()
  local file = io.open(temp_file, "w")
  file:write(content)
  file:close()
  
  local model_arg = get_model_arg()
  local cmd = string.format('cat %s | llm %s -s "Explain this code"', temp_file, model_arg)
  local result = run_llm_command(cmd)
  
  -- Clean up temp file
  os.remove(temp_file)
  
  create_response_buffer(result)
end

-- Start a chat session with llm
function M.start_chat(model_override)
  if not check_llm_installed() then
    return
  end
  
  local model = model_override or config.get("model") or ""
  local model_arg = model ~= "" and "-m " .. model or ""
  
  -- Create a terminal buffer
  api.nvim_command('new')
  api.nvim_command('terminal llm chat ' .. model_arg)
  api.nvim_command('startinsert')
end

-- Select a model from available models
function M.select_model()
  if not check_llm_installed() then
    return
  end
  
  local models = get_available_models()
  if #models == 0 then
    api.nvim_err_writeln("No models found. Make sure llm is properly configured.")
    return
  end
  
  -- Check if we have telescope
  local has_telescope, telescope = pcall(require, "telescope.builtin")
  if has_telescope then
    -- Use telescope for selection
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    
    pickers.new({}, {
      prompt_title = "Select LLM Model",
      finder = finders.new_table({
        results = models
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry(prompt_bufnr)
          actions.close(prompt_bufnr)
          
          if selection then
            -- Update the model in config
            config.options.model = selection[1]
            vim.notify("Model set to: " .. selection[1], vim.log.levels.INFO)
          end
        end)
        return true
      end,
    }):find()
  else
    -- Fallback to vim.ui.select if available (Neovim 0.6+)
    if vim.ui and vim.ui.select then
      vim.ui.select(models, {
        prompt = "Select LLM Model:",
        format_item = function(item)
          return item
        end,
      }, function(model)
        if model then
          -- Update the model in config
          config.options.model = model
          vim.notify("Model set to: " .. model, vim.log.levels.INFO)
        end
      end)
    else
      -- Very basic fallback using inputlist
      local options = {"Select a model:"}
      for i, model in ipairs(models) do
        table.insert(options, i .. ": " .. model)
      end
      
      local choice = vim.fn.inputlist(options)
      if choice >= 1 and choice <= #models then
        local model = models[choice]
        config.options.model = model
        vim.notify("Model set to: " .. model, vim.log.levels.INFO)
      end
    end
  end
end

-- Setup function for configuration
function M.setup(opts)
  -- Load the configuration module
  config = require('llm.config')
  config.setup(opts)
  return M
end

-- Initialize with default configuration
config = require('llm.config')
config.setup()

return M
