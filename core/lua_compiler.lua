local tsukuyomi = require('tsukuyomi')
local tsukuyomi_core = require('tsukuyomi.core')
local Symbol = require('tsukuyomi.lang.Symbol')
local Namespace = require('tsukuyomi.lang.Namespace')
local Compiler = Namespace.intern('tsukuyomi.lang.Compiler')
local Var = require('tsukuyomi.lang.Var')
local Namespace = require('tsukuyomi.lang.Namespace')

local safe_char_map = {
  -- is the below a good idea?
  -- or is the following needed instead?
  --['-'] = '__SUB__',
  --['.'] = '__DOT__',
  ['-'] = '_',
  ['.'] = '_',

  ['+'] = '__ADD__',
  ['*'] = '__MUL__',
  ['/'] = '__DIV__',
  ['?'] = '__QMARK__',
  [':'] = '__COLON__',
}
function Compiler.to_safe_lua_identifier(lisp_name)
  local safe_var = {}
  for i = 1, lisp_name:len() do
    local ch = lisp_name:sub(i, i)
    local safe_ch = safe_char_map[ch]
    safe_ch = safe_ch or ch
    safe_var[i] = safe_ch
  end
  return table.concat(safe_var)
end

local function check_var_exists(bound_symbol)
  local lisp_var_exists = Var.GetVar(bound_symbol)
  local ns = Namespace.intern(bound_symbol.namespace)
  local external_var_exists = ns[bound_symbol.name]

  if lisp_var_exists ~= nil or external_var_exists ~= nil then
    return
  end

  local err = {
    'unable to resolve var: ',
    tostring(bound_symbol),
    ' while compiling to Lua',
  }
  assert(false, table.concat(err))
end

local function symbol_to_lua(state, symbol, skip_var_existence_check)
  local code = {}
  local bound_symbol = tsukuyomi_core['*ns*']:__bind_symbol__(symbol)

  -- var existence check should only be skipped when defining something
  if not skip_var_existence_check then
    check_var_exists(bound_symbol)
  end

  local namespace = bound_symbol.namespace
  if namespace then
    table.insert(code, Compiler.compile_ns(state, namespace))
  end

  table.insert(code, '["')
  table.insert(code, bound_symbol.name)
  table.insert(code, '"]')

  return table.concat(code)
end

local kNilSymbol = Symbol.intern('nil')
local function compile_string_or_symbol(state, datum, environment)
  if type(datum) == 'string' then
    return datum
  elseif datum == kNilSymbol then
    return 'nil'
  elseif getmetatable(datum) == Symbol then
    if environment:has_symbol(datum) then
      return datum.name
    else
      return symbol_to_lua(state, datum)
    end
  else
    assert(false)
  end
end

local function get_bound_var_name(state, obj)
  local name

  if obj.new_lvar_name then
    assert(name == nil)
    name = obj.new_lvar_name
  end
  if obj.define_symbol then
    assert(name == nil)
    name = symbol_to_lua(state, obj.define_symbol, true)
  end
  if obj.set_var_name then
    assert(name == nil)
    name = obj.set_var_name
  end

  assert(name)
  return name
end

function Compiler.compile_ns(state, ns)
  local identifier = '__NS__' .. Compiler.to_safe_lua_identifier(ns)
  if not state.seen_namespaces[ns] then
    table.insert(state.seen_namespaces_list, {identifier, ns})
    state.seen_namespaces[ns] = true
  end
  return identifier
end

function Compiler.compile_symbol(state, symbol)
  local full_symbol_name = tostring(symbol)
  local identifier = '__SYM__' .. Compiler.to_safe_lua_identifier(full_symbol_name)
  if not state.seen_symbols[full_symbol_name] then
    table.insert(state.seen_symbols_list, {identifier, {symbol.name, symbol.namespace}})
    state.seen_namespaces[full_symbol_name] = true
  end
  return identifier
end

function Compiler.compile_keyword(state, keyword)
  local full_keyword_name = tostring(keyword)
  local identifier = '__KEYWORD__' .. Compiler.to_safe_lua_identifier(full_keyword_name)
  if not state.seen_keywords[full_keyword_name] then
    table.insert(state.seen_keywords_list,
                 {identifier, Compiler.compile_symbol(state, keyword.sym)})
    state.seen_namespaces[full_keyword_name] = true
  end
  return identifier
end

function Compiler.compile_data(state, data)
  local var_name = Compiler.make_unique_var_name('data')
  local data_str = string.format('%q', tsukuyomi_core['pr-str'][1](data))
  table.insert(state.data_list, {var_name, data_str})
  return var_name
end

local insn_dispatch = {}
Compiler.insn_dispatch = insn_dispatch
local insn_dispatch_mt = {}
insn_dispatch_mt.__index = insn_dispatch_mt
function insn_dispatch_mt.__index(t, k)
  assert(false, 'Lua compiler missing opcode dispatch for: ' .. k)
end
setmetatable(insn_dispatch, insn_dispatch_mt)

insn_dispatch['NOP'] = function(insn, state, line)
end

insn_dispatch['EMPTYVAR'] = function(insn, state, line)
  table.insert(state.line, 'local ')
  table.insert(state.line, insn.args[1])
end

insn_dispatch['NS'] = function(insn, state, line)
  table.insert(state.line, Compiler.compile_ns(state, 'tsukuyomi.lang.Namespace'))
  table.insert(state.line, '.SetActiveNamespace("')
  table.insert(state.line, insn.args[1].name)
  table.insert(state.line, '"); ')
end

insn_dispatch['PRIMITIVE'] = function(insn, state, line)
  table.insert(state.line, compile_string_or_symbol(state, insn.args[1], insn.environment))
end

insn_dispatch['RAW'] = function(insn, state, line)
  table.insert(state.line, insn.args[1])
end

insn_dispatch['DATA'] = function(insn, state, line)
  table.insert(state.line, Compiler.compile_data(state, insn.args[1]))
end

insn_dispatch['CALL'] = function(insn, state, line)
  local args = insn.args

  local fn = insn.args[1]
  assert(getmetatable(fn) == Symbol or type(fn) == 'string')
  local name_len
  if getmetatable(fn) == Symbol then
    name_len = fn.name:len()
  elseif type(fn) == 'string' then
    name_len = fn:len()
  else
    -- does this always hold true? are there other things that are callable?
  end

  local arg_start_index
  local num_func_symbols

  if getmetatable(fn) == Symbol and fn.namespace == nil and fn.name:sub(1, 1) == '.' then
    -- object oriented function call
    -- (.method_name object arg0 arg1 ... argN)
    table.insert(state.line, compile_string_or_symbol(state, args[2], insn.environment))
    table.insert(state.line, ':')
    table.insert(state.line, fn.name:sub(2))

    arg_start_index = 3
    num_func_symbols = 2
  elseif getmetatable(fn) == Symbol and fn.name:sub(name_len, name_len) == '.' then
    -- Protoype.new style constructor call
    -- (Namespace/Prototype.)
    local real_sym = Symbol.intern(args[1].name:sub(1, name_len - 1), args[1].namespace)
    table.insert(state.line, compile_string_or_symbol(state, args[2], insn.environment))
    table.insert(state.line, '.new')

    arg_start_index = 2
    num_func_symbols = 1
  else
    table.insert(state.line, compile_string_or_symbol(state, fn, insn.environment))
    local arity = #args - 1
    if not insn.is_pure_lua_function then
      table.insert(state.line, '[')
      table.insert(state.line, tostring(math.min(arity, 21)))
      table.insert(state.line, ']')
    end

    arg_start_index = 2
    num_func_symbols = 1
  end

  table.insert(state.line, '(')

  local stray_args_max_bounds = math.min(20 + num_func_symbols, #args)
  for i = arg_start_index, stray_args_max_bounds do
    table.insert(state.line, compile_string_or_symbol(state, args[i], insn.environment))
    if i < stray_args_max_bounds then
      table.insert(state.line, ', ')
    end
  end
  if #args > (20 + num_func_symbols) then
    table.insert(state.line, ', ')
    table.insert(state.line, Compiler.compile_ns(state, 'tsukuyomi.lang.ArraySeq'))
    table.insert(state.line, '.new(nil, {')
    for i = 21 + num_func_symbols, #args do
      table.insert(state.line, compile_string_or_symbol(state, args[i], insn.environment))
      if i < #args then
        table.insert(state.line, ', ')
      end
    end
    table.insert(state.line, '}, 1, ')
    table.insert(state.line, tostring(#args - 20 - num_func_symbols))
    table.insert(state.line,  ')')
  end
  table.insert(state.line,  ')')
end

insn_dispatch['FUNC'] = function(insn, state, line)
  table.insert(state.line, Compiler.compile_ns(state,  'tsukuyomi.lang.Function'))
  table.insert(state.line, '.new()')
end

insn_dispatch['FUNCBODY'] = function(insn, state, line)
  local arity = #insn.args
  table.insert(state.line, get_bound_var_name(state, insn.parent))
  table.insert(state.line, '[')
  table.insert(state.line, tostring(arity))
  table.insert(state.line, ']')
  table.insert(state.line, ' = function ')
  table.insert(state.line, '(')
  for i = 1, #insn.args do
    local arg_name = insn.args[i]
    table.insert(state.line, arg_name)
    if i < #insn.args then
      table.insert(state.line, ', ')
    end
  end
  table.insert(state.line, ')')
end

insn_dispatch['RESTARGSAT'] = function(insn, state, line)
  local args = insn.args

  table.insert(state.line, Compiler.compile_ns(state,  'tsukuyomi.lang.Function'))
  table.insert(state.line, '.make_functions_for_rest(')

  table.insert(state.line, get_bound_var_name(state, args[1]))

  table.insert(state.line, ', ')
  table.insert(state.line, insn.args[2])
  table.insert(state.line, ')')
end

insn_dispatch['ENDFUNCBODY'] = function(insn, state, line)
  table.insert(state.line, 'end')
  state.indent = state.indent - 1
end

insn_dispatch['ENDFUNC'] = function(insn, state, line)
end

insn_dispatch['IF'] = function(insn, state, line)
  table.insert(state.line, 'if ')
  table.insert(state.line, insn.args[1])
  table.insert(state.line, ' then')
end

insn_dispatch['ELSE'] = function(insn, state, line)
  state.indent = state.indent - 1
  table.insert(state.line, 'else')
end

insn_dispatch['ENDIF'] = function(insn, state, line)
  state.indent = state.indent - 1
  table.insert(state.line, 'end')
end

insn_dispatch['VARFENCE'] = function(insn, state, line)
  table.insert(state.line, 'do')
end

insn_dispatch['ENDVARFENCE'] = function(insn, state, line)
  table.insert(state.line, 'end')
  state.indent = state.indent - 1
end

insn_dispatch['INTERNVAR'] = function(insn, state, line)
  table.insert(state.line, Compiler.compile_ns(state, 'tsukuyomi.lang.Var'))
  table.insert(state.line, '.intern(')
  table.insert(state.line, Compiler.compile_data(state, insn.args[1]))
  table.insert(state.line, '):set_metadata(')
  table.insert(state.line, Compiler.compile_data(state, insn.args[2]))
  table.insert(state.line, ')')
end

insn_dispatch['GETVAR'] = function(insn, state, line)
  table.insert(state.line, Compiler.compile_ns(state, 'tsukuyomi.lang.Var'))
  table.insert(state.line, '.GetVar(')
  table.insert(state.line, Compiler.compile_data(state, insn.args[1]))
  table.insert(state.line, ')')
end

insn_dispatch['NEWVEC'] = function(insn, state, line)
  table.insert(state.line, Compiler.compile_ns(state,  'tsukuyomi.lang.PersistentVector'))
  table.insert(state.line, '.new()')
end

insn_dispatch['VECADD'] = function(insn, state, line)
  local vec = insn.args[1]
  local datum = insn.args[2]
  local vec_name = get_bound_var_name(state, vec)
  table.insert(state.line, vec_name)
  table.insert(state.line, ' = ')
  table.insert(state.line, vec_name)
  table.insert(state.line, ':conj(')
  table.insert(state.line, compile_string_or_symbol(state, insn.args[2], insn.environment))
  table.insert(state.line, ')')
end

insn_dispatch['NEWMAP'] = function(insn, state, line)
  table.insert(state.line, Compiler.compile_ns(state,  'tsukuyomi.lang.PersistentHashMap'))
  table.insert(state.line, '.new()')
end

insn_dispatch['MAPADD'] = function(insn, state, line)
  local map = insn.args[1]
  local k = insn.args[2]
  local v = insn.args[3]
  local map_name = get_bound_var_name(state, map)
  table.insert(state.line, map_name)
  table.insert(state.line, ' = ')
  table.insert(state.line, map_name)
  table.insert(state.line, ':assoc(')
  table.insert(state.line, compile_string_or_symbol(state, insn.args[2], insn.environment))
  table.insert(state.line, ', ')
  table.insert(state.line, compile_string_or_symbol(state, insn.args[3], insn.environment))
  table.insert(state.line, ')')
end

insn_dispatch['KEYWORD'] = function(insn, state, line)
  table.insert(state.line, Compiler.compile_keyword(state, insn.args[1]))
end

function Compiler.compile_to_lua(ir_list)
  local lines = {}

  local state = {
    indent = 0,
    line = {},

    seen_namespaces = {},
    seen_namespaces_list = {},

    seen_symbols = {},
    seen_symbols_list = {},

    seen_keywords = {},
    seen_keywords_list = {},

    data_list = {},
  }

  local insn = ir_list
  while insn do
    -- IR instructions can be tagged in the following fashion to signal
    -- variable definition, or returning
    if insn.new_lvar_name then
      table.insert(state.line, 'local ')
      table.insert(state.line, insn.new_lvar_name)
      table.insert(state.line, ' = ')
    elseif insn.set_var_name then
      table.insert(state.line, insn.set_var_name)
      table.insert(state.line, ' = ')
    elseif insn.define_symbol then
      table.insert(state.line, symbol_to_lua(state, insn.define_symbol, true))
      table.insert(state.line, " = ")
    elseif insn.is_return then
      table.insert(state.line, 'return ')
    end

    insn_dispatch[insn.op](insn, state)

    if #state.line > 0 then
      for i = 1, state.indent do
        table.insert(state.line, 1, '\t')
      end
      table.insert(lines, table.concat(state.line))
      state.line = {}
    end

    -- state.indent change after line is generated
    if insn.op == 'FUNCBODY' then
      state.indent = state.indent + 1
    elseif insn.op == 'IF' then
      state.indent = state.indent + 1
    elseif insn.op == 'ELSE' then
      state.indent = state.indent + 1
    elseif insn.op == 'VARFENCE' then
      state.indent = state.indent + 1
    end

    insn = insn.next
  end

  local body = table.concat(lines, '\n')

  local final = {}

  if #state.seen_symbols_list > 0 then
    Compiler.compile_ns(state, 'tsukuyomi.lang.Symbol')
  end
  if #state.seen_keywords_list > 0 then
    Compiler.compile_ns(state, 'tsukuyomi.lang.Keyword')
  end
  if #state.data_list > 0 then
    Compiler.compile_ns(state, 'tsukuyomi.core')
  end

  -- write out seen namespaces
  for i = 1, #state.seen_namespaces_list do
    local pair = state.seen_namespaces_list[i]
    local line = {}
    table.insert(line, 'local ')
    table.insert(line, pair[1])
    table.insert(line, ' = require("')
    table.insert(line, pair[2])
    table.insert(line, '")')
    table.insert(final, table.concat(line))
  end
  table.insert(final, '')

  -- write out seen symbols
  for i = 1, #state.seen_symbols_list do
    local pair = state.seen_symbols_list[i]
    local symbol = pair[2]
    local line = {}
    table.insert(line, 'local ')
    table.insert(line, pair[1])
    table.insert(line, ' = ')
    table.insert(line, Compiler.compile_ns(state, 'tsukuyomi.lang.Symbol'))
    table.insert(line, '.intern(')
    table.insert(line, string.format('%q', symbol[1]))
    table.insert(line, '')
    if symbol[2] then
      table.insert(line, ', ')
      table.insert(line, string.format('%q', symbol[2]))
    end
    table.insert(line, ')')
    table.insert(final, table.concat(line))
  end
  table.insert(final, '')

  -- write out seen keywords
  for i = 1, #state.seen_keywords_list do
    local pair = state.seen_keywords_list[i]
    local line = {}
    table.insert(line, 'local ')
    table.insert(line, pair[1])
    table.insert(line, ' = ')
    table.insert(line, Compiler.compile_ns(state, 'tsukuyomi.lang.Keyword'))
    table.insert(line, '.intern(')
    table.insert(line, pair[2])
    table.insert(line, ')')
    table.insert(final, table.concat(line))
  end
  table.insert(final, '')

  -- write out data
  for i = 1, #state.data_list do
    local pair = state.data_list[i]
    local line = {}
    table.insert(line, 'local ')
    table.insert(line, pair[1])
    table.insert(line, ' = ')
    table.insert(line, Compiler.compile_ns(state, 'tsukuyomi.core'))
    table.insert(line, '.read[1](')
    table.insert(line, pair[2])
    table.insert(line, ')')
    table.insert(final, table.concat(line))
  end
  table.insert(final, '')

  table.insert(final, body)

  return table.concat(final, '\n')
end
