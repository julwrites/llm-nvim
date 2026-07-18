-- llm/managers/embeddings_manager.lua - Embeddings management for llm-nvim
-- License: Apache 2.0

local M = {}

local llm_cli = require('llm.core.data.llm_cli')

function M.embed(opts)
  if type(opts) == 'string' then
    return llm_cli.run_llm_command('embed ' .. opts)
  end

  opts = opts or {}
  local cmd = 'embed'

  if opts.collection then
    cmd = cmd .. ' ' .. vim.fn.shellescape(opts.collection)
  end
  if opts.id then
    cmd = cmd .. ' ' .. vim.fn.shellescape(opts.id)
  end
  if opts.model then
    cmd = cmd .. ' -m ' .. vim.fn.shellescape(opts.model)
  end
  if opts.input then
    cmd = cmd .. ' -i ' .. vim.fn.shellescape(opts.input)
  elseif opts.content then
    cmd = cmd .. ' -c ' .. vim.fn.shellescape(opts.content)
  end
  if opts.format then
    cmd = cmd .. ' -f ' .. vim.fn.shellescape(opts.format)
  end
  if opts.store then
    cmd = cmd .. ' --store'
  end

  return llm_cli.run_llm_command(cmd)
end

return M
