function tsukuyomi.compile_to_lua(ir_list)
  local lines = {}

  local indent_level = 0

  -- these are basically a variables that are not bound to the current
  -- namespace because a function being defined is generating them.
  --
  -- like
  --   (ns core)
  --   (lambda (a b c)
  --     (print a))
  --
  -- the "a" in "print a" would NOT bind to core.a, but the a of the lambda

  --mapping of variable name to number of time mentioned in enclosing functions
  local environment_symbols = {}
  local environment_stack = {}

  local function push_new_frame()
    table.insert(environment_stack, {})
  end
  local function add_arg_to_frame(arg_name)
    local frame = environment_stack[#environment_stack]
    table.insert(frame, arg_name)

    environment_symbols[arg_name] = environment_symbols[arg_name] or 0
    environment_symbols[arg_name] = environment_symbols[arg_name] + 1
  end
  local function pop_frame()
    local frame = table.remove(environment_stack)
    for i = 1, #frame do
      local arg_name = frame[i]
      environment_symbols[arg_name] = environment_symbols[arg_name] - 1
      if environment_symbols[arg_name] == 0 then
        environment_symbols[arg_name] = nil
      end
    end
  end

  local function resolve_symbol_or_string(datum)
    if type(datum) == 'string' then
      return datum
    elseif tsukuyomi.is_symbol(datum) then
      local name = tsukuyomi.get_symbol_name(datum)
      if environment_symbols[name] then
        return name
      else
        return tsukuyomi.symbol_to_lua(datum)
      end
    else
      assert(false)
    end
  end

  local insn = ir_list
  while insn do
    local line = {}

    -- IR instructions can be tagged in the following fashion to signal
    -- variable definition, or returning
    if insn.var_name then
      table.insert(line, 'local ')
      table.insert(line, insn.var_name)
      table.insert(line, ' = ')
    elseif insn.define_symbol and insn.op ~= 'FUNC' then
      table.insert(line, tsukuyomi.symbol_to_lua(insn.define_symbol))
      table.insert(line, " = ")
    end
    if insn.is_return then
      table.insert(line, 'return ')
    end

    if insn.op == 'NOP' then
      -- pass
    elseif insn.op == 'RAW' then
      table.insert(line, insn.args[1])
    elseif insn.op == 'SYMBOL' then
      local symbol = insn.args[1]
      if environment_symbols[tsukuyomi.get_symbol_name(symbol)] then
        table.insert(line, tsukuyomi.get_symbol_name(symbol))
      else
        table.insert(line, tsukuyomi.symbol_to_lua(symbol))
      end
    elseif insn.op == 'DATA' then
      table.insert(line, 'tsukuyomi._consume_data(')
      table.insert(line, insn.data_key)
      table.insert(line, ')')
    elseif insn.op == 'CALL' then
      local args = insn.args
      table.insert(line, resolve_symbol_or_string(args[1]))

      table.insert(line, '(')
      for i = 2, #args do
        table.insert(line, resolve_symbol_or_string(args[i]))
        if i < #args then
          table.insert(line, ', ')
        end
      end
      table.insert(line, ')')
    elseif insn.op == 'FUNC' then
      if not (insn.var_name or insn.define_symbol) then
        table.insert(line, 'local ')
      end
      table.insert(line, 'function ')
      if insn.define_symbol then
        table.insert(line, tsukuyomi.symbol_to_lua(insn.define_symbol))
      end
      push_new_frame()
      table.insert(line, '(')
      for i = 1, #insn.args do
        local arg_name = insn.args[i]
        add_arg_to_frame(arg_name)
        table.insert(line, arg_name)
        if i < #insn.args then
          table.insert(line, ', ')
        end
      end
      table.insert(line, ')')
    elseif insn.op == 'ENDFUNC' then
      table.insert(line, 'end')

      pop_frame()

      indent_level = indent_level - 1
    elseif insn.op == 'LISP' then
      table.insert(line, '-- ')
      table.insert(line, tsukuyomi.print(insn.args[1]))
    end

    if #line > 0 then
      for i = 1, indent_level do
        table.insert(line, 1, '    ')
      end
      table.insert(lines, table.concat(line))
    end

    if insn.op == 'FUNC' then
      indent_level = indent_level + 1
    end

    insn = insn.next
  end

  assert(#environment_stack == 0)
  for _, frame in pairs(environment_symbols) do
    assert(false)
  end

  return table.concat(lines, '\n')
end
