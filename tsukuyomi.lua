local M = {}

M.core = {}
local core = M.core

local kSymbolTag = {}
local kCellTag = {}

M.TheGlobalEnvironment = {}

local ParentEnvironmentOf = {}
local kSymbolCache = {}

function core._init()
  local mt = {}
  mt.__mode = 'kv'
  setmetatable(ParentEnvironmentOf, mt)
  setmetatable(kSymbolCache, mt)
end


function core.CreateSymbol(name, namespace)
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
function core.GetSymbolName(symbol)
  return symbol.name
end
function core.GetSymbolNamespace(symbol)
  return symbol.namespace
end

local kQuoteSymbol = core.CreateSymbol('quote')
local kSetSymbol = core.CreateSymbol('set!')
local kDefineSymbol = core.CreateSymbol('define')
local kIfSymbol = core.CreateSymbol('if')
local kOkSymbol = core.CreateSymbol('ok')
local kLambdaSymbol = core.CreateSymbol('lambda')

function core.CreateCell(first, rest)
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

  word_done_check()

  return tokens
end

-- the base reader
-- for bootstrapping, and maybe actual execution?
function core._read(text)
  local tokens = core._tokenize(text)

  -- a Lua array of all the lists, and atoms
  -- like if you fed this function "42 foobar (+ 1 1)" you would get 3 items in the array
  -- necessary because a file can contain many functions
  local data_list = core.CreateCell(nil, nil)
  local data_list_head = data_list
  data_list[1] = core.CreateSymbol('do')
  data_list[2] = core.CreateCell(nil, nil)
  data_list = data_list[2]

  local head_stack = {}
  local tail_stack = {}

  local prev_cell

  local function append(datum, is_quoted)
    if is_quoted then
      datum = core.CreateCell(kQuoteSymbol, core.CreateCell(datum, nil))
      is_quoted = false
    end
    if prev_cell == nil then
      data_list[1] = datum
      local new_cell = core.CreateCell(nil, nil)
      data_list[2] = new_cell
      data_list = new_cell
    else
      if prev_cell[1] == nil then
        prev_cell[1] = datum
      else
        local cell = core.CreateCell(datum, nil)
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
      local new_cell = core.CreateCell(nil, nil)
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
        local symbol = core.CreateSymbol(name, namespace)
        atom = symbol
      end
      append(atom, quote_next)
      quote_next = false
    end
  end

  return data_list_head
end

function core._print(datum)
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
          table.insert(items, core._print(cell[1]))
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
    table.insert(output, core._compile(expr[1]))
    expr = expr[2]
    table.insert(output, ',')
  end

  if output[#output] == ',' then
    table.remove(output)
  end
end

function core._compile(expr)
  print('compiling: ' .. core._print(expr))
  local output = {}

  if type(expr) ~= 'table' or getmetatable(expr) ~= kCellTag then
    return core._print(expr)
  end

  local function_symbol
  if type(expr) == 'table' and getmetatable(expr) == kCellTag then
    local item = expr[1]
    if getmetatable(item) == kSymbolTag then
      function_symbol = expr[1]
    end
  end

  if function_symbol then
    local name = core.GetSymbolName(function_symbol)

    if name == 'do' then
      local bodies = expr[2]
      while bodies do
        table.insert(output, core._compile(bodies[1]))
        bodies = bodies[2]
      end
    elseif name == 'if' then
      local subexprs = {}
      expr = expr[2]
      while expr do
        table.insert(subexprs, expr[1])
        expr = expr[2]
      end

      table.insert(output, 'if (')
      table.insert(output, core._compile(subexprs[1]))
      table.insert(output, ') then\n')
      table.insert(output, core._compile(subexprs[2]))
      table.insert(output, '\nelse\n')
      table.insert(output, core._compile(subexprs[3]))
      table.insert(output, '\nend\n')
    else
      -- regular function call
      local prefix = name:sub(1, 1)
      if prefix == '.' or prefix == ':' then
        expr = expr[2]
        local object_symbol = expr[1]
        local object_name = core.GetSymbolName(object_symbol)
        table.insert(output, object_name)
        table.insert(output, prefix)
        table.insert(output, name:sub(2))
      else
        table.insert(output, name)
      end
      expr = expr[2]

      table.insert(output, '(');
      unpack_args(expr, output)
      table.insert(output, ');\n')
    end
  else
    table.insert(output, core._print(expr))
  end

  return table.concat(output)
end

M.core._init()

return M
