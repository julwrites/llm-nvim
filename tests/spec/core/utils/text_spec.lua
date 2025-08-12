require('tests.spec.spec_helper')

describe('llm.core.utils.text', function()
  local text_utils = require('llm.core.utils.text')

  describe('capitalize()', function()
    it('should capitalize the first letter of a lowercase string', function()
      assert.are.equal('Hello', text_utils.capitalize('hello'))
    end)

    it('should not change a string that is already capitalized', function()
      assert.are.equal('Hello', text_utils.capitalize('Hello'))
    end)

    it('should handle an empty string', function()
      assert.are.equal('', text_utils.capitalize(''))
    end)

    it('should handle a single character string', function()
      assert.are.equal('A', text_utils.capitalize('a'))
    end)

    it('should not change a string that starts with a number', function()
      assert.are.equal('1hello', text_utils.capitalize('1hello'))
    end)
  end)

  describe('get_visual_selection()', function()
    it('should return the selected text', function()
      local original_vim_fn = vim.fn
      local original_vim_api = vim.api

      vim.fn = {
        getpos = function(pos)
          if pos == "'<" then
            return { 0, 1, 1, 0 }
          elseif pos == "'>" then
            return { 0, 1, 5, 0 }
          end
        end,
      }

      vim.api = {
        nvim_buf_get_lines = function()
          return { 'hello world' }
        end,
      }

      local selection = text_utils.get_visual_selection()
      assert.are.equal('hello', selection)

      vim.fn = original_vim_fn
      vim.api = original_vim_api
    end)
  end)

  describe('escape_pattern()', function()
    it('should escape magic characters', function()
      local unescaped = 'hello.world(how-are%you)'
      local escaped = text_utils.escape_pattern(unescaped)
      assert.are.equal('hello%.world%(how%-are%%you%)', escaped)
    end)
  end)

  describe('parse_simple_yaml()', function()
    it('should parse a simple yaml string', function()
      local yaml_string = [[
key1: value1
key2:
  nested_key1: nested_value1
  nested_key2: nested_value2
key3:
  - item1
  - item2
]]
      local expected_table = {
        key1 = 'value1',
        key2 = {
          nested_key1 = 'nested_value1',
          nested_key2 = 'nested_value2',
        },
        key3 = {
          'item1',
          'item2',
        },
      }

      local file = io.open('temp_yaml.yaml', 'w')
      file:write(yaml_string)
      file:close()

      local parsed_table = text_utils.parse_simple_yaml('temp_yaml.yaml')
      assert.are.same(expected_table, parsed_table)

      os.remove('temp_yaml.yaml')
    end)
  end)

  describe('wrap()', function()
    it('should not wrap a line shorter than the width', function()
      local text = 'hello world'
      local wrapped = text_utils.wrap(text, 80)
      assert.are.equal('hello world', wrapped)
    end)

    it('should wrap a long line', function()
      local text = 'this is a long line of text that should be wrapped'
      local wrapped = text_utils.wrap(text, 20)
      local expected = 'this is a long line\nof text that should\nbe wrapped'
      assert.are.equal(expected, wrapped)
    end)

    it('should wrap a long line with an indent', function()
      local text = 'this is a long line of text that should be wrapped'
      local wrapped = text_utils.wrap(text, 30, '  ')
      local expected = '  this is a long line of text\n  that should be wrapped'
      assert.are.equal(expected, wrapped)
    end)

    it('should handle a word longer than the width', function()
      local text = 'thisisaverylongword'
      local wrapped = text_utils.wrap(text, 10)
      assert.are.equal('thisisaverylongword', wrapped)
    end)

    it('should handle an empty string', function()
      local text = ''
      local wrapped = text_utils.wrap(text, 80)
      assert.are.equal('', wrapped)
    end)

    it('should handle a string with only spaces', function()
      local text = '   '
      local wrapped = text_utils.wrap(text, 80)
      assert.are.equal('', wrapped)
    end)

    it('should handle a string shorter than the width', function()
      local text = 'a short string'
      local wrapped = text_utils.wrap(text, 80)
      assert.are.equal('a short string', wrapped)
    end)
  end)
end)
