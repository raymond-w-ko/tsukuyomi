local tsukuyomi = tsukuyomi
local tsukuyomi_core = tsukuyomi.core
local PushbackReader = tsukuyomi.lang.PushbackReader
local Compiler = tsukuyomi.lang.Namespace.GetNamespaceSpace('tsukuyomi.lang.Compiler')

tsukuyomi_core['eval'] = tsukuyomi.lang.Function.new()
tsukuyomi_core['eval'][1] = function (form)
  assert(false)
end

tsukuyomi_core['load-file'] = tsukuyomi.lang.Function.new()
tsukuyomi_core['load-file'][1] = function (name)
  local f = io.open(name)
  local text = f:read('*all')
  f:close()
  local r = PushbackReader.new(text, name)

  local datum = tsukuyomi_core.read[1](r)
  while datum do
    local lua_code = Compiler.compile(datum)
    local chunk, err = loadstring(lua_code)
    if err then
      io.stderr:write(err)
      io.stderr:write('\n')
      assert(false)
    else
      chunk()
    end

    datum = tsukuyomi_core.read[1](r)
  end
end
