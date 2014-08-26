-- use metatable tagging to mark a Lua table as a Lisp cons cell AKA singly linked list
local kCellTag = {}

function tsukuyomi.create_cell(first, rest)
  local cell = {first, rest}
  setmetatable(cell, kCellTag)
  return cell
end

function tsukuyomi.is_cons_cell(datum)
  if type(datum) ~= 'table' then
    return false
  end
  if getmetatable(datum) ~= kCellTag then
    return false
  end
  return true
end
