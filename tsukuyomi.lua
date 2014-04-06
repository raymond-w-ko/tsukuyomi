local M = {}

M.core = {}
local core = M.core

function core._init()
  -- create metatable tags
  core.tags = {}
  core.tags.symbol = {}
  core.tags.keyword = {}
  core.tags.cell = {}
end

function core.CreateSymbol(name, namespace)
  local symbol = {
    ['name'] = name,
    ['namespace'] = namespace,
  }
  setmetatable(symbol, core.tags.symbol)
  return symbol
end

function core.CreateCell(first, rest)
  local cell = {
    [1] = first,
    [2] = rest,
  }
  setmetatable(cell, core.tags.cell)
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
function core._tokenize(text)
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

  return tokens
end

-- the base reader
-- for bootstrapping, and maybe actual execution?
function core._read(text)
  local tokens = core._tokenize(text)

  -- a Lua array of all the lists, and atoms
  -- like if you fed this function "42 foobar (+ 1 1)" you would get 3 items in the array
  -- necessary because a file can contain many functions
  local lists = {}

  -- the head of a linked list chain
  local head_stack = {}
  local tail_stack = {}

  local prev_cell

  local function append(datum)
    if prev_cell == nil then
      table.insert(lists, datum)
    else
      if prev_cell[1] == nil then
        -- the first cons cell
        prev_cell[1] = datum
      else
        -- the rest
        local cell = core.CreateCell(datum, nil)
        prev_cell[2] = cell
        prev_cell = cell
      end
    end
  end

  for i = 1, #tokens do
    local token = tokens[i]
    if token == '(' then
      
      local new_cell = core.CreateCell(nil, nil)
      table.insert(head_stack, new_cell)
      table.insert(tail_stack, prev_cell)
      prev_cell = new_cell
    elseif token == ')' then
      local finished_list = table.remove(head_stack)
      prev_cell = table.remove(tail_stack)
      append(finished_list)
    elseif token == '\'' then
    else
      local atom
      if token:find('^%-?%d+') then
        local num = tonumber(token)
        atom = num
      elseif token:sub(1, 1) == '"' then
        local str = token:sub(2, #token - 1)
        atom = str
      else
        local symbol = core.CreateSymbol(token)
        atom = symbol
      end
      append(atom)
    end
  end

  return lists
end

function core._print(datum)
  if type(datum) == 'number' then
    return tostring(datum)
  elseif type(datum) == 'string' then
    return '"' .. datum .. '"'
  elseif type(datum) == 'table' then
    local mt = getmetatable(datum)
    if mt == core.tags.symbol then
      local fqn = datum.name
      if datum.namespace then
        fqn = datum.namespace .. '/' .. fqn
      end
      return fqn
    elseif mt == core.tags.cell then
      local items = {}
      table.insert(items, '(')
      local cell = datum
      while cell do
        if cell[1] then
          table.insert(items, core._print(cell[1]))
        end
        cell = cell[2]
      end
      table.insert(items, ')')
      return table.concat(items, ' ')
    else
      assert(false)
    end
  else
    assert(false)
  end
end

M.core._init()

return M
