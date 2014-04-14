require('strict')
require('util')
local tsukuyomi = require('tsukuyomi')

local function compile(text)
  local data = tsukuyomi._read(text)
  --print('raw: ' .. table.show(data))

  local output = tsukuyomi.compile(data)
  print(output)

  local f = io.open('compiled.lua', 'wb')
  f:write(output)
  f:close()

  assert(loadstring(output, 'repl'))()

  print('--------------------------------------------------------------------------------')
end

--compile([[]])
--compile([[
--]])

compile([[
(lambda () (+ 2 2))
1
]]
)


--compile([[

--(require "strict")
--(require "util")

--(define square (lambda (x) (* x x)))
--(print (square 2))
--(define square
  --(lambda (x) (* x x))
  --(lambda (x) (* x x))
  --)

--(+ ((lambda () (+ 2 2))) 1)
--(func arg1 arg2 arg3)
--(if cond foo)

--(if cond
  --foo
  --(if bar buzz baz))

--(if cond
  --(do
     --(f1)
     --(f2)
     --(f3)
     --(f4))
  --(if bar
    --buzz
    --baz))

--(cat)

--(lambda (x) (* x x))
--(lambda (y) (+ y y))

--(lambda (x y z) (* x x))

--(lambda (x) (- 1))
--(lambda (x) (- 1 2 x))

--(lambda (x) (/ 2))
--(lambda (x) (/ 3 4 x))


--]]
--)
