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
(def z2ljr2jlslfl3jf 1)
]])

-- real test, 2+
test([[
(ns core)
(def a 3)
(def b 4)
(def b a)
]])

test([[
(ns core)

(def first
  (fn (cell)
    (_raw_ "cell[1]")))

(def rest
  (fn (cell)
    (_raw_ "cell[2]")))

]])
