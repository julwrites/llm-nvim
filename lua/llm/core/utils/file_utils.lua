local M = {}

local config = require('llm.config')
local shell = require('llm.utils.shell')

-- Pure path utilities --------------------------------------------------------

local function trim_path(path)
  return path and path:gsub("[\r\n]+$", ""):gsub("%s+$", "") or nil
end

local function join_path(dir, file)
  return dir and file and dir .. "/" .. file or nil
end

local function debug_log(message, level)
  if config.get('debug') then
    vim.notify(message, level or vim.log.levels.DEBUG)
  end
end

-- Directory operations -------------------------------------------------------

local config_dir_cache = nil

local function with_directory(dir, action)
  if not dir or dir == "" then return false end

  local test_file = join_path(dir, ".llm_nvim_test")
  local success, err = pcall(function()
    local f = io.open(test_file, "a")
    if not f then return false end
    f:close()

    if action == "test" then
      os.remove(test_file)
      return true
    elseif action == "create" then
      local mkdir_cmd = string.format("mkdir -p '%s'", dir)
      return os.execute(mkdir_cmd) == 0
    end
    return false
  end)

  return success and err ~= false
end

local function test_directory_writable(dir)
  return with_directory(dir, "test")
end

local function create_directory(dir)
  if with_directory(dir, "create") then
    debug_log("Created directory: " .. dir)
    return true
  else
    vim.notify("Failed to create directory: " .. dir, vim.log.levels.ERROR)
    return false
  end
end

function M.ensure_config_dir_exists(dir)
  return dir and (test_directory_writable(dir) or create_directory(dir))
end

-- Config path resolution -----------------------------------------------------

local function resolve_config_dir()
  local logs_path = trim_path(shell.safe_shell_command(
    "llm logs path",
    "Failed to get LLM logs path"
  ))
  if not logs_path then return nil end

  debug_log("Found logs path: " .. logs_path)
  return trim_path(shell.safe_shell_command(
    string.format("dirname '%s'", logs_path),
    "Failed to get config directory"
  ))
end

function M.get_config_path(filename)
  if not filename then return nil, nil end

  -- Use cached config directory if available
  if config_dir_cache then
    local path = join_path(config_dir_cache, filename)
    debug_log("Using cached path: " .. path)
    return config_dir_cache, path
  end

  -- Resolve fresh config directory
  local config_dir = resolve_config_dir()
  if not config_dir then return nil, nil end

  -- Ensure directory exists and cache it
  if M.ensure_config_dir_exists(config_dir) then
    config_dir_cache = config_dir
    local path = join_path(config_dir, filename)

    debug_log("Final path: " .. path)
    debug_log("File " .. (io.open(path, "r") and "exists" or "does not exist"))
    return config_dir, path
  end

  return nil, nil
end

return M
