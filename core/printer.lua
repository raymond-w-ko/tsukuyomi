local tsukuyomi = tsukuyomi
local PersistentList = tsukuyomi.lang.PersistentList
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
  elseif getmetatable(datum) == Symbol then
    return tostring(datum)
  elseif tsukuyomi.is_array(datum) then
    local items = {}
    for i = 1, #datum do
      table.insert(items, tsukuyomi.print(datum[i]))
    end
    return '[' .. table.concat(items, ' ') .. ']'
  elseif getmetatable(datum) == PersistentList then
    local items = {}
    while datum do
      if datum[1] ~= nil then
        table.insert(items, tsukuyomi.print(datum[1]))
      end
      datum = datum[2]
    end
    return '(' .. table.concat(items, ' ') .. ')'
  else
    assert(false)
  end
end
