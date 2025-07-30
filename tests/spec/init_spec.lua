local spy = require('luassert.spy')

describe('llm.init', function()
  local llm_init
  local config_mock
  local styles_mock
  local loaders_mock
  local shell_mock

  before_each(function()
    _G.vim = {
      env = {},
      fn = {
        stdpath = function() return "/tmp" end,
        json_encode = function(data) return "" end,
        system = function() end,
      },
      log = {
        levels = {
          INFO = 1,
          WARN = 2,
          ERROR = 3,
        },
      },
      notify = spy.new(function() end),
      defer_fn = function(fn) fn() end,
    }
    package.loaded['llm.managers.plugins_manager'] = {
        refresh_available_plugins = function() end,
    }
    package.loaded['llm.init'] = nil
    package.loaded['llm.config'] = nil
    package.loaded['llm.ui.styles'] = nil
    package.loaded['llm.core.loaders'] = nil
    package.loaded['llm.core.utils.shell'] = nil

    config_mock = {
      setup = spy.new(function() end),
      get = spy.new(function(key)
        if key == 'auto_update_cli' then
          return false
        end
        if key == 'auto_update_interval_days' then
          return 7
        end
        return nil
      end),
    }

    styles_mock = {
      setup_highlights = spy.new(function() end),
    }

    loaders_mock = {
      load_all = spy.new(function() end),
    }

    shell_mock = {
      get_last_update_timestamp = spy.new(function() return 0 end),
      update_llm_cli = spy.new(function() end),
    }

    package.loaded['llm.config'] = config_mock
    package.loaded['llm.ui.styles'] = styles_mock
    package.loaded['llm.core.loaders'] = loaders_mock
    package.loaded['llm.core.utils.shell'] = shell_mock

    llm_init = require('llm.init')
  end)

  after_each(function()
    package.loaded['llm.config'] = nil
    package.loaded['llm.ui.styles'] = nil
    package.loaded['llm.core.loaders'] = nil
    package.loaded['llm.core.utils.shell'] = nil
  end)

  it('should call config.setup with provided options', function()
    local opts = { model = 'test-model' }
    llm_init.setup(opts)
    assert.spy(config_mock.setup).was.called_with(opts)
  end)

  it('should call styles.setup_highlights', function()
    llm_init.setup({})
    assert.spy(styles_mock.setup_highlights).was.called()
  end)

  it('should call loaders.load_all', function()
    llm_init.setup({})
    assert.spy(loaders_mock.load_all).was.called()
  end)

  describe('auto-update', function()
    it('should not check for updates if auto_update_cli is false', function()
      config_mock.get = spy.new(function(key)
        if key == 'auto_update_cli' then
          return false
        end
        return nil
      end)
      llm_init.setup({})
      assert.spy(shell_mock.get_last_update_timestamp).was.not_called()
    end)

    it('should check for updates if auto_update_cli is true and interval has passed', function()
      config_mock.get = spy.new(function(key)
        if key == 'auto_update_cli' then
          return true
        end
        if key == 'auto_update_interval_days' then
          return 7
        end
        return nil
      end)
      shell_mock.get_last_update_timestamp = spy.new(function() return os.time() - (8 * 24 * 60 * 60) end) -- 8 days ago
      vim.defer_fn = function(fn) fn() end
      shell_mock.update_llm_cli = spy.new(function() return { success = true } end)

      llm_init.setup({})

      assert.spy(shell_mock.get_last_update_timestamp).was.called()
      assert.spy(shell_mock.update_llm_cli).was.called()
    end)

    it('should not check for updates if auto_update_cli is true but interval has not passed', function()
      config_mock.get = spy.new(function(key)
        if key == 'auto_update_cli' then
          return true
        end
        if key == 'auto_update_interval_days' then
          return 7
        end
        return nil
      end)
      shell_mock.get_last_update_timestamp = spy.new(function() return os.time() - (6 * 24 * 60 * 60) end) -- 6 days ago

      llm_init.setup({})
      assert.spy(shell_mock.get_last_update_timestamp).was.called()
      assert.spy(shell_mock.update_llm_cli).was.not_called()
    end)
  end)
end)
