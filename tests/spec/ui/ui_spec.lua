require('spec_helper')

describe('llm.ui.ui', function()
  vim.ui = {}
  local ui = require('llm.ui.ui')

  describe('display_in_buffer()', function()
    it('should set buffer lines and syntax', function()
      vim.api.nvim_buf_set_lines = spy.new(function() end)
      vim.bo = { [1] = { syntax = '' } }

      ui.display_in_buffer(1, { 'hello' }, 'markdown')

      assert.spy(vim.api.nvim_buf_set_lines).was.called_with(1, 0, -1, false, { 'hello' })
      assert.are.equal('markdown', vim.bo[1].syntax)
    end)
  end)

  describe('notify()', function()
    it('should call vim.notify', function()
      vim.notify = spy.new(function() end)
      ui.notify('test message', 'INFO')
      assert.spy(vim.notify).was.called_with('test message', 'INFO')
    end)
  end)

  describe('get_input()', function()
    it('should call vim.ui.input', function()
      vim.ui.input = spy.new(function() end)
      local on_confirm = function() end
      ui.get_input('test prompt', on_confirm)
      assert.spy(vim.ui.input).was.called_with({ prompt = 'test prompt' }, on_confirm)
    end)
  end)

  describe('select()', function()
    it('should call vim.ui.select', function()
      vim.ui.select = spy.new(function() end)
      local on_choice = function() end
      ui.select({ 'item1' }, { prompt = 'test prompt' }, on_choice)
      assert.spy(vim.ui.select).was.called_with({ 'item1' }, { prompt = 'test prompt' }, on_choice)
    end)
  end)
end)
