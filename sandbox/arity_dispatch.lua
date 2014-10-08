local sum = 0
for i = 1, 1000000000 do
  sum = sum + 1
end

local function f1(x)
  return x + 1
end

local sum = 0
for i = 1, 1000000000 do
  sum = sum + f1(sum)
end

local function f2(x, arg1, arg2, arg3, arg4, arg5)
  return x + 1
end
local sum = 0
for i = 1, 1000000000 do
  sum = sum + f2(sum)
end
print(sum)

local function f3(x, arg1, arg2, arg3, arg4, arg5)
  if arg1 == nil then
    return x + 1
  else
    return x + arg1
  end
end
local sum = 0
for i = 1, 1000000000 do
  sum = sum + f3(sum)
end

print(sum)
