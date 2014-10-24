local tsukuyomi = tsukuyomi
local bit = require('bit')
local tobit = bit.tobit

local Keyword = {}
tsukuyomi.lang.Keyword = Keyword
Keyword.__index = Keyword
Keyword.__newindex = function(t, k)
  assert(false, 'attempted to modify tsukuyomi.lang.Keyword')
end

local keyword_cache = {}
setmetatable(keyword_cache, {__mode = 'v'})

-- duplication for the same reason as mentioned in PersistentList
function Keyword.intern(sym)
  local k = tostring(sym)

  local keyword = keyword_cache[k]
  if keyword then
    return keyword
  end

  if sym:meta() ~= nil then
    sym = sym:with_meta(nil)
  end

  local hash = tobit(sym:hasheq() + 0x9e3779b9)
  keyword = setmetatable({sym = sym, _hasheq = hash}, Keyword)
  keyword_cache[k] = keyword
  return keyword
end

function Keyword:__tostring()
  return ':' .. tostring(self.sym)
end

function Keyword:hasheq()
  return self._hasheq
end
