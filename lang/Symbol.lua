local hamt = require('hamt')

local Symbol = {}
Symbol.__index = Symbol
Symbol.__newindex = function()
  assert(false, 'attempted to modify tsukuyomi.lang.Symbol')
end

function Symbol.intern(name, namespace, meta)
  return setmetatable({name = name, namespace = namespace, _meta = meta}, Symbol)
end

function Symbol:__tostring()
  if self.namespace then
    return table.concat({self.namespace, '/', self.name})
  else
    return self.name
  end
end

function Symbol.__eq(a, b)
  return a.name == b.name and a.namespace == b.namespace
end

function Symbol:meta()
  return self._meta
end

function Symbol:with_meta(m)
  return Symbol.intern(self.name, self.namespace, m)
end

local hash_fn = hamt.hash

function Symbol:hasheq()
  if self._hasheq == nil then
    rawset(self, '_hasheq', hash_fn(tostring(self)))
  end
  return self._hasheq
end

return Symbol
