local tsukuyomi_lang = tsukuyomi.lang.Namespace.GetNamespaceSpace('tsukuyomi.lang')

local PersistentList = {}
tsukuyomi_lang.PersistentList = PersistentList
PersistentList.__index = PersistentList
-- This is a persistent data structure :-)
PersistentList.__newindex = function()
  assert(false)
end

-- Since I only use LuaJIT so far, take advantage of the fact that all array
-- parts have a 0 index part. Like when you have {"foo", "bar"}, you actually
-- have an array part of size 3.
--
-- Since the basis of Lisp is linked lists, this will serve to conserve memory.
--
-- If you ever use this on original Lua, move "meta" to be self[4], otherwise
-- you create an array part as well as a hash part, which would be a waste of memory.
assert(_G.jit)

function PersistentList.new(meta, first, rest, count)
  return setmetatable({[0] = meta, first, rest, count}, PersistentList)
end

function PersistentList:meta()
  return self[0]
end
function PersistentList:with_meta(meta)
  if self[0] ~= meta then
    return PersistentList.new(meta, self[1], self[2], self[3])
  else
    return self
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

function PersistentList:cons(datum)
  return PersistentList.new(self[0], datum, self, self[3] + 1)
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
function EmptyList:count()
  return 0
end
function EmptyList:is_empty()
  return true
end

function EmptyList:cons(datum)
  return PersistentList.new(self._meta, datum, nil, 1)
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

function PersistentList:empty()
  return EMPTY:with_meta(self[0])
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
