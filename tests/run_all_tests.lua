local paths = {
  'tsukuyomi/thirdparty/hamt.lua/?.lua',
  package.path,
  './?/init.lua',
  './?.lua',
}
package.path=table.concat(paths, ';')

if _G.jit then
  --jit.off()
  require('jit.v').start()
  --require('jit.dump').start()
end

-- Lua 5.2 compatibility fix
if _G.loadstring == nil then
  function _G.loadstring(string, chunkname)
    return load(string, chunkname, 't')
  end
end

require('tsukuyomi.thirdparty.strict')

require('tsukuyomi')

--require('tsukuyomi.tests.reader')
--require('tsukuyomi.tests.compiler')

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
