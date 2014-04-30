local M = {}

M = {}

-- holds all quoted data temporarily
M._data = {}

function M._consume_data(key)
  local data = M._data[key]
  M._data[key] = nil
  return data
end

-- holds all the core functions of the language
M.core = {}
M.math = {}

--------------------------------------------------------------------------------
-- doubly-linked list
--------------------------------------------------------------------------------
local function ll_new_node(op)
  local node = {}
  node.op = op
  return node
end

local function ll_insert_after(node, new_node)
  new_node.prev = node
  new_node.next = node.next
  if node.next then
    node.next.prev = new_node
  end
  node.next = new_node
end

local function ll_insert_before(node, new_node)
  new_node.prev = node.prev
  new_node.next = node
  if node.prev then
    node.prev.next = new_node
  end
  node.prev = new_node
end

local function ll_remove(node)
  node.prev.next = node.next
  node.next.prev = node.prev
end

--------------------------------------------------------------------------------
-- tsukuyomi
--------------------------------------------------------------------------------

local kSymbolTag = {}
-- tag for cons cell
local kCellTag = {}

local kSymbolCache = {}

local function _init()
  local mt = {}
  mt.__mode = 'kv'
  setmetatable(kSymbolCache, mt)
end

function kSymbolTag.__tostring(symbol)
  if symbol.namespace then
    return symbol.namespace .. '/' .. symbol
  else
    return symbol.name
  end
end

function SymbolToLua(symbol)
  local namespace = symbol.namespace
  local name = symbol.name
  if not namespace then
    namespace = 'core'
  end

  local text = {}
  table.insert(text, "tsukuyomi['")
  table.insert(text, namespace)
  table.insert(text, "']['")
  table.insert(text, name)
  table.insert(text, "']")
  return table.concat(text)
end

local function CreateSymbol(name, namespace)
  local key
  if namespace then
    key = namespace .. '/' .. name
  else
    key = name
  end
  local value = kSymbolCache[key]
  if value then
    return value
  end

  local symbol = {
    ['name'] = name,
    ['namespace'] = namespace,
  }
  setmetatable(symbol, kSymbolTag)

  kSymbolCache[key] = symbol
  return symbol
end
function GetSymbolName(symbol)
  return symbol.name
end
function GetSymbolNamespace(symbol)
  return symbol.namespace
end

local kQuoteSymbol = CreateSymbol('quote')
local kSetSymbol = CreateSymbol('set!')
local kDefineSymbol = CreateSymbol('define')
local kIfSymbol = CreateSymbol('if')
local kOkSymbol = CreateSymbol('ok')
local kLambdaSymbol = CreateSymbol('lambda')

local kRawSymbol = CreateSymbol('_raw_')

function CreateCell(first, rest)
  local cell = {
    [1] = first,
    [2] = rest,
  }
  setmetatable(cell, kCellTag)
  return cell
end

local kDelimiters = {
  ['('] = true,
  [')'] = true,
  ['\''] = true,
}
local kWhitespaces = {
  [' '] = true,
  ['\n'] = true,
  ['\r'] = true,
  ['\t'] = true,
}

-- splits a raw input string into an array of tokens suitable for parsing
local function _tokenize(text)
  local tokens = {}

  -- stores an array of chars to form the next word
  local word_bucket = {}
  local function word_done_check()
    if #word_bucket > 0 then
      local word = table.concat(word_bucket)
      table.insert(tokens, word)
      word_bucket = {}
    end
  end

  local in_string = false

  for i = 1, #text do
    local ch = text:sub(i, i)

    if ch == '"' then
      table.insert(word_bucket, ch)
      in_string = not in_string
      if not in_string then
        word_done_check()
      end
    elseif not in_string and kWhitespaces[ch] then
      word_done_check()
    elseif not in_string and kDelimiters[ch] then
      word_done_check()
      table.insert(tokens, ch)
    else
      table.insert(word_bucket, ch)
    end
  end

  word_done_check()

  return tokens
end

-- the base reader
-- for bootstrapping, and maybe actual execution?
function M._read(text)
  local tokens = _tokenize(text)

  -- a Lua array of all the lists, and atoms
  -- like if you fed this function "42 foobar (+ 1 1)" you would get 3 items in the array
  -- necessary because a file can contain many functions
  local data_list = CreateCell(nil, nil)
  local data_list_head = data_list

  local head_stack = {}
  local tail_stack = {}

  local prev_cell

  local function append(datum, is_quoted)
    if is_quoted then
      datum = CreateCell(kQuoteSymbol, CreateCell(datum, nil))
      is_quoted = false
    end

    if prev_cell == nil then
      if data_list[1] == nil then
        data_list[1] = datum
      else
        data_list[2] = CreateCell(datum, nil)
        data_list = data_list[2]
      end
    else
      if prev_cell[1] == nil then
        prev_cell[1] = datum
      else
        local cell = CreateCell(datum, nil)
        prev_cell[2] = cell
        prev_cell = cell
      end
    end
  end

  local quote_next = false
  local need_quote = {}

  for i = 1, #tokens do
    local token = tokens[i]
    if token == '(' then
      local new_cell = CreateCell(nil, nil)
      table.insert(head_stack, new_cell)
      table.insert(tail_stack, prev_cell)
      prev_cell = new_cell

      if quote_next then
        need_quote[new_cell] = true
        quote_next = false
      end
    elseif token == ')' then
      local finished_list = table.remove(head_stack)
      prev_cell = table.remove(tail_stack)
      append(finished_list, need_quote[finished_list])
      need_quote[finished_list] = nil
    elseif token == '\'' then
      quote_next = true
    else
      local atom
      if token == 'true' then
        atom = true
      elseif token == 'false' then
        atom = false
      elseif token:find('^%-?%d+') then
        local num = tonumber(token)
        atom = num
      elseif token:sub(1, 1) == '"' then
        local str = token:sub(2, #token - 1)
        atom = str
      else
        local index = token:find('/')
        local namespace
        local name
        if index and token:len() > 1 then
          namespace = token:sub(1, index - 1)
          name = token:sub(index + 1)
        else
          name = token
        end
        local symbol = CreateSymbol(name, namespace)
        atom = symbol
      end
      append(atom, quote_next)
      quote_next = false
    end
  end

  return data_list_head
end

function M._print(datum)
  if type(datum) == 'boolean' then
    return tostring(datum)
  elseif type(datum) == 'number' then
    return tostring(datum)
  elseif type(datum) == 'string' then
    return '"' .. datum .. '"'
  elseif type(datum) == 'table' then
    local mt = getmetatable(datum)
    if mt == kSymbolTag then
      local fqn = datum.name
      if datum.namespace then
        fqn = datum.namespace .. '/' .. fqn
      end
      return fqn
    elseif mt == kCellTag then
      local items = {}
      local cell = datum
      while cell do
        if cell[1] ~= nil then
          table.insert(items, M._print(cell[1]))
        end
        cell = cell[2]
      end
      return '(' .. table.concat(items, ' ') .. ')'
    else
      assert(false)
    end
  else
    return tostring(datum)
  end
end

local function list_to_array(datum)
  local arr = {}
  while datum and datum[1] do
    table.insert(arr, datum[1])
    datum = datum[2]
  end
  return arr
end

local compiled_forms = {}

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
  if type(datum) == 'string' or type(datum) == 'number' or type(datum) == 'boolean' then
    return true
  end

  return false
end

local function compile_lua_primitive(datum)
  if type(datum) == 'number' or type(datum) == 'boolean' then
    return tostring(datum)
  end

  if type(datum) == 'string' then
    return '"' .. datum .. '"'
  end

  assert(false)
end

function M.compile_to_ir(head_node)
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
        local tag
        if type(datum) == 'table' then
          tag = getmetatable(datum)
        end

        if tag == kSymbolTag then
          node.op = 'SYMBOL'
          node.args = { datum }
        elseif tag == kCellTag then
          local first = datum[1]
          local rest = datum[2]
          
          if first == kRawSymbol then
            node.op = 'RAW'
            local inline = rest[1]
            assert(type(inline) == 'string')
            node.args = { inline }
          elseif first == kQuoteSymbol then
            node.op = 'DATA'
            node.data_key = make_unique_data_key()
            M._data[node.data_key] = rest[1]
          elseif first == kLambdaSymbol then
            -- (labmda (arg0 arg1) (body))
            node.op = 'FUNC'
            node.args = list_to_array(rest[1])
            -- convert symbol to string
            for i = 1, #node.args do
              node.args[i] = tostring(node.args[i])
            end
            
            local body = rest[2]
            while body and body[1] do
              local lisp_node = ll_new_node('LISP')
              table.insert(new_dirty_nodes, lisp_node)
              lisp_node.args = { body[1] }
              if body[2] == nil then
                lisp_node.is_return = true
              end
              ll_insert_after(node, lisp_node)

              node = lisp_node
              body = body[2]
            end

            local end_func_node = ll_new_node('ENDFUNC')
            ll_insert_after(node, end_func_node)
          elseif first == kDefineSymbol then
            -- (define symbol datum)
            table.insert(dirty_nodes, node)
            node.op = 'LISP'
            local symbol = rest[1]
            node.define_symbol = symbol

            args[1] = rest[2][1]
            args[2] = nil

          else
            -- normal function call
            node.op = 'CALL'
            node.args = list_to_array(datum)
            table.insert(new_dirty_nodes, node)
          end
        end
      elseif op == 'CALL' then
        for i = 1, #args do
          if is_lua_primitive(args[i]) then
            args[i] = compile_lua_primitive(args[i])
          else
            local var_node = ll_new_node('VAR')
            table.insert(dirty_nodes, var_node)

            local var_name = make_unique_var_name()
            var_node.args = {var_name, args[i]}
            args[i] = var_name
            ll_insert_before(node, var_node)
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

  -- DEBUG
  --local node = head_node
  --while node do
    --local line = {}
    --table.insert(line, node.op)
    --table.insert(line, ': ')
    --if node.op == 'VAR' then
      --table.insert(line, node.args[1])
      --table.insert(line, ' - > ')
      --table.insert(line, node.args[2].op)
      --table.insert(line, ' - > ')
      --table.insert(line, table.show(node.args[2].args))
    --else
      --table.insert(line, table.show(node.args))
    --end
    --print(table.concat(line))
    --node = node.next
  --end
end

local function to_lua_call(insn)
  local text = {}
  assert(insn.op == 'CALL')
  local args = insn.args
  assert(type(args[1]) == 'string')
  table.insert(text, args[1])
  table.insert(text, '(')
  for i = 2, #args do
    assert(type(args[i]) == 'string')
    table.insert(text, args[i])
    if i < #args then
      table.insert(text, ', ')
    end
  end
  table.insert(text, ')')
  return table.concat(text)
end

function M.compile_to_lua(ir_list)
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

  local insn = ir_list
  while insn do
    local line = {}

    -- IR instructions can be tagged in the following fashion to signal
    -- variable definition, or returning
    if insn.var_name then
      table.insert(line, 'local ')
      table.insert(line, insn.var_name)
      table.insert(line, ' = ')
    elseif insn.define_symbol then
      table.insert(line, SymbolToLua(insn.define_symbol))
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
      if environment_symbols[GetSymbolName(symbol)] then
        table.insert(line, GetSymbolName(symbol))
      else
        table.insert(line, SymbolToLua(symbol))
      end
    elseif insn.op == 'DATA' then
      table.insert(line, 'tsukuyomi._consume_data(')
      table.insert(line, insn.data_key)
      table.insert(line, ')')
    elseif insn.op == 'CALL' then
      table.insert(line, to_lua_call(insn))
    elseif insn.op == 'FUNC' then
      if not (insn.var_name or insn.define_symbol) then
        table.insert(line, 'local ')
      end
      table.insert(line, 'function ')
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
      table.insert(line, M._print(insn.args[1]))
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

function M.compile(datum)
  -- convert cons cell linked list to lua doubly-linked list
  local head_node
  local node
  while datum and datum[1] do
    local new_node = ll_new_node('LISP')
    new_node.args = { datum[1] }

    if node then
      ll_insert_after(node, new_node)
    else
      head_node = new_node
    end
    node = new_node

    datum = datum[2]
  end

  M.compile_to_ir(head_node)

  local lua_source_code = M.compile_to_lua(head_node)

  return lua_source_code
end

-- FIXME: WRONG, first var should be let style binding arg list
--compiled_forms['do'] = function(datum, output)
  --table.insert(output, '(function()\n')
  --while datum do
    --if datum[2] == nil then
      --table.insert(output, 'return ')
    --end
    --table.insert(output, M.compile(datum[1]))
    --table.insert(output, ';\n')
    --datum = datum[2]
  --end
  --table.insert(output, 'end)()\n')
--end

--compiled_forms['if'] = function(datum, output)
  --table.insert(output, '((function()\n')
  --table.insert(output, 'if ')
  --table.insert(output, M.compile(datum[1]))
  --datum = datum[2]
  --table.insert(output, ' then\n')
  --table.insert(output, 'return ')
  --table.insert(output, M.compile(datum[1]))
  --table.insert(output, ' \n')
  --datum = datum[2]
  --if datum then
    --table.insert(output, 'else\n')
    --table.insert(output, 'return ')
    --table.insert(output, M.compile(datum[1]))
    --table.insert(output, ' \n')
  --end
  --table.insert(output, 'end)())\n')
--end

--compiled_forms['lambda'] = function(datum, output)
  --local args = datum[1]
  --datum = datum[2]

  --local bodies = datum

  --table.insert(output, '(function (')
  --unpack_args(args, output)
  --table.insert(output, ')\n')
  --while bodies do
    --if bodies[2] == nil then
      --table.insert(output, 'return ')
    --end
    --table.insert(output, M.compile(bodies[1]))
    --table.insert(output, '\n')
    --bodies = bodies[2]
  --end
  --table.insert(output, 'end)\n')
--end

--compiled_forms['define'] = function(datum, output)
  --local symbol = datum[1]
  --local symbol_name = tostring(symbol)
  --datum = datum[2]

  --table.insert(output, '(function ()\n')

  ---- strict.lua
  --if global then
    --table.insert(output, 'global(\'')
    --table.insert(output, symbol_name)
    --table.insert(output, '\')\n')
  --end

  --table.insert(output, '_G[\'')
  --table.insert(output, symbol_name)
  --table.insert(output, '\'] = ')
  --table.insert(output, M.compile(datum[1]))

  --table.insert(output, 'end)()\n')
--end

--compiled_forms['+'] = function(datum, output)
  --table.insert(output, '(')
  --table.insert(output, '0')
  --while datum do
    --table.insert(output, ' + (')
    --table.insert(output, M.compile(datum[1]))
    --table.insert(output, ')')
    --datum = datum[2]
  --end
  --table.insert(output, ')')
--end

--compiled_forms['*'] = function(datum, output)
  --table.insert(output, '(')
  --table.insert(output, '1')
  --while datum do
    --table.insert(output, ' * (')
    --table.insert(output, M.compile(datum[1]))
    --table.insert(output, ')')
    --datum = datum[2]
  --end
  --table.insert(output, ')')
--end

--compiled_forms['-'] = function(datum, output)
  --table.insert(output, '(')
  --local args = list_to_array(datum)
  --if #args == 0 then
    --assert(false)
  --elseif #args == 1 then
    --table.insert(output, '0 - (')
    --table.insert(output, M.compile(args[1]))
    --table.insert(output, ')')
  --else
    --table.insert(output, '(')
    --table.insert(output, M.compile(args[1]))
    --table.insert(output, ')')

    --for i = 2, #args do
      --table.insert(output, ' - (')
      --table.insert(output, M.compile(args[i]))
      --table.insert(output, ')')
    --end
  --end
  --table.insert(output, ')')
--end

--compiled_forms['/'] = function(datum, output)
  --table.insert(output, '(')
  --local args = list_to_array(datum)
  --if #args == 0 then
    --assert(false)
  --elseif #args == 1 then
    --table.insert(output, '1 / (')
    --table.insert(output, M.compile(args[1]))
    --table.insert(output, ')')
  --else
    --table.insert(output, '(')
    --table.insert(output, M.compile(args[1]))
    --table.insert(output, ')')

    --for i = 2, #args do
      --table.insert(output, ' / (')
      --table.insert(output, M.compile(args[i]))
      --table.insert(output, ')')
    --end
  --end
  --table.insert(output, ')')
--end

_init()

return M
