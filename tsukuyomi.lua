local M = {}

M = {}

local kSymbolTag = {}
-- tag for cons cell
local kCellTag = {}

M.TheGlobalEnvironment = {}

local ParentEnvironmentOf = {}
local kSymbolCache = {}

local function _init()
  local mt = {}
  mt.__mode = 'kv'
  setmetatable(ParentEnvironmentOf, mt)
  setmetatable(kSymbolCache, mt)
end

function kSymbolTag.__tostring(symbol)
  if symbol.namespace then
    return symbol.namespace .. '/' .. symbol
  else
    return symbol.name
  end
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
  data_list[1] = CreateSymbol('do')

  local head_stack = {}
  local tail_stack = {}

  local prev_cell

  local function append(datum, is_quoted)
    if is_quoted then
      datum = CreateCell(kQuoteSymbol, CreateCell(datum, nil))
      is_quoted = false
    end

    if prev_cell == nil then
      data_list[2] = CreateCell(datum, nil)
      data_list = data_list[2]
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
        if index then
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

local function unpack_args(expr, output)
  while expr do
    table.insert(output, M.compile(expr[1]))
    expr = expr[2]
    table.insert(output, ',')
  end

  if output[#output] == ',' then
    table.remove(output)
  end
end

local compiled_forms = {}

function M.compile(datum)
  print('compiling: ' .. M._print(datum))
  --print('raw: ' .. table.show(datum))

  local output = {}

  if type(datum) == 'boolean' or type(datum) == 'string' or type(datum) == 'number' then
    -- atom types
    table.insert(output, tostring(datum))
  elseif type(datum) == 'table' then
    local tag = getmetatable(datum)
    if tag == kSymbolTag then
      -- FIXME: proper symbol name lookup
      return tostring(datum)
    elseif tag == kCellTag then
      local first = datum[1]
      local symbol_name = tostring(first)
      local rest = datum[2]

      if type(first) == 'table' and getmetatable(first) == kSymbolTag then
        -- this is a form, meaning something like (lisp-function arg0 arg1 arg2)

        if compiled_forms[symbol_name] then
          compiled_forms[symbol_name](rest, output)
        else
          -- already compiled
          --table.insert(output, '(function() return ')
          --table.insert(output, tostring(first))
          --table.insert(output, '() end)()')
          table.insert(output, tostring(first))
          table.insert(output, '(')
          unpack_args(rest, output)
          table.insert(output, ')')
        end
      end
    end
  else
    print(M._print(datum))
    assert(false)
  end

  return table.concat(output)
end

-- FIXME: WRONG, first var should be let style binding arg list
compiled_forms['do'] = function(datum, output)
  table.insert(output, '(function()\n')
  while datum do
    if datum[2] == nil then
      table.insert(output, 'return ')
    end
    table.insert(output, M.compile(datum[1]))
    table.insert(output, '\n')
    datum = datum[2]
  end
  table.insert(output, 'end)()\n')
end

compiled_forms['if'] = function(datum, output)
  table.insert(output, '(function()\n')
  table.insert(output, 'if ')
  table.insert(output, M.compile(datum[1]))
  datum = datum[2]
  table.insert(output, ' then\n')
  table.insert(output, 'return ')
  table.insert(output, M.compile(datum[1]))
  table.insert(output, ' \n')
  datum = datum[2]
  if datum then
    table.insert(output, 'else\n')
    table.insert(output, 'return ')
    table.insert(output, M.compile(datum[1]))
    table.insert(output, ' \n')
  end
  table.insert(output, 'end)()\n')
end

compiled_forms['define'] = function(datum, output)
end

_init()

return M
