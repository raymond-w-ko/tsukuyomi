local M = {}
if _G['global'] then
  global('tsukuyomi')
end
tsukuyomi = M

require('tsukuyomi_util')
require('tsukuyomi_linked_list')
require('tsukuyomi_symbol')
require('tsukuyomi_cons_cell')

require('tsukuyomi_printer')

require('tsukuyomi_tokenizer')
require('tsukuyomi_reader')

require('tsukuyomi_ir_compiler')
require('tsukuyomi_lua_compiler')
require('tsukuyomi_compiler')

-- TODO: is there a better to pass quoted data?
tsukuyomi._data = {}
function tsukuyomi._consume_data(key)
  local data = tsukuyomi._data[key]
  tsukuyomi._data[key] = nil
  return data
end

return tsukuyomi
