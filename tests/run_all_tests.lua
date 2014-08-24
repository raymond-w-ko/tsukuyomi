package.path=package.path..';./?/init.lua;./?.lua'

require('jit.v').start()

require('tsukuyomi.thirdparty.strict')
require('tsukuyomi.thirdparty.util')

require('tsukuyomi')

local input = io.open('tsukuyomi/tests/window.el', 'r')
local output = io.open('tsukuyomi/tests/tokenizer.txt', 'w')
local tokens = tsukuyomi.tokenize(input:read('*all'))
input:close()
for _, token in ipairs(tokens) do
  output:write(token)
  output:write('\n')
end
output:close()
