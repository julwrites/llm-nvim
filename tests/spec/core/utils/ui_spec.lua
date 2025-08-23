require('spec_helper')

describe('llm.core.utils.ui', function()
  local ui_utils = require('llm.core.utils.ui')

  describe('create_chat_buffer()', function()
    it('should create and configure the chat buffer correctly', function()
      -- Spies for API calls
      vim.cmd = spy.new(function() end)
      vim.api.nvim_get_current_buf = spy.new(function() return 1 end)
      vim.api.nvim_buf_set_lines = spy.new(function() end)
      vim.api.nvim_buf_set_keymap = spy.new(function() end)
      vim.api.nvim_win_set_cursor = spy.new(function() end)
      vim.api.nvim_buf_set_option = spy.new(function() end)
      vim.api.nvim_buf_set_name = spy.new(function() end)

      -- Execute the function
      ui_utils.create_chat_buffer()

      -- Assertions
      assert.spy(vim.cmd).was.called_with('vnew')
      assert.spy(vim.api.nvim_get_current_buf).was.called()

      -- Check that the prompt is set correctly
      local expected_prompt = {
        '--- User Prompt ---',
        'Enter your prompt below and press <Enter> to submit.',
        '-------------------',
        ''
      }
      assert.spy(vim.api.nvim_buf_set_lines).was.called_with(1, 0, -1, false, expected_prompt)

      -- Check that keymaps are set
      assert.spy(vim.api.nvim_buf_set_keymap).was.called_with(1, 'i', '<Enter>', '<Cmd>lua require("llm.chat").send_prompt()<CR>', { noremap = true, silent = true })
      assert.spy(vim.api.nvim_buf_set_keymap).was.called_with(1, 'n', 'q', '<Cmd>bd<CR>', { noremap = true, silent = true })

      -- Check that the cursor is positioned correctly
      assert.spy(vim.api.nvim_win_set_cursor).was.called_with(0, { 4, 0 })

      -- Check that Neovim is put into insert mode
      assert.spy(vim.cmd).was.called_with('startinsert')
    end)
  end)

  describe('create_prompt_buffer()', function()
    it('should create a prompt buffer', function()
      vim.cmd = spy.new(function() end)
      vim.api.nvim_get_current_buf = spy.new(function() return 1 end)
      vim.api.nvim_buf_set_lines = spy.new(function() end)
      vim.api.nvim_create_augroup = spy.new(function() return 1 end)
      vim.api.nvim_create_autocmd = spy.new(function() end)

      ui_utils.create_prompt_buffer()

      assert.spy(vim.cmd).was.called_with('vnew')
      assert.spy(vim.cmd).was.called_with('startinsert')
      assert.spy(vim.api.nvim_get_current_buf).was.called()
      assert.spy(vim.api.nvim_buf_set_lines).was.called()
      assert.spy(vim.api.nvim_create_augroup).was.called()
      assert.spy(vim.api.nvim_create_autocmd).was.called()
    end)
  end)

  describe('buffer content', function()
    it('should create a buffer with content', function()
      vim.api.nvim_create_buf = spy.new(function() return 1 end)
      vim.api.nvim_open_win = spy.new(function() end)
      vim.api.nvim_buf_set_lines = spy.new(function() end)
      vim.cmd = spy.new(function() end)
      vim.api.nvim_buf_set_option = spy.new(function() end)
      vim.api.nvim_buf_set_name = spy.new(function() end)
      vim.api.nvim_buf_get_name = spy.new(function() return "test_buffer" end)
      vim.api.nvim_create_augroup = spy.new(function() end)
      vim.api.nvim_create_autocmd = spy.new(function() end)

      package.loaded['llm.core.utils.ui'] = nil
      ui_utils = require('llm.core.utils.ui')

      ui_utils.create_buffer_with_content('hello', 'test_buffer', 'markdown')

      assert.spy(vim.api.nvim_create_buf).was.called()
      assert.spy(vim.api.nvim_buf_set_lines).was.called_with(1, 0, -1, false, { 'hello' })
    end)

    it('should replace buffer content', function()
      vim.api.nvim_buf_set_option = spy.new(function() end)
      vim.api.nvim_buf_set_lines = spy.new(function() end)

      ui_utils.replace_buffer_with_content('new content', 2, 'text')

      assert.spy(vim.api.nvim_buf_set_lines).was.called_with(2, 0, -1, false, { 'new content' })
    end)
  end)

  describe('floating window', function()
    it('should create a floating window', function()
      vim.api.nvim_open_win = spy.new(function() return 1 end)
      vim.api.nvim_win_set_option = spy.new(function() end)

      vim.o = { columns = 100, lines = 50 }

      ui_utils.create_floating_window(1, 'test_window')

      assert.spy(vim.api.nvim_open_win).was.called()
      assert.spy(vim.api.nvim_win_set_option).was.called_with(1, 'cursorline', true)
    end)
  end)

  describe('floating input', function()
    it('should create a floating input', function()
      vim.api.nvim_create_buf = spy.new(function() return 1 end)
      vim.api.nvim_open_win = spy.new(function() return 2 end)
      vim.api.nvim_buf_set_keymap = spy.new(function() end)
      vim.api.nvim_buf_set_var = spy.new(function() end)
      vim.api.nvim_command = spy.new(function() end)
      vim.o = { columns = 100, lines = 50 }

      ui_utils.floating_input({ prompt = 'test' }, function() end)

      assert.spy(vim.api.nvim_create_buf).was.called()
      assert.spy(vim.api.nvim_open_win).was.called()
      assert.spy(vim.api.nvim_buf_set_keymap).was.called()
      assert.spy(vim.api.nvim_buf_set_var).was.called()
      assert.spy(vim.api.nvim_command).was.called_with('startinsert')
    end)
  end)

  describe('floating confirm', function()
    it('should create a floating confirm', function()
      vim.api.nvim_create_buf = spy.new(function() return 1 end)
      vim.api.nvim_open_win = spy.new(function() return 2 end)
      vim.api.nvim_set_hl = spy.new(function() end)
      vim.api.nvim_win_set_option = spy.new(function() end)
      vim.api.nvim_buf_set_lines = spy.new(function() end)
      vim.api.nvim_buf_add_highlight = spy.new(function() end)
      vim.api.nvim_buf_set_keymap = spy.new(function() end)
      vim.api.nvim_buf_set_var = spy.new(function() end)
      vim.o = { columns = 100, lines = 50 }

      ui_utils.floating_confirm({ prompt = 'test' })

      assert.spy(vim.api.nvim_create_buf).was.called()
      assert.spy(vim.api.nvim_open_win).was.called()
      assert.spy(vim.api.nvim_set_hl).was.called()
      assert.spy(vim.api.nvim_win_set_option).was.called()
      assert.spy(vim.api.nvim_buf_set_lines).was.called()
      assert.spy(vim.api.nvim_buf_add_highlight).was.called()
      assert.spy(vim.api.nvim_buf_set_keymap).was.called()
      assert.spy(vim.api.nvim_buf_set_var).was.called()
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
      vim.api.nvim_buf_set_lines = spy.new(function() end)
      vim.api.nvim_win_set_cursor = spy.new(function() end)
      vim.api.nvim_buf_line_count = spy.new(function() return 5 end)
      vim.fn.bufwinid = spy.new(function() return 1 end)
      vim.api.nvim_get_current_buf = spy.new(function() return 123 end)

      ui_utils.append_to_buffer(123, 'some new content')

      assert.spy(vim.api.nvim_buf_line_count).was.called_with(123)
      assert.spy(vim.api.nvim_buf_set_lines).was.called_with(123, 5, 5, false, { 'some new content' })
      assert.spy(vim.api.nvim_win_set_cursor).was.called_with(0, { 6, 0 })
    end)

    it('should do nothing for empty content', function()
      vim.api.nvim_buf_set_lines = spy.new(function() end)

      ui_utils.append_to_buffer(123, '')

      assert.spy(vim.api.nvim_buf_set_lines).was.not_called()
    end)

    it('should do nothing for nil content', function()
      vim.api.nvim_buf_set_lines = spy.new(function() end)

      ui_utils.append_to_buffer(123, nil)

      assert.spy(vim.api.nvim_buf_set_lines).was.not_called()
    end)

    it('should handle invalid buffer handle gracefully', function()
      vim.api.nvim_buf_line_count = spy.new(function()
        error('Invalid buffer id')
      end)
      vim.api.nvim_buf_set_lines = spy.new(function() end)

      assert.is_not.error(function()
        ui_utils.append_to_buffer(999, 'content')
      end)
      assert.spy(vim.api.nvim_buf_set_lines).was.not_called()
    end)
  end)
end)
