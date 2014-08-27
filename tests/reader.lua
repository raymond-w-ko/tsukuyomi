local tsukuyomi = tsukuyomi

local function test(text)
  local data = tsukuyomi.read(text)
  print(tsukuyomi.print(data))
end

test([[
(-42) (asdf) ((foo)) ((foo) bar ((fuzz)))
]])
test([[
'42 '`''(asdf)
]])

return true
