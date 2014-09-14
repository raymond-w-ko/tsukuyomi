package.path=package.path..';./?/init.lua;./?.lua'

jit.off()
--require('jit.v').start()
--require('jit.dump').start()

require('tsukuyomi.thirdparty.strict')
require('tsukuyomi.thirdparty.util')

require('tsukuyomi')

require('tsukuyomi.tests.tokenizer')
require('tsukuyomi.tests.reader')
require('tsukuyomi.tests.compiler')

--print('********************************************************************************')
--print('global table dump')
--for k, v in pairs(_G) do
  --print(tostring(k))
--end

--[[
local input = io.open('tsukuyomi/tests/window.el', 'r')
local text = input:read('*all')
input:close()

local output = io.open('tsukuyomi/tests/tokenizer.txt', 'w')
local tokens = tsukuyomi.tokenize(text)
for _, token in ipairs(tokens) do
  output:write(token)
  output:write('\n')
end
output:close()

local data = tsukuyomi.read(text)
]]--
