local mock_vim = require('tests.spec.mock_vim')

describe('llm.core.utils.stream', function()
    local stream

    before_each(function()
        mock_vim.setup()
        stream = require('llm.core.utils.stream')
    end)

    after_each(function()
        mock_vim.teardown()
    end)

    it('should call vim.loop.spawn with the correct arguments', function()
        local on_stdout = function() end
        local on_stderr = function() end
        local on_exit = function() end
        stream.stream_command('test command', on_stdout, on_stderr, on_exit)
        assert.spy(vim.loop.spawn).was.called()
    end)
end)
