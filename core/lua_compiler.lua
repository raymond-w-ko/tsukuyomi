local tsukuyomi = tsukuyomi
local Symbol = tsukuyomi.lang.Symbol
local Compiler = tsukuyomi.lang.Namespace.GetNamespaceSpace('tsukuyomi.lang.Compiler')

local safe_char_map = {
  ['+'] = '__ADD__',
  ['-'] = '__SUB__',
  ['*'] = '__MUL__',
  ['/'] = '__DIV__',
  ['.'] = '__DOT__',
  ['?'] = '__QMARK__',
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
local function convert_ns_to_lua(ns)
  return '__' .. to_lua_identifier(ns)
end

local tsukuyomi_core_ns = tsukuyomi.lang.Namespace.GetNamespaceSpace('tsukuyomi.core')
local function symbol_to_lua(symbol, used_namespaces)
  local code = {}
  local bound_symbol = tsukuyomi_core_ns['*ns*']:bind_symbol(symbol)

  local namespace = bound_symbol.namespace
  if namespace then
    table.insert(code, convert_ns_to_lua(namespace))
    used_namespaces[namespace] = true
  end

  table.insert(code, '["')
  table.insert(code, bound_symbol.name)
  table.insert(code, '"]')

  return table.concat(code)
end

local kNilSymbol = Symbol.intern('nil')
local function compile_string_or_symbol(datum, environment, used_namespaces)
  if type(datum) == 'string' then
    return datum
  elseif datum == kNilSymbol then
    return 'nil'
  elseif getmetatable(datum) == Symbol then
    if environment:has_symbol(datum) then
      return datum.name
    else
      return symbol_to_lua(datum, used_namespaces)
    end
  else
    assert(false)
  end
end

local function make_unique_data_var(data_bindings, data_key)
  local var_name = '__data' .. tostring(data_key)
  data_bindings[var_name] = data_key
  return var_name
end

function Compiler.compile_to_lua(ir_list)
  local lines = {}

  local indent = 0
  local used_namespaces = {}
  local data_bindings = {}

  local insn = ir_list
  local line = {}
  local function emit(...)
    local t = {...}
    for _, text in ipairs(t) do
      table.insert(line, text)
    end
  end
  while insn do
    -- IR instructions can be tagged in the following fashion to signal
    -- variable definition, or returning
    if insn.new_lvar_name and insn.op ~= 'FUNCBODY' then
      emit('local ', insn.new_lvar_name, ' = ')
    elseif insn.set_var_name then
      emit(insn.set_var_name, ' = ')
    elseif insn.define_symbol and insn.op ~= 'FUNCBODY' then
      emit(symbol_to_lua(insn.define_symbol, used_namespaces), " = ")
    elseif insn.is_return then
      emit('return ')
    end

    if insn.op == 'NOP' then
      -- pass
    elseif insn.op == 'EMPTYVAR' then
      emit('local ', insn.args[1])
    elseif insn.op == 'NS' then
      emit('tsukuyomi.lang.Namespace.SetActiveNamespace("')
      emit(insn.args[1].name)
      emit('"); ')
    elseif insn.op == 'PRIMITIVE' then
      emit(compile_string_or_symbol(insn.args[1], insn.environment, used_namespaces))
    elseif insn.op == 'RAW' then
      emit(insn.args[1])
    elseif insn.op == 'DATA' then
      emit(make_unique_data_var(data_bindings, insn.data_key))
    elseif insn.op == 'CALL' then
      local args = insn.args
      emit(compile_string_or_symbol(insn.args[1], insn.environment, used_namespaces))
      local arity = #args - 1
      emit('[', tostring(arity), ']')
      emit('(')
      for i = 2, #args do
        emit(compile_string_or_symbol(args[i], insn.environment, used_namespaces))
        if i < #args then
          emit(', ')
        end
      end
      emit( ')')
    elseif insn.op == 'FUNC' then
      emit('tsukuyomi.lang.Function.new()')
    elseif insn.op == 'FUNCBODY' then
      local arity = #insn.args
      if insn.new_lvar_name then
        emit(insn.new_lvar_name)
        emit('[', tostring(arity), ']')
      elseif insn.define_symbol then
        emit(symbol_to_lua(insn.define_symbol, used_namespaces))
        emit('[', tostring(arity), ']')
      end
      emit(' = function ')
      emit('(')
      for i = 1, #insn.args do
        local arg_name = insn.args[i]
        emit(arg_name)
        if i < #insn.args then emit(', ') end
      end
      emit(')')
    elseif insn.op == 'ENDFUNCBODY' then
      emit('end')
      indent = indent - 1
    elseif insn.op == 'ENDFUNC' then
      -- pass
    elseif insn.op == 'IF' then
      emit('if ', insn.args[1], ' then')
    elseif insn.op == 'ELSE' then
      indent = indent - 1
      emit('else')
    elseif insn.op == 'ENDIF' then
      indent = indent - 1
      emit('end')
    elseif insn.op == 'VARFENCE' then
      emit('do')
    elseif insn.op == 'ENDVARFENCE' then
      emit('end')
      indent = indent - 1
    else
      print('unknown opcode: ' .. insn.op)
      assert(false)
    end

    if #line > 0 then
      for i = 1, indent do
        table.insert(line, 1, '\t')
      end
      table.insert(lines, table.concat(line))
      line = {}
    end

    -- indent change after line is generated
    if insn.op == 'FUNCBODY' then
      indent = indent + 1
    elseif insn.op == 'IF' then
      indent = indent + 1
    elseif insn.op == 'ELSE' then
      indent = indent + 1
    elseif insn.op == 'VARFENCE' then
      indent = indent + 1
    end

    insn = insn.next
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
    table.insert(line, ' = tsukuyomi.lang.Namespace.GetNamespaceSpace("')
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
    table.insert(line, ' = tsukuyomi.retrieve_data(')
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
