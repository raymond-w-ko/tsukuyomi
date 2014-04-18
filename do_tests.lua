require('strict')
require('util')
local tsukuyomi = require('tsukuyomi')

local function compile(text)
  local datum = tsukuyomi._read(text)
  print(tsukuyomi._print(datum))
  print()

  local output = tsukuyomi.compile(datum)
  print(output)
end

--compile([[]])
--compile([[
--]])

compile(
[[
(func a b c d)
(print "stuff" "more stuff" "even more stuff")
(f1 (f2 a) b c d)
(f1 (f2 (f3 a) b) c d e)
(f1 (f2 (f3 a) b) c (f5 x y z) (f8 i (foo bar baz) k))

]])


--compile([[

--(require "strict")
--(require "util")

--(lambda (x) (* x x))
--(lambda (y) (+ y y))

--(lambda (x y z) (* x x))

--(lambda (x) (- 1))
--(lambda (x) (- 1 2 x))

--(lambda (x) (/ 2))
--(lambda (x) (/ 3 4 x))


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


--]]
--)
