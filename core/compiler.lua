local log = io.open('tsukuyomi/tests/compiler.out.txt', 'w')
if not log then assert(false) end

local function prepare_data(datum)
  local node = tsukuyomi.ll_new_node('LISP')
  node.args = { datum }
  node.is_return = true
  return node
end

function tsukuyomi.compile(datum)
  log:write('compiling:\n')
  log:write(tsukuyomi.print(datum))
  log:write('\n')
  log:write('\n')

  local list = prepare_data(datum)
  local list = tsukuyomi.compile_to_ir(list)
  log:write('IR:\n')
  log:write(tsukuyomi._debug_ir(list))
  log:write('\n')
  log:write('\n')

  local source_code = tsukuyomi.compile_to_lua(list)
  log:write('Lua source code:\n')
  log:write(source_code)
  log:write('\n')
  log:write('\n')

  log:write('********************************************************************************\n\n')
  return source_code
end
