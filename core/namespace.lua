local tsukuyomi = tsukuyomi
local util = require('tsukuyomi.thirdparty.util')

local namespace_cache = setmetatable({}, {__mode = 'kv'})

-- namespaces are just a series of table starting from the global table
-- therefore tsukuyomi.core == _G.tsukuyomi.core == _G["tsukuyomi"]["core"]
function tsukuyomi.get_namespace(ns)
  local t = namespace_cache[ns]
  if t then return t end
  
  local tokens = util.split(ns, '.')
  assert(#tokens >= 1)
  -- support strict.lua
  if _G.__STRICT then
    global(tokens[1])
  end
  local t = _G
  for i = 1, #tokens do
    local ns_chunk = tokens[i]
    if t[ns_chunk] == nil then
      t[ns_chunk] = {}
    end
    t = t[ns_chunk]
  end
  namespace_cache[ns] = t
  return t
end

-- the namespace argument is just a string like "tsukuyomi.core"
function tsukuyomi.set_active_namespace(namespace)
  -- TODO: mimic clojure / python and have a way to import symbols from other namespaces
  -- so you import math / other libraries
  local ns = {}
  local mt = {}
  function mt.__index(t, symbol_name)
    local imported_ns = rawget(t, symbol_name)
    if imported_ns == nil then
      return namespace
    else
      return imported_ns
    end
  end
  setmetatable(ns, mt)
  tsukuyomi.get_namespace('tsukuyomi.core')['*ns*'] = ns
  return ns
end
