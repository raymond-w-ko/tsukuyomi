local M = {}
-- support strict.lua
if _G.__STRICT then
  global('tsukuyomi')
end
tsukuyomi = M

require('tsukuyomi.lang.Namespace')
-- loaded by Namespace due to somewhat complicated initialization order
--require('tsukuyomi.lang.Symbol')

require('tsukuyomi.lang.PushbackReader')

require('tsukuyomi.lang.PersistentList')
require('tsukuyomi.lang.ArraySeq')
require('tsukuyomi.lang.PersistentVectorSeq')
require('tsukuyomi.lang.PersistentVector')
require('tsukuyomi.lang.PersistentHashMap')

require('tsukuyomi.lang.Function')
require('tsukuyomi.lang.Var')

require('tsukuyomi.core.printer')

require('tsukuyomi.core.reader')

require('tsukuyomi.core.ir_compiler')
require('tsukuyomi.core.lua_compiler')
require('tsukuyomi.core.compiler')
require('tsukuyomi.core.eval')

--------------------------------------------------------------------------------
-- structures to store data from reader to compiler and evalulation
--------------------------------------------------------------------------------

local available_data_keys = {}
local data_key_counter = 1
tsukuyomi._data_store = {}
local data_store = tsukuyomi._data_store

function tsukuyomi.retrieve_data(key)
  local datum = data_store[key]
  data_store[key] = nil
  table.insert(available_data_keys, key)
  return datum
end

function tsukuyomi.store_data(datum)
  local data_key
  if #available_data_keys == 0 then
    data_key = data_key_counter
    data_key_counter = data_key_counter + 1
  else
    data_key = table.remove(available_data_keys)
  end

  data_store[data_key] = datum

  return data_key
end

--------------------------------------------------------------------------------
-- We can finally load Lisp :-)
--------------------------------------------------------------------------------
tsukuyomi.core['load-file'][1]('tsukuyomi/core/bootstrap.tsu')

return tsukuyomi
