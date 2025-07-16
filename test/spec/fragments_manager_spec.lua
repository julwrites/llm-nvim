-- test/spec/fragments_manager_spec.lua

describe("fragments_manager", function()
  local fragments_manager
  local mock_fragments_loader

  before_each(function()
    mock_fragments_loader = {
      load_fragments = function() return {} end,
    }

    package.loaded['llm.fragments.fragments_loader'] = mock_fragments_loader
    fragments_manager = require('llm.fragments.fragments_manager')
  end)

  after_each(function()
    package.loaded['llm.fragments.fragments_loader'] = nil
    package.loaded['llm.fragments.fragments_manager'] = nil
  end)

  it("should be a table", function()
    assert.is_table(fragments_manager)
  end)

  describe("get_fragments", function()
    it("should return the loaded fragments", function()
      local fake_fragments = { { name = "fragment1" }, { name = "fragment2" } }
      mock_fragments_loader.load_fragments = function() return fake_fragments end
      fragments_manager.load()
      assert.are.same(fake_fragments, fragments_manager.get_fragments())
    end)
  end)

  describe("add_file_as_fragment", function()
    it("should add a file as a fragment", function()
        local mock_file_utils = {
            save_json = require('luassert.spy').create(),
            get_config_dir = function() return "config_dir" end,
        }
        package.loaded['llm.utils.file_utils'] = mock_file_utils
        fragments_manager = require('llm.fragments.fragments_manager')

        fragments_manager.add_file_as_fragment("/path/to/file.txt")
        assert.spy(mock_file_utils.save_json).was.called_with("config_dir/fragments/file.txt.json", { path = "/path/to/file.txt" })
    end)
  end)

  describe("add_github_repo_as_fragment", function()
    it("should add a github repo as a fragment", function()
        local mock_shell = {
            run = require('luassert.spy').create(),
        }
        package.loaded['llm.utils.shell'] = mock_shell
        fragments_manager = require('llm.fragments.fragments_manager')

        fragments_manager.add_github_repo_as_fragment("owner/repo")
        assert.spy(mock_shell.run).was.called_with("llm fragments add-repo owner/repo")
    end)
  end)

  describe("prompt_with_fragment", function()
    it("should prompt with a fragment", function()
        local mock_shell = {
            run = require('luassert.spy').create(),
        }
        package.loaded['llm.utils.shell'] = mock_shell
        fragments_manager = require('llm.fragments.fragments_manager')

        fragments_manager.prompt_with_fragment("my-fragment")
        assert.spy(mock_shell.run).was.called_with("llm prompt -s 'my-fragment'")
    end)
  end)
end)
