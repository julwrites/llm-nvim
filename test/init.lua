-- Test initialization file for llm-nvim
-- License: Apache 2.0

-- Export test utilities
local M = {}

-- Setup function to be called at the beginning of each test
function M.setup()
  -- Set minimal vim configuration for testing
  vim.opt.runtimepath:append('.')
  vim.opt.runtimepath:append('./test')
  vim.opt.runtimepath:append('./test/plenary.nvim')

  -- Set test environment variable
  vim.env.LLM_NVIM_TEST = "1"

  -- Reset any global variables that might affect tests
  vim.g.llm_model = nil
  vim.g.llm_system_prompt = nil
  vim.g.llm_no_mappings = nil
  vim.g.loaded_llm = nil

  -- Clear any existing mappings
  vim.cmd('mapclear')

  print("Loading plugin...")
  -- Load the plugin
  -- Use pcall to catch any errors during loading
  local ok, err = pcall(function()
    dofile(vim.fn.fnamemodify('./plugin/llm.lua', ':p'))
  end)

  if not ok then
    print("Error loading plugin: " .. tostring(err))
  end
  print("Plugin loaded.")

  -- Make sure the module is loaded and available globally for tests
  print("Loading llm module...")
  _G.llm = require('llm')
  print("llm module loaded.")
end

-- Mock function for llm command execution
function M.mock_llm_command(expected_cmd, return_value)
  -- Store original io.popen and system
  local original_popen = io.popen
  local original_system = vim.fn.system

  -- Mock io.popen
  io.popen = function(cmd)
    -- Only assert if the expected command is provided
    if expected_cmd and expected_cmd ~= "" then
      -- Skip the check for "which llm" command
      if not cmd:match("which llm") then
        assert(cmd:match(expected_cmd),
          string.format("Expected command to match '%s', got '%s'", expected_cmd, cmd))
      end
    end

    return {
      read = function(self, format)
        if format == "*a" then
          return return_value
        end
        return ""
      end,
      close = function() return true end
    }
  end

  -- Mock vim.fn.system
  vim.fn.system = function(cmd)
    -- Only assert if the expected command is provided
    if expected_cmd and expected_cmd ~= "" then
      -- Skip the check for "which llm" command
      if type(cmd) == "string" and not cmd:match("which llm") then
        assert(cmd:match(expected_cmd),
          string.format("Expected command to match '%s', got '%s'", expected_cmd, cmd))
      end
    end
    return return_value
  end

  -- Return cleanup function
  return function()
    io.popen = original_popen
    vim.fn.system = original_system
  end
end

-- Helper function to expose module functions for testing
function M.expose_module_functions(module)
  -- Explicitly set each function in the global scope for testing
  -- Make sure select_model is available in the global scope
  _G.select_model = module.select_model

  -- Set all public functions
  _G.prompt = module.prompt
  _G.prompt_with_selection = module.prompt_with_selection
  _G.explain_code = module.explain_code
  _G.ask_question = module.ask_question
  _G.prompt_with_fragments = module.prompt_with_fragments
  _G.prompt_with_selection_and_fragments = module.prompt_with_selection_and_fragments
  _G.select_model = module.select_model
  _G.manage_models = module.manage_models
  _G.manage_plugins = module.manage_plugins or function() end
  _G.manage_keys = module.manage_keys
  _G.manage_fragments = module.manage_fragments
  _G.select_fragment = module.select_fragment
  _G.manage_templates = module.manage_templates
  _G.select_template = module.select_template
  _G.manage_schemas = module.manage_schemas
  _G.select_schema = module.select_schema
  _G.get_available_models = module.get_available_models

  -- Expose fragment management functions
  if module.get_fragments then
    _G.get_fragments = module.get_fragments
  end
  if module.set_fragment_alias then
    _G.set_fragment_alias = module.set_fragment_alias
  end
  if module.remove_fragment_alias then
    _G.remove_fragment_alias = module.remove_fragment_alias
  end

  -- Expose template management functions
  if module.get_templates then
    _G.get_templates = module.get_templates
  end
  if module.get_template_details then
    _G.get_template_details = module.get_template_details
  end
  if module.create_template then
    _G.create_template = module.create_template
  end
  if module.delete_template then
    _G.delete_template = module.delete_template
  end

  -- Expose schema management functions
  if module.get_schemas then
    _G.get_schemas = module.get_schemas
  end
  if module.get_schema_details then
    _G.get_schema_details = module.get_schema_details
  end
  if module.create_schema then
    _G.create_schema = module.create_schema
  end
  if module.delete_schema then
    _G.delete_schema = module.delete_schema
  end
  if module.dsl_to_schema then
    _G.dsl_to_schema = module.dsl_to_schema
  end

  -- Also expose helper functions that are used in tests
  _G.extract_model_name = _G.extract_model_name or function(model_line)
    -- Extract the actual model name (after the provider type)
    local model_name = model_line:match(": ([^%(]+)")
    if model_name then
      -- Trim whitespace
      model_name = model_name:match("^%s*(.-)%s*$")
      return model_name
    end
    -- Fallback to the first word if the pattern doesn't match
    return model_line:match("^([^%s]+)")
  end

  _G.set_default_model = _G.set_default_model or function(model_name)
    return true -- Mock implementation for testing
  end

  _G.get_installed_plugins = _G.get_installed_plugins or function()
    return { "llm-gguf", "llm-ollama" }
  end

  _G.is_plugin_installed = _G.is_plugin_installed or function(plugin_name)
    return plugin_name == "llm-gguf" or plugin_name == "llm-ollama"
  end

  _G.install_plugin = _G.install_plugin or function(plugin_name)
    return true
  end

  _G.uninstall_plugin = _G.uninstall_plugin or function(plugin_name)
    return true
  end

  -- Fragment management mock functions
  _G.get_fragments = _G.get_fragments or function()
    return {
      { hash = "1234abcd", path = "/path/to/file1.txt",           alias = "file1" },
      { hash = "5678efgh", path = "/path/to/file2.py",            alias = nil },
      { hash = "9012ijkl", path = "https://example.com/resource", alias = nil }
    }
  end

  _G.set_fragment_alias = _G.set_fragment_alias or function(hash, alias)
    return true
  end

  _G.remove_fragment_alias = _G.remove_fragment_alias or function(alias)
    return true
  end

  -- Template management mock functions
  _G.get_templates = _G.get_templates or function()
    return { "explain-code", "summarize", "translate" }
  end

  _G.get_template_details = _G.get_template_details or function(template_name)
    if template_name == "explain-code" then
      return {
        name = "explain-code",
        prompt = "Explain this code: {{input}}",
        system = "You are a helpful coding assistant.",
        schema = {
          properties = {
            input = {
              type = "string",
              description = "The code to explain"
            }
          }
        }
      }
    else
      return {
        name = template_name,
        prompt = "Template prompt for " .. template_name,
        system = "You are a helpful assistant.",
        schema = {
          properties = {
            input = {
              type = "string",
              description = "The input to process"
            }
          }
        }
      }
    end
  end

  _G.create_template = _G.create_template or function(name, prompt, system, schema)
    return true
  end

  _G.delete_template = _G.delete_template or function(name)
    return true
  end

  -- Schema management mock functions
  _G.get_schemas = _G.get_schemas or function()
    return {
      { id = "3b7702e71da3dd791d9e17b76c88730e", summary = "{items: [{name, organization, role}]}", usage = "1 time" },
      { id = "520f7aabb121afd14d0c6c237b39ba2d", summary = "{name, age int, bio}",                  usage = "3 times" }
    }
  end

  _G.get_schema_details = _G.get_schema_details or function(schema_id)
    return {
      id = schema_id,
      schema = [[{
  "type": "object",
  "properties": {
    "name": {
      "type": "string"
    },
    "age": {
      "type": "integer"
    },
    "bio": {
      "type": "string"
    }
  },
  "required": [
    "name",
    "age",
    "bio"
  ]
}]]
    }
  end

  _G.create_schema = _G.create_schema or function(name, schema_content)
    return true
  end

  _G.delete_schema = _G.delete_schema or function(schema_id)
    return true
  end

  _G.dsl_to_schema = _G.dsl_to_schema or function(dsl)
    return [[{
  "type": "object",
  "properties": {
    "name": {
      "type": "string"
    },
    "age": {
      "type": "integer"
    },
    "bio": {
      "type": "string"
    }
  },
  "required": [
    "name",
    "age",
    "bio"
  ]
}]]
  end
end

return M
