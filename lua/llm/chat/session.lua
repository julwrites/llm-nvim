-- lua/llm/chat/session.lua

local api = require("llm.api")

local M = {}

function M.new(opts)
  local self = setmetatable({}, { __index = M })
  opts = opts or {}
  self.conversation_id = opts.conversation_id or "chat-" .. os.time()
  self.model = opts.model
  self.system_prompt = opts.system_prompt
  self.history = {}
  return self
end

function M:send_prompt(prompt, callbacks)
  table.insert(self.history, { role = "user", content = prompt })

  local cmd_args = { "prompt" }
  table.insert(cmd_args, "-c")
  table.insert(cmd_args, self.conversation_id)

  if self.model then
    table.insert(cmd_args, "--model")
    table.insert(cmd_args, self.model)
  end

  if self.system_prompt and #self.history == 1 then
    table.insert(cmd_args, "--system")
    table.insert(cmd_args, self.system_prompt)
  end
  
  table.insert(cmd_args, prompt)

  return api.run(cmd_args, callbacks)
end

function M:is_ready()
    return true
end

function M:get_conversation_id()
    return self.conversation_id
end

return M
