-- llm/managers/embeddings_manager.lua - Embeddings management for llm-nvim
-- License: Apache 2.0

local M = {}

local llm_cli = require('llm.core.data.llm_cli')

function M.embed(opts)
  if type(opts) == 'string' then
    return llm_cli.run_llm_command('embed ' .. opts)
  end

  opts = opts or {}
  local cmd_parts = {'embed'}

  if opts.collection then
    table.insert(cmd_parts, vim.fn.shellescape(opts.collection))
  end
  if opts.id then
    table.insert(cmd_parts, vim.fn.shellescape(opts.id))
  end
  if opts.model then
    table.insert(cmd_parts, '-m')
    table.insert(cmd_parts, vim.fn.shellescape(opts.model))
  end
  if opts.input then
    table.insert(cmd_parts, '-i')
    table.insert(cmd_parts, vim.fn.shellescape(opts.input))
  elseif opts.content then
    table.insert(cmd_parts, '-c')
    table.insert(cmd_parts, vim.fn.shellescape(opts.content))
  end
  if opts.format then
    table.insert(cmd_parts, '-f')
    table.insert(cmd_parts, vim.fn.shellescape(opts.format))
  end
  if opts.store then
    table.insert(cmd_parts, '--store')
  end

  return llm_cli.run_llm_command(table.concat(cmd_parts, ' '))
end

function M.embed_models(opts)
  if type(opts) == 'string' then
    return llm_cli.run_llm_command('embed-models ' .. opts)
  end
  opts = opts or {}
  local cmd = 'embed-models'
  if opts.subcommand then
    cmd = cmd .. ' ' .. opts.subcommand
  end
  if opts.args then
    cmd = cmd .. ' ' .. opts.args
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

  local cmd_parts = {'embed-multi', vim.fn.shellescape(opts.collection)}
  if opts.input_path then
    table.insert(cmd_parts, vim.fn.shellescape(opts.input_path))
  end

  if opts.format then
    table.insert(cmd_parts, '--format')
    table.insert(cmd_parts, vim.fn.shellescape(opts.format))
  end
  if opts.files_dir and opts.files_pattern then
    table.insert(cmd_parts, '--files')
    table.insert(cmd_parts, vim.fn.shellescape(opts.files_dir))
    table.insert(cmd_parts, vim.fn.shellescape(opts.files_pattern))
  end
  if opts.encoding then
    table.insert(cmd_parts, '--encoding')
    table.insert(cmd_parts, vim.fn.shellescape(opts.encoding))
  end
  if opts.binary then
    table.insert(cmd_parts, '--binary')
  end
  if opts.sql then
    table.insert(cmd_parts, '--sql')
    table.insert(cmd_parts, vim.fn.shellescape(opts.sql))
  end
  if opts.model then
    table.insert(cmd_parts, '-m')
    table.insert(cmd_parts, vim.fn.shellescape(opts.model))
  end
  if opts.store then
    table.insert(cmd_parts, '--store')
  end

  return llm_cli.run_llm_command(table.concat(cmd_parts, ' '))
end

function M.similar(opts)
  if type(opts) == 'string' then
    return llm_cli.run_llm_command('similar ' .. opts)
  end
  opts = opts or {}
  if not opts.collection then
    return { success = false, message = "Collection name is required for similar" }
  end

  local cmd_parts = {'similar', vim.fn.shellescape(opts.collection)}
  if opts.id then
    table.insert(cmd_parts, vim.fn.shellescape(opts.id))
  end

  if opts.input then
    table.insert(cmd_parts, '-i')
    table.insert(cmd_parts, vim.fn.shellescape(opts.input))
  end
  if opts.content then
    table.insert(cmd_parts, '-c')
    table.insert(cmd_parts, vim.fn.shellescape(opts.content))
  end
  if opts.binary then
    table.insert(cmd_parts, '--binary')
  end
  if opts.number then
    table.insert(cmd_parts, '-n')
    table.insert(cmd_parts, tostring(opts.number))
  end

  return llm_cli.run_llm_command(table.concat(cmd_parts, ' '))
end

function M.collections(opts)
  if type(opts) == 'string' then
    return llm_cli.run_llm_command('collections ' .. opts)
  end
  opts = opts or {}
  local cmd = 'collections'
  if opts.subcommand then
    cmd = cmd .. ' ' .. opts.subcommand
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
    cmd = cmd .. ' ' .. opts.subcommand
  end
  if opts.args then
    cmd = cmd .. ' ' .. opts.args
  end
  return llm_cli.run_llm_command(cmd)
end

return M
