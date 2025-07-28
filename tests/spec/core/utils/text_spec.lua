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
end)
