local tsukuyomi = tsukuyomi
local util = require('tsukuyomi.thirdparty.util')
local PersistentList = tsukuyomi.lang.PersistentList
local PersistentVector = tsukuyomi.lang.PersistentVector
local PersistentHashMap = tsukuyomi.lang.PersistentHashMap
local Symbol = tsukuyomi.lang.Symbol

-- TODO: add indenting
-- TODO: make not vulnerable to a stack overflow when printing cons cells
-- TODO: make not vulnerable to infinite loop due to self referential data structures
function tsukuyomi.print(datum)
  if type(datum) == 'boolean' then
    return tostring(datum)
  elseif type(datum) == 'number' then
    return tostring(datum)
  elseif type(datum) == 'string' then
    return '"' .. datum .. '"'
  elseif datum == nil then
    return 'nil'
  end

  local mt = getmetatable(datum)

  if mt == Symbol then
    return tostring(datum)
  elseif mt == PersistentList then
    local items = {}
    while datum ~= nil and datum ~= PersistentList.EMPTY do
      local item = datum:first()
      table.insert(items, tsukuyomi.print(item))
      datum = datum:rest()
    end
    return '(' .. table.concat(items, ' ') .. ')'
  elseif mt == PersistentVector then
    local items = {}
    for i = 0, datum:count() - 1 do
      table.insert(items, tsukuyomi.print(datum:get(i)))
    end
    return '[' .. table.concat(items, ' ') .. ']'
  elseif mt == PersistentHashMap then
    local items = {}
    local seq = datum:seq()
    while seq and seq:first() ~= nil do
      local kv = seq:first()
      table.insert(items, kv:get(0))
      table.insert(items, kv:get(1))
      seq = seq:rest()
    end
    return '{' .. table.concat(items, ' ') .. '}'
  else
    print(util.show(datum))
    assert(false)
  end
end
