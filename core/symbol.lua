-- use metatable tagging to mark a Lua table as a Lisp symbol
local kSymbolTag = {}

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

function tsukuyomi.create_symbol(name, namespace)
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

function tsukuyomi.get_symbol_name(symbol)
  return symbol.name
end

function tsukuyomi.get_symbol_namespace(symbol)
  return symbol.namespace
end

function tsukuyomi.is_symbol(datum)
  if type(datum) ~= 'table' then
    return false
  end
  if getmetatable(datum) ~= kSymbolTag then
    return false
  end
  return true
end

-- used to compile a symbol to Lua code
function tsukuyomi.symbol_to_lua(symbol)
  local namespace = symbol.namespace
  local name = symbol.name
  assert(namespace)

  local text = {}
  table.insert(text, namespace)
  table.insert(text, ".")
  table.insert(text, name)
  local ideal_name = table.concat(text)
  return 'tsukuyomi.' .. ideal_name
end
