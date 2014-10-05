local tsukuyomi = tsukuyomi

local Function = {}
tsukuyomi.lang.Function = Function

function Function.new()
  return setmetatable({}, Function)
end
