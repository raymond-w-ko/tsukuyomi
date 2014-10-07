local tsukuyomi = tsukuyomi
local tsukuyomi_lang = tsukuyomi.lang.Namespace.GetNamespaceSpace('tsukuyomi.lang')
local PersistentHashMap = tsukuyomi.lang.PersistentHashMap
local Symbol = tsukuyomi.lang.Symbol

-- Since variables do not not as feature rich or complicated as Clojure, this
-- is basically just a place to:
-- 1. store metadata
local Var = {}
Var.__index = Var
tsukuyomi_lang.Var = Var

local var_cache = {}
setmetatable(var_cache, {__mode = 'v'})

function Var.intern(symbol)
  assert(getmetatable(symbol) == Symbol, 'tsukuyomi.lang.Var.intern() only accepts Symbols')
  assert(symbol.namespace, 'tsukuyomi.lang.Var.intern() needs a symbol with a namespace')

  local fullname = tostring(symbol)
  local var
  if var_cache[fullname] then
    var = var_cache[fullname]
  else
    var = {}
    setmetatable(var, Var)
    var_cache[fullname] = var
  end

  var:set_metadata(symbol:meta())

  return var
end

function Var.get(symbol)
  return var_cache[tostring(symbol)]
end

function Var:set_metadata(m)
  assert(m == nil or getmetatable(m) == PersistentHashMap,
         'Var:set_metadata() needs the argument to be a PersistentHashMap')
  self._meta = m
end

function Var:meta()
  return self._meta
end

function Var:is_macro()
  if self._meta == nil then
    return false
  end
  return self._meta:get('macro') == true
end
