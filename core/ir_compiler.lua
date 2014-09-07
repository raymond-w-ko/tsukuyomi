-- special forms
local kNsSymbol = tsukuyomi.create_symbol('ns')
local kQuoteSymbol = tsukuyomi.create_symbol('quote')
local kSetSymbol = tsukuyomi.create_symbol('set!')
local kDefSymbol = tsukuyomi.create_symbol('def')
local kIfSymbol = tsukuyomi.create_symbol('if')
local kFnSymbol = tsukuyomi.create_symbol('fn')
local kRawSymbol = tsukuyomi.create_symbol('_raw_')

local var_counter = -1
local function make_unique_var_name()
  var_counter = var_counter + 1
  return '__var' .. tostring(var_counter)
end

local data_key_counter = -1
local function make_unique_data_key()
  data_key_counter = data_key_counter + 1
  return data_key_counter
end

local function is_lua_primitive(datum)
  -- actual primitive types
  if type(datum) == 'string' or type(datum) == 'number' or type(datum) == 'boolean' then
    return true
  end

  -- this isn't a true Lua primitive, but it's intent is that it is just a variable name
  -- referring to something
  if tsukuyomi.is_symbol(datum) then
    return true
  end

  return false
end

local function compile_lua_primitive(datum)
  if type(datum) == 'number' or type(datum) == 'boolean' then
    return tostring(datum)
  end

  if type(datum) == 'string' then
    return '"'..datum..'"'
  end

  if tsukuyomi.is_symbol(datum) then
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
  end

  -- if using is_lua_primitive, this should never happend
  assert(false)
end

-- dispatch tables to compile down input

-- used to implement dispatch based on the first / car of a cons cell
special_forms = {}

special_forms[kNsSymbol] = function(node, datum, new_dirty_nodes)
  node.op = 'NS'
  node.args = { datum[1] }

  -- TODO: support other namespaces via require
  -- TODO: check for symbol collision in namespaces
  if node.is_return then
    node.is_return = false

    local new_node = tsukuyomi.ll_new_node('LISP')
    new_node.args = { true }
    tsukuyomi.ll_insert_after(node, new_node)
    new_node.is_return = true
    table.insert(new_dirty_nodes, new_node)
  end
end

special_forms[kDefSymbol] = function(node, datum, new_dirty_nodes)
  -- (define symbol datum)
  table.insert(new_dirty_nodes, node)
  node.op = 'LISP'
  local symbol = datum[1]
  node.define_symbol = symbol

  node.args[1] = datum[2][1]
  node.args[2] = nil

  -- it's not possible to get a return value on an assignment, to just add a
  -- dummy instruction after it
  -- TODO: figure out what the sensible dummy return value is
  if node.is_return then
    node.is_return = false

    local new_node = tsukuyomi.ll_new_node('LISP')
    new_node.args = { true }
    tsukuyomi.ll_insert_after(node, new_node)
    new_node.is_return = true
    table.insert(new_dirty_nodes, new_node)
  end
end

special_forms[kRawSymbol] = function(node, datum, new_dirty_nodes)
  node.op = 'RAW'
  local inline = datum[1]
  assert(type(inline) == 'string')
  node.args = { inline }
end

special_forms[kQuoteSymbol] = function(node, datum, new_dirty_nodes)
  node.op = 'DATA'
  node.data_key = make_unique_data_key()
  tsukuyomi._data[node.data_key] = datum[1]
end

special_forms[kIfSymbol] = function(node, datum, new_dirty_nodes)
  -- TODO: implement this
  assert(false)
end

special_forms[kFnSymbol] = function(node, datum, new_dirty_nodes)
  -- (fn [arg0 arg1] (body))
  node.op = 'FUNC'
  node.args = datum[1]

  -- convert function argument symbols to string
  -- TODO: will I or someone ever put namespace symbols here by accident?
  -- is it even worth it to check?
  for i = 1, #node.args do
    node.args[i] = tostring(node.args[i])
  end
            
  local body = datum[2]
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
end

op_dispatch = {}

op_dispatch['LISP'] = function(node, new_dirty_nodes)
  local datum = node.args[1]
  if tsukuyomi.is_cons_cell(datum) then
    local first = datum[1]
    local rest = datum[2]
    if special_forms[first] then
      special_forms[first](node, rest, new_dirty_nodes)
    else
      -- normal function call
      node.op = 'CALL'
      node.args = tsukuyomi.cons_to_lua_array(datum)
      table.insert(new_dirty_nodes, node)
    end
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
      local var_node = tsukuyomi.ll_new_node('VAR')
      table.insert(new_dirty_nodes, var_node)

      local var_name = make_unique_var_name()
      var_node.args = {var_name, args[i]}
      args[i] = var_name
      tsukuyomi.ll_insert_before(node, var_node)
    end
  end
end

op_dispatch['VAR'] = function(node, new_dirty_nodes)
  node.op = 'LISP'
  node.var_name = node.args[1]
  node.args[1] = node.args[2]
  node.args[2] = nil
  table.insert(new_dirty_nodes, node)
end

-- given a doubly linked list, iteratively process each node until each node
-- has been "cleaned". processing a node usually expands / creates more nodes
-- around it, as lisp is being broken into elementary operations.
--
-- by default nodes are dirty, until it has been processed through once.
--
-- nodes are in the form of
-- node = {
--    ['op'] = 'OPCODE',
--    ['args'] = { arg0, arg1, arg2 },
-- }
-- optional fields are:
-- var_name
-- define_symbol
-- is_return
function tsukuyomi.compile_to_ir(head_node)
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

    if node.var_name then
      table.insert(line, 'VAR ')
      table.insert(line, node.var_name)
      table.insert(line, ' := ')
    elseif node.define_symbol then
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

    table.insert(lines, table.concat(line))
    node = node.next
  end

  return table.concat(lines, '\n')
end
