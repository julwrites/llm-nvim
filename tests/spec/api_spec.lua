
describe("api", function()
  local api
  local job_mock

  before_each(function()
    package.loaded["llm.api"] = nil
    package.loaded["llm.core.utils.job"] = nil
    require("spec_helper")

    job_mock = {
      run = spy.new(function() end),
    }
    package.loaded["llm.core.utils.job"] = job_mock

    api = require("llm.api")
  end)

  describe("run_streaming_command", function()
    it("should call job.run with the correct command and callbacks", function()
      -- Arrange
      local command_parts = { "llm", "prompt", "hello" }
      local callbacks = {
        on_stdout = function() end,
        on_stderr = function() end,
        on_exit = function() end,
      }
      job_mock.run = spy.new(function() return 123 end)

      -- Act
      local result = api.run_streaming_command(command_parts, "test prompt", callbacks)

      -- Assert
      assert.spy(job_mock.run).was.called_with(command_parts, callbacks)
      assert.are.equal(result, 123)
    end)

    it("should call jobsend and jobclose when a prompt is provided", function()
      -- Arrange
      local command_parts = { "llm", "prompt", "hello" }
      local callbacks = {}
      job_mock.run = spy.new(function() return 123 end)
      local jobsend_spy = spy.on(vim.fn, "jobsend")
      jobsend_spy.revert = function() end
      local jobclose_spy = spy.on(vim.fn, "jobclose")
      jobclose_spy.revert = function() end

      -- Act
      api.run_streaming_command(command_parts, "test prompt", callbacks)

      -- Assert
      assert.spy(jobsend_spy).was.called_with(123, "test prompt")
      assert.spy(jobclose_spy).was.called_with(123, "stdin")
    end)

    it("should not call jobsend when prompt is nil or empty", function()
      -- Arrange
      local command_parts = { "llm", "prompt", "hello" }
      local callbacks = {}
      job_mock.run = spy.new(function() return 123 end)
      local jobsend_spy = spy.on(vim.fn, "jobsend")
      jobsend_spy.revert = function() end

      -- Act
      api.run_streaming_command(command_parts, nil, callbacks)
      api.run_streaming_command(command_parts, "", callbacks)

      -- Assert
      assert.spy(jobsend_spy).was.not_called()
    end)
  end)

  describe("job chunking and accumulation", function()
    local real_job

    local old_jobstart

    before_each(function()
      package.loaded["llm.core.utils.job"] = nil
      real_job = require("llm.core.utils.job")

      old_jobstart = _G.vim.fn.jobstart
      _G.vim.fn.jobstart = function(cmd, opts)
        _G._sim_job_opts = opts
        return 1
      end
    end)

    after_each(function()
      _G.vim.fn.jobstart = old_jobstart
    end)

    it("handles Neovim data arrays and split lines without truncation", function()
      local stdout_lines = {}
      real_job.run({"dummy"}, {
        on_stdout = function(err, lines)
          for _, line in ipairs(lines) do
            table.insert(stdout_lines, line)
          end
        end
      })

      -- Neovim passes split lines. If the final chunk has no newline,
      -- the last element is that partial line. If it has a newline,
      -- the last element is an empty string.
      _G._sim_job_opts.on_stdout(1, {"line1", "line2", "part"})
      _G._sim_job_opts.on_stdout(1, {"ial", "line3", ""})
      _G._sim_job_opts.on_exit(1, 0)

      assert.are.same({"line1", "line2", "partial", "line3"}, stdout_lines)
    end)
  end)
end)
