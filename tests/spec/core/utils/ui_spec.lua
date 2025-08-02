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

  describe('buffer content', function()
    it('should create a buffer with content', function()
      local create_buf_spy = spy.new(function() return 1 end)
      local open_win_spy = spy.new(function() end)
      local set_lines_spy = spy.new(function() end)
      local cmd_spy = spy.new(function() end)

      -- Mock vim.cmd and vim.api
      vim.cmd = cmd_spy
      ui_utils.set_api({
        nvim_create_buf = create_buf_spy,
        nvim_open_win = open_win_spy,
        nvim_buf_set_option = function() end,
        nvim_buf_set_name = function() end,
        nvim_buf_set_lines = set_lines_spy,
        nvim_create_augroup = function() end,
        nvim_create_autocmd = function() end,
      })

      ui_utils.create_buffer_with_content('hello', 'test_buffer', 'markdown')

      assert.spy(create_buf_spy).was.called()
      assert.spy(open_win_spy).was.called()
      assert.spy(set_lines_spy).was.called_with(1, 0, -1, false, { 'hello' })
    end)

    it('should replace buffer content', function()
      local set_lines_spy = spy.new(function() end)

      ui_utils.set_api({
        nvim_buf_set_option = function() end,
        nvim_buf_set_lines = set_lines_spy,
      })

      ui_utils.replace_buffer_with_content('new content', 2, 'text')

      assert.spy(set_lines_spy).was.called_with(2, 0, -1, false, { 'new content' })
    end)
  end)

  describe('floating window', function()
    it('should create a floating window', function()
      local open_win_spy = spy.new(function() return 1 end)
      local set_option_spy = spy.new(function() end)

      ui_utils.set_api({
        nvim_open_win = open_win_spy,
        nvim_win_set_option = set_option_spy,
      })

      vim.o = { columns = 100, lines = 50 }

      ui_utils.create_floating_window(1, 'test_window')

      assert.spy(open_win_spy).was.called()
      assert.spy(set_option_spy).was.called_with(1, 'cursorline', true)
    end)
  end)

  describe('floating input', function()
    it('should create a floating input', function()
      local create_buf_spy = spy.new(function() return 1 end)
      local open_win_spy = spy.new(function() return 2 end)
      local set_keymap_spy = spy.new(function() end)
      local set_var_spy = spy.new(function() end)
      local command_spy = spy.new(function() end)

      ui_utils.set_api({
        nvim_create_buf = create_buf_spy,
        nvim_open_win = open_win_spy,
        nvim_buf_set_keymap = set_keymap_spy,
        nvim_buf_set_var = set_var_spy,
        nvim_command = command_spy,
      })
      vim.o = { columns = 100, lines = 50 }

      ui_utils.floating_input({ prompt = 'test' }, function() end)

      assert.spy(create_buf_spy).was.called()
      assert.spy(open_win_spy).was.called()
      assert.spy(set_keymap_spy).was.called()
      assert.spy(set_var_spy).was.called()
      assert.spy(command_spy).was.called_with('startinsert')
    end)
  end)

  describe('floating confirm', function()
    it('should create a floating confirm', function()
      local create_buf_spy = spy.new(function() return 1 end)
      local open_win_spy = spy.new(function() return 2 end)
      local set_hl_spy = spy.new(function() end)
      local win_set_option_spy = spy.new(function() end)
      local buf_set_lines_spy = spy.new(function() end)
      local buf_add_highlight_spy = spy.new(function() end)
      local buf_set_keymap_spy = spy.new(function() end)
      local buf_set_var_spy = spy.new(function() end)

      ui_utils.set_api({
        nvim_create_buf = create_buf_spy,
        nvim_open_win = open_win_spy,
        nvim_set_hl = set_hl_spy,
        nvim_win_set_option = win_set_option_spy,
        nvim_buf_set_lines = buf_set_lines_spy,
        nvim_buf_add_highlight = buf_add_highlight_spy,
        nvim_buf_set_keymap = buf_set_keymap_spy,
        nvim_buf_set_var = buf_set_var_spy,
      })
      vim.o = { columns = 100, lines = 50 }

      ui_utils.floating_confirm({ prompt = 'test' })

      assert.spy(create_buf_spy).was.called()
      assert.spy(open_win_spy).was.called()
      assert.spy(set_hl_spy).was.called()
      assert.spy(win_set_option_spy).was.called()
      assert.spy(buf_set_lines_spy).was.called()
      assert.spy(buf_add_highlight_spy).was.called()
      assert.spy(buf_set_keymap_spy).was.called()
      assert.spy(buf_set_var_spy).was.called()
    end)
  end)

  describe('append_to_buffer', function()
    local orig_bufwinid

    before_each(function()
      orig_bufwinid = vim.fn.bufwinid
    end)

    after_each(function()
      vim.fn.bufwinid = orig_bufwinid
    end)

    it('should append lines and move cursor', function()
      local set_lines_spy = spy.new(function() end)
      local set_cursor_spy = spy.new(function() end)
      local line_count_spy = spy.new(function() return 5 end)
      local bufwinid_spy = spy.new(function() return 1 end)

      ui_utils.set_api({
        nvim_buf_set_lines = set_lines_spy,
        nvim_win_set_cursor = set_cursor_spy,
        nvim_buf_line_count = line_count_spy,
      })
      vim.fn.bufwinid = bufwinid_spy

      ui_utils.append_to_buffer(123, 'some new content')

      assert.spy(line_count_spy).was.called_with(123)
      assert.spy(set_lines_spy).was.called_with(123, 5, 5, false, { 'some new content' })
      assert.spy(bufwinid_spy).was.called_with(123)
      assert.spy(set_cursor_spy).was.called_with(1, { 6, 0 })
    end)

    it('should do nothing for empty content', function()
      local set_lines_spy = spy.new(function() end)
      ui_utils.set_api({ nvim_buf_set_lines = set_lines_spy })

      ui_utils.append_to_buffer(123, '')

      assert.spy(set_lines_spy).was.not_called()
    end)

    it('should do nothing for nil content', function()
      local set_lines_spy = spy.new(function() end)
      ui_utils.set_api({ nvim_buf_set_lines = set_lines_spy })

      ui_utils.append_to_buffer(123, nil)

      assert.spy(set_lines_spy).was.not_called()
    end)

    it('should handle invalid buffer handle gracefully', function()
      local line_count_spy = spy.new(function()
        error('Invalid buffer id')
      end)
      local set_lines_spy = spy.new(function() end)
      ui_utils.set_api({
        nvim_buf_line_count = line_count_spy,
        nvim_buf_set_lines = set_lines_spy,
      })

      assert.is_not.error(function()
        ui_utils.append_to_buffer(999, 'content')
      end)
      assert.spy(set_lines_spy).was.not_called()
    end)
  end)
end)
