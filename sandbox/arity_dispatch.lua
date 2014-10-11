local BOUNDS = 100000000

local sum = 0
for i = 1, BOUNDS do
  sum = sum + 1
end

local function f1(x)
  return x + 1
end

local sum = 0
for i = 1, BOUNDS do
  sum = sum + f1(sum)
end

local function f2(x, arg1, arg2, arg3, arg4, arg5)
  return x + 1
end
local sum = 0
for i = 1, BOUNDS do
  sum = 1 + f2(sum)
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
for i = 1, BOUNDS do
  sum = sum + f3(sum)
end

-- following function can't be jitted
local function f4(...)
  local t = {...}
  return t[1] + t[2] + t[3] + t[4]
end

-- this can be JITed
local function f4(w, x, y, z)
  return w + x + y + z
end
local sum = 0
for i = 1, BOUNDS do
  sum = f4(sum, 1, 1, 1)
end

-- this can be JITed
local function f4(t)
  return t[1] + t[2] + t[3] + t[4]
end
local sum = 0
for i = 1, BOUNDS do
  sum = f4({sum, 1, 1, 1})
end

print(sum)
