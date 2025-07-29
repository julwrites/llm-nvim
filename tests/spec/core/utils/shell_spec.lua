require('tests.spec.spec_helper')

local spy = require('luassert.spy')

describe('llm.core.utils.shell', function()
  local shell = require('llm.core.utils.shell')


  describe('safe_shell_command()', function()
    local original_vim_fn

    before_each(function()
      original_vim_fn = vim.fn
    end)

    after_each(function()
      vim.fn = original_vim_fn
    end)

    it('should call vim.fn.system with the correct command', function()
      local was_called = false
      vim.fn.system = function(cmd)
        was_called = true
        assert.are.equal('ls 2>&1', cmd)
        return ''
      end
      shell.safe_shell_command('ls', 'error')
      assert.is_true(was_called)
    end)

    it('should return the trimmed result', function()
      vim.fn.system = function() return '  result  \n' end
      local result, err = shell.safe_shell_command('ls', 'error')
      assert.are.equal('result', result)
      assert.is_nil(err)
    end)

    it('should return an error if the command returns nil', function()
      vim.fn.system = function() return nil end
      local result, err = shell.safe_shell_command('ls', 'error')
      assert.is_nil(result)
      assert.are.equal('Command returned nil', err)
    end)

    it('should return an error if the command returns an empty string', function()
      vim.fn.system = function() return '' end
      local result, err = shell.safe_shell_command('ls', 'error')
      assert.is_nil(result)
      assert.are.equal('error', err)
    end)
  end)

  describe('command_exists()', function()
    local original_os_execute

    before_each(function()
      original_os_execute = os.execute
    end)

    after_each(function()
      os.execute = original_os_execute
    end)

    it('should return true if command exists', function()
      local was_called = false
      os.execute = function(cmd)
        was_called = true
        assert.are.equal('command -v ls >/dev/null 2>&1', cmd)
        return 0
      end
      assert.is_true(shell.command_exists('ls'))
      assert.is_true(was_called)
    end)

    it('should return false if command does not exist', function()
      os.execute = function() return 1 end
      assert.is_false(shell.command_exists('not-a-command'))
    end)
  end)

  describe('execute()', function()
    local original_io_popen

    before_each(function()
      original_io_popen = io.popen
    end)

    after_each(function()
      io.popen = original_io_popen
    end)

    it('should return output on success', function()
      io.popen = function()
        return {
          read = function() return 'output' end,
          close = function() return true, '', 0 end,
        }
      end
      local output, err = shell.execute('ls')
      assert.are.equal('output', output)
      assert.is_nil(err)
    end)

    it('should return an error on failure', function()
      io.popen = function()
        return {
          read = function() return 'error' end,
          close = function() return false, '', 1 end,
        }
      end
      local output, err = shell.execute('ls')
      assert.is_nil(output)
      assert.are.equal('Command failed', err)
    end)
  end)

  describe('timestamps', function()
    before_each(function()
      vim.fn.isdirectory = function() return 1 end
      vim.fn.mkdir = function() end
    end)

    it('should get and set last update timestamp', function()
      local read_mock = spy.new(function() return '123' end)
      local write_mock = spy.new(function() end)
      local close_mock = spy.new(function() end)

      io.open = function(path, mode)
        if mode == 'r' then
          return { read = read_mock, close = close_mock }
        elseif mode == 'w' then
          return { write = write_mock, close = close_mock }
        end
      end

      assert.are.equal(123, shell.get_last_update_timestamp())
      shell.set_last_update_timestamp()
      assert.spy(write_mock).was.called()
    end)
  end)

  describe('update_llm_cli()', function()
    it('should try different update methods and succeed', function()
      local command_exists_calls = {}
      shell.command_exists = function(cmd)
        table.insert(command_exists_calls, cmd)
        return cmd == 'pipx'
      end

      local run_update_calls = {}
      shell.run_update_command = function(cmd)
        table.insert(run_update_calls, cmd)
        return 'success', 0
      end

      local result = shell.update_llm_cli()

      assert.is_true(result.success)
      assert.are.equal('llm CLI updated successfully via pipx.', result.message)
      assert.are.same({ 'uv', 'pipx' }, command_exists_calls)
      assert.are.same({ 'pipx upgrade llm' }, run_update_calls)
    end)

    it('should try all methods and fail', function()
      shell.command_exists = function() return false end
      shell.run_update_command = function() return 'fail', 1 end

      local result = shell.update_llm_cli()

      assert.is_false(result.success)
      assert.is_not_nil(result.message:find('uv command not found'))
      assert.is_not_nil(result.message:find('pipx command not found'))
    end)
  end)
end)
