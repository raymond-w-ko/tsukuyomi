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
  return setmetatable({count = 0, hamt = nil}, PersistentVector)
end

function PersistentVector:assoc(k, v)
  assert(type(k) == 'number')
  assert(k >= 0 and k <= self.count, 'PersistentVector:assoc() out of bounds')

  local hamt = hamt.setHash(k, k, v, self.hamt)
  local count = self.count
  if k == count then
    count = count + 1
  end
  return setmetatable({count = count, hamt = hamt}, PersistentVector)
end

function PersistentVector:pop()
  assert(self.count > 0)

  local count = self.count - 1
  local hamt = hamt.remove(count, self.hamt)
  return setmetatable({count = count, hamt = hamt}, PersistentVector)
end

function PersistentVector:conj(x)
  local count = self.count + 1
  local hamt = hamt.setHash(count, count, x, self.hamt)
  return setmetatable({count = count, hamt = hamt}, PersistentVector)
end

function PersistentVector:nth(index, not_found)
  if index < 0 or index >= self.count then
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
