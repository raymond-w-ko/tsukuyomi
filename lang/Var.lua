local PersistentHashMap = require('tsukuyomi.lang.PersistentHashMap')
local Symbol = require('tsukuyomi.lang.Symbol')
local Keyword = require('tsukuyomi.lang.Keyword')

-- Since variables do not not as feature rich or complicated as Clojure, this
-- is basically just a place to:
-- 1. store metadata
local Var = {}
Var.__index = Var
function Var:__tostring()
  local name = self._name
  if name then
    return name
  end

  name = "#'" .. tostring(self._symbol)
  self._name = name
  return name
end

local var_cache = {}

function Var.intern(symbol)
  assert(getmetatable(symbol) == Symbol, 'tsukuyomi.lang.Var.intern() only accepts Symbols')
  assert(symbol.namespace, 'tsukuyomi.lang.Var.intern() needs a symbol with a namespace')

  local fullname = tostring(symbol)
  local var
  if var_cache[fullname] then
    var = var_cache[fullname]
  else
    var = {_symbol = symbol}
    setmetatable(var, Var)
    var_cache[fullname] = var
  end

  var:set_metadata(symbol:meta())

  return var
end

function Var.GetVar(symbol)
  return var_cache[tostring(symbol)]
end

function Var:get()
  local ns = require(self._symbol.namespace)
  return ns[self._symbol.name]
end

function Var:set(x)
  local ns = require(self._symbol.namespace)
  ns[self._symbol.name] = x
end

function Var:set_metadata(m)
  assert(m == nil or getmetatable(m) == PersistentHashMap,
         'Var:set_metadata() needs the argument to be a PersistentHashMap')
  self._meta = m
end

function Var:meta()
  return self._meta
end

local macro_keyword = Keyword.intern(Symbol.intern('macro'))
function Var:is_macro()
  if self._meta == nil then
    return false
  end
  return self._meta:get(macro_keyword) == true
end

return Var
