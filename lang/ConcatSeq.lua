local PersistentList = require('tsukuyomi.lang.PersistentList')
local EMPTY = PersistentList.EMPTY

local ConcatSeq = {}
ConcatSeq.__index = ConcatSeq
-- This is a persistent data structure :-)
ConcatSeq.__newindex = function()
  -- only self[3] == self._count maybe modified after the fact
  assert(false, 'attempted to modify tsukuyomi.lang.ConcatSeq')
end

-- duplication for the same reason as mentioned in PersistentList

-- (for ConcatSeq:rest())
-- it is possible that we might not have triggered self:count() yet, so
-- don't do it unless the user does it through some operation.
--
-- this helps against crazy cases where where count() maybe O(n + m).
if rawget(_G, 'jit') then
  function ConcatSeq.new(meta, x, y)
    if x == nil then
      assert(y.first)
      return y
    elseif y == nil then
      assert(x.first)
      return x
    else
      assert(x.first)
      assert(y.first)
      return setmetatable({[0] = meta, x, y, nil}, ConcatSeq)
    end
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

  function ConcatSeq:rest()
    local remainder = self[1]:next()
    if remainder == nil then
      return self[2]:with_meta(self[0])
    else
      local count = self[3]
      if count then
        count = count - 1
      end
      return setmetatable({[0] = self[0], remainder, self[2], count}, ConcatSeq)
    end
  end

  function ConcatSeq:cons(datum)
    return PersistentList.new(self[0], datum, self, self:count() + 1)
  end
else
  function ConcatSeq.new(meta, x, y)
    if x == nil then
      assert(y.first)
      return y
    elseif y == nil then
      assert(x.first)
      return x
    else
      assert(x.first)
      assert(y.first)
      return setmetatable({x, y, nil, meta}, ConcatSeq)
    end
  end

  function ConcatSeq:meta()
    return self[4]
  end
  function ConcatSeq:with_meta(meta)
    if self[4] ~= meta then
      return setmetatable({self[1], self[2], self[3], meta}, ConcatSeq)
    else
      return self
    end
  end

  function ConcatSeq:rest()
    local remainder = self[1]:next()
    if remainder == nil then
      return self[2]:with_meta(self[4])
    else
      local count = self[3]
      if count then
        count = count - 1
      end
      return setmetatable({remainder, self[2], count, self[4]}, ConcatSeq)
    end
  end

  function ConcatSeq:cons(datum)
    return PersistentList.new(self[4], datum, self, self:count() + 1)
  end
end

function ConcatSeq:first()
  return self[1]:first()
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
  rawset(self, 3, count)
  return count
end

function ConcatSeq:seq()
  return self
end

return ConcatSeq
