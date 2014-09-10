package.path=package.path..';./?/init.lua;./?.lua'

--require('jit.v').start()
--require('jit.dump').start()

require('tsukuyomi.thirdparty.strict')
require('tsukuyomi.thirdparty.util')

require('tsukuyomi')

require('tsukuyomi.tests.tokenizer')
require('tsukuyomi.tests.reader')
require('tsukuyomi.tests.compiler')

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
