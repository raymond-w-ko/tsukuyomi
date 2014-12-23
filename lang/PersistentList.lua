local PersistentList = {}

PersistentList.__index = PersistentList
-- This is a persistent data structure :-)
PersistentList.__newindex = function()
  assert(false)
end


-- We have this crazy duplication here since LuaJIT has a penalty free 0-index,
-- but Lua proper does not. This means that Lua proper's 1 index is the same
-- memory location location as LuaJIT's 0 index in the array part of the table
-- data structure
if rawget(_G, 'jit') then
  function PersistentList.new(meta, first, rest, count)
    return setmetatable({[0] = meta, first, rest, count}, PersistentList)
  end

  function PersistentList:meta()
    return self[0]
  end
  function PersistentList:with_meta(meta)
    if self[0] ~= meta then
      return setmetatable({[0] = meta, self[1], self[2], self[3]}, PersistentList)
    else
      return self
    end
  end

  function PersistentList:cons(datum)
    return setmetatable({[0] = self[0], datum, self, self[3] + 1}, PersistentList)
  end
else
  function PersistentList.new(meta, first, rest, count)
    return setmetatable({first, rest, count, meta}, PersistentList)
  end

  function PersistentList:meta()
    return self[4]
  end
  function PersistentList:with_meta(meta)
    if self[4] ~= meta then
      return setmetatable({self[1], self[2], self[3], meta}, PersistentList)
    else
      return self
    end
  end

  function PersistentList:cons(datum)
    return setmetatable({datum, self, self[3] + 1, self[4]}, PersistentList)
  end
end

function PersistentList:first()
  return self[1]
end
function PersistentList:rest()
  return self[2]
end
function PersistentList:next()
  if self[3] == 1 then
    return nil
  else
    return self[2]
  end
end
function PersistentList:count()
  return self[3]
end

function PersistentList:seq()
  return self
end

-- EMPTY list specialization, which is weird
--------------------------------------------------------------------------------

local EmptyList = {}
EmptyList.__index = EmptyList
-- This is a persistent data structure :-)
EmptyList.__newindex = function()
  assert(false)
end

function EmptyList.new(meta)
  return setmetatable({_meta = meta}, EmptyList)
end

function EmptyList:hash_code()
  return 1
end

function EmptyList:first()
  return nil
end
function EmptyList:rest()
  return self
end
function EmptyList:next()
  return nil
end
function EmptyList:empty()
  return self
end
function EmptyList:seq()
  return nil
end
function EmptyList:count()
  return 0
end
function EmptyList:is_empty()
  return true
end

function EmptyList:cons(datum)
  return PersistentList.new(self._meta, datum, self, 1)
end

function EmptyList:meta()
  return self._meta
end
function EmptyList:with_meta(meta)
  if self._meta ~= meta then
    return EmptyList.new(meta)
  else
    return self
  end
end

local EMPTY = EmptyList.new()
PersistentList.EMPTY = EMPTY

--------------------------------------------------------------------------------

if rawget(_G, 'jit') then
  function PersistentList:empty()
    return EMPTY:with_meta(self[0])
  end
else
  function PersistentList:empty()
    return EMPTY:with_meta(self[4])
  end
end

function PersistentList.FromLuaArray(array, len)
  assert(false, 'PersistentList.FromLuaArray(): use ArraySeq instead')
end

function PersistentList:ToLuaArray()
  local array = {}
  local next_slot = 1

  local datum = self

  while datum do
    array[next_slot] = datum:first()
    next_slot = next_slot + 1
    datum = datum:next()
  end

  return array, self[3]
end

return PersistentList
