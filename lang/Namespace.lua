local tsukuyomi = tsukuyomi
local util = require('tsukuyomi.thirdparty.util')
local split = util.split

local function create_or_get_space(name)
  local tokens = split(name, '.')
  assert(#tokens >= 1)
  -- support strict.lua
  if __STRICT then
    global(tokens[1])
  end
  local t = _G
  for i = 1, #tokens do
    local ns_chunk = tokens[i]
    if t[ns_chunk] == nil then
      t[ns_chunk] = {}
    end
    t = t[ns_chunk]
  end
  return t
end

local Namespace = {}
Namespace.__index = Namespace

function Namespace.new(name)
  local t = {}
  t.name = name
  t.space = create_or_get_space(name)
  return setmetatable(t, Namespace)
end

function Namespace:bind_symbol(symbol)
  assert(symbol.namespace == nil)
  -- TODO: mimic clojure / python and have a way to import symbols from other
  -- namespaces so you import math / other libraries
  return self.name
end

local namespace_cache = {}

function Namespace.GetNamespace(name)
  local ns

  if namespace_cache[name] then
    ns = namespace_cache[name]
  else
    ns = Namespace.new(name)
    namespace_cache[name] = ns
  end

  return ns
end

function Namespace.GetNamespaceSpace(name)
  return Namespace.GetNamespace(name).space
end

local tsukuyomi_core = Namespace.GetNamespaceSpace('tsukuyomi.core')
local tsukuyomi_lang = Namespace.GetNamespaceSpace('tsukuyomi.lang')

-- the namespace argument is just a string like "tsukuyomi.core"
function Namespace.SetActiveNamespace(name)
  local ns = Namespace.GetNamespace(name)
  tsukuyomi_core['*ns*'] = ns
  return ns
end

tsukuyomi_lang.Namespace = Namespace