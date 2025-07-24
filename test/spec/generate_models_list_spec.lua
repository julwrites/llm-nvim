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
      get_aliases_from_cli = function() return '{"gpt3": "gpt-3.5-turbo"}', nil end,
    }

    mock_custom_openai = {
        custom_openai_models = {},
        load_custom_openai_models = function() end,
        is_custom_openai_model_valid = function(_) return false end,
    }

    -- Load models_manager with mocked dependencies
    package.loaded['llm.managers.models_io'] = mock_models_io
    package.loaded['llm.managers.custom_openai'] = mock_custom_openai
    package.loaded['llm.ui.unified_manager'] = {
      switch_view = function() end,
    }
    models_manager = require('llm.managers.models_manager')
    models_manager.set_custom_openai(mock_custom_openai)
  end)

  after_each(function()
    package.loaded['llm.models.models_io'] = nil
    package.loaded['llm.models.custom_openai'] = nil
    package.loaded['llm.models.models_manager'] = nil
  end)

  it("should return a list of formatted models", function()
    models_manager.get_available_models = function()
        return { { id = "gpt-3.5-turbo", provider = "OpenAI" }, { id = "claude-2", provider = "Anthropic" } }
    end
    mock_models_io.get_default_model_from_cli = function()
      return "gpt-3.5-turbo", nil
    end
    models_manager.get_model_provider = function(model_id)
        if string.match(model_id, "gpt-3.5-turbo") then
            return "OpenAI"
        elseif string.match(model_id, "claude-2") then
            return "Anthropic"
        end
        return "Unknown"
    end

    local data = models_manager.generate_models_list()

    assert.is_table(data)
    assert.is_table(data.lines)
    assert.is_table(data.line_to_model_id)
    assert.is_table(data.model_data)

    local expected_lines = {
        '# Model Management',
        '',
        'Navigate: [P]lugins [K]eys [F]ragments [T]emplates [S]chemas',
        'Actions: [s]et default [a]dd alias [r]emove alias [c]ustom model [q]uit',
        '──────────────────────────────────────────────────────────────',
        '',
        'Anthropic',
        '─────────',
        '[ ] claude-2',
        '',
        'OpenAI',
        '──────',
        '[✓] gpt-3.5-turbo (aliases: gpt3)',
        '',
        ''
    }

    assert.are.same(expected_lines, data.lines)
  end)
end)
