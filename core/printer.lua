local util = require('tsukuyomi.thirdparty.util')

local PersistentList = require('tsukuyomi.lang.PersistentList')
local PersistentVector = require('tsukuyomi.lang.PersistentVector')
local PersistentHashMap = require('tsukuyomi.lang.PersistentHashMap')
local ArraySeq = require('tsukuyomi.lang.ArraySeq')
local ConcatSeq = require('tsukuyomi.lang.ConcatSeq')
local Symbol = require('tsukuyomi.lang.Symbol')
local Keyword = require('tsukuyomi.lang.Keyword')
local Var = require('tsukuyomi.lang.Var')

print('PersistentList: ' .. tostring(PersistentList))
print('PersistentList.EMPTY: ' .. tostring(PersistentList.EMPTY))
print('PersistentVector: ' .. tostring(PersistentVector))
print('PersistentHashMap: ' .. tostring(PersistentHashMap))
print('ConcatSeq: ' .. tostring(ConcatSeq))
print('ArraySeq: ' .. tostring(ArraySeq))

-- TODO: add indenting
-- TODO: make not vulnerable to a stack overflow when printing cons cells
-- TODO: make not vulnerable to infinite loop due to self referential data structures
local function _print(datum)
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

  if mt == Symbol or mt == Keyword then
    return tostring(datum)
  elseif mt == PersistentVector then
    local items = {}
    for i = 0, datum:count() - 1 do
      table.insert(items, _print(datum:get(i)))
    end
    return '[' .. table.concat(items, ' ') .. ']'
  elseif mt == PersistentHashMap then
    local items = {}
    local seq = datum:seq()
    while seq and seq:first() ~= nil do
      local kv = seq:first()
      local k = kv:get(0)
      local v = kv:get(1)
      table.insert(items, _print(k))
      table.insert(items, _print(v))
      seq = seq:rest()
    end
    return '{' .. table.concat(items, ' ') .. '}'
  elseif mt == Var then
    return tostring(datum)
  elseif datum.first ~= nil then
    local items = {}

    --while true do
      --if datum:count() == 0 then
        --local check = datum:seq()
        --if check ~= nil then
          --print(getmetatable(datum))
          --print(util.show(datum))
          --assert(false)
        --end
        --break
      --end

      --local item = datum:first()
      --table.insert(items, _print(item))

      --datum = datum:rest()
    --end

    while datum:seq() do
      local item = datum:first()
      table.insert(items, _print(item))
      datum = datum:rest()
    end
    return '(' .. table.concat(items, ' ') .. ')'
  else
    print(util.show(datum))
    assert(false)
  end
end

local tsukuyomi = require('tsukuyomi')
tsukuyomi.print = _print
local core = require('tsukuyomi.core')
local Function = require('tsukuyomi.lang.Function')
core['pr-str'] = Function.new()
core['pr-str'][1] = _print
Var.intern(Symbol.intern('pr-str', 'tsukuyomi.core'))
