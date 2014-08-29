local tsukuyomi = tsukuyomi

local function test(text)
  local data = tsukuyomi.read(text)
  tsukuyomi.compile(data)
  print('--------------------------------------------------------------------------------')
end

-- empty test
test([[
]])

-- 1 datum test
test([[
(ns core)
]])

-- 2 datum test
test([[
(ns core)
(define z2ljr2jlslfl3jf 1)
]])

-- real test, 2+
test([[
(ns core)
(define a 3)
(define b 4)
]])
