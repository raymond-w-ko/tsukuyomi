local tsukuyomi = require('tsukuyomi')
print('basic testing of eval')

local function test(input, expected_output)
  local list = tsukuyomi.core._read(input)[1]
  local output = tsukuyomi.core._eval(list, tsukuyomi.TheGlobalEnvironment)
  if output ~= expected_output  then
    print()

    print('input:')
    print(input)
    print()

    print('output:')
    print(output)
    print()

    print('expected_output:')
    print(expected_output)
    print()

    print('raw:')
    print(table.show(list))

    assert(false)
  end
end

-- self evaluating
test(
  '42',
  42)

test(
  'true',
  true)

test(
  'false',
  false)

test(
  '1',
  1)

test(
  '42',
  42)

test(
  '3.14',
  3.14)

test(
  '"foobar"',
  "foobar")

-- quote self evaluating
test(
  '(quote 42)',
  42)

test(
  '(quote true)',
  true)

test(
  '(quote false)',
  false)

test(
  '(quote 1)',
  1)

test(
  '(quote 42)',
  42)

test(
  '(quote 3.14)',
  3.14)

test(
  '(quote "foobar")',
  "foobar")

local ok = tsukuyomi.core.CreateSymbol('ok')

test(
  'ok',
  nil)

test(
  '(define a true)',
  ok)

test(
  '(define b false)',
  ok)

test(
  '(define c 1)',
  ok)

test(
  '(define d 42)',
  ok)

test(
  '(define e 3.14)',
  ok)

test(
  '(define f "foobar")',
  ok)

test(
  '(define f \'(data))',
  ok)

test(
  '(set! a "wat")',
  ok)

test(
  '(set! b "wat")',
  ok)

test(
  '(if true 42 13)',
  42)

test(
  '(if false 42 13)',
  13)
