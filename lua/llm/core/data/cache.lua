-- llm/core/data/cache.lua - Caching for llm-nvim
-- License: Apache 2.0

local M = {}

local cache = {}

function M.get(key)
    return cache[key]
end

function M.set(key, value)
    cache[key] = value
end

function M.invalidate(key)
    cache[key] = nil
end

return M
