local M = {}
-- support strict.lua
if _G.__STRICT then
  global('tsukuyomi')
end
tsukuyomi = M

require('tsukuyomi.core.namespace')
require('tsukuyomi.core.linked_list')
require('tsukuyomi.core.symbol')
require('tsukuyomi.core.cons_cell')
require('tsukuyomi.core.array')
require('tsukuyomi.core.function')

require('tsukuyomi.core.printer')

require('tsukuyomi.core.tokenizer')
require('tsukuyomi.core.reader')

require('tsukuyomi.core.ir_compiler')
require('tsukuyomi.core.lua_compiler')
require('tsukuyomi.core.compiler')

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

return tsukuyomi
