require('spec_helper')
local fragments_manager = require('llm.managers.fragments_manager')
local llm_cli = require('llm.core.data.llm_cli')
local cache = require('llm.core.data.cache')
local fragments_view = require('llm.ui.views.fragments_view')
local unified_manager = require('llm.ui.unified_manager')

describe('fragments_manager', function()
  describe('get_fragments', function()
    local cache_data
    before_each(function()
      cache_data = nil
      cache.get = function()
        return cache_data
      end
      cache.set = function(key, value)
        cache_data = value
      end
    end)

    it('should return a table of fragments', function()
      local fragments = fragments_manager.get_fragments()
      assert.is_table(fragments)
    end)

    it('should cache the fragments', function()
      -- Mock the llm_cli.run_llm_command
      local llm_cli_call_count = 0
      llm_cli.run_llm_command = function()
        llm_cli_call_count = llm_cli_call_count + 1
        return '[]'
      end

      -- Call get_fragments twice
      fragments_manager.get_fragments()
      fragments_manager.get_fragments()

      -- Assert that llm_cli.run_llm_command was only called once
      assert.are.equal(1, llm_cli_call_count)
    end)
  end)

  describe('set_alias_for_fragment_under_cursor', function()
    it('should call llm_cli.run_llm_command with the correct arguments', function()
      -- Mock the necessary functions
      fragments_manager.get_fragment_info_under_cursor = function()
        return '123', {}
      end
      fragments_view.get_alias = function(callback)
        callback('my-alias')
      end
      local llm_cli_spy = spy.new(function()
        return true
      end)
      llm_cli.run_llm_command = llm_cli_spy
      unified_manager.switch_view = function() end

      -- Call the function to be tested
      fragments_manager.set_alias_for_fragment_under_cursor(0)

      -- Assert that llm_cli.run_llm_command was called with the correct arguments
      assert.spy(llm_cli_spy).was.called_with('fragments set my-alias 123')
    end)
  end)

  describe('remove_alias_from_fragment_under_cursor', function()
    it('should call llm_cli.run_llm_command with the correct arguments', function()
      -- Mock the necessary functions
      fragments_manager.get_fragment_info_under_cursor = function()
        return '123', { aliases = { 'my-alias' } }
      end
      fragments_view.confirm_remove_alias = function(alias, callback)
        callback(true)
      end
      local llm_cli_spy = spy.new(function()
        return true
      end)
      llm_cli.run_llm_command = llm_cli_spy
      unified_manager.switch_view = function() end

      -- Call the function to be tested
      fragments_manager.remove_alias_from_fragment_under_cursor(0)

      -- Assert that llm_cli.run_llm_command was called with the correct arguments
      assert.spy(llm_cli_spy).was.called_with('fragments remove my-alias')
    end)
  end)

  describe('add_file_fragment', function()
    it('should call llm_cli.run_llm_command with the correct arguments', function()
      -- Mock the necessary functions
      fragments_view.select_file = function(callback)
        callback('/path/to/file.txt')
      end
      local llm_cli_spy = spy.new(function()
        return true
      end)
      llm_cli.run_llm_command = llm_cli_spy
      unified_manager.switch_view = function() end

      -- Call the function to be tested
      fragments_manager.add_file_fragment(0)

      -- Assert that llm_cli.run_llm_command was called with the correct arguments
      assert.spy(llm_cli_spy).was.called_with('fragments store /path/to/file.txt')
    end)
  end)

  describe('add_github_fragment_from_manager', function()
    it('should call llm_cli.run_llm_command with the correct arguments', function()
      -- Mock the necessary functions
      fragments_view.get_github_url = function(callback)
        callback('https://github.com/user/repo/blob/main/file.txt')
      end
      local llm_cli_spy = spy.new(function()
        return true
      end)
      llm_cli.run_llm_command = llm_cli_spy
      unified_manager.switch_view = function() end

      -- Call the function to be tested
      fragments_manager.add_github_fragment_from_manager(0)

      -- Assert that llm_cli.run_llm_command was called with the correct arguments
      assert.spy(llm_cli_spy).was.called_with('fragments store https://github.com/user/repo/blob/main/file.txt')
    end)
  end)

  describe('populate_fragments_buffer', function()
    it('should set lines in the buffer', function()
      local nvim_buf_set_lines_spy = spy.on(vim.api, 'nvim_buf_set_lines')
      local styles = require('llm.ui.styles')
      local setup_highlights_spy = spy.on(styles, 'setup_highlights')
      local setup_buffer_syntax_spy = spy.on(styles, 'setup_buffer_syntax')
      vim.b = { [1] = {} }
      _G.llm_fragments_show_all = true

      fragments_manager.get_fragments = function()
        return { { hash = '123', content = 'test', aliases = {'test-alias'} } }
      end

      fragments_manager.populate_fragments_buffer(1)
      assert.spy(nvim_buf_set_lines_spy).was_called()
      setup_highlights_spy:revert()
      setup_buffer_syntax_spy:revert()
      nvim_buf_set_lines_spy:revert()
    end)
  end)

  describe('toggle_fragments_view', function()
    it('should switch view and toggle global flag', function()
      local unified_manager_spy = spy.on(unified_manager, 'switch_view')
      _G.llm_fragments_show_all = false
      fragments_manager.toggle_fragments_view(1)
      assert.is_true(_G.llm_fragments_show_all)
      assert.spy(unified_manager_spy).was_called_with('Fragments')
      unified_manager_spy:revert()
    end)
  end)

  describe('get_fragment_info_under_cursor', function()
    it('should return fragment info', function()
      local nvim_win_get_cursor_spy = spy.on(vim.api, 'nvim_win_get_cursor')
      vim.api.nvim_win_get_cursor = function() return {1, 0} end
      vim.b = { [1] = { line_to_fragment = { [1] = '123' }, fragment_data = { ['123'] = { hash = '123' } } } }
      local fragment_hash, fragment_info = fragments_manager.get_fragment_info_under_cursor(1)
      assert.are.equal('123', fragment_hash)
      assert.is_table(fragment_info)
      nvim_win_get_cursor_spy:revert()
    end)
  end)

  describe('manage_fragments', function()
    it('should call open_specific_manager', function()
      local open_specific_manager_spy = spy.on(unified_manager, 'open_specific_manager')
      fragments_manager.manage_fragments(true)
      assert.is_true(_G.llm_fragments_show_all)
      assert.spy(open_specific_manager_spy).was_called_with('Fragments')
      open_specific_manager_spy:revert()
    end)
  end)
end)
