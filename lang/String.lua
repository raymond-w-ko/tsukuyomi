local hamt = require('hamt')
local string_hash_fn = hamt.hash

assert(string.hasheq == nil, 'string metatable already has hasheq key, cannot install hasheq function')
function string:hasheq()
  return string_hash_fn(self)
end
