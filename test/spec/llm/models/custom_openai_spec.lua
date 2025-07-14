-- test/spec/llm/models/custom_openai_spec.lua
local spy = require('luassert.spy')
local stub = require('luassert.stub')
local custom_openai -- to be required
local mock_utils
local mock_keys_manager
local mock_config

-- Helper to simulate file content for io.open mock
local mock_file_content = ""
local mock_files_written = {} -- To store what's written
local mock_file_exists_flags = {} -- To simulate if a file exists for io.open "r"
local mock_os_rename_calls = {} -- To track os.rename calls

local MOCK_YAML_PATH = "test_extra_openai_models.yaml"
local MOCK_CONFIG_DIR = "test_config_dir"

describe("llm.models.custom_openai", function()

  before_each(function()
    mock_files_written = {}
    mock_file_content = ""
    mock_file_exists_flags = {}
    mock_os_rename_calls = {}

    mock_utils = {
      get_config_path = spy.new(function(filename)
        if filename == "extra-openai-models.yaml" then
          return MOCK_CONFIG_DIR, MOCK_YAML_PATH
        elseif filename == "extra-openai-models.yaml.sample" then
          return MOCK_CONFIG_DIR, "test_sample.yaml"
        end
        return "mock_dir", "mock_file"
      end),
      parse_simple_yaml = spy.new(function(filepath)
        -- This mock will be overridden in specific tests for more control
        if mock_file_exists_flags[filepath] and mock_file_content and mock_file_content ~= "" then
          -- A very basic YAML list parser for testing purposes
          -- Assumes simple structure like "- model_id: id_value" per line for multiple entries
          -- or direct key-value for single map (which load_custom_openai_models should reject/backup)
          local lines = {}
          for line in mock_file_content:gmatch("[^\r\n]+") do table.insert(lines, line) end

          if mock_file_content:match("^- model_id:") then -- Likely a list
            local items = {}
            local current_item = nil
            for _, line in ipairs(lines) do
              local mid = line:match("^- model_id:%s*(.+)")
              local mn = line:match("^%s*model_name:%s*(.+)")
              -- Add more fields as needed for mock parsing
              if mid then
                if current_item then table.insert(items, current_item) end
                current_item = { model_id = mid }
              elseif current_item and mn then
                current_item.model_name = mn
              end
            end
            if current_item then table.insert(items, current_item) end
            return items
          elseif mock_file_content:match("model_id:") then -- Might be a map
             local item = {}
             local mid = mock_file_content:match("model_id:%s*([%w%-]+)")
             if mid then item.model_id = mid end
             return item -- load_custom_openai_models should detect this is not a list
          end
        end
        return nil
      end)
    }
    package.loaded['llm.utils'] = mock_utils

    mock_keys_manager = {
      is_key_set = spy.new(function(key_name) return true end) -- Assume key is set by default
    }
    package.loaded['llm.keys.keys_manager'] = mock_keys_manager

    mock_config = {
        get = spy.new(function(key)
            if key == 'debug' then return false end -- Default debug to false
            return nil
        end)
    }
    package.loaded['llm.config'] = mock_config

    -- Mock io.open and os.rename
    stub(io, "open", function(filepath, mode)
      if mode == "r" then
        if mock_file_exists_flags[filepath] then
          return {
            read = function() return mock_file_content end,
            lines = function() -- Basic lines iterator for parse_simple_yaml if it uses it
                local lines_tbl = {}
                for line in mock_file_content:gmatch("[^\r\n]+") do table.insert(lines_tbl, line) end
                local i = 0
                return function() i = i + 1; return lines_tbl[i] end
            end,
            close = function() end
          }
        else
          return nil -- File doesn't exist
        end
      elseif mode == "w" then
        return {
          write = function(content_written)
            mock_files_written[filepath] = content_written
          end,
          close = function() end
        }
      else
        return nil -- Fallback for other modes
      end
    end)
    stub(os, "rename", function(oldpath, newpath)
      table.insert(mock_os_rename_calls, {oldpath = oldpath, newpath = newpath})
      mock_file_exists_flags[oldpath] = false -- Simulate file being "moved"
      mock_file_exists_flags[newpath] = true  -- Simulate backup file appearing
      return true
    end)
    stub(os, "time", function() return 123456789 end) -- Consistent timestamp for backup names

    -- Mock vim.fn for json_encode/decode if needed by the module directly
    _G.vim = _G.vim or {}
    _G.vim.fn = _G.vim.fn or {}
    _G.vim.fn.json_encode = spy.new(function(tbl)
        -- Basic JSON encode mock: not fully compliant, for test purposes
        local parts = {}
        for k, v in pairs(tbl) do
            local key_str = '"' .. tostring(k) .. '":'
            local val_str = type(v) == "string" and ('"' .. v .. '"') or tostring(v)
            table.insert(parts, key_str .. val_str)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end)
    _G.vim.fn.json_decode = spy.new(function(str)
        -- Basic JSON decode mock
        if str == '{"X-Test":"HeaderValue"}' then return {["X-Test"] = "HeaderValue"} end
        if str == 'malformed_json_string' then error("decode error") end;
        return {}
    end)
    _G.vim.notify = spy.new(function() end)
    _G.vim.inspect = spy.new(function(val) return type(val) end) -- simple inspect mock

    package.loaded['llm.models.custom_openai'] = nil
    custom_openai = require('llm.models.custom_openai')
  end)

  after_each(function()
    spy.restore_all()
    if io.open.is_stub then io.open:revert() end
    if os.rename.is_stub then os.rename:revert() end
    if os.time.is_stub then os.time:revert() end

    package.loaded['llm.utils'] = nil
    package.loaded['llm.keys.keys_manager'] = nil
    package.loaded['llm.config'] = nil
    package.loaded['llm.models.custom_openai'] = nil
    _G.vim.fn.json_encode = nil
    _G.vim.fn.json_decode = nil
    _G.vim.notify = nil
    _G.vim.inspect = nil
  end)

  describe("M.add_custom_openai_model", function()
    it("should add a new model to a non-existent file", function()
      mock_file_exists_flags[MOCK_YAML_PATH] = false -- File doesn't exist

      local model_details = { model_id = "gpt-custom", model_name = "My Custom GPT", needs_auth = false }
      local success, err = custom_openai.add_custom_openai_model(model_details)

      assert.is_true(success, err)
      assert.is_nil(err)
      local written_content = mock_files_written[MOCK_YAML_PATH]
      assert.truthy(written_content)
      assert.string_matches(written_content, "- model_id: gpt%-custom")
      assert.string_matches(written_content, "  model_name: My Custom GPT")
      assert.string_matches(written_content, "  needs_auth: false")
    end)

    it("should add a new model to an existing file", function()
      mock_file_exists_flags[MOCK_YAML_PATH] = true
      mock_file_content = "- model_id: existing-model\n  api_key_name: existing_key\n"
      -- mock utils.parse_simple_yaml to return the parsed content of mock_file_content
      mock_utils.parse_simple_yaml = spy.new(function()
          return {{model_id = "existing-model", api_key_name = "existing_key"}}
      end)
      package.loaded['llm.utils'] = mock_utils -- re-apply mock
      package.loaded['llm.models.custom_openai'] = nil; custom_openai = require('llm.models.custom_openai')


      local model_details = { model_id = "new-model", supports_functions = true }
      custom_openai.add_custom_openai_model(model_details)

      local written_content = mock_files_written[MOCK_YAML_PATH]
      assert.truthy(written_content)
      assert.string_matches(written_content, "- model_id: existing%-model")
      assert.string_matches(written_content, "- model_id: new%-model")
      assert.string_matches(written_content, "  supports_functions: true")
      -- Default needs_auth=true should NOT be written
      assert.string_not_matches(written_content, "new%-model\n.-needs_auth: true")
    end)

    it("should correctly serialize all fields, omitting defaults", function()
        mock_file_exists_flags[MOCK_YAML_PATH] = false
        local model_details = {
            model_id = "full-model",
            model_name = "Full Model Name",
            api_base = "https://example.com/api",
            api_key_name = "full_model_key",
            headers = { ["X-Custom"] = "TestValue" },
            needs_auth = false,
            supports_functions = true,
            supports_system_prompt = false
        }
        custom_openai.add_custom_openai_model(model_details)
        local written_content = mock_files_written[MOCK_YAML_PATH]
        assert.truthy(written_content)
        assert.string_matches(written_content, "- model_id: full%-model")
        assert.string_matches(written_content, "  model_name: Full Model Name")
        assert.string_matches(written_content, "  api_base: https://example%.com/api")
        assert.string_matches(written_content, "  api_key_name: full_model_key")
        assert.string_matches(written_content, "  headers: '{\"X%-Custom\":\"TestValue\"}'") -- Check for JSON string in YAML
        assert.string_matches(written_content, "  needs_auth: false")
        assert.string_matches(written_content, "  supports_functions: true")
        assert.string_matches(written_content, "  supports_system_prompt: false")
    end)

    it("should backup malformed YAML and start fresh", function()
      mock_file_exists_flags[MOCK_YAML_PATH] = true
      mock_file_content = "this is not a list: { not_a_model_id: true }"
      -- Ensure parse_simple_yaml returns something that is not a list (e.g. a map or nil)
      mock_utils.parse_simple_yaml = spy.new(function() return { not_a_model_id = true } end)
      package.loaded['llm.utils'] = mock_utils
      package.loaded['llm.models.custom_openai'] = nil; custom_openai = require('llm.models.custom_openai')


      local model_details = { model_id = "fresh-start" }
      custom_openai.add_custom_openai_model(model_details)

      assert.spy(os.rename).was.called_with(MOCK_YAML_PATH, MOCK_YAML_PATH .. ".non_list_backup." .. 123456789)
      local written_content = mock_files_written[MOCK_YAML_PATH]
      assert.truthy(written_content)
      assert.string_matches(written_content, "- model_id: fresh%-start")
      assert.string_not_matches(written_content, "this is not a list")
    end)
  end

  describe("M.load_custom_openai_models", function()
    it("should load models with various fields and apply defaults", function()
      mock_file_exists_flags[MOCK_YAML_PATH] = true
      mock_file_content = [[
- model_id: model1
  model_name: Model One
  api_key_name: key1
  supports_functions: true
- model_id: model2
  api_base: http://local/v1
  needs_auth: false
  headers: '{"X-Local": "Enabled"}'
- model_id: model3 # Will use default name, default needs_auth (true), default no functions, default system_prompt (true)
  api_key_name: key3 # Assumed set by mock_keys_manager
]]
      mock_utils.parse_simple_yaml = spy.new(function()
          return {
              {model_id = "model1", model_name="Model One", api_key_name="key1", supports_functions=true},
              {model_id = "model2", api_base="http://local/v1", needs_auth=false, headers='{"X-Local": "Enabled"}'},
              {model_id = "model3", api_key_name="key3"}
          }
      end)
      package.loaded['llm.utils'] = mock_utils
      package.loaded['llm.models.custom_openai'] = nil; custom_openai = require('llm.models.custom_openai')

      local models = custom_openai.load_custom_openai_models()

      assert.is_table(models.model1)
      assert.are.equal("Model One", models.model1.model_name)
      assert.is_true(models.model1.supports_functions)
      assert.is_true(models.model1.needs_auth) -- Default
      assert.is_true(models.model1.is_valid) -- key1 is set by mock

      assert.is_table(models.model2)
      assert.is_false(models.model2.needs_auth)
      assert.is_true(models.model2.is_valid) -- Valid because needs_auth is false
      assert.is_table(models.model2.headers)
      assert.are.equal("Enabled", models.model2.headers["X-Local"])
      assert.is_false(models.model2.supports_functions) -- Default

      assert.is_table(models.model3)
      assert.are.equal("model3", models.model3.model_name) -- Default name
      assert.is_true(models.model3.needs_auth) -- Default
      assert.is_true(models.model3.is_valid) -- key3 is set
    end)

    it("should handle old map format by backing up and returning empty", function()
        mock_file_exists_flags[MOCK_YAML_PATH] = true
        mock_file_content = "old-model-id:\n  model_name: Old Name" -- This is a map
        mock_utils.parse_simple_yaml = spy.new(function() return { ["old-model-id"] = { model_name = "Old Name"} } end)
        package.loaded['llm.utils'] = mock_utils
        package.loaded['llm.models.custom_openai'] = nil; custom_openai = require('llm.models.custom_openai')

        local models = custom_openai.load_custom_openai_models()
        assert.spy(os.rename).was.called_with(MOCK_YAML_PATH, MOCK_YAML_PATH .. ".non_list_backup." .. 123456789)
        assert.is_empty(models)
    end)
  end

  describe("M.is_custom_openai_model_valid", function()
    it("validates model needing auth with key set", function()
      local model_data = { model_id="auth_model", api_key_name="mykey", needs_auth=true }
      mock_keys_manager.is_key_set = spy.new(function(key) return key == "mykey" end)
      package.loaded['llm.keys.keys_manager'] = mock_keys_manager
      package.loaded['llm.models.custom_openai'] = nil; custom_openai = require('llm.models.custom_openai')

      assert.is_true(custom_openai.is_custom_openai_model_valid(model_data))
      assert.is_true(model_data.is_valid)
    end)

    it("invalidates model needing auth with key not set", function()
      local model_data = { model_id="auth_model_no_key", api_key_name="anotherkey", needs_auth=true }
      mock_keys_manager.is_key_set = spy.new(function(key) return false end)
      package.loaded['llm.keys.keys_manager'] = mock_keys_manager
      package.loaded['llm.models.custom_openai'] = nil; custom_openai = require('llm.models.custom_openai')

      assert.is_false(custom_openai.is_custom_openai_model_valid(model_data))
      assert.is_false(model_data.is_valid)
    end)

    it("validates model not needing auth even if key not set", function()
      local model_data = { model_id="no_auth_model", needs_auth=false, api_key_name="optional_key" }
      mock_keys_manager.is_key_set = spy.new(function(key) return false end) -- Key not set
      package.loaded['llm.keys.keys_manager'] = mock_keys_manager
      package.loaded['llm.models.custom_openai'] = nil; custom_openai = require('llm.models.custom_openai')

      assert.is_true(custom_openai.is_custom_openai_model_valid(model_data))
      assert.is_true(model_data.is_valid)
    end)
  end

  describe("M.create_sample_yaml_file", function()
    it("should run without error and attempt to write a file", function()
        mock_file_exists_flags["test_sample.yaml"] = false -- ensure it tries to create
        assert.does_not_error(function() custom_openai.create_sample_yaml_file() end)
        assert.truthy(mock_files_written["test_sample.yaml"]) -- Check that write was attempted
        assert.string_matches(mock_files_written["test_sample.yaml"], "model_id: my%-custom%-gpt4%-turbo")
        assert.string_matches(mock_files_written["test_sample.yaml"], "supports_functions:%s*%(Optional%)")
    end)
  end
end)
