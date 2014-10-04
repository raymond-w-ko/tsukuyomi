local hamt = require('hamt')
local tsukuyomi_lang = tsukuyomi.lang.Namespace.GetNamespaceSpace('tsukuyomi.lang')

local PersistentVector = {}
tsukuyomi_lang.PersistentVector = PersistentVector
PersistentVector.__index = PersistentVector
-- This is a persistent data structure :-)
PersistentVector.__newindex = function()
  assert(false)
end

function PersistentVector.new()
  return setmetatable({_count = 0, hamt = nil}, PersistentVector)
end

function PersistentVector:count()
  return self._count
end

function PersistentVector:assoc(key, value)
  assert(type(key) == 'number')
  assert(key >= 0 and key <= self._count, 'PersistentVector:assoc() out of bounds')

  local hamt = hamt.setHash(key, key, value, self.hamt)
  local count = self._count
  if key == count then
    count = count + 1
  end
  return setmetatable({_count = count, hamt = hamt}, PersistentVector)
end

function PersistentVector:pop()
  assert(self._count > 0, 'PersistentVector:pop() has no more items left')

  local count = self._count - 1
  local hamt = hamt.remove(count, self.hamt)
  return setmetatable({_count = count, hamt = hamt}, PersistentVector)
end

function PersistentVector:conj(x)
  local count = self._count
  local hamt = hamt.setHash(count, count, x, self.hamt)
  local count = count + 1
  return setmetatable({_count = count, hamt = hamt}, PersistentVector)
end

function PersistentVector:nth(index, not_found)
  if index < 0 or index >= self._count then
    if not_found == nil then
      assert(false, 'PersistentVector:nth() out of bounds')
    else
      return not_found
    end
  else
    return hamt.getHash(index, index, self.hamt)
  end
end

function PersistentVector:get(key, not_found)
  return hamt.tryGetHash(not_found, key, key, self.hamt)
end

function PersistentVector.FromLuaArray(array)
  local vec = PersistentVector.new()
  for i = 1, #array do
    vec = vec:conj(array[i])
  end
  return vec
end
