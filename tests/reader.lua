local tsukuyomi = tsukuyomi
local PushbackReader = tsukuyomi.lang.PushbackReader

local function test(text)
  local r = PushbackReader.new(text)

  local datum = tsukuyomi.read(r)
  while datum ~= nil do
    print(tsukuyomi.print(datum))
    datum = tsukuyomi.read(r) 
  end
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

-- https://gist.github.com/jlongster/1712455
test([[
;; outlet code for implementing traditional macro expansion

;; macros

(define (expand form)
  (cond
   ((variable? form) form)
   ((literal? form) form)
   ((macro? (car form))
    (expand ((macro-function (car form)) form)))
   ((eq? (car form) 'quote)
    form)
   ((eq? (car form) 'lambda)
    `(lambda ,(car (cdr form))
       ,@(map expand (cdr (cdr form)))))   
   (else (map expand form))))

(define _macros_ {})

(define (macro-function name)
  (ref _macros_ (symbol->string name)))

(define (install-macro name func)
  (put! _macros_ (symbol->string name) func))

(define (macro? name)
  (not (eq? (ref _macros_ (symbol->string name))
            undefined)))

;; compiler

(define (read src)
  (vector-to-list
   (reader grammar src '[begin])))

(install-macro 'define (lambda (form)
                         `(define* ,(car (cdr form))
                            ,@(cdr (cdr form)))))

(let ((src (fs.readFileSync "example.ol" "utf-8")))
  (pretty (expand (read src))))

;; (define (foo x y z)
;;   (+ x y z))
;;
;; expand to:
;;
;; (define* (foo x y z)
;;   (+ x y z))
]])

return true
