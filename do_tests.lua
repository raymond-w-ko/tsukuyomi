require ('strict')
require ('util')
local tsukuyomi = require('tsukuyomi')

print('running tsukuyomi test suite')

local function parser_test(text)
  local lists = tsukuyomi.core._read(text)
  for _, list in ipairs(lists) do
    --print(table.show(list))
    print(tsukuyomi.core._print(list))
    print('--------------------------')
  end
end

parser_test('"fun\ttimes"')
parser_test('"(inner list)')

parser_test(
[[
42
"fish\tsticks"
""
()
(test)
("conjoined""twins")
("foo" "bar")
(1)
(-1)
(1.2)
(-1.2)
(543.21E8)
(-543.21E8)
(2.56e-4)
(-2.56e-4)
(+ 1 1)
(+ '(+ 1 1) '(+ 1 1))
]])

parser_test(
[[
(defun eval. (e a)
  (cond
    ((atom e) (assoc. e a))
    ((atom (car e))
     (cond
       ((eq (car e) 'quote) (cadr e))
       ((eq (car e) 'atom)  (atom   (eval. (cadr e) a)))
       ((eq (car e) 'eq)    (eq     (eval. (cadr e) a)
                                    (eval. (caddr e) a)))
       ((eq (car e) 'car)   (car    (eval. (cadr e) a)))
       ((eq (car e) 'cdr)   (cdr    (eval. (cadr e) a)))
       ((eq (car e) 'cons)  (cons   (eval. (cadr e) a)
                                    (eval. (caddr e) a)))
       ((eq (car e) 'cond)  (evcon. (cdr e) a))
       ('t (eval. (cons (assoc. (car e) a)
                        (cdr e))
                  a))))
    ((eq (caar e) 'label)
     (eval. (cons (caddar e) (cdr e))
            (cons (list. (cadar e) (car e)) a)))
    ((eq (caar e) 'lambda)
     (eval. (caddar e)
            (append. (pair. (cadar e) (evlis. (cdr e) a))
                     a)))))
]]
)
