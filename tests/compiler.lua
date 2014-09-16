local tsukuyomi = tsukuyomi

local function test(text)
  local datum = tsukuyomi.read(text)
  while datum and datum[1] do
    local info
    if datum[1][1] == tsukuyomi.get_symbol('def') then
      local symbol_name = datum[1][2][1].name
      local ns = tsukuyomi.core['*ns*'][symbol_name]
      info =  ns .. '/' .. symbol_name
    end
    local code = tsukuyomi.compile(datum[1])
    local chunk, err = loadstring(code, info)
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
(ns tsukuyomi.core)
]])

-- 2 datum test
test([[
(ns tsukuyomi.core)
(def z2ljr2jlslfl3jf 1)
]])

-- real test, 2+
test([[
(ns tsukuyomi.core)
(def a 3)
(def b 4)
(def b a)
]])

test([[
(ns tsukuyomi.core)

(def print
  (fn [obj]
    (_emit_ "print(tostring(obj))")
    ;(_emit_ "assert(false)")
    ))

(def +
  (fn [x y]
    (_emit_ "x + y")))

(def first
  (fn [cell]
    (_emit_ "cell[1]")))

(def rest
  (fn [cell]
    (_emit_ "cell[2]")))

(let [_cons (_emit_ "tsukuyomi.create_cell")]
  (def cons (fn [item coll]
     (_cons item coll))))

(def second
  (fn [coll]
    (first (rest coll))))

(def test1 (fn [] (print "foobar")))
(test1)

(print "asdf")
;(print (second '(42 43)))
;(print (first '(3 4 5)))
(print (first (cons 9 (cons 8 (cons 7 nil)))))
(print (second (cons 9 (cons 8 (cons 7 nil)))))

(def user/test "lisp")

(def f? (fn [foo]
  ((fn [bar] (+ foo bar)) 42)))

(print (f? 43))

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

(print (f3 42))

]])
