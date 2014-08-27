local tsukuyomi = tsukuyomi

local function test(text)
  local data = tsukuyomi.read(text)
  print(tsukuyomi.print(data))
end

test([[
(-42) (asdf) ((foo)) ((foo) bar ((fuzz)))
]])
test([[
'42 '`````''(asdf)
]])
test([[
(def foobar (1 2 3))
]])

-- http://stackoverflow.com/questions/3683388/given-the-following-lisp-eval-function-what-is-required-to-add-defmacro
test([[
((eq (caar e) 'macro)
     (cond
      ((eq (cadar e) 'lambda)
       (eval. (eval. (car (cdddar e))
                     (cons (list. (car (caddar e)) (cadr e)) a))
              a))))
]])

return true
