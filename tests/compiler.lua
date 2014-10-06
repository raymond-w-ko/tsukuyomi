local tsukuyomi = tsukuyomi
local Symbol = tsukuyomi.lang.Symbol
local PushbackReader = tsukuyomi.lang.PushbackReader
local PersistentList = tsukuyomi.lang.PersistentList
local Compiler = tsukuyomi.lang.Namespace.GetNamespaceSpace('tsukuyomi.lang.Compiler')

local def_symbol = Symbol.intern('def')

local function dump_vars()
  print('--------------------------------------------------------------------------------')
  print('vars in tsukuyomi:')
  for k, v in pairs(tsukuyomi) do
    print(k)
  end
  print('--------------------------------------------------------------------------------')
  print('vars in tsukuyomi.core:')
  for k, v in pairs(tsukuyomi.core) do
    print(k)
  end
end

local function test(text)
  local r = PushbackReader.new(text)

  local datum = tsukuyomi.lang.LispReader.read(r)
  while datum do
    print('')
    print(tsukuyomi.print(datum))

    local info
    if getmetatable(datum) == PersistentList then
      if datum:first() == def_symbol then
        local symbol = datum:rest():first()
        symbol = tsukuyomi.core['*ns*']:bind_symbol(symbol)
        info = tostring(symbol)
      end
    end

    local code = Compiler.compile(datum)
    local chunk, err = loadstring(code, info)
    if err then
      print(err)
      assert(chunk)
    else
      chunk()
      -- check to make sure all data is consumed, dangling data is bad
      for var, data in pairs(tsukuyomi._data_store) do assert(false) end
    end

    datum = tsukuyomi.lang.LispReader.read(r)
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
  (fn [coll]
    (_emit_ "coll:first()")))

(def rest
  (fn [coll]
    (_emit_ "coll:rest()")))

(def cons
  (fn [x seq]
    (_emit_ "seq:cons(x)")))

(def second
  (fn [coll]
    (first (rest coll))))

(def test1 (fn [] (print "foobar")))
(test1)

(print "asdf")
(print (first '(42 43)))
;(print (rest '(42 43)))
(print (second '(42 43)))
(print (first '(3 4 5)))
(print (first (cons 9 (cons 8 (cons 7 '())))))
(print (second (cons 9 (cons 8 (cons 7 '())))))

(def user/test "lisp")

(def f? (fn [foo]
  ((fn [bar] (+ foo bar)) 42)))

(print (f? 43))

(if false (print "pepperoni"))

^{} (if nil (print "hoagie"))

^{:asdf true}
(if true
  (print "pizza\tpie\n\twith \"extra cheese\" and \"anchovies\"")
  (print "hotdog\n\twith\n\"onions\" and \"relish\""))

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

(def multifn
  (fn
    ([] "arity 0")
    ([x] "arity 1")
    ([x y] "arity 2")))

(print (multifn))
(print (multifn 1))
(print (multifn 1 2))
]])
