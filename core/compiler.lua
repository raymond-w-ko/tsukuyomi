local util = require('tsukuyomi.thirdparty.util')
local tsukuyomi = require('tsukuyomi')
local Namespace = require('tsukuyomi.lang.Namespace')
local Compiler = Namespace.intern('tsukuyomi.lang.Compiler')

local log = io.open('tsukuyomi/tests/compiler.out.txt', 'w')
if not log then assert(false) end
function Compiler._log(line)
  log:write(line)
  log:write('\n')
end


function Compiler.compile(datum)
  log:write('*** Lisp ***\n\n')
  log:write(tsukuyomi.print(datum))
  log:write('\n\n')

  local list = Compiler.compile_to_ir(datum)
  log:write('*** IR ***\n\n')
  log:write(Compiler._debug_ir(list))
  log:write('\n\n')

  local source_code = Compiler.compile_to_lua(list)
  log:write('*** Lua source code ***\n\n')
  log:write(source_code)
  log:write('\n\n')

  log:write('********************************************************************************\n\n')
  return source_code
end
