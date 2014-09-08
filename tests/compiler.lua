local tsukuyomi = tsukuyomi

local function test(text)
  local datum = tsukuyomi.read(text)
  while datum and datum[1] do
    local code = tsukuyomi.compile(datum[1])
    local chunk, err = loadstring(code, 'asdf')
    if err then
      print(err)
      assert(chunk)
    else
      chunk()
      -- check to make sure all data is consumed, dangling data is bad
      for var, data in pairs(tsukuyomi._data) do assert(false) end
    end

    datum = datum[2]
  end
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

(def print
  (fn [obj]
    (_raw_ "print(tostring(obj))")))

(def first
  (fn [cell]
    (_raw_ "cell[1]")))

(def rest
  (fn [cell]
    (_raw_ "cell[2]")))

(def second
  (fn [coll]
    (first (rest coll))))

(print "asdf")
(print (second '(42 43)))
(print (first '(3 4 5)))

(def user/test "lisp")

]])
