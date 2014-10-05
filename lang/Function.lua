local kFunctionTag = {}

function tsukuyomi.create_function()
  return setmetatable({}, kFunctionTag)
end

function tsukuyomi.is_function(datum)
  return getmetatable(datum) == kFunctionTag
end
