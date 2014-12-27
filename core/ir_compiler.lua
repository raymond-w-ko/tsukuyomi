local tsukuyomi = require('tsukuyomi')
local tsukuyomi_core = require('tsukuyomi.core')
local util = require('tsukuyomi.thirdparty.util')

local Symbol = require('tsukuyomi.lang.Symbol')
-- special forms
local kNilSymbol = Symbol.intern("nil")
local kAmpersandSymbol = Symbol.intern("&")
local kDotSymbol = Symbol.intern(".")

local Keyword = require('tsukuyomi.lang.Keyword')
local Function = require('tsukuyomi.lang.Function')

local PersistentList = require('tsukuyomi.lang.PersistentList')
local PersistentVector = require('tsukuyomi.lang.PersistentVector')
local PersistentHashMap = require('tsukuyomi.lang.PersistentHashMap')

local Var = require('tsukuyomi.lang.Var')
local Namespace = require('tsukuyomi.lang.Namespace')

local Compiler = Namespace.intern('tsukuyomi.lang.Compiler')

--------------------------------------------------------------------------------
-- standard doubly-linked list
--
-- so far, just used for IR list, so that is why ll_new_node accepts op
--------------------------------------------------------------------------------
function Compiler.ll_new_node(op, env)
  assert(op)
  assert(env)

  local node = {}
  node.op = op
  node.environment = env
  return node
end

function Compiler.ll_insert_after(node, new_node)
  new_node.prev = node
  new_node.next = node.next
  if node.next then
    node.next.prev = new_node
  end
  node.next = new_node
end

function Compiler.ll_insert_before(node, new_node)
  new_node.prev = node.prev
  new_node.next = node
  if node.prev then
    node.prev.next = new_node
  end
  node.prev = new_node
end

function Compiler.ll_remove(node)
  node.prev.next = node.next
  node.next.prev = node.prev
end

--------------------------------------------------------------------------------

local var_counter = -1
local function make_unique_var_name(desc)
  desc = desc or 'var'
  var_counter = var_counter + 1
  return '__' .. desc .. '_' .. tostring(var_counter)
end
Compiler.make_unique_var_name = make_unique_var_name

--------------------------------------------------------------------------------

local function is_lua_primitive(datum)
  -- actual primitive types
  if type(datum) == 'string' or type(datum) == 'number' or type(datum) == 'boolean' then
    return true
  elseif datum == nil then
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
  if type(datum) == 'boolean' then
    return tostring(datum)
  elseif type(datum) == 'number' then
    return datum
  elseif type(datum) == 'string' then
    return string.format('%q', datum)
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

  -- if datum has been checked using is_lua_primitive, this should never happend
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
Compiler.LexicalEnvironment = {}
local LexicalEnvironment = Compiler.LexicalEnvironment
LexicalEnvironment.__index = LexicalEnvironment

function LexicalEnvironment.new()
  local env = setmetatable({symbols = {}}, LexicalEnvironment)
  return env
end

function LexicalEnvironment:extend_with(symbols)
  local newenv = LexicalEnvironment.new()
  for i = 1, #symbols do
    local symbol = symbols[i]
    assert(getmetatable(symbol) == Symbol,
           'LexicalEnvironment:extend_with(): argument must be a list of tsukuyomi.lang.Symbol')
    if symbol ~= kAmpersandSymbol then
      newenv.symbols[tostring(symbol)] = true
    end
  end
  newenv.parent = self
  return newenv
end

function LexicalEnvironment:has_symbol(symbol)
  assert(getmetatable(symbol) == Symbol,
         'LexicalEnvironment:has_symbol(): argument must be tsukuyomi.lang.Symbol')

  if self.symbols[tostring(symbol)] then
    return true
  end

  if self.parent then
    return self.parent:has_symbol(symbol)
  else
    return false
  end
end

function LexicalEnvironment:set_recur_point(recur_type, recur_label_name, recur_arity, rest_arg_index)
  if recur_type == 'fn' then
    self.recur_type = 'fn'
    self.recur_label_name = recur_label_name
    self.recur_arg_list = recur_arity
    self.recur_rest_arg_index = rest_arg_index
  else
    assert(false)
  end
end

function LexicalEnvironment:__tostring()
  local t = {}

  local symbols = {}
  local env = self
  while env do
    for symbol, _ in pairs(env.symbols) do
      symbols[symbol] = true
    end
    env = env.parent
  end
  table.insert(t, 'LOCALS: ')
  for symbol, _ in pairs(symbols) do
    table.insert(t, symbol)
    table.insert(t, ' ')
  end

  if self.recur_type == 'fn' then
    table.insert(t, '\t[RECUR]')
    table.insert(t, ' TYPE: ')
    table.insert(t, self.recur_type)
    table.insert(t, ' NAME: ')
    table.insert(t, self.recur_label_name)
    table.insert(t, ' ARITY: ')
    table.insert(t, #self.recur_arg_list)
    table.insert(t, ' ARGS: ')
    for i = 1, #self.recur_arg_list do
      table.insert(t, self.recur_arg_list[i])
      table.insert(t, ' ')
    end
  end

  return table.concat(t)
end

--------------------------------------------------------------------------------

-- dispatch tables to compile down input

-- used to implement dispatch based on the first / car of a cons cell
Compiler.special_forms = {}
local special_forms = Compiler.special_forms

-- TODO: support other namespaces via require
-- TODO: check for symbol collision in namespaces
special_forms['ns'] = function(node, datum, new_dirty_nodes)
  node.op = 'NS'
  node.args = {datum:first()}

  -- TODO: see if it makes sense to return anything here other than a dummy value
  if node.is_return then
    node.is_return = false

    local dummy_return = Compiler.ll_new_node('PRIMITIVE', node.environment)
    dummy_return.args = { 'nil' }
    Compiler.ll_insert_after(node, dummy_return)
    dummy_return.is_return = true
  end
end

special_forms['def'] = function(node, datum, new_dirty_nodes)
  local orig_node = node

  local symbol = datum:first()
  assert(getmetatable(symbol) == Symbol, 'First argument to def must be a Symbol')

  local intern_var_node = Compiler.ll_new_node('INTERNVAR', orig_node.environment)
  local bound_symbol = tsukuyomi_core['*ns*']:__bind_symbol__(symbol)
  intern_var_node.args = {bound_symbol, symbol:meta()}
  Compiler.ll_insert_before(node, intern_var_node)

  -- (def symbol datum)
  local defnode = Compiler.ll_new_node('LISP', node.environment)
  table.insert(new_dirty_nodes, defnode)
  defnode.op = 'LISP'
  defnode.define_symbol = symbol
  defnode.args = {datum:rest():first()}
  Compiler.ll_insert_before(node, defnode)

  node.op = 'GETVAR'
  node.args = {bound_symbol}
end

special_forms['_emit_'] = function(node, datum, new_dirty_nodes)
  node.op = 'RAW'
  local inline = datum:first()
  assert(type(inline) == 'string')
  node.args = {inline}
end

special_forms['quote'] = function(node, datum, new_dirty_nodes)
  node.op = 'DATA'
  node.args = {datum:first()}
end

special_forms['if'] = function(node, datum, new_dirty_nodes)
  local orig_node = node

  local ret_var_node = Compiler.ll_new_node('EMPTYVAR', orig_node.environment)
  local ret_var_name = make_unique_var_name('if_ret')
  ret_var_node.args = {ret_var_name}
  Compiler.ll_insert_before(orig_node, ret_var_node)
  node = ret_var_node

  local fence = Compiler.ll_new_node('VARFENCE', orig_node.environment)
  Compiler.ll_insert_after(node, fence)
  node = fence

  local test = datum
  -- this can be nil legitimately, although I don't know why anyone would do
  -- this, maybe a macro?
  --assert(test:first() ~= nil)
  local var_test_node = Compiler.ll_new_node('NEWLVAR', orig_node.environment)
  table.insert(new_dirty_nodes, var_test_node)
  local var_name = make_unique_var_name('cond')
  var_test_node.args = {var_name, test:first()}
  Compiler.ll_insert_after(node, var_test_node)
  node = var_test_node

  local if_node = Compiler.ll_new_node('IF', orig_node.environment)
  if_node.args = { var_name }
  Compiler.ll_insert_after(node, if_node)
  node = if_node

  local then_cell = test:rest()
  assert(then_cell)
  local then_node = Compiler.ll_new_node('LISP', orig_node.environment)
  table.insert(new_dirty_nodes, then_node)
  then_node.args = { then_cell:first() }
  then_node.set_var_name = ret_var_name
  Compiler.ll_insert_after(node, then_node)
  node = then_node

  local else_keyword_node = Compiler.ll_new_node('ELSE', orig_node.environment)
  Compiler.ll_insert_after(node, else_keyword_node)
  node = else_keyword_node

  local else_cell = then_cell:rest()
  local else_node
  if else_cell then
    else_node = Compiler.ll_new_node('LISP', orig_node.environment)
    else_node.args = { else_cell:first() }
    table.insert(new_dirty_nodes, else_node)
  else
    else_node = Compiler.ll_new_node('PRIMITIVE', orig_node.environment)
    else_node.args = { kNilSymbol }
  end
  else_node.set_var_name = ret_var_name
  Compiler.ll_insert_after(node, else_node)
  node = else_node

  local end_node = Compiler.ll_new_node('ENDIF', orig_node.environment)
  Compiler.ll_insert_after(node, end_node)
  node = end_node

  local endfence = Compiler.ll_new_node('ENDVARFENCE', orig_node.environment)
  Compiler.ll_insert_after(node, endfence)
  node = endfence

  node = orig_node
  node.op = 'PRIMITIVE'
  node.args = { ret_var_name }
end

special_forms['do'] = function(node, datum, dirty_nodes)
  local orig_node = node

  local ret_var_node = Compiler.ll_new_node('EMPTYVAR', orig_node.environment)
  local ret_var_name = make_unique_var_name('do_ret')
  ret_var_node.args = {ret_var_name}
  Compiler.ll_insert_before(orig_node, ret_var_node)
  node = ret_var_node

  local num_forms = 0

  while datum:seq() do
    local form = datum:first()

    num_forms = num_forms + 1

    local fence = Compiler.ll_new_node('VARFENCE', orig_node.environment)
    Compiler.ll_insert_after(node, fence)
    node = fence

    local lisp_node = Compiler.ll_new_node('LISP', orig_node.environment)
    lisp_node.args = {form}
    Compiler.ll_insert_after(node, lisp_node)
    table.insert(dirty_nodes, lisp_node)
    node = lisp_node

    local endfence = Compiler.ll_new_node('ENDVARFENCE', orig_node.environment)
    Compiler.ll_insert_after(node, endfence)
    node = endfence

    datum = datum:rest()
  end

  if num_forms > 0 then
    node.prev.set_var_name = ret_var_name
  end

  node = orig_node
  node.op = 'PRIMITIVE'
  node.args = { ret_var_name }
end

special_forms['let'] = function(node, datum, new_dirty_nodes)
  local orig_node = node

  local bindings = datum:first()
  assert(bindings and getmetatable(bindings) == PersistentVector and (bindings:count() % 2 == 0))
  local exprs = datum:rest()

  local ret_var_node = Compiler.ll_new_node('EMPTYVAR', orig_node.environment)
  local ret_var_name = make_unique_var_name('let_ret')
  ret_var_node.args = { ret_var_name }
  Compiler.ll_insert_before(orig_node, ret_var_node)
  node = ret_var_node

  local fence = Compiler.ll_new_node('VARFENCE', orig_node.environment)
  Compiler.ll_insert_after(node, fence)
  node = fence

  local extended_environment = orig_node.environment
  local i = 0
  while i < bindings:count() do
    -- TODO: support destructuring
    local var_symbol = bindings:get(i)
    local var_name = var_symbol.name
    extended_environment = extended_environment:extend_with({var_symbol})

    local form = bindings:get(i + 1)
    local lisp_node = Compiler.ll_new_node('NEWLVAR', extended_environment)
    lisp_node.args = { var_name, form }
    table.insert(new_dirty_nodes, lisp_node)
    Compiler.ll_insert_after(node, lisp_node)
    node = lisp_node

    i = i + 2
  end

  while exprs do
    local fence = Compiler.ll_new_node('VARFENCE', extended_environment)
    Compiler.ll_insert_after(node, fence)
    node = fence

    local lisp_node = Compiler.ll_new_node('LISP', extended_environment)
    lisp_node.args = { exprs:first() }
    if exprs:next() == nil then
      lisp_node.set_var_name = ret_var_name
    end
    table.insert(new_dirty_nodes, lisp_node)
    Compiler.ll_insert_after(node, lisp_node)
    node = lisp_node

    exprs = exprs:next()

    local endfence = Compiler.ll_new_node('ENDVARFENCE', extended_environment)
    Compiler.ll_insert_after(node, endfence)
    node = endfence
  end

  local endfence = Compiler.ll_new_node('ENDVARFENCE', extended_environment)
  Compiler.ll_insert_after(node, endfence)
  node = endfence

  node = orig_node
  node.op = 'PRIMITIVE'
  node.args = { ret_var_name }
end

-- (fn [arg0 arg1] (body))
special_forms['fn'] = function(node, datum, new_dirty_nodes)
  local func_var_name = make_unique_var_name('func')

  local orig_node = node
  node.op = 'PRIMITIVE'
  node.args = {func_var_name}

  local real_func_node = Compiler.ll_new_node('FUNC', orig_node.environment)
  Compiler.ll_insert_before(node, real_func_node)
  real_func_node.new_lvar_name = func_var_name
  node = real_func_node
  orig_node = node

  local bodies = {}
  local mt = datum.first and getmetatable(datum:first())
  if mt == PersistentVector then
    -- this function has only 1 arity
    table.insert(bodies, datum)
  elseif datum:first() then
    -- this function has multiple aritys
    while datum do
      table.insert(bodies, datum:first())
      datum = datum:next()
    end
  else
    assert(false)
  end

  local rest_arg_index = false

  for i = 1, #bodies do
    local body = bodies[i]
    local args = body:first()
    local exprs = body:rest()

    local extended_environment = orig_node.environment:extend_with(args:ToLuaArray())
    local func_node = Compiler.ll_new_node('FUNCBODY', extended_environment)
    Compiler.ll_insert_after(node, func_node)
    node = func_node
    node.args = {}; local slot = 1
    local function_arg_list = node.args
    node.parent = orig_node

    -- convert function argument symbols to string
    -- TODO: will I or someone ever put explicit namespace symbols here by accident?
    -- like (fn [foobar lol/wut] (+ foobar lol/wut))
    -- is it even worth it to check?
    local args_count = args:count()
    if args_count > 20 then
      if (args_count == 21 or args_count == 22) then
        if (args:get(20) == kAmpersandSymbol) then
          -- pass
        else
          assert(false, "Can't specify more than 20 params, did you mean to use (... & rest)?")
        end
      else
        assert(false, "Can't specify more than 20 params")
      end
    end
    for i = 0, args_count - 1 do
      local arg_name = tostring(args:get(i))
      if arg_name ~= '&' then
        node.args[slot] = arg_name
        slot = slot + 1
      else
        rest_arg_index = i + 1
      end
    end

    local entry_point_name = func_var_name .. '_entry_point'
    local rebind_point_name = func_var_name .. '_rebind_point'

    local rebind_args_list = {}
    extended_environment:set_recur_point('fn', rebind_point_name, rebind_args_list, rest_arg_index)

    for i = 1, #function_arg_list do
      local rebind_arg_node = Compiler.ll_new_node('EMPTYVAR', extended_environment)
      local rebind_arg_name = Compiler.make_unique_var_name('rebind_arg')
      rebind_arg_node.args = {rebind_arg_name}
      table.insert(rebind_args_list, rebind_arg_name)
      Compiler.ll_insert_after(node, rebind_arg_node)
      node = rebind_arg_node
    end

    local goto_entry_point_node = Compiler.ll_new_node('GOTO', extended_environment)
    goto_entry_point_node.args = {entry_point_name}
    Compiler.ll_insert_after(node, goto_entry_point_node)
    node = goto_entry_point_node

    -- rebind entry point
    local rebind_entry_point_node = Compiler.ll_new_node('LABEL', extended_environment)
    rebind_entry_point_node.args = {rebind_point_name}
    Compiler.ll_insert_after(node, rebind_entry_point_node)
    node = rebind_entry_point_node

    for i = 1, #function_arg_list do
      local rebind_var_node = Compiler.ll_new_node('PRIMITIVE', extended_environment)
      rebind_var_node.set_var_name = function_arg_list[i]
      rebind_var_node.args = {rebind_args_list[i]}
      Compiler.ll_insert_after(node, rebind_var_node)
      node = rebind_var_node
    end

    -- initial, normal entry point
    local entry_point_label_node = Compiler.ll_new_node('LABEL', extended_environment)
    entry_point_label_node.args = {entry_point_name}
    Compiler.ll_insert_after(node, entry_point_label_node)
    node = entry_point_label_node

    while exprs do
      local fence = Compiler.ll_new_node('VARFENCE', extended_environment)
      Compiler.ll_insert_after(node, fence)
      node = fence

      local lisp_node = Compiler.ll_new_node('LISP', extended_environment)
      table.insert(new_dirty_nodes, lisp_node)
      lisp_node.args = { exprs:first() }
      if exprs:next() == nil then
        lisp_node.is_return = true
      end
      Compiler.ll_insert_after(node, lisp_node)
      node = lisp_node

      local endfence = Compiler.ll_new_node('ENDVARFENCE', extended_environment)
      Compiler.ll_insert_after(node, endfence)
      node = endfence

      exprs = exprs:next()
    end

    local end_func_body_node = Compiler.ll_new_node('ENDFUNCBODY', extended_environment)
    Compiler.ll_insert_after(node, end_func_body_node)
    node = end_func_body_node
  end

  if rest_arg_index then
    local rest_args_at_node = Compiler.ll_new_node('RESTARGSAT', orig_node.environment)
    rest_args_at_node.args = {orig_node, rest_arg_index}
    Compiler.ll_insert_after(node, rest_args_at_node)
    node = rest_args_at_node
  end

  local end_func_node = Compiler.ll_new_node('ENDFUNC', orig_node.environment)
  Compiler.ll_insert_after(node, end_func_node)
end

special_forms['recur'] = function(node, datum, new_dirty_nodes)
  local env = node.environment
  local recur_type = env.recur_type
  local label = env.recur_label_name
  local rebind_args =  env.recur_arg_list
  local rest_arg_index = env.recur_rest_arg_index

  assert(type(label) == 'string', '(recur ...) does not have a valid point to jump to')

  local args = datum

  if recur_type == 'fn' then
    if not rest_arg_index then
      assert(#rebind_args == args:count(),
             'number of args supplied to (recur) does not match number of args of (fn)')
    else
      assert(args:count() >= (#rebind_args - 1),
             'number of args supplied to (recur) does not match number of args of (fn), maybe you forgot the rest argument?')
    end
  else
    assert(false, 'unkown (recur) type')
  end

  local arg_num = 1
  local rest_args = {}
  local rest_args_rebind_arg
  if rest_arg_index then
    rest_args_rebind_arg = rebind_args[rest_arg_index]
  end
  local had_some_rest_args = false
  while args:seq() do
    node.op = 'LISP'
    node.args = {args:first()}
    args = args:rest()

    if recur_type == 'fn' then
      if not rest_arg_index then
        -- easy, just set the variables one by one
        node.set_var_name = rebind_args[arg_num]
      else
        if arg_num < rest_arg_index then
          node.set_var_name = rebind_args[arg_num]
        else
          local seq_item_name = make_unique_var_name('array_seq_item')
          node.new_lvar_name = seq_item_name
          table.insert(rest_args, seq_item_name)
          had_some_rest_args = true
        end
      end
    else
      assert(false, 'unrecognized recur point type, please implement')
    end

    arg_num = arg_num + 1

    table.insert(new_dirty_nodes, node)

    local next_node = Compiler.ll_new_node('UNINITIALIZED', env)
    Compiler.ll_insert_after(node, next_node)
    node = next_node
  end

  if recur_type == 'fn' and rest_args_rebind_arg and had_some_rest_args then
    node.op = 'ARRAYSEQ'
    node.args = rest_args
    node.set_var_name = rest_args_rebind_arg

    local next_node = Compiler.ll_new_node('UNINITIALIZED', env)
    Compiler.ll_insert_after(node, next_node)
    node = next_node
  end
  -- I think this is needed in case a function has two possible (recur) calls ,
  -- where one uses the "rest" arg and then one doesn't. If this is the case,
  -- then the rest arg can contains "stale" data which totally breaks things in
  -- the subtlest ways possible.
  if recur_type == 'fn' and rest_args_rebind_arg and not had_some_rest_args then
    node.op = 'PRIMITIVE'
    node.args = {'nil'}
    node.set_var_name = rest_args_rebind_arg

    local next_node = Compiler.ll_new_node('UNINITIALIZED', env)
    Compiler.ll_insert_after(node, next_node)
    node = next_node
  end

  node.op = 'GOTO'
  node.args = {label}
end

Compiler.op_dispatch = {}
local op_dispatch = Compiler.op_dispatch

op_dispatch['LISP'] = function(node, new_dirty_nodes)
  local datum = node.args[1]
  local mt = getmetatable(datum)
  if mt == PersistentVector then
    local orig_node = node

    node.op = 'NEWVEC'
    node.args = {}

    for i = 0, datum:count() - 1 do
      local arg = datum:get(i)

      local vecadd_node = Compiler.ll_new_node('VECADD', orig_node.environment)
      table.insert(new_dirty_nodes, vecadd_node)
      vecadd_node.args = {orig_node, arg}
      Compiler.ll_insert_after(node, vecadd_node)
      node = vecadd_node
    end
  elseif mt == PersistentHashMap then
    local orig_node = node

    node.op = 'NEWMAP'
    node.args = {}

    local items = datum:seq()
    while items:seq() do
      local kv = items:first()
      local k = kv:get(0)
      local v = kv:get(1)

      local mapadd_node = Compiler.ll_new_node('MAPADD', orig_node.environment)
      table.insert(new_dirty_nodes, mapadd_node)
      mapadd_node.args = {orig_node, k, v}
      Compiler.ll_insert_after(node, mapadd_node)
      node = mapadd_node

      items = items:rest()
    end
  elseif type(datum) == 'table' and datum.first ~= nil then
    --print(tsukuyomi.print(datum))
    --print(util.show(datum))
    local first = datum:first()
    local rest = datum:rest()
    local symbol
    local symbol_name
    if getmetatable(first) == Symbol then
      symbol = first
      symbol_name = tostring(first)
    end

    assert(first ~= nil, 'tsukuyomi.lang.Compiler: attempted to call with a nil function or empty list')

    -- below does not hold, it make actually be another list, which returns a function,
    -- like: ((fn [x] (+ 1 x)) 42)
    -- assert(getmetatable(first) == Symbol)
    if special_forms[symbol_name] then
      special_forms[symbol_name](node, rest, new_dirty_nodes)
      return
    end

    -- check to see if this is actually a macro
    if symbol and not node.environment:has_symbol(symbol) then
      local len = symbol_name:len()
      -- make sure it is not an interop macro
      if symbol_name:sub(1, 1) ~= '.' and symbol_name:sub(len, len) ~= '.' then
        local bound_symbol = tsukuyomi_core['*ns*']:__bind_symbol__(symbol)
        local var = Var.GetVar(bound_symbol)
        if var == nil then
          local err = {
            'unable to resolve var: ',
            tostring(symbol),
            ' while checking for macro. attemped to retrieve Var ',
            tostring(bound_symbol),
          }
          assert(false, table.concat(err))
        end
        if var:is_macro() then
          local transformed_list = tsukuyomi_core['apply'][2](var:get(), rest)
          Compiler._log('*** MACRO TRANSFORMATION TO ***')
          Compiler._log(tsukuyomi.print(transformed_list))

          node.args[1] = transformed_list
          table.insert(new_dirty_nodes, node)
          return
        end
      end
    end

    if first == kDotSymbol then
      datum = datum:rest()

      local ns = datum:first()
      datum = datum:rest()

      local method = datum:first()
      datum = datum:rest()

      local real_sym = Symbol.intern(method.name, ns.name)
      datum = PersistentList.new(nil, real_sym, datum, 1 + datum:count())

      node.is_pure_lua_function = true
    end

    -- normal function call
    node.op = 'CALL'
    node.args, node.args_length = datum:ToLuaArray()
    table.insert(new_dirty_nodes, node)
  elseif mt == Keyword then
    node.op = 'KEYWORD'
    node.args = {datum}
  else
    local primitive = compile_lua_primitive(datum)
    node.op = 'PRIMITIVE'
    node.args = {primitive}
  end
end

op_dispatch['VECADD'] = function(node, new_dirty_nodes)
  local args = node.args

  local datum = args[2]
  if is_lua_primitive(datum) then
    args[2] = compile_lua_primitive(args[2])
  else
    local var_name = make_unique_var_name('vec_item')
    args[2] = var_name

    local datum_node = Compiler.ll_new_node('NEWLVAR', node.environment)
    datum_node.args = {var_name, datum}

    table.insert(new_dirty_nodes, datum_node)
    Compiler.ll_insert_before(node, datum_node)
  end
end

op_dispatch['MAPADD'] = function(node, new_dirty_nodes)
  local args = node.args

  local datum = args[2]
  if is_lua_primitive(datum) then
    args[2] = compile_lua_primitive(args[2])
  else
    local var_name = make_unique_var_name('map_key')
    args[2] = var_name

    local datum_node = Compiler.ll_new_node('NEWLVAR', node.environment)
    datum_node.args = {var_name, datum}

    table.insert(new_dirty_nodes, datum_node)
    Compiler.ll_insert_before(node, datum_node)
  end

  local datum = args[3]
  if is_lua_primitive(datum) then
    args[3] = compile_lua_primitive(args[3])
  else
    local var_name = make_unique_var_name('map_value')
    args[3] = var_name

    local datum_node = Compiler.ll_new_node('NEWLVAR', node.environment)
    datum_node.args = {var_name, datum}

    table.insert(new_dirty_nodes, datum_node)
    Compiler.ll_insert_before(node, datum_node)
  end
end

op_dispatch['CALL'] = function(node, new_dirty_nodes)
  local args = node.args
  for i = 1, node.args_length do
    if is_lua_primitive(args[i]) then
      args[i] = compile_lua_primitive(args[i])
    else
      local var_node = Compiler.ll_new_node('NEWLVAR', node.environment)
      table.insert(new_dirty_nodes, var_node)

      local var_name = make_unique_var_name('arg')
      var_node.args = {var_name, args[i]}
      args[i] = var_name
      Compiler.ll_insert_before(node, var_node)
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
function Compiler.compile_to_ir(datum)
  local head_node = Compiler.ll_new_node('LISP', LexicalEnvironment.new())
  head_node.args = {datum}
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

function Compiler._debug_ir(node)
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
        elseif type(arg) == 'table' and arg.op ~= nil and arg.environment ~= nil then
          table.insert(line, 'NODE(')
          table.insert(line, tostring(arg))
          table.insert(line, ')')
        else
          table.insert(line, tostring(arg))
        end

        if i < #args then
          table.insert(line, ', ')
        end
      end
    end

    assert(node.environment)
    local line_prefix = table.concat(line)
    line = {line_prefix}
    local spacing = 50 - line_prefix:len()
    spacing = math.max(spacing, 1)
    for i = 1, spacing do
      table.insert(line, ' ')
    end
    table.insert(line, tostring(node.environment))

    table.insert(lines, table.concat(line))
    node = node.next
  end

  return table.concat(lines, '\n')
end
