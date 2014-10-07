local tsukuyomi = tsukuyomi
local tsukuyomi_lang = tsukuyomi.lang.Namespace.GetNamespaceSpace('tsukuyomi.lang')

local Symbol = {}
tsukuyomi_lang.Symbol = Symbol
Symbol.__index = Symbol
Symbol.__newindex = function(t, k)
  assert(false, 'attempted to modify tsukuyomi.lang.Symbol')
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

function Symbol.intern(name, namespace, meta)
  return setmetatable({name = name, namespace = namespace, _meta = meta}, Symbol)
end
