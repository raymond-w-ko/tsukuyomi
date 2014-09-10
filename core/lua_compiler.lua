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
-- e.g. 2 would print instead of 1

--mapping of variable name to number of time mentioned in enclosing functions
local function push_new_frame(stack)
  table.insert(stack, {})
end

local function add_arg_to_frame(stack, arg_name, fn_arg_symbols)
  local frame = stack[#stack]
  table.insert(frame, arg_name)

  fn_arg_symbols[arg_name] = fn_arg_symbols[arg_name] or 0
  fn_arg_symbols[arg_name] = fn_arg_symbols[arg_name] + 1
end

local function pop_frame(stack, fn_arg_symbols)
  local frame = table.remove(stack)
  for i = 1, #frame do
    local arg_name = frame[i]
    fn_arg_symbols[arg_name] = fn_arg_symbols[arg_name] - 1
    if fn_arg_symbols[arg_name] == 0 then
      fn_arg_symbols[arg_name] = nil
    end
  end
end

local safe_char_map = {
  ['+'] = '__PLUS__',
  ['-'] = '_MINUS__',
  ['*'] = '__ASTERISK__',
  ['/'] = '__SLASH__',
}
local function to_lua_identifier(lisp_name)
  local safe_var = {}
  for i = 1, lisp_name:len() do
    local ch = lisp_name:sub(i, i)
    local safe_ch = safe_char_map[ch]
    safe_ch = safe_ch or ch
    safe_var[i] = safe_ch
  end
  return table.concat(safe_var)
end

-- convert Lisp namespace name to a valid Lua identifier, with some prefix so
-- that it doesn't get accidentally called
function convert_ns_to_lua(ns)
  -- TODO: SO much here to make it safe
  return '__' .. ns
end

local function symbol_to_lua(symbol, used_namespaces)
  local code = {}

  local namespace = tsukuyomi.get_symbol_namespace(symbol)
  local name = tsukuyomi.get_symbol_name(symbol)
  if namespace then
    table.insert(code, convert_ns_to_lua(namespace))
    used_namespaces[namespace] = true
  else
    local active_ns = tsukuyomi['*ns*'][symbol]
    table.insert(code, convert_ns_to_lua(active_ns))
    used_namespaces[active_ns] = true
  end

  table.insert(code, '.')
  table.insert(code, to_lua_identifier(name))

  return table.concat(code)
end

local kNilSymbol = tsukuyomi.create_symbol("nil")

local function compile_string_or_symbol(datum, fn_arg_symbols, used_namespaces)
  if type(datum) == 'string' then
    return datum
  elseif datum == kNilSymbol then
    return 'nil'
  elseif tsukuyomi.is_symbol(datum) then
    local name = tsukuyomi.get_symbol_name(datum)
    if fn_arg_symbols[name] then
      return name
    else
      return symbol_to_lua(datum, used_namespaces)
    end
  else
    assert(false)
  end
end

local data_var_counter = -1
local function make_unique_data_var(data_bindings, data_key)
  data_var_counter = data_var_counter + 1
  local var_name = '__data' .. tostring(data_var_counter)
  data_bindings[var_name] = data_key
  return var_name
end

function tsukuyomi.compile_to_lua(ir_list)
  local lines = {}

  local indent = 0
  local stack = {}
  local fn_arg_symbols = {}

  local used_namespaces = {}
  local data_bindings = {}

  local insn = ir_list
  while insn do
    local line = {}
    local function emit(...)
      local t = {...}
      for _, text in ipairs(t) do
        table.insert(line, text)
      end
    end

    -- IR instructions can be tagged in the following fashion to signal
    -- variable definition, or returning
    if insn.var_name and insn.op ~= 'FUNC' then
      emit('local ', insn.var_name, ' = ')
    elseif insn.define_symbol and insn.op ~= 'FUNC' then
      emit(symbol_to_lua(insn.define_symbol, used_namespaces), " = ")
    elseif insn.is_return then
      emit('return ')
    end

    if insn.op == 'NOP' then
      -- pass
    elseif insn.op == 'NS' then
      emit('tsukuyomi.set_active_namespace("')
      emit(tsukuyomi.get_symbol_name(insn.args[1]))
      emit('"); ')
    elseif insn.op == 'PRIMITIVE' then
      emit(compile_string_or_symbol(insn.args[1], fn_arg_symbols, used_namespaces))
    elseif insn.op == 'RAW' then
      emit(insn.args[1])
    elseif insn.op == 'DATA' then
      emit(make_unique_data_var(data_bindings, insn.data_key))
    elseif insn.op == 'CALL' then
      local args = insn.args
      emit(compile_string_or_symbol(insn.args[1], fn_arg_symbols, used_namespaces))
      emit('(')
      for i = 2, #args do
        emit(compile_string_or_symbol(args[i], fn_arg_symbols, used_namespaces))
        if i < #args then
          emit(', ')
        end
      end
      emit( ')')
    elseif insn.op == 'FUNC' then
      if insn.var_name then emit('local ') end
      emit('function ')
      if insn.define_symbol then emit(symbol_to_lua(insn.define_symbol, used_namespaces))
      elseif insn.var_name then emit(insn.var_name) end
      emit('(')
      push_new_frame(stack)
      for i = 1, #insn.args do
        local arg_name = insn.args[i]
        add_arg_to_frame(stack, arg_name, fn_arg_symbols)
        emit(arg_name)
        if i < #insn.args then emit(', ') end
      end
      emit(')')
    elseif insn.op == 'ENDFUNC' then
      emit('end')
      pop_frame(stack, fn_arg_symbols)
      indent = indent - 1
    elseif insn.op == 'IF' then
      emit('if ', insn.args[1], ' then')
    elseif insn.op == 'ELSE' then
      indent = indent - 1
      emit('else')
    elseif insn.op == 'ENDIF' then
      indent = indent - 1
      emit('end')
    else
      print('unknown opcode: ' .. insn.op)
      assert(false)
    end

    if #line > 0 then
      for i = 1, indent do
        table.insert(line, 1, '    ')
      end
      table.insert(lines, table.concat(line))
    end

    -- indent change after line is generated
    if insn.op == 'FUNC' then
      indent = indent + 1
    elseif insn.op == 'IF' then
      indent = indent + 1
    elseif insn.op == 'ELSE' then
      indent = indent + 1
    end

    insn = insn.next
  end

  -- sanity checks to make sure there aren't error in the IR with lambda generation
  assert(#stack == 0)
  for _, frame in pairs(fn_arg_symbols) do
    assert(false)
  end

  local body = table.concat(lines, '\n')

  local header = {}
  table.insert(header, 'local tsukuyomi = tsukuyomi')
  table.insert(header, '')
  -- write out used namespaces
  local has_namespace = false
  for ns, _ in pairs(used_namespaces) do
    has_namespace = true
    local line = {}
    table.insert(line, 'local ')
    table.insert(line, convert_ns_to_lua(ns))
    table.insert(line, ' = tsukuyomi.get_namespace("')
    table.insert(line, ns)
    table.insert(line, '")')
    table.insert(header, table.concat(line))
  end
  if has_namespace then
    table.insert(header, '')
  end

  -- write out data bindings
  local has_data_bindings = false
  for data_var_name, data_key in pairs(data_bindings) do
    has_data_bindings = true
    local line = {}
    table.insert(line, 'local ')
    table.insert(line, data_var_name)
    table.insert(line, ' = tsukuyomi._get_data(')
    table.insert(line, data_key)
    table.insert(line, ')')
    table.insert(header, table.concat(line))
  end
  if has_data_bindings then
    table.insert(header, '')
  end

  local final = {}
  table.insert(final, table.concat(header, '\n'))
  table.insert(final, body)
  return table.concat(final, '\n')
end
