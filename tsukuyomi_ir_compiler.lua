-- special forms
local kNsSymbol = tsukuyomi.create_symbol('ns')
local kQuoteSymbol = tsukuyomi.create_symbol('quote')
local kSetSymbol = tsukuyomi.create_symbol('set!')
local kDefineSymbol = tsukuyomi.create_symbol('define')
local kIfSymbol = tsukuyomi.create_symbol('if')
local kLambdaSymbol = tsukuyomi.create_symbol('lambda')
local kRawSymbol = tsukuyomi.create_symbol('_raw_')

local var_counter = -1
local function make_unique_var_name()
  var_counter = var_counter + 1
  return '__Var' .. tostring(var_counter)
end

local data_key_counter = -1
local function make_unique_data_key()
  data_key_counter = data_key_counter + 1
  return data_key_counter
end

local function is_lua_primitive(datum)
  if type(datum) == 'string' or type(datum) == 'number' or type(datum) == 'boolean' or
    tsukuyomi.is_symbol(datum) then
    return true
  else
    return false
  end

  return false
end

local function compile_symbol(datum, current_ns)
    if tsukuyomi.get_symbol_namespace(current_ns) then
      return datum
    elseif current_ns then
      return tsukuyomi.create_symbol(tsukuyomi.get_symbol_name(datum), current_ns)
    else
      -- could not compile resolve symbol to namespace
      assert(false)
    end
    return datum
end

local function compile_lua_primitive(datum, current_ns)
  if type(datum) == 'number' or type(datum) == 'boolean' then
    return tostring(datum)
  end

  if type(datum) == 'string' then
    return '"' .. datum .. '"'
  end

  if tsukuyomi.is_symbol(datum) then
    return compile_symbol(datum, current_ns)
  end

  -- if using is_lua_primitive, this should never happend
  assert(false)
end

function tsukuyomi.compile_to_ir(head_node)
  local current_ns = nil

  local dirty_nodes = {}

  local node = head_node
  while node do
    table.insert(dirty_nodes, node)
    node = node.next
  end

  while #dirty_nodes > 0 do
    local new_dirty_nodes = {}

    for _, node in ipairs(dirty_nodes) do
      local op = node.op
      local args = node.args
      if op == 'LISP' then
        local datum = args[1]

        if tsukuyomi.is_cons_cell(datum) then
          local first = datum[1]
          local rest = datum[2]
          
          if first == kRawSymbol then
            node.op = 'RAW'
            local inline = rest[1]
            assert(type(inline) == 'string')
            node.args = { inline }
          elseif first == kQuoteSymbol then
            -- TODO
            node.op = 'DATA'
            node.data_key = make_unique_data_key()
            tsukuyomi._data[node.data_key] = rest[1]
          elseif first == kIfSymbol then
            assert(false)
          elseif first == kLambdaSymbol then
            -- (labmda (arg0 arg1) (body))
            node.op = 'FUNC'
            node.args = tsukuyomi.cons_to_lua_array(rest[1])
            -- convert symbol to string
            for i = 1, #node.args do
              node.args[i] = tostring(node.args[i])
            end
            
            local body = rest[2]
            while body and body[1] do
              local lisp_node = tsukuyomi.ll_new_node('LISP')
              table.insert(new_dirty_nodes, lisp_node)
              lisp_node.args = { body[1] }
              if body[2] == nil then
                lisp_node.is_return = true
              end
              tsukuyomi.ll_insert_after(node, lisp_node)

              node = lisp_node
              body = body[2]
            end

            local end_func_node = tsukuyomi.ll_new_node('ENDFUNC')
            tsukuyomi.ll_insert_after(node, end_func_node)
          elseif first == kDefineSymbol then
            -- (define symbol datum)
            table.insert(dirty_nodes, node)
            node.op = 'LISP'
            local symbol = rest[1]
            node.define_symbol = compile_symbol(symbol, current_ns)

            args[1] = rest[2][1]
            args[2] = nil
          elseif first == kNsSymbol then
            current_ns = tsukuyomi.get_symbol_name(rest[1])
            node.op = 'NOP'
            node.args = nil
          else
            -- normal function call
            node.op = 'CALL'
            node.args = tsukuyomi.cons_to_lua_array(datum)
            table.insert(new_dirty_nodes, node)
          end
        end
      elseif op == 'CALL' then
        for i = 1, #args do
          if is_lua_primitive(args[i]) then
            args[i] = compile_lua_primitive(args[i], current_ns)
          else
            local var_node = tsukuyomi.ll_new_node('VAR')
            table.insert(dirty_nodes, var_node)

            local var_name = make_unique_var_name()
            var_node.args = {var_name, args[i]}
            args[i] = var_name
            tsukuyomi.ll_insert_before(node, var_node)
          end
        end
      elseif op == 'VAR' then
        table.insert(dirty_nodes, node)
        node.op = 'LISP'
        node.var_name = args[1]
        args[1] = args[2]
        args[2] = nil
      end
    end

    dirty_nodes = new_dirty_nodes
  end

  tsukuyomi._debug_ir(head_node)
end

function tsukuyomi._debug_ir(node)
  local lines = {}

  while node do
    local line = {}

    if node.var_name then
      table.insert(line, 'VAR ')
      table.insert(line, node.var_name)
      table.insert(line, ' <- ')
    elseif node.define_symbol then
      table.insert(line, 'SYMBOL ')
      table.insert(line, tostring(node.define_symbol))
      table.insert(line, ' <- ')
    elseif node.is_return then
      table.insert(line, 'RET ')
    end

    table.insert(line, node.op)
    table.insert(line, ' ')
    local args = node.args
    if args then
      for i = 1, #args do
        local arg = args[i]
        table.insert(line, tostring(arg))
        if i < #args then
          table.insert(line, ', ')
        end
      end
    end

    table.insert(lines, table.concat(line))
    node = node.next
  end

  print(table.concat(lines, '\n'))
end
