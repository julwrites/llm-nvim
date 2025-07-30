require('tests.spec.spec_helper')

describe('llm.core.utils.ui', function()
  local ui_utils = require('llm.core.utils.ui')

  describe('create_split_buffer()', function()
    it('should create a split buffer', function()
      local create_buf_spy = spy.new(function() return 1 end)
      local open_win_spy = spy.new(function() end)

      ui_utils.set_api({
        nvim_create_buf = create_buf_spy,
        nvim_open_win = open_win_spy,
        nvim_buf_set_option = function() end,
      })

      ui_utils.create_split_buffer('test')

      assert.spy(create_buf_spy).was.called_with(false, true)
      assert.spy(open_win_spy).was.called()
    end)
  end)

  describe('buffer content', function()
    it('should create a buffer with content', function()
      local create_buf_spy = spy.new(function() return 1 end)
      local set_lines_spy = spy.new(function() end)

      ui_utils.set_api({
        nvim_create_buf = create_buf_spy,
        nvim_open_win = function() end,
        nvim_buf_set_option = function() end,
        nvim_buf_set_name = function() end,
        nvim_buf_set_lines = set_lines_spy,
      })

      ui_utils.create_buffer_with_content('hello', 'test_buffer', 'markdown')

      assert.spy(create_buf_spy).was.called()
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
end)
