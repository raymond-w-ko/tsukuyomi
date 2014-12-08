local util = require('tsukuyomi.thirdparty.util')
local split = util.split

local Symbol = require('tsukuyomi.lang.Symbol')

local Namespace = {}
Namespace.__index = Namespace

local ActualNamespace = {}
ActualNamespace.__index = ActualNamespace

function ActualNamespace:__bind_symbol__(symbol)
  -- TODO: this will no longer hold once we have namespace aliases
  --assert(symbol.namespace == nil)
  -- TODO: mimic clojure / python and have a way to import symbols from other
  -- namespaces so you import math / other libraries
  local ns = symbol.namespace or self.__name__
  local name = symbol.name
  return Symbol.intern(name, ns, symbol:meta())
end

function Namespace.intern(name)
  local ns = package.loaded[name]
  if ns then
    return ns
  else
    ns = {}
    ns.__name__ = name
    setmetatable(ns, ActualNamespace)
    package.loaded[name] = ns
    return ns
  end
end

local tsukuyomi_core = Namespace.intern('tsukuyomi.core')

-- the namespace argument is just a string like "tsukuyomi.core"
function Namespace.SetActiveNamespace(name)
  local ns = Namespace.intern(name)
  tsukuyomi_core['*ns*'] = ns
  return ns
end

return Namespace
