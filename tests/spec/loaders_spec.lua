-- tests/spec/core/loaders_spec.lua
--
-- Unit tests for the loaders module.
-- License: Apache 2.0

describe('llm.core.loaders', function()
  describe('load_models()', function()
    it('should parse model list and set cache', function()
      -- Arrange
      local mock_llm_cli = {
        run_llm_command = spy.new(function()
          return [[
openai: gpt-4
openai: gpt-3.5-turbo
]]
        end),
      }
      local mock_cache = {
        set = spy.new(function() end),
      }
      package.loaded['llm.core.data.llm_cli'] = mock_llm_cli
      package.loaded['llm.core.data.cache'] = mock_cache
      package.loaded['llm.core.loaders'] = nil
      local loaders = require('llm.core.loaders')

      -- Act
      loaders.load_models()

      -- Assert
      assert.spy(mock_llm_cli.run_llm_command).was_called_with('models list')
      assert.spy(mock_cache.set).was_called()
      local cache_args = mock_cache.set.calls[1].vals
      assert.are.equal('models', cache_args[1])
      assert.are.same({
        { provider = 'openai', id = 'gpt-4', name = 'gpt-4' },
        { provider = 'openai', id = 'gpt-3.5-turbo', name = 'gpt-3.5-turbo' },
      }, cache_args[2])

      -- Clean up
      package.loaded['llm.core.data.llm_cli'] = nil
      package.loaded['llm.core.data.cache'] = nil
    end)
  end)

  describe('load_schemas()', function()
    it('should parse schema list and set cache', function()
      -- Arrange
      local mock_llm_cli = {
        run_llm_command = spy.new(function()
          return [[
schema1 - description1
schema2 - description2
]]
        end),
      }
      local mock_cache = {
        set = spy.new(function() end),
      }
      package.loaded['llm.core.data.llm_cli'] = mock_llm_cli
      package.loaded['llm.core.data.cache'] = mock_cache
      package.loaded['llm.core.loaders'] = nil
      local loaders = require('llm.core.loaders')

      -- Act
      loaders.load_schemas()

      -- Assert
      assert.spy(mock_llm_cli.run_llm_command).was_called_with('schemas list')
      assert.spy(mock_cache.set).was_called()
      local cache_args = mock_cache.set.calls[1].vals
      assert.are.equal('schemas', cache_args[1])
      assert.are.same({
        { id = 'schema1', description = 'description1' },
        { id = 'schema2', description = 'description2' },
      }, cache_args[2])

      -- Clean up
      package.loaded['llm.core.data.llm_cli'] = nil
      package.loaded['llm.core.data.cache'] = nil
    end)
  end)

  describe('load_templates()', function()
    it('should parse template list and set cache', function()
      -- Arrange
      local mock_llm_cli = {
        run_llm_command = spy.new(function()
          return [[
template1 - description1
template2 - description2
]]
        end),
      }
      local mock_cache = {
        set = spy.new(function() end),
      }
      package.loaded['llm.core.data.llm_cli'] = mock_llm_cli
      package.loaded['llm.core.data.cache'] = mock_cache
      package.loaded['llm.core.loaders'] = nil
      local loaders = require('llm.core.loaders')

      -- Act
      loaders.load_templates()

      -- Assert
      assert.spy(mock_llm_cli.run_llm_command).was_called_with('templates list')
      assert.spy(mock_cache.set).was_called()
      local cache_args = mock_cache.set.calls[1].vals
      assert.are.equal('templates', cache_args[1])
      assert.are.same({
        { name = 'template1', description = 'description1' },
        { name = 'template2', description = 'description2' },
      }, cache_args[2])

      -- Clean up
      package.loaded['llm.core.data.llm_cli'] = nil
      package.loaded['llm.core.data.cache'] = nil
    end)
  end)

  describe('load_fragments()', function()
    it('should parse fragment list and set cache', function()
      -- Arrange
      local mock_llm_cli = {
        run_llm_command = spy.new(function()
          return [[
  - hash: 12345
    - alias1
    - alias2
    source: source1
    content: content1
    datetime: datetime1
  - hash: 67890
    - alias3
    source: source2
    content: content2
    datetime: datetime2
]]
        end),
      }
      local mock_cache = {
        set = spy.new(function() end),
      }
      package.loaded['llm.core.data.llm_cli'] = mock_llm_cli
      package.loaded['llm.core.data.cache'] = mock_cache
      package.loaded['llm.core.loaders'] = nil
      local loaders = require('llm.core.loaders')

      -- Act
      loaders.load_fragments()

      -- Assert
      assert.spy(mock_llm_cli.run_llm_command).was_called_with('fragments list')
      assert.spy(mock_cache.set).was_called()
      local cache_args = mock_cache.set.calls[1].vals
      assert.are.equal('fragments', cache_args[1])
      assert.are.same({
        {
          hash = '12345',
          aliases = { 'alias1', 'alias2' },
          source = 'source1',
          content = 'content1',
          datetime = 'datetime1',
        },
        {
          hash = '67890',
          aliases = { 'alias3' },
          source = 'source2',
          content = 'content2',
          datetime = 'datetime2',
        },
      }, cache_args[2])

      -- Clean up
      package.loaded['llm.core.data.llm_cli'] = nil
      package.loaded['llm.core.data.cache'] = nil
    end)
  end)

  describe('load_keys()', function()
    it('should parse key list and set cache', function()
      -- Arrange
      local mock_llm_cli = {
        run_llm_command = spy.new(function()
          return [[
Stored keys:
------------------
key1
key2
]]
        end),
      }
      local mock_cache = {
        set = spy.new(function() end),
      }
      package.loaded['llm.core.data.llm_cli'] = mock_llm_cli
      package.loaded['llm.core.data.cache'] = mock_cache
      package.loaded['llm.core.loaders'] = nil
      local loaders = require('llm.core.loaders')

      -- Act
      loaders.load_keys()

      -- Assert
      assert.spy(mock_llm_cli.run_llm_command).was_called_with('keys list')
      assert.spy(mock_cache.set).was_called()
      local cache_args = mock_cache.set.calls[1].vals
      assert.are.equal('keys', cache_args[1])
      assert.are.same({
        { name = 'key1' },
        { name = 'key2' },
      }, cache_args[2])

      -- Clean up
      package.loaded['llm.core.data.llm_cli'] = nil
      package.loaded['llm.core.data.cache'] = nil
    end)
  end)

  describe('load_available_plugins()', function()
    it('should parse plugin list and set cache', function()
      -- Arrange
      local mock_llm_cli = {
        run_llm_command = spy.new(function()
          return [[
plugin1 - description1
plugin2 - description2
]]
        end),
      }
      local mock_cache = {
        set = spy.new(function() end),
      }
      package.loaded['llm.core.data.llm_cli'] = mock_llm_cli
      package.loaded['llm.core.data.cache'] = mock_cache
      package.loaded['llm.core.loaders'] = nil
      local loaders = require('llm.core.loaders')

      -- Act
      loaders.load_available_plugins()

      -- Assert
      assert.spy(mock_llm_cli.run_llm_command).was_called_with('plugins --all')
      assert.spy(mock_cache.set).was_called()
      local cache_args = mock_cache.set.calls[1].vals
      assert.are.equal('available_plugins', cache_args[1])
      assert.are.same({
        { name = 'plugin1', description = 'description1' },
        { name = 'plugin2', description = 'description2' },
      }, cache_args[2])

      -- Clean up
      package.loaded['llm.core.data.llm_cli'] = nil
      package.loaded['llm.core.data.cache'] = nil
    end)
  end)

  describe('load_all()', function()
    it('should call all loader functions', function()
      -- Arrange
      local loaders = require('llm.core.loaders')
      local spy_load_models = spy.on(loaders, 'load_models')
      local spy_load_available_plugins = spy.on(loaders, 'load_available_plugins')
      local spy_load_keys = spy.on(loaders, 'load_keys')
      local spy_load_fragments = spy.on(loaders, 'load_fragments')
      local spy_load_templates = spy.on(loaders, 'load_templates')
      local spy_load_schemas = spy.on(loaders, 'load_schemas')

      -- Act
      loaders.load_all()

      -- Assert
      assert.spy(spy_load_models).was_called()
      assert.spy(spy_load_available_plugins).was_called()
      assert.spy(spy_load_keys).was_called()
      assert.spy(spy_load_fragments).was_called()
      assert.spy(spy_load_templates).was_called()
      assert.spy(spy_load_schemas).was_called()
    end)
  end)
end)
