-- test/spec/fragments_manager_spec.lua

describe("fragments_manager", function()
  local fragments_manager
  local mock_fragments_loader
  local mock_file_utils
  local mock_shell

  before_each(function()
    mock_fragments_loader = {
      load_fragments = function() return {} end,
    }

    mock_file_utils = {
      save_json = function(_, _) end,
      get_config_dir = function() return "config_dir" end,
    }

    mock_shell = {
      run = function(_) end,
    }

    package.loaded['llm.fragments.fragments_loader'] = mock_fragments_loader
    package.loaded['llm.utils.file_utils'] = mock_file_utils
    package.loaded['llm.utils.shell'] = mock_shell
    package.loaded['llm.unified_manager'] = {
      switch_view = function() end,
    }
    fragments_manager = require('llm.fragments.fragments_manager')
    fragments_manager.load = function() end
  end)

  after_each(function()
    package.loaded['llm.fragments.fragments_loader'] = nil
    package.loaded['llm.fragments.fragments_manager'] = nil
    package.loaded['llm.utils.file_utils'] = nil
    package.loaded['llm.utils.shell'] = nil
  end)

  it("should be a table", function()
    assert.is_table(fragments_manager)
  end)

  describe("get_fragments", function()
    it("should return the loaded fragments", function()
      local fake_fragments = { { name = "fragment1" }, { name = "fragment2" } }
      mock_fragments_loader.load_fragments = function() return fake_fragments end
      fragments_manager:load()
      assert.are.same(fake_fragments, fragments_manager.get_fragments())
    end)
  end)

  describe("add_file_as_fragment", function()
    it("should add a file as a fragment", function()
      local saved_path, saved_data
      mock_file_utils.save_json = function(path, data)
        saved_path = path
        saved_data = data
      end
      fragments_manager:add_file_as_fragment("/path/to/file.txt")
      assert.are.equal("config_dir/fragments/file.txt.json", saved_path)
      assert.are.same({ path = "/path/to/file.txt" }, saved_data)
    end)
  end)

  describe("add_github_repo_as_fragment", function()
    it("should add a github repo as a fragment", function()
      local command_run
      mock_shell.run = function(command)
        command_run = command
      end
      fragments_manager:load()
      fragments_manager.add_github_repo_as_fragment("owner/repo")
      assert.are.equal("llm fragments add-repo owner/repo", command_run)
    end)
  end)

  describe("prompt_with_fragment", function()
    it("should prompt with a fragment", function()
      local command_run
      mock_shell.run = function(command)
        command_run = command
      end
      fragments_manager:load()
      fragments_manager:prompt_with_fragment("my-fragment")
      assert.are.equal("llm prompt -s 'my-fragment'", command_run)
    end)
  end)
end)
