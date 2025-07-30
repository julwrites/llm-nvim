-- llm/core/data/cache.lua - Caching for llm-nvim
-- License: Apache 2.0

local M = {}

local cache_file_path = vim.fn.stdpath('cache') .. '/llm_nvim_cache.json'
local cache = {}

-- Load cache from file
local function load_cache()
  local file = io.open(cache_file_path, "r")
  if file then
    local content = file:read("*all")
    file:close()
    local ok, decoded = pcall(vim.fn.json_decode, content)
    if ok and type(decoded) == 'table' then
      cache = decoded
    else
      -- If decoding fails, initialize an empty cache
      cache = {}
    end
  else
    cache = {}
  end
end

-- Save cache to file
local function save_cache()
  local encoded = vim.fn.json_encode(cache)
  local file = io.open(cache_file_path, "w")
  if file then
    file:write(encoded)
    file:close()
  end
end

-- Initialize cache on module load
load_cache()

function M.get(key)
  return cache[key]
end

function M.set(key, value)
  cache[key] = value
  save_cache()
end

function M.invalidate(key)
  cache[key] = nil
  save_cache()
end

return M