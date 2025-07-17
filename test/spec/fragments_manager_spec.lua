-- test/spec/fragments_manager_spec.lua

describe("fragments_manager", function()
  local fragments_manager
  local spy
  local mock_fragments_loader

  before_each(function()
    spy = require('luassert.spy')
    mock_fragments_loader = {
      get_fragments = function()
        return {
          {
            hash = 'hash1',
            aliases = { 'alias1' },
            source = 'source1',
            content = 'content1',
            datetime = 'datetime1',
          },
        }
      end,
      get_all_fragments = function()
        return {
          {
            hash = 'hash1',
            aliases = { 'alias1' },
            source = 'source1',
            content = 'content1',
            datetime = 'datetime1',
          },
          {
            hash = 'hash2',
            aliases = {},
            source = 'source2',
            content = 'content2',
            datetime = 'datetime2',
          },
        }
      end,
      set_fragment_alias = spy.new(function() return true end),
      remove_fragment_alias = spy.new(function() return true end),
      select_file_as_fragment = spy.new(function() end),
      add_github_fragment = spy.new(function() end),
    }

    package.loaded['llm.fragments.fragments_loader'] = mock_fragments_loader
    package.loaded['llm.unified_manager'] = {
      switch_view = function() end,
    }
    package.loaded['llm.utils'] = {
        floating_input = function(_, cb) cb("test") end,
        floating_confirm = function(opts) opts.on_confirm(true) end,
        create_floating_window = function() end,
    }
    package.loaded['llm'] = {
        prompt = spy.new(function() end)
    }

    fragments_manager = require('llm.fragments.fragments_manager')
  end)

  after_each(function()
    package.loaded['llm.fragments.fragments_loader'] = nil
    package.loaded['llm.fragments.fragments_manager'] = nil
    package.loaded['llm.unified_manager'] = nil
    package.loaded['llm.utils'] = nil
    package.loaded['llm'] = nil
  end)

  it("should be a table", function()
    assert.is_table(fragments_manager)
  end)

  describe("set_alias_for_fragment_under_cursor", function()
    it("should set an alias for a fragment", function()
      vim.b[1] = {
        line_to_fragment = { [1] = "hash1" },
        fragment_data = { hash1 = { start_line = 1, end_line = 6 } },
      }
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      fragments_manager.set_alias_for_fragment_under_cursor(1)
      assert.spy(mock_fragments_loader.set_fragment_alias).was.called_with("hash1", "test")
    end)
  end)

  describe("remove_alias_from_fragment_under_cursor", function()
    it("should remove an alias from a fragment", function()
        vim.b[1] = {
            line_to_fragment = { [1] = "hash1" },
            fragment_data = { hash1 = { start_line = 1, end_line = 6, aliases = { "alias1" } } },
        }
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        fragments_manager.remove_alias_from_fragment_under_cursor(1)
        assert.spy(mock_fragments_loader.remove_fragment_alias).was.called_with("alias1")
    end)
  end)

  describe("add_file_fragment", function()
    it("should add a file fragment", function()
      fragments_manager.add_file_fragment(1)
      assert.spy(mock_fragments_loader.select_file_as_fragment).was.called()
    end)
  end)

  describe("add_github_fragment_from_manager", function()
    it("should add a github fragment", function()
      fragments_manager.add_github_fragment_from_manager(1)
      assert.spy(mock_fragments_loader.add_github_fragment).was.called()
    end)
  end)

  describe("prompt_with_fragment_under_cursor", function()
    it("should prompt with a fragment", function()
        vim.b[1] = {
            line_to_fragment = { [1] = "hash1" },
            fragment_data = { hash1 = { start_line = 1, end_line = 6, aliases = { "alias1" } } },
        }
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        fragments_manager.prompt_with_fragment_under_cursor(1)
        assert.spy(package.loaded['llm'].prompt).was.called_with("test", { "alias1" })
    end)
  end)
end)
