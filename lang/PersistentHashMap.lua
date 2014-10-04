local hamt = require('hamt')
local hash = hamt.hash
local tsukuyomi_lang = tsukuyomi.lang.Namespace.GetNamespaceSpace('tsukuyomi.lang')
local PersistentVector = tsukuyomi.lang.PersistentVector
local PersistentList = tsukuyomi.lang.PersistentList

local PersistentHashMap = {}
tsukuyomi_lang.PersistentHashMap = PersistentHashMap
PersistentHashMap.__index = PersistentHashMap
-- This is a persistent data structure :-)
PersistentHashMap.__newindex = function()
  assert(false)
end

function PersistentHashMap.new()
  return setmetatable({hamt = nil}, PersistentHashMap)
end

function PersistentHashMap:assoc(key, value)
  assert(type(key) == 'string', 'PersistentHashMap:assoc() only accepts string keys right now')

  local hamt = hamt.setHash(hash(key), key, value, self.hamt)
  return setmetatable({hamt = hamt}, PersistentHashMap)
end

function PersistentHashMap:get(key)
  assert(type(key) == 'number', 'PersistentHashMap:get() only accepts string keys right now')
  return hamt.tryGetHash(not_found, hash(key), key, self.hamt)
end

function PersistentHashMap:conj(vec)
  assert(getmetatable(vec) == PersistentVector,
         'PersistentHashMap:conj() only accepts a PersistentVector argument')
  assert(vec:count() == 2, 'PersistentHashMap:conj() argument must be a vector of length 2')
  local key = vec:get(0)
  local value = vec:get(1)
  return self:assoc(key, value)
end

function PersistentHashMap:count()
  return hamt.count(self.hamt)
end

local table_insert = table.insert
local function build_key_value_fn(collection_array, item)
  table_insert(collection_array, PersistentVector.FromLuaArray({item.key, item.value}))
  return collection_array
end

function PersistentHashMap:seq()
  -- TODO: make this more efficient
  local array = hamt.fold(build_key_value_fn, {}, self.hamt)
  return PersistentList.FromLuaArray(array)
end

function PersistentHashMap.FromLuaArray(array, len)
  len = len or #array

  local m = PersistentHashMap.new()
  for i = 1, len - 1, 2 do
    local key = array[i]
    local value = array[i + 1]
    m = m:assoc(key, value)
  end

  return m
end
