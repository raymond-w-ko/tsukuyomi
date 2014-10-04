local tsukuyomi = tsukuyomi
local tsukuyomi_lang = tsukuyomi.lang.Namespace.GetNamespaceSpace('tsukuyomi.lang')

local Symbol = {}
tsukuyomi_lang.Symbol = Symbol
Symbol.__index = Symbol
Symbol.__newindex = function(t, k)
  assert(false, 'attempted to modify tsukuyomi.lang.Symbol')
end

function Symbol:__tostring()
  if self.namespace then
    return self.namespace .. '/' .. self.name
  else
    return self.name
  end
end

-- use a table with weak references to make sure that only one symbol can ever be created.
-- when we create symbols, we look at this cache first to see if it exists first
--
-- this way, we can use Lua == to check for symbol equality
local symbol_cache = {}
setmetatable(symbol_cache, {__mode = 'v'})

function Symbol.intern(name, namespace)
  local key
  if namespace then
    key = namespace .. '/' .. name
  else
    key = name
  end
  local value = symbol_cache[key]
  if value then
    return value
  end

  local symbol = {
    ['name'] = name,
    ['namespace'] = namespace,
  }
  setmetatable(symbol, Symbol)

  symbol_cache[key] = symbol
  return symbol
end
