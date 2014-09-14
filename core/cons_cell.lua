-- use metatable tagging to mark a Lua table as a Lisp cons cell AKA singly linked list
local kCellTag = {}

function tsukuyomi.create_cell(first, rest)
  local cell = {first, rest}
  setmetatable(cell, kCellTag)
  return cell
end

function tsukuyomi.is_cons_cell(datum)
  return getmetatable(datum) == kCellTag
end

function tsukuyomi.cons_to_lua_array(datum)
  local arr = {}
  while datum and datum[1] do
    table.insert(arr, datum[1])
    datum = datum[2]
  end
  return arr
end
