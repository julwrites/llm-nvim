require('tests.spec.spec_helper')

describe('llm.core.utils.file_utils', function()
  local file_utils

  before_each(function()
    package.loaded['llm.core.utils.file_utils'] = nil
    file_utils = require('llm.core.utils.file_utils')
  end)

  describe('ensure_config_dir_exists()', function()
    it('should return true if directory is writable', function()
      local was_called = false
      file_utils._test_directory_writable = function(dir)
        was_called = true
        assert.are.equal('/tmp/llm-nvim', dir)
        return true
      end

      assert.is_true(file_utils.ensure_config_dir_exists('/tmp/llm-nvim'))
      assert.is_true(was_called)
    end)

    it('should create directory if not writable', function()
      local was_called_test = false
      local was_called_create = false
      file_utils._test_directory_writable = function(dir)
        was_called_test = true
        return false
      end
      file_utils._create_directory = function(dir)
        was_called_create = true
        assert.are.equal('/tmp/llm-nvim', dir)
        return true
      end

      assert.is_true(file_utils.ensure_config_dir_exists('/tmp/llm-nvim'))
      assert.is_true(was_called_test)
      assert.is_true(was_called_create)
    end)

    it('should return false if directory creation fails', function()
      file_utils._test_directory_writable = function() return false end
      file_utils._create_directory = function() return false end
      assert.is_false(file_utils.ensure_config_dir_exists('/tmp/llm-nvim'))
    end)
  end)

  describe('get_config_path()', function()
    local mock_shell

    before_each(function()
      mock_shell = {
        safe_shell_command = function() end
      }
      file_utils.set_shell(mock_shell)
      file_utils.config_dir_cache = nil
    end)

    it('should resolve and cache the config path', function()
      local shell_calls = 0
      mock_shell.safe_shell_command = function(cmd)
        shell_calls = shell_calls + 1
        if cmd == 'llm logs path' then
          return '/home/user/.logs/llm'
        elseif cmd == "dirname '/home/user/.logs/llm'" then
          return '/home/user/.logs'
        end
      end

      file_utils.ensure_config_dir_exists = function() return true end

      local config_dir, path = file_utils.get_config_path('test.json')
      assert.are.equal('/home/user/.logs', config_dir)
      assert.are.equal('/home/user/.logs/test.json', path)
      assert.are.equal(2, shell_calls)

      -- Call again to test caching
      file_utils.get_config_path('test.json')
      assert.are.equal(2, shell_calls) -- No new calls
    end)

    it('should return nil if filename is not provided', function()
      local config_dir, path = file_utils.get_config_path(nil)
      assert.is_nil(config_dir)
      assert.is_nil(path)
    end)

    it('should return nil if llm logs path fails', function()
      mock_shell.safe_shell_command = function() return nil end
      local config_dir, path = file_utils.get_config_path('test.json')
      assert.is_nil(config_dir)
      assert.is_nil(path)
    end)

    it('should return nil if ensure_config_dir_exists fails', function()
      mock_shell.safe_shell_command = function() return '/home/user/.logs/llm' end
      file_utils.ensure_config_dir_exists = function() return false end
      local config_dir, path = file_utils.get_config_path('test.json')
      assert.is_nil(config_dir)
      assert.is_nil(path)
    end)
  end)
end)
