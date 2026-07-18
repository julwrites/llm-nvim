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

function M.embed_multi(opts)
  if type(opts) == 'string' then
    return llm_cli.run_llm_command('embed-multi ' .. opts)
  end
  opts = opts or {}
  if not opts.collection then
    return { success = false, message = "Collection name is required for embed-multi" }
  end

  local cmd = 'embed-multi ' .. vim.fn.shellescape(opts.collection)
  if opts.input_path then
    cmd = cmd .. ' ' .. vim.fn.shellescape(opts.input_path)
  end

  if opts.format then cmd = cmd .. ' --format ' .. vim.fn.shellescape(opts.format) end
  if opts.files_dir and opts.files_pattern then
    cmd = cmd .. ' --files ' .. vim.fn.shellescape(opts.files_dir) .. ' ' .. vim.fn.shellescape(opts.files_pattern)
  end
  if opts.encoding then cmd = cmd .. ' --encoding ' .. vim.fn.shellescape(opts.encoding) end
  if opts.binary then cmd = cmd .. ' --binary' end
  if opts.sql then cmd = cmd .. ' --sql ' .. vim.fn.shellescape(opts.sql) end
  if opts.model then cmd = cmd .. ' -m ' .. vim.fn.shellescape(opts.model) end
  if opts.store then cmd = cmd .. ' --store' end

  return llm_cli.run_llm_command(cmd)
end

function M.similar(opts)
  if type(opts) == 'string' then
    return llm_cli.run_llm_command('similar ' .. opts)
  end
  opts = opts or {}
  if not opts.collection then
    return { success = false, message = "Collection name is required for similar" }
  end

  local cmd = 'similar ' .. vim.fn.shellescape(opts.collection)
  if opts.id then
    cmd = cmd .. ' ' .. vim.fn.shellescape(opts.id)
  end

  if opts.input then cmd = cmd .. ' -i ' .. vim.fn.shellescape(opts.input) end
  if opts.content then cmd = cmd .. ' -c ' .. vim.fn.shellescape(opts.content) end
  if opts.binary then cmd = cmd .. ' --binary' end
  if opts.number then cmd = cmd .. ' -n ' .. tostring(opts.number) end

  return llm_cli.run_llm_command(cmd)
end

function M.collections(opts)
  if type(opts) == 'string' then
    return llm_cli.run_llm_command('collections ' .. opts)
  end
  opts = opts or {}
  local cmd = 'collections'
  if opts.subcommand then
    cmd = cmd .. ' ' .. vim.fn.shellescape(opts.subcommand)
  end
  if opts.args then
    cmd = cmd .. ' ' .. opts.args
  end
  return llm_cli.run_llm_command(cmd)
end

function M.aliases(opts)
  if type(opts) == 'string' then
    return llm_cli.run_llm_command('aliases ' .. opts)
  end
  opts = opts or {}
  local cmd = 'aliases'
  if opts.subcommand then
    cmd = cmd .. ' ' .. vim.fn.shellescape(opts.subcommand)
  end
  if opts.args then
    cmd = cmd .. ' ' .. opts.args
  end
  return llm_cli.run_llm_command(cmd)
end

return M
