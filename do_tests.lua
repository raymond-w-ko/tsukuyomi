require('strict')
require('util')
local tsukuyomi = require('tsukuyomi')

local function compile(text)
  local data = tsukuyomi.core._read(text)
  print()
  print(tsukuyomi.core._print(data))

  local output = tsukuyomi.core._compile(data)
  print()
  print(output)

  print('--------------------------------------------------------------------------------')
end

compile([[
(require "strict")
(require "util")

(:sub str1 1 2)
(:len str2)

(.concat table t1 t2)
(.show table t)

(func arg1 arg2 arg3)

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

]]
)
