-- use metatable tagging to mark a Lua table as a regular array
local kArrayTag = {}

function tsukuyomi.create_array()
  local array = {}
  setmetatable(array, kArrayTag)
  return array
end

function tsukuyomi.is_array(datum)
  if type(datum) ~= 'table' then
    return false
  end
  if getmetatable(datum) ~= kArrayTag then
    return false
  end
  return true
end
