local util = require('tsukuyomi.thirdparty.util')
local tsukuyomi_lang = tsukuyomi.lang.Namespace.GetNamespaceSpace('tsukuyomi.lang')
local PersistentList = tsukuyomi.lang.PersistentList
local EMPTY = PersistentList.EMPTY

-- ArraySeq transforms a Lua array into something like a PersistentList in
-- constant time, and uses a cursor to maintain state for first and rest,
-- basically like a lazy version.
--
-- This is necessary to maintain speed in (read)ing and destructuring of
-- function call argument [& rest]
local ArraySeq = {}
tsukuyomi_lang.ArraySeq = ArraySeq
ArraySeq.__index = ArraySeq
-- This is a persistent data structure :-)
ArraySeq.__newindex = function()
  assert(false)
end

-- same reason as mentioned in PersistentList
assert(_G.jit)

function ArraySeq.new(meta, array, cursor, count)
  assert(array)
  assert(cursor)
  assert(count)
  return setmetatable({[0] = meta, array, cursor, count}, ArraySeq)
end

function ArraySeq:meta()
  return self[0]
end
function ArraySeq:with_meta(meta)
  if self[0] ~= meta then
    return setmetatable({[0] = meta, self[1], self[2], self[3]}, ArraySeq)
  else
    return self
  end
end

function ArraySeq:first()
  return self[1][self[2]]
end

function ArraySeq:rest()
  if self[3] == 1 then
    return EMPTY:with_meta(self[0])
  else
    return setmetatable({[0] = self[0], self[1], self[2] + 1, self[3] - 1}, ArraySeq)
  end
end

function ArraySeq:next()
  if self[3] == 1 then
    return nil
  else
    
    return setmetatable({[0] = self[0], self[1], self[2] + 1, self[3] - 1}, ArraySeq)
  end
end

function ArraySeq:count()
  return self[3]
end

function ArraySeq:cons(datum)
  return PersistentList.new(self[0], datum, self, self[3] + 1)
end

function ArraySeq:empty()
  return EMPTY:with_meta(self[0])
end

function ArraySeq:ToLuaArray()
  local out = {}
  local next_slot = 1

  local cursor = self[2]
  local count = self[3]
  local len = count - cursor + 1
  local data_array = self[1]

  for i = cursor, count do
    out[next_slot] = data_array[i]
    next_slot = next_slot + 1
  end

  return out, len
end
