local tsukuyomi = tsukuyomi
local util = require('tsukuyomi.thirdparty.util')

function tsukuyomi.get_namespace(ns)
  local tokens = util.split(ns, '.')
  assert(#tokens >= 1)
  -- support strict.lua
  if _G.__STRICT then
    global(tokens[1])
  end
  local t = _G
  for i = 1, #tokens do
    local ns_chunk = tokens[i]
    if t[ns_chunk] == nil then t[ns_chunk] = {} end
    t = t[ns_chunk]
  end
  return t
end

function tsukuyomi.set_active_namespace(name)
  -- TODO: mimic clojure / python and have a way to import symbols from other namespaces
  -- so you import math / other libraries
  local ns = {}
  local mt = {}
  function mt.__index(t, symbol_name)
    local imported_ns = rawget(t, symbol_name)
    if imported_ns == nil then
      return name
    else
      return imported_ns
    end
  end
  setmetatable(ns, mt)
  tsukuyomi.get_namespace('tsukuyomi.core')['*ns*'] = ns
  return ns
end
