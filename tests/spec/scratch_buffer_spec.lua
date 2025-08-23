require('spec_helper')

describe('llm.core.utils.ui', function()
  local ui_utils = require('llm.core.utils.ui')

  describe('create_prompt_buffer()', function()
    it('should create a prompt buffer', function()
        spy.on(vim, 'cmd')
        spy.on(vim.api, 'nvim_get_current_buf')
        spy.on(vim.api, 'nvim_buf_set_lines')
        spy.on(vim.api, 'nvim_create_augroup')
        spy.on(vim.api, 'nvim_create_autocmd')

        ui_utils.create_prompt_buffer()

        assert.spy(vim.cmd).was.called_with('vnew')
        assert.spy(vim.cmd).was.called_with('startinsert')
        assert.spy(vim.api.nvim_get_current_buf).was.called()
        assert.spy(vim.api.nvim_buf_set_lines).was.called()
        assert.spy(vim.api.nvim_create_augroup).was.called()
        assert.spy(vim.api.nvim_create_autocmd).was.called()
    end)
  end)
end)
