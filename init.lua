local tsukuyomi = {}
package.loaded['tsukuyomi'] = tsukuyomi

-- patches string metatable with required functions
require('tsukuyomi.lang.String')

require('tsukuyomi.lang.Symbol')
require('tsukuyomi.lang.Namespace')
require('tsukuyomi.lang.Keyword')

require('tsukuyomi.lang.PushbackReader')

require('tsukuyomi.lang.PersistentList')
require('tsukuyomi.lang.ArraySeq')
require('tsukuyomi.lang.PersistentVectorSeq')
require('tsukuyomi.lang.PersistentVector')
require('tsukuyomi.lang.PersistentHashMap')
require('tsukuyomi.lang.ConcatSeq')

require('tsukuyomi.lang.Function')
require('tsukuyomi.lang.Var')

require('tsukuyomi.core.printer')

require('tsukuyomi.core.reader')

require('tsukuyomi.core.ir_compiler')
require('tsukuyomi.core.lua_compiler')
require('tsukuyomi.core.compiler')
require('tsukuyomi.core.eval')
require('tsukuyomi.core.apply')

--------------------------------------------------------------------------------
-- We can finally load Lisp :-)
--------------------------------------------------------------------------------
local core = require('tsukuyomi.core')
core['load-file'][1]('tsukuyomi/core/bootstrap.tsu')
core['load-file'][1]('tsukuyomi/core/tests.tsu')

return tsukuyomi
