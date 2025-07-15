-- test/spec/generate_models_list_spec.lua

describe("generate_models_list", function()
  local models_manager
  local mock_models_io
  local mock_custom_openai

  before_each(function()
    -- Mock models_io
    mock_models_io = {
      get_models_from_cli = function() return "", nil end,
      get_default_model_from_cli = function() return "", nil end,
      get_aliases_from_cli = function() return "{}", nil end,
    }

    mock_custom_openai = {
        custom_openai_models = {},
        load_custom_openai_models = function() end,
        is_custom_openai_model_valid = function(_) return false end,
    }

    -- Load models_manager with mocked dependencies
    package.loaded['llm.models.models_io'] = mock_models_io
    package.loaded['llm.models.custom_openai'] = mock_custom_openai
    models_manager = require('llm.models.models_manager')
    models_manager.set_custom_openai(mock_custom_openai)
  end)

  after_each(function()
    package.loaded['llm.models.models_io'] = nil
    package.loaded['llm.models.custom_openai'] = nil
    package.loaded['llm.models.models_manager'] = nil
  end)

  it("should return a list of formatted models", function()
    mock_models_io.get_models_from_cli = function()
      return "OpenAI: gpt-3.5-turbo\nAnthropic: claude-2", nil
    end
    mock_models_io.get_default_model_from_cli = function()
      return "gpt-3.5-turbo", nil
    end

    local data = models_manager.generate_models_list()

    assert.is_table(data)
    assert.is_table(data.lines)
    assert.is_table(data.line_to_model_id)
    assert.is_table(data.model_data)
    local expected_lines = {
        "# Model Management",
        "",
        "Navigate: [P]lugins [K]eys [F]ragments [T]emplates [S]chemas",
        "Actions: [s]et default [a]dd alias [r]emove alias [c]ustom model [q]uit",
        "──────────────────────────────────────────────────────────────",
        "",
        "OpenAI",
        "───",
        "[✓] OpenAI: gpt-3.5-turbo",
        "",
        "Anthropic",
        "─────────",
        "[ ] Anthropic: claude-2",
        "",
        ""
    }
    for _, expected_line in ipairs(expected_lines) do
        local found = false
        for _, actual_line in ipairs(data.lines) do
            if actual_line == expected_line then
                found = true
                break
            end
        end
        assert.is_true(found, "Expected line not found: " .. expected_line)
    end
  end)
end)
