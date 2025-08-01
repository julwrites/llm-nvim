require('tests.spec.spec_helper')

describe('llm.core.utils.ui', function()
  local ui_utils = require('llm.core.utils.ui')

  describe('create_prompt_buffer()', function()
    it('should create a prompt buffer', function()
        local cmd_spy = spy.new(function() end)
        local get_current_buf_spy = spy.new(function() return 1 end)
        local set_lines_spy = spy.new(function() end)
        local create_augroup_spy = spy.new(function() return 1 end)
        local create_autocmd_spy = spy.new(function() end)

        -- Mock vim.cmd and vim.api
        vim.cmd = cmd_spy
        ui_utils.set_api({
            nvim_get_current_buf = get_current_buf_spy,
            nvim_buf_set_lines = set_lines_spy,
            nvim_create_augroup = create_augroup_spy,
            nvim_create_autocmd = create_autocmd_spy,
        })

        ui_utils.create_prompt_buffer()

        assert.spy(cmd_spy).was.called_with('vnew')
        assert.spy(cmd_spy).was.called_with('startinsert')
        assert.spy(get_current_buf_spy).was.called()
        assert.spy(set_lines_spy).was.called()
        assert.spy(create_augroup_spy).was.called()
        assert.spy(create_autocmd_spy).was.called()
    end)
  end)
end)
