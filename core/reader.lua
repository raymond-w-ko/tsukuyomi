local tsukuyomi = tsukuyomi
local PersistentList = tsukuyomi.lang.PersistentList

local kDigits = {
  ['0'] = true,
  ['1'] = true,
  ['2'] = true,
  ['3'] = true,
  ['4'] = true,
  ['5'] = true,
  ['6'] = true,
  ['7'] = true,
  ['8'] = true,
  ['9'] = true,
}

local kReaderMacros = {
  ["'"] = tsukuyomi.get_symbol('quote'),
  -- TODO: should I use Clojure macros or old-school Lisp macros ???
  ['`'] = tsukuyomi.get_symbol('syntax-quote'),
}

local function convert_token_to_atom(token)
  local atom

  local ch1 = token:sub(1, 1)
  local ch2 = token:sub(2, 2)
  if token == 'true' then
    atom = true
  elseif token == 'false' then
    atom = false
  elseif kDigits[ch1] or (ch1 == '-' and kDigits[ch2]) then
    -- TODO: FIXME: this is so wrong, numbers vary like:
    -- 3   3.0   3.1416   314.16e-2   0.31416E1   0xff   0x56
    local num = tonumber(token)
    atom = num
  elseif token:sub(1, 1) == '"' then
    local str = token:sub(2, #token - 1)
    atom = str
  else
    local namespace
    local name
    local index = token:find('/')
    if index and token:len() > 1 then
      namespace = token:sub(1, index - 1)
      name = token:sub(index + 1)
    else
      name = token
    end
    local symbol = tsukuyomi.get_symbol(name, namespace)
    atom = symbol
  end

  return atom
end

local function push_back(stack, datum)
  local coll = stack[#stack]
  if tsukuyomi.is_array(coll) then
    table.insert(coll, datum)
  else
    -- there are two cases, like a linked list,
    -- the first is when the head does not exist,
    -- the second is when you are appending you an existing node
    local prev_cell = coll.tail
    if prev_cell[1] == nil then
      prev_cell[1] = datum
    else
      local cell = tsukuyomi.create_cell(datum, nil)
      prev_cell[2] = cell
      coll.tail = cell
    end
  end
end

-- basically make a new linked list in the stack in the form of
-- {head_node, tail_node}
-- head_node is necessary, when closing off a Lisp list via ')'
local function new_linked_list(stack)
  local cell = PersistentList.EMPTY_LIST
  local list = {
    ['head'] = cell,
    ['tail'] = cell,
  }
  table.insert(stack, list)
  return list
end

local function new_array(stack)
  local array = tsukuyomi.create_array()
  table.insert(stack, array)
  return array
end

local function wrap(data, symbol)
  return tsukuyomi.create_cell(symbol, tsukuyomi.create_cell(data, nil))
end
local function multiwrap(data, symbol_stack)
  while #symbol_stack > 0 do
    local symbol = table.remove(symbol_stack)
    data = wrap(data, symbol)
  end
  return data
end

-- converts Lisp text source code and returns a Lisp list of all data
-- e.g.
-- "42" -> (42)
-- "3 4 5" -> (3 4 5)
-- "(def a 1)" -> ((def a 1)
-- "(def a 1) (def b 2)" -> ((def a 1) (def b 2))
function tsukuyomi.read(text)
  local tokens, token_line_numbers = tsukuyomi.tokenize(text)

  local stack = {}
  new_linked_list(stack)

  local macro_stack = {}
  local pending_macro_stack_of_coll = {}

  for i = 1, #tokens do
    local token = tokens[i]

    if token == '(' or token == '[' then
      local coll
      if token == '(' then coll = new_linked_list(stack) end
      if token == '[' then coll = new_array(stack) end
      --pending_macro_stack_of_coll[coll] = macro_stack
      pending_macro_stack_of_coll[coll] = nil
      macro_stack = {}
    elseif token == ')' or token == ']' then
      local coll = table.remove(stack)
      if not tsukuyomi.is_array(coll) then coll = coll.head end
      if pending_macro_stack_of_coll[coll] then
        coll = multiwrap(coll, pending_macro_stack_of_coll[coll])
        pending_macro_stack_of_coll[coll] = nil
      end
      push_back(stack, coll)
    elseif kReaderMacros[token] then
      table.insert(macro_stack, kReaderMacros[token])
    else
      local atom = convert_token_to_atom(token)
      atom = multiwrap(atom, macro_stack)
      push_back(stack, atom)
    end
  end

  return stack[1].head
end
