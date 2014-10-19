local tsukuyomi = tsukuyomi
local util = require('tsukuyomi.thirdparty.util')

local PersistentList = tsukuyomi.lang.PersistentList
local EMPTY = PersistentList.EMPTY

local ConcatSeq = {}
tsukuyomi.lang.ConcatSeq = ConcatSeq
ConcatSeq.__index = ConcatSeq
-- This is a persistent data structure :-)
ConcatSeq.__newindex = function(t, k, v)
  -- only self[3] == self._count maybe modified after the fact
  assert(k == 3)
end

-- same reason as mentioned in PersistentList
assert(_G.jit)

function ConcatSeq.new(meta, x, y)
  assert(x.first and x.rest)
  assert(y.first and y.rest)
  return setmetatable({[0] = meta, x, y, nil}, ConcatSeq)
end

function ConcatSeq:meta()
  return self[0]
end

function ConcatSeq:with_meta(meta)
  if self[0] ~= meta then
    return setmetatable({[0] = meta, self[1], self[2], self[3]}, ConcatSeq)
  else
    return self
  end
end

function ConcatSeq:first()
  return self[1]:first()
end

function ConcatSeq:rest()
  local remainder = self[1]:next()
  if remainder == nil then
    return self[2]
  else
    -- it is possible that we might not have triggered self:count() yet, so
    -- don't do it unless the user does it through some operation.
    --
    -- this helps against crazy cases where where count() maybe O(n + m).
    local count = self[3]
    if count then
      count = count - 1
    end
    return setmetatable({[0] = self[0], remainder, self[2], count}, ConcatSeq)
  end
end

-- by the time we reach the count of 1, this will no longer exists since we
-- just return the second part.
ConcatSeq.next = ConcatSeq.rest

function ConcatSeq:count()
  do
    local maybe_count = self[3]
    if maybe_count ~= nil then
      return maybe_count
    end
  end

  local count = self[1]:count() + self[2]:count()
  self[3] = count
  return count
end

function ConcatSeq:cons(datum)
  return PersistentList.new(self[0], datum, self, self:count() + 1)
end

function ConcatSeq:seq()
  return self
end
