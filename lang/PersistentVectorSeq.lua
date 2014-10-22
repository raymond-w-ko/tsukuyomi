local tsukuyomi = tsukuyomi
local util = require('tsukuyomi.thirdparty.util')

local PersistentList = tsukuyomi.lang.PersistentList
local EMPTY = PersistentList.EMPTY

local PersistentVectorSeq = {}
tsukuyomi.lang.PersistentVectorSeq = PersistentVectorSeq
PersistentVectorSeq.__index = PersistentVectorSeq
-- This is a persistent data structure :-)
PersistentVectorSeq.__newindex = function()
  assert(false)
end

-- duplication for the same reason as mentioned in PersistentList
if rawget(_G, 'jit') then
  function PersistentVectorSeq.new(meta, vector, cursor, count)
    if count == 0 then
      return EMPTY:with_meta(meta)
    end
    return setmetatable({[0] = meta, vector, cursor, count}, PersistentVectorSeq)
  end

  function PersistentVectorSeq:meta()
    return self[0]
  end
  function PersistentVectorSeq:with_meta(meta)
    if self[0] ~= meta then
      return setmetatable({[0] = meta, self[1], self[2], self[3]}, PersistentVectorSeq)
    else
      return self
    end
  end

  function PersistentVectorSeq:rest()
    if self[3] == 1 then
      return EMPTY:with_meta(self[0])
    else
      return setmetatable({[0] = self[0], self[1], self[2] + 1, self[3] - 1}, PersistentVectorSeq)
    end
  end

  function PersistentVectorSeq:next()
    if self[3] == 1 then
      return nil
    else

      return setmetatable({[0] = self[0], self[1], self[2] + 1, self[3] - 1}, PersistentVectorSeq)
    end
  end

  function PersistentVectorSeq:cons(datum)
    return PersistentList.new(self[0], datum, self, self[3] + 1)
  end

  function PersistentVectorSeq:empty()
    return EMPTY:with_meta(self[0])
  end
else
  function PersistentVectorSeq.new(meta, vector, cursor, count)
    if count == 0 then
      return EMPTY:with_meta(meta)
    end
    return setmetatable({vector, cursor, count, meta}, PersistentVectorSeq)
  end

  function PersistentVectorSeq:meta()
    return self[4]
  end
  function PersistentVectorSeq:with_meta(meta)
    if self[4] ~= meta then
      return setmetatable({self[1], self[2], self[3], meta}, PersistentVectorSeq)
    else
      return self
    end
  end

  function PersistentVectorSeq:rest()
    if self[3] == 1 then
      return EMPTY:with_meta(self[4])
    else
      return setmetatable({self[1], self[2] + 1, self[3] - 1, self[4]}, PersistentVectorSeq)
    end
  end

  function PersistentVectorSeq:next()
    if self[3] == 1 then
      return nil
    else

      return setmetatable({self[1], self[2] + 1, self[3] - 1, self[4]}, PersistentVectorSeq)
    end
  end

  function PersistentVectorSeq:cons(datum)
    return PersistentList.new(self[4], datum, self, self[3] + 1)
  end

  function PersistentVectorSeq:empty()
    return EMPTY:with_meta(self[4])
  end
end

function PersistentVectorSeq:first()
  return self[1]:get(self[2])
end

function PersistentVectorSeq:count()
  return self[3]
end

function PersistentVectorSeq:seq()
  return self
end

function PersistentVectorSeq:ToLuaArray()
  local out = {}
  local next_slot = 1

  local cursor = self[2]
  local count = self[3]
  local len = count - cursor + 1
  local vector = self[1]

  for i = cursor, count - 1 do
    out[next_slot] = vector:get(i)
    next_slot = next_slot + 1
  end

  return out, len
end
