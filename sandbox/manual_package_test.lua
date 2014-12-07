local namespace = {}
namespace.add = function(x, y)
  return x + y
end

package.loaded['tsukuyomi.core'] = namespace

local sum = require('tsukuyomi.core').add(42, 43)
print(sum)
