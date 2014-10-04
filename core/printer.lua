local tsukuyomi = tsukuyomi
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
  end

  local mt = getmetatable(datum)

  if mt == Symbol then
    return tostring(datum)
  elseif mt == PersistentList then
    local items = {}
    while datum do
      if datum:first() ~= nil then
        table.insert(items, tsukuyomi.print(datum[1]))
      end
      datum = datum:rest()
    end
    return '(' .. table.concat(items, ' ') .. ')'
  elseif mt == PersistentVector then
    local items = {}
    for i = 1, datum:count() do
      table.insert(items, tsukuyomi.print(datum:get(i)))
    end
    return '[' .. table.concat(items, ' ') .. ']'
  else
    assert(false)
  end
end
