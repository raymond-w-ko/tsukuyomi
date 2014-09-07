local tsukuyomi = tsukuyomi

function tsukuyomi.get_namespace(ns)
  tsukuyomi[ns] = tsukuyomi[ns] or {}
  return tsukuyomi[ns]
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
  tsukuyomi['*ns*'] = ns
  return ns
end
