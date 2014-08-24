require('strict')
require('util')

global('tsukuyomi')
tsukuyomi = require('tsukuyomi')

local function compile(text)
  local datum = tsukuyomi.read(text)
  --print(tsukuyomi._print(datum))
  --print()

  local output = tsukuyomi.compile(datum)
  print('*** compiler output ***')
  print()
  print(output)
  print()

  local f = io.open('compiled.lua', 'w')
  f:write(output)
  f:close()

  print('*** load ***')
  print()
  local chunk, err = loadstring(output, 'compiler output')
  if chunk == nil then
    print(err)
  else
    xpcall(chunk, function(err)
      print(err)
      print(debug.traceback())
    end)
  end
  print()
end

--compile([[]])
--compile([[
--]])

compile(
[[
(ns core)

(define print
  (lambda (arg0)
    (_raw_ "print(arg0)")))

(print "first \"lisp\" code is now being executed!")

(define car
  (lambda (cell)
    (_raw_ "cell[1]")))

(define cdr
  (lambda (cell)
    (_raw_ "cell[2]")))

(define cadr
  (lambda (cell)
    (car (cdr cell))))

(define first
  (lambda (cell)
    (car cell)))

(define ffirst
  (lambda (cell)
     (first (first cell))))

(define rest
  (lambda (cell)
     (cdr cell)))
]])

-- FIXME: split should not be necessary, need to allow for symbols to be
-- defined as they are being compiled

compile(
[[
(ns user)

(define list1 (quote (1 2)))

(print (car list1))
(print (cdr list1))
(print (cadr list1))

(print (first list1))
(print (rest list1))
(print (first (rest list1)))

]])

--compile([[
--(func a b c d)
--(f1 (f2 a) b c d)
--(f1 (f2 (f3 a) b) c d e)
--(f1 (f2 (f3 a) b) c (f5 x y z) (f8 i (foo bar baz) k))
--(lambda (x) (* x x))
--(lambda (y) (+ y y))

--(define add1 (lambda (y) (+ y y)))


--(require "strict")
--(require "util")

--((lambda (x) (+ 1 x)) 9000)

--(lambda (x y z) (* x x))

--(lambda (x) (- 1))
--(lambda (x) (- 1 2 x))

--(lambda (x) (/ 2))
--(lambda (x) ((lambda (a b c) (+ a b c)) 3 4 x))

--(func a b (lambda (x y) (< x y)))

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
