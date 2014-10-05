local tsukuyomi = tsukuyomi
local util = require('tsukuyomi.thirdparty.util')

local Symbol = tsukuyomi.lang.Symbol
-- special forms
local kNsSymbol = Symbol.intern('ns')
local kQuoteSymbol = Symbol.intern('quote')
local kDefSymbol = Symbol.intern('def')
local kIfSymbol = Symbol.intern('if')
local kFnSymbol = Symbol.intern('fn')
local kEmitSymbol = Symbol.intern('_emit_')
local kNilSymbol = Symbol.intern("nil")
local kLetSymbol = Symbol.intern("let")

local PersistentList = tsukuyomi.lang.PersistentList
local PersistentVector = tsukuyomi.lang.PersistentVector
local PersistentHashMap = tsukuyomi.lang.PersistentHashMap

--------------------------------------------------------------------------------

local var_counter = -1
local function make_unique_var_name(desc)
  desc = desc or 'var'
  var_counter = var_counter + 1
  return '__' .. desc .. '_' .. tostring(var_counter)
end

local data_key_counter = -1
local function make_unique_data_key()
  data_key_counter = data_key_counter + 1
  return data_key_counter
end

--------------------------------------------------------------------------------

local function is_lua_primitive(datum)
  -- actual primitive types
  if type(datum) == 'string' or type(datum) == 'number' or type(datum) == 'boolean' then
    return true
  elseif getmetatable(datum) == Symbol then
    -- this isn't a true Lua primitive, but it's intent is that it is just a
    -- variable name referring to something like a Lua variable, so pretend
    -- that it is
    return true
  end

  return false
end

local function compile_lua_primitive(datum)
  if type(datum) == 'number' or type(datum) == 'boolean' then
    return tostring(datum)
  elseif type(datum) == 'string' then
    return '"'..datum..'"'
  elseif getmetatable(datum) == Symbol then
    -- we can't do symbol binding here since we don't know if the symbol is
    -- referring to a variable in a namespace or a lambda function argument
    -- variable
    -- do this in the the lua_compiler
    -- (ns core)
    -- (def a 1234)
    -- (fn (a) (+ 1 a))
    -- "a" above should refer to the function argument "a", not "a" in the
    -- namespace
    return datum
  elseif datum == nil then
    return 'nil'
  end

  -- if using is_lua_primitive, this should never happend
  assert(false)
end

--------------------------------------------------------------------------------

-- these set of function are used to maintain the lexical stack of symbols
-- introduced that are actually bound to lambdas instead of resolving to
-- something inside a namespace
--
-- like
--   (ns core)
--   (def a 1)
--   ((lambda [a b c] a) 2)
--
-- the "a" in "print a" would NOT bind to core/a, but the "a" of the lambda argument
-- e.g. this would print 2 instead of 1

-- mapping of variable name to number of time mentioned in enclosing functions
local EnvironmentMetatable = {}
EnvironmentMetatable.__index = EnvironmentMetatable

local function create_environment()
  local env = setmetatable({symbols = {}}, EnvironmentMetatable)
  return env
end

function EnvironmentMetatable:extend_with(symbols)
  local newenv = create_environment()
  for i = 1, #symbols do
    newenv.symbols[symbols[i]] = true
  end
  newenv.parent = self
  return newenv
end

function EnvironmentMetatable:has_symbol(symbol)
  if self.symbols[symbol] then
    return true
  end

  if self.parent then
    return self.parent:has_symbol(symbol)
  else
    return false
  end
end

function EnvironmentMetatable:__tostring()
  local t = {'ENV:'}
  local env = self

  while env do
    table.insert(t, '(')
    for symbol, _ in pairs(env.symbols) do
      assert(getmetatable(symbol) == Symbol)
      table.insert(t, symbol.name)
    end
    table.insert(t, ')')
    env = env.parent
  end

  return table.concat(t, ' ')
end

--------------------------------------------------------------------------------

-- dispatch tables to compile down input

-- used to implement dispatch based on the first / car of a cons cell
local special_forms = {}

-- TODO: support other namespaces via require
-- TODO: check for symbol collision in namespaces
special_forms[kNsSymbol] = function(node, datum, new_dirty_nodes)
  node.op = 'NS'
  node.args = {datum[1]}

  -- TODO: see if it makes sense to return anything here other than a dummy value
  if node.is_return then
    node.is_return = false

    local dummy_return = tsukuyomi.ll_new_node('LISP', node.environment)
    dummy_return.args = { true }
    tsukuyomi.ll_insert_after(node, dummy_return)
    dummy_return.is_return = true
    table.insert(new_dirty_nodes, dummy_return)
  end
end

special_forms[kDefSymbol] = function(node, datum, new_dirty_nodes)
  -- (def symbol datum)
  local defnode = tsukuyomi.ll_new_node('LISP', node.environment)
  table.insert(new_dirty_nodes, defnode)
  defnode.op = 'LISP'
  defnode.define_symbol = datum[1]
  defnode.args = { datum[2][1] }
  tsukuyomi.ll_insert_before(node, defnode)

  -- it's not possible to get a return value on an assignment, to just add a
  -- dummy instruction after it
  -- TODO: figure out what the sensible dummy return value is
  -- TODO: can we even have something like a Clojure Var?
  node.op = 'LISP'
  node.args = {true}
  table.insert(new_dirty_nodes, node)
end

special_forms[kEmitSymbol] = function(node, datum, new_dirty_nodes)
  node.op = 'RAW'
  local inline = datum[1]
  assert(type(inline) == 'string')
  node.args = {inline}
end

special_forms[kQuoteSymbol] = function(node, datum, new_dirty_nodes)
  node.op = 'DATA'
  node.data_key = tsukuyomi.store_data(datum:first())
end

special_forms[kIfSymbol] = function(node, datum, new_dirty_nodes)
  local orig_node = node

  local ret_var_node = tsukuyomi.ll_new_node('EMPTYVAR', orig_node.environment)
  local ret_var_name = make_unique_var_name('if_ret')
  ret_var_node.args = { ret_var_name }
  tsukuyomi.ll_insert_before(orig_node, ret_var_node)
  node = ret_var_node

  local fence = tsukuyomi.ll_new_node('VARFENCE', orig_node.environment)
  tsukuyomi.ll_insert_after(node, fence)
  node = fence

  local test = datum
  -- this can be nil legitimately, although I don't know why anyone would do this
  --assert(test[1] ~= nil)
  local var_test_node = tsukuyomi.ll_new_node('NEWLVAR', orig_node.environment)
  table.insert(new_dirty_nodes, var_test_node)
  local var_name = make_unique_var_name('cond')
  var_test_node.args = {var_name, test[1]}
  tsukuyomi.ll_insert_after(node, var_test_node)
  node = var_test_node

  local if_node = tsukuyomi.ll_new_node('IF', orig_node.environment)
  if_node.args = { var_name }
  tsukuyomi.ll_insert_after(node, if_node)
  node = if_node

  local then_cell = test[2]
  assert(then_cell)
  local then_node = tsukuyomi.ll_new_node('LISP', orig_node.environment)
  table.insert(new_dirty_nodes, then_node)
  then_node.args = { then_cell[1] }
  then_node.set_var_name = ret_var_name
  tsukuyomi.ll_insert_after(node, then_node)
  node = then_node

  local else_keyword_node = tsukuyomi.ll_new_node('ELSE', orig_node.environment)
  tsukuyomi.ll_insert_after(node, else_keyword_node)
  node = else_keyword_node

  local else_cell = then_cell[2]
  local else_node
  if else_cell then
    else_node = tsukuyomi.ll_new_node('LISP', orig_node.environment)
    else_node.args = { else_cell[1] }
    table.insert(new_dirty_nodes, else_node)
  else
    else_node = tsukuyomi.ll_new_node('PRIMITIVE', orig_node.environment)
    else_node.args = { kNilSymbol }
  end
  else_node.set_var_name = ret_var_name
  tsukuyomi.ll_insert_after(node, else_node)
  node = else_node

  local end_node = tsukuyomi.ll_new_node('ENDIF', orig_node.environment)
  tsukuyomi.ll_insert_after(node, end_node)
  node = end_node

  local endfence = tsukuyomi.ll_new_node('ENDVARFENCE', orig_node.environment)
  tsukuyomi.ll_insert_after(node, endfence)
  node = endfence

  node = orig_node
  node.op = 'PRIMITIVE'
  node.args = { ret_var_name }
end

special_forms[kLetSymbol] = function(node, datum, new_dirty_nodes)
  local orig_node = node

  local bindings = datum[1]
  assert(bindings and getmetatable(bindings) == PersistentVector and (bindings:count() % 2 == 0))
  local exprs = datum[2]

  local ret_var_node = tsukuyomi.ll_new_node('EMPTYVAR', orig_node.environment)
  local ret_var_name = make_unique_var_name('let_ret')
  ret_var_node.args = { ret_var_name }
  tsukuyomi.ll_insert_before(orig_node, ret_var_node)
  node = ret_var_node

  local fence = tsukuyomi.ll_new_node('VARFENCE', orig_node.environment)
  tsukuyomi.ll_insert_after(node, fence)
  node = fence

  local extended_environment = orig_node.environment
  local i = 0
  while i < bindings:count() do
    -- TODO: support destructuring
    local var_symbol = bindings:get(i)
    local var_name = var_symbol.name
    extended_environment = extended_environment:extend_with({var_symbol})

    local form = bindings:get(i + 1)
    local lisp_node = tsukuyomi.ll_new_node('LISP', extended_environment)
    lisp_node.args = { form }
    lisp_node.new_lvar_name = var_name
    table.insert(new_dirty_nodes, lisp_node)
    tsukuyomi.ll_insert_after(node, lisp_node)
    node = lisp_node

    i = i + 2
  end

  while exprs and exprs[1] do
    local fence = tsukuyomi.ll_new_node('VARFENCE', extended_environment)
    tsukuyomi.ll_insert_after(node, fence)
    node = fence

    local lisp_node = tsukuyomi.ll_new_node('LISP', extended_environment)
    lisp_node.args = { exprs[1] }
    if exprs[2] == nil then
      lisp_node.set_var_name = ret_var_name
    end
    table.insert(new_dirty_nodes, lisp_node)
    tsukuyomi.ll_insert_after(node, lisp_node)
    node = lisp_node

    exprs = exprs[2]

    local endfence = tsukuyomi.ll_new_node('ENDVARFENCE', extended_environment)
    tsukuyomi.ll_insert_after(node, endfence)
    node = endfence
  end

  local endfence = tsukuyomi.ll_new_node('ENDVARFENCE', extended_environment)
  tsukuyomi.ll_insert_after(node, endfence)
  node = endfence

  node = orig_node
  node.op = 'PRIMITIVE'
  node.args = { ret_var_name }
end

special_forms[kFnSymbol] = function(node, datum, new_dirty_nodes)
  -- (fn [arg0 arg1] (body))
  local orig_node = node
  node.op = 'FUNC'
  node.args = nil

  local bodies = {}
  local mt = getmetatable(datum:first())
  if mt == PersistentList then
    -- this function has multiple aritys
    while datum do
      table.insert(bodies, datum:first())
      datum = datum:rest()
    end
  elseif mt == PersistentVector then
    -- this function has only 1 arity
    table.insert(bodies, datum)
  else
    assert(false)
  end

  for i = 1, #bodies do
    local body = bodies[i]
    local args = body:first()
    local exprs = body:rest()

    local extended_environment = orig_node.environment:extend_with(args:ToLuaArray())
    local func_node = tsukuyomi.ll_new_node('FUNCBODY', extended_environment)
    tsukuyomi.ll_insert_after(node, func_node)
    node = func_node
    node.args = {}
    -- propagate what variable this function is suppose to live in
    node.new_lvar_name = orig_node.new_lvar_name
    node.define_symbol = orig_node.define_symbol

    -- convert function argument symbols to string
    -- TODO: will I or someone ever put explicit namespace symbols here by accident?
    -- like (fn [foobar lol/wut] (+ foobar lol/wut))
    -- is it even worth it to check?
    for i = 0, args:count() - 1 do
      node.args[i + 1] = tostring(args:get(i))
    end

    while exprs and exprs[1] do
      local fence = tsukuyomi.ll_new_node('VARFENCE', extended_environment)
      tsukuyomi.ll_insert_after(node, fence)
      node = fence

      local lisp_node = tsukuyomi.ll_new_node('LISP', extended_environment)
      table.insert(new_dirty_nodes, lisp_node)
      lisp_node.args = { exprs[1] }
      if exprs[2] == nil then
        lisp_node.is_return = true
      end
      tsukuyomi.ll_insert_after(node, lisp_node)
      node = lisp_node

      local endfence = tsukuyomi.ll_new_node('ENDVARFENCE', extended_environment)
      tsukuyomi.ll_insert_after(node, endfence)
      node = endfence

      exprs = exprs[2]
    end

    local end_func_body_node = tsukuyomi.ll_new_node('ENDFUNCBODY', extended_environment)
    tsukuyomi.ll_insert_after(node, end_func_body_node)
    node = end_func_body_node
  end

  local end_func_node = tsukuyomi.ll_new_node('ENDFUNC', orig_node.environment)
  tsukuyomi.ll_insert_after(node, end_func_node)
end

local op_dispatch = {}

op_dispatch['LISP'] = function(node, new_dirty_nodes)
  local datum = node.args[1]
  local mt = getmetatable(datum)
  if mt == PersistentList then
    local first = datum[1]
    local rest = datum[2]
    if special_forms[first] then
      special_forms[first](node, rest, new_dirty_nodes)
    else
      -- normal function call
      node.op = 'CALL'
      node.args = datum:ToLuaArray()
      table.insert(new_dirty_nodes, node)
    end
  elseif mt == PersistentVector then
    assert(false)
  elseif mt == PersistentHashMap then
    assert(false)
  else
    local primitive = compile_lua_primitive(datum)
    node.op = 'PRIMITIVE'
    node.args = {primitive}
  end
end

op_dispatch['CALL'] = function(node, new_dirty_nodes)
  local args = node.args
  for i = 1, #args do
    if is_lua_primitive(args[i]) then
      args[i] = compile_lua_primitive(args[i])
    else
      local var_node = tsukuyomi.ll_new_node('NEWLVAR', node.environment)
      table.insert(new_dirty_nodes, var_node)

      local var_name = make_unique_var_name('arg')
      var_node.args = {var_name, args[i]}
      args[i] = var_name
      tsukuyomi.ll_insert_before(node, var_node)
    end
  end
end

op_dispatch['NEWLVAR'] = function(node, new_dirty_nodes)
  node.op = 'LISP'
  node.new_lvar_name = node.args[1]
  node.args = {node.args[2]}
  table.insert(new_dirty_nodes, node)
end

-- given a doubly linked list, iteratively process each node until each node
-- has been "cleaned". processing a node usually expands / creates more nodes
-- around it, as the Lisp is being broken into elementary operations.
--
-- by default nodes are dirty, until it has been processed through once.
--
-- nodes are in the form of
-- node = {
--    ['op'] = 'OPCODE',
--    ['args'] = { arg0, arg1, arg2 },
-- }
-- optional fields are:
-- new_lvar_name
-- set_var_name
-- define_symbol
-- is_return
function tsukuyomi.compile_to_ir(datum)
  local head_node = tsukuyomi.ll_new_node('LISP', create_environment())
  head_node.args = { datum }
  head_node.is_return = true

  -- prepare input nodes by marking them all as dirty
  local dirty_nodes = {}
  local node = head_node
  while node do
    table.insert(dirty_nodes, node)
    node = node.next
  end

  while #dirty_nodes > 0 do
    local new_dirty_nodes = {}
    for i = 1, #dirty_nodes do
      local node = dirty_nodes[i]
      local op = node.op
      op_dispatch[op](node, new_dirty_nodes)
    end
    dirty_nodes = new_dirty_nodes
  end

  -- it is possible that this expansion process has tacked on nodes in front of the head node
  while head_node.prev do
    head_node = head_node.prev
  end
  
  return head_node
end

function tsukuyomi._debug_ir(node)
  local lines = {}

  while node do
    local line = {}

    if node.is_return then
      table.insert(line, 'RET ')
    end
    if node.new_lvar_name then
      table.insert(line, 'NEWLVAR ')
      table.insert(line, node.new_lvar_name)
      table.insert(line, ' := ')
    end
    if node.set_var_name then
      table.insert(line, 'SETVAR ')
      table.insert(line, node.set_var_name)
      table.insert(line, ' := ')
    end
    if node.define_symbol then
      table.insert(line, 'DEFSYM ')
      table.insert(line, tostring(node.define_symbol))
      table.insert(line, ' := ')
    end

    table.insert(line, node.op)
    table.insert(line, ' ')
    local args = node.args
    if args then
      for i = 1, #args do
        local arg = args[i]
        if node.op == 'LISP' then
          table.insert(line, tsukuyomi.print(arg))
        else
          table.insert(line, tostring(arg))
        end
        if i < #args then
          table.insert(line, ', ')
        end
      end
    end

    table.insert(line, '\t\t\t\t\t\t')
    assert(node.environment)
    table.insert(line, tostring(node.environment))

    table.insert(lines, table.concat(line))
    node = node.next
  end

  return table.concat(lines, '\n')
end
