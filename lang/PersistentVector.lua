local hamt = require('hamt')
local PersistentVectorSeq = require('tsukuyomi.lang.PersistentVectorSeq')

local PersistentVector = {}
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

function PersistentVector.FromLuaArray(array, len)
  len = len or #array

  local vec = PersistentVector.new()
  for i = 1, len do
    vec = vec:conj(array[i])
  end
  return vec
end

function PersistentVector:ToLuaArray()
  local array = {}
  local next_slot = 1

  for i = 0, self._count - 1 do
    array[next_slot] = self:get(i)
    next_slot = next_slot + 1
  end

  return array
end

function PersistentVector:meta()
  return self._meta
end

function PersistentVector:with_meta(m)
  return setmetatable({_count = self._count, hamt = self.hamt, _meta = m}, PersistentVector)
end

function PersistentVector:seq()
  return PersistentVectorSeq.new(self._meta, self, 0, self._count)
end

return PersistentVector
