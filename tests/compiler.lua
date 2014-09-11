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

(def +
  (fn [x y]
    (_raw_ "x + y")))

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

(def f (fn [foo]
  ((fn [bar] (+ foo bar)) 42)))

(print (f 43))

(if false (print "pepperoni"))
(if nil (print "hoagie"))

(if true
  (print "pizza")
  (print "hotdog"))

(if false
  (print "pizza")
  (print "hotdog"))

(if ((fn [] (+ 1 1)))
  (print "pizza")
  (print "hotdog"))

(if ((fn [] nil))
  (print "pizza")
  (print "hotdog"))

(if ((fn [] true))
  ((fn [x] (print (+ 1 x))) 24)
  (print "hotdog"))

(def a (if true "mayo" "ketchup"))
(def b (if false "horseradish" "wasabi"))

(print a)
(print b)

(def c (if true (if true "ketchup" "mustard") (if false "jam" "gravy")))
(print c)

(def f2
  (fn []
    (+ 1 1)
    (+ 2 2)))

(def f3
  (fn [x]
    (let [x 1
          y x]
      y)))

]])
