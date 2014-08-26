local tsukuyomi = tsukuyomi

local function test(text, expected_tokens)
  local tokens = tsukuyomi.tokenize(text)
  for i = 1, math.max(#expected_tokens, #tokens) do
    if tokens[i] ~= expected_tokens[i] then
      print('failed tokenizer test on item '..tostring(i))
      print('got:')
      print(tostring(tokens[i]))
      print('expected:')
      print(tostring(expected_tokens[i]))
      assert(false)
    end
  end
end

test(
[[
; this is ignored
0
; this is also ignored
1

true
false
; add some whitespace


""
"a"
"ab"
"abc"

(+ 1 2)
foo`bar
foo'bar,baz@'buzz
]],
{
  '0',
  '1',
  'true',
  'false',
  '""',
  '"a"',
  '"ab"',
  '"abc"',
  '(',
  '+',
  '1',
  '2',
  ')',
  'foo',
  '`',
  'bar',
  'foo',
  '\'',
  'bar', ',', 'baz', '@', '\'', 'buzz'
})

return true
