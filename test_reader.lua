local tsukuyomi = require('tsukuyomi')
print('testing parser and reader')

local function test(input, expected_output)
  local list = tsukuyomi.core._read(input)[1]
  local output = tsukuyomi.core._print(list)
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

local identities = {
  '"fun\ttimes"',
  '"(inner list)"',
  'true',
  'false',
  '42',
  '3.14',
  '"foo bar"',
  '""',
  '()',
  '(42)',
  '(-42)',
  '(arg0)',
  '(arg1)',
  '(arg1 arg2)',
  '(arg1 arg2 arg3)',
  '("foo" "bar")',
  '("foo" 42 3.14 true false)',
  '(+ (* 2 2) (/ 4 2) 42)',
}

for _, code in ipairs(identities) do
  test(code, code)
end

local maps = {
  ['("conjoined""twins")'] = '("conjoined" "twins")',
  ['\'("foo" 42 3.14 true false)'] = '(quote ("foo" 42 3.14 true false))',
  ['\'()'] = '(quote ())',
}
for input, output in pairs(maps) do
  test(input, output)
end
