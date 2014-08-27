local tsukuyomi = tsukuyomi
local kQuoteSymbol = tsukuyomi.create_symbol('quote')

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

local function convert_token_to_atom(token)
  local atom

  local ch1 = token:sub(1, 1)
  local ch2 = token:sub(2, 2)
  if token == 'true' then
    atom = true
  elseif token == 'false' then
    atom = false
  elseif kDigits[ch1] or (ch1 == '-' and kDigits[ch2]) then
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
    local symbol = tsukuyomi.create_symbol(name, namespace)
    atom = symbol
  end

  return atom
end

local function push_back(stack, datum)
  -- there are two cases, like a linked list,
  -- the first is when the head does not exist,
  -- the second is when you are appending you an existing node
  local list = stack[#stack]
  local prev_cell = list[2]
  if prev_cell[1] == nil then
    prev_cell[1] = datum
  else
    local cell = tsukuyomi.create_cell(datum, nil)
    prev_cell[2] = cell
    list[2] = cell
  end
end

-- basically make a new linked list in the stack in the form of
-- {head_node, tail_node}
-- head_node is necessary, when closing off a Lisp list via ')'
local function new_linked_list(stack)
  local cell = tsukuyomi.create_cell(nil, nil)
  local list = {cell, cell}
  table.insert(stack, list)
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

  local quote_next = false

  for i = 1, #tokens do
    local token = tokens[i]
    if token == '(' then
      new_linked_list(stack)
    elseif token == ')' then
      local list = table.remove(stack)
      local head = list[1]
      push_back(stack, head)
    elseif token == "'" then
      quote_next = true
    else
      local atom = convert_token_to_atom(token)
      push_back(stack, atom)
    end
  end

  return stack[1][1]
end

--[[
function tsukuyomi.read(text)
  local tokens = tsukuyomi.tokenize(text)

  -- a Lua array of all the lists, and atoms
  -- like if you fed this function "42 foobar (+ 1 1)" you would get 3 items in the array
  -- necessary because a file can contain many functions
  local data_list = tsukuyomi.create_cell(nil, nil)
  local data_list_head = data_list

  local head_stack = {}
  local tail_stack = {}

  local prev_cell

  local function append(datum, is_quoted)
    if is_quoted then
      datum = tsukuyomi.create_cell(kQuoteSymbol, tsukuyomi.create_cell(datum, nil))
      is_quoted = false
    end

    if prev_cell == nil then
      if data_list[1] == nil then
        data_list[1] = datum
      else
        data_list[2] = tsukuyomi.create_cell(datum, nil)
        data_list = data_list[2]
      end
    else
      if prev_cell[1] == nil then
        prev_cell[1] = datum
      else
        local cell = tsukuyomi.create_cell(datum, nil)
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
      local new_cell = tsukuyomi.create_cell(nil, nil)
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
      local atom = convert_token_to_atom(token)
      append(atom, quote_next)
      quote_next = false
    end
  end

  return data_list_head
end
]]--
