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
-- If you ever use this on original Lua, move "count" to be self[3], otherwise
-- you create an array part as well as a hash part, which would be bad
assert(_G.jit)

function PersistentList.new(first, rest, count)
  return setmetatable({[0] = count, first, rest}, PersistentList)
end

function PersistentList:first()
  return self[1]
end
function PersistentList:rest()
  return self[2]
end
function PersistentList:count()
  return self[0]
end

function PersistentList:cons(datum)
  return PersistentList.new(datum, self, self[0] + 1)
end

local EMPTY = {}
PersistentList.EMPTY = EMPTY
function EMPTY:cons(datum)
  return PersistentList.new(datum, nil, 1)
end
setmetatable(EMPTY, PersistentList)

function PersistentList.FromLuaArray(array, len)
  len = len or #array

  local plist = EMPTY
  for i = len, 1, -1 do
    plist = plist:cons(array[i])
  end
  return plist
end

function PersistentList:ToLuaArray()
  local array = {}
  local next_slot = 1

  local datum = self

  while datum ~= nil and datum ~= EMPTY do
    array[next_slot] = datum:first()
    next_slot = next_slot + 1
    datum = datum:rest()
  end

  return array, self:count()
end
