-- use metatable tagging to mark a Lua table as a Lisp symbol
local kSymbolTag = {
  __newindex = function(t, k)
    assert(false)
  end
}

-- print the Lisp name
-- since we use metatable tagging, might as well make it useful
function kSymbolTag.__tostring(symbol)
  if symbol.namespace then
    return symbol.namespace .. '/' .. symbol.name
  else
    return symbol.name
  end
end

-- use a table with weak references to make sure that only one symbol can ever be created.
-- when we create symbols, we look at this cache first to see if it exists first
--
-- this way, we can use Lua == to check for symbol equality
local kSymbolCache = {}
setmetatable(kSymbolCache, {__mode = 'kv'})

function tsukuyomi.get_symbol(name, namespace)
  local key
  if namespace then
    key = namespace .. '/' .. name
  else
    key = name
  end
  local value = kSymbolCache[key]
  if value then
    return value
  end

  local symbol = {
    ['name'] = name,
    ['namespace'] = namespace,
  }
  setmetatable(symbol, kSymbolTag)

  kSymbolCache[key] = symbol
  return symbol
end

function tsukuyomi.is_symbol(datum)
  if getmetatable(datum) ~= kSymbolTag then
    return false
  else
    return true
  end
end
