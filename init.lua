local M = {}
if _G['global'] then
  global('tsukuyomi')
end
tsukuyomi = M

require('tsukuyomi.core.util')
require('tsukuyomi.core.linked_list')
require('tsukuyomi.core.symbol')
require('tsukuyomi.core.cons_cell')
require('tsukuyomi.core.array')
require('tsukuyomi.core.namespace')

require('tsukuyomi.core.printer')

require('tsukuyomi.core.tokenizer')
require('tsukuyomi.core.reader')

require('tsukuyomi.core.ir_compiler')
require('tsukuyomi.core.lua_compiler')
require('tsukuyomi.core.compiler')

tsukuyomi._data = {}
function tsukuyomi._get_data(key)
  local data = tsukuyomi._data[key]
  tsukuyomi._data[key] = nil
  return data
end

return tsukuyomi
