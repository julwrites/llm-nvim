-- lua/llm/chat/session.lua

local api = require("llm.api")

local M = {}

function M.new(opts)
  local self = setmetatable({}, { __index = M })
  opts = opts or {}
  self.conversation_id = opts.conversation_id or "chat-" .. os.time()
  self.model = opts.model
  self.system_prompt = opts.system_prompt
  self.fragments = opts.fragments
  self.history = {}
  self.state = "ready"
  return self
end

function M:build_command(prompt)
  local config = require("llm.config")
  local llm_executable = config.get("llm_executable_path")

  local cmd_args = { llm_executable }

  if self.model then
    table.insert(cmd_args, "-m")
    table.insert(cmd_args, self.model)
  end

  if self.conversation_id and #self.history > 0 then
    table.insert(cmd_args, "-c")
    table.insert(cmd_args, self.conversation_id)
  elseif self.system_prompt then
    table.insert(cmd_args, "-s")
    table.insert(cmd_args, self.system_prompt)
  end

  return cmd_args
end

function M:extract_conversation_id(output)
  local match = output:match("Conversation ID: (.+)")
  if match then
    return match:gsub("%s+$", "")
  end
  return nil
end

function M:send_prompt(prompt, callbacks)
  self.state = "processing"
  local cmd = self:build_command(prompt)

  table.insert(self.history, { role = "user", content = prompt })
  self.current_job_id = api.run_llm_command(cmd, prompt, callbacks)

  return self.current_job_id
end

function M:is_ready()
  return self.state == "ready"
end

function M:get_conversation_id()
    return self.conversation_id
end

function M:reset_state()
    self.state = "ready"
end

return { ChatSession = M }
