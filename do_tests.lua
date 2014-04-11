require('strict')
require('util')
local tsukuyomi = require('tsukuyomi')

local function compile(text)
  local data = tsukuyomi._read(text)
  print()
  --print('raw: ' .. table.show(data))

  local output = tsukuyomi.compile(data)
  print()
  print(output)

  print('--------------------------------------------------------------------------------')
end

compile([[]])
compile([[
]])

compile([[
(require "strict")
(require "util")

(func arg1 arg2 arg3)

(if cond
  foo)

(if cond
  foo
  (if bar buzz baz))

(if cond
  (do
     (f1)
     (f2)
     (f3)
     (f4))
  (if bar
    buzz
    baz))

(cat)

(lambda (x) (* x x))
(lambda (y) (+ y y))

(lambda (x y z) (* x x))

(lambda (x) (- 1))
(lambda (x) (- 1 2 x))

(lambda (x) (/ 2))
(lambda (x) (/ 3 4 x))

]]
)
