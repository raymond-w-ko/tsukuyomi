local M = {}

M.core = {}
local core = M.core

local kKeywordTag = {}
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
  local lists = {}

  local head_stack = {}
  local tail_stack = {}

  local prev_cell

  local function append(datum, is_quoted)
    if is_quoted then
      datum = core.CreateCell(kQuoteSymbol, core.CreateCell(datum, nil))
      is_quoted = false
    end
    if prev_cell == nil then
      table.insert(lists, datum)
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

  return lists
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

local function is_self_evaluating(expr)
  local expr_type = type(expr) 
  if expr_type == 'boolean' then
    return true
  elseif expr_type == 'string' then
    return true
  elseif expr_type == 'number' then
    return true
  else
    return false
  end
end

local function is_variable(expr)
  if type(expr) == 'table' and getmetatable(expr) == kSymbolTag then
    return true
  else
    return false
  end
end

local function lookup_variable_value(expr, env)
  assert(env)

  local name = core.GetSymbolName(expr)
  while env do
    local value = env[name]
    if value then
      return value
    end
    env = ParentEnvironmentOf[env]
  end
end

local function set_symbol(cell, env)
  local symbol = cell[1]
  local expr = cell[2][1]

  local name = core.GetSymbolName(symbol)
  while env do
    if env[name] then
      env[name] = core._eval(expr)
      return kOkSymbol
    end
    env = ParentEnvironmentOf[env]
  end
end

local function define_symbol(cell, env)
  local symbol = cell[1]
  local expr = cell[2][1]

  local name = core.GetSymbolName(symbol)
  env[name] = core._eval(expr)

  -- TODO: maybe account for scheme type function define here?
  -- (define func (var1 var2) body)
  return kOkSymbol
end

local function eval_if(expr, env)
end

function core._eval(expr, env)
  if expr == nil then
    return nil
  elseif is_self_evaluating(expr) then
    return expr
  elseif is_variable(expr) then
    return lookup_variable_value(expr, env)
  end

  local func_symbol
  if type(expr) == 'table' and getmetatable(expr) == kCellTag then
    func_symbol = expr[1]
  end

  if func_symbol == kQuoteSymbol then
    return expr[2][1]
  elseif func_symbol == kSetSymbol then
    return set_symbol(expr[2], env)
  elseif func_symbol == kDefineSymbol then
    return define_symbol(expr[2], env)
  elseif func_symbol == kIfSymbol then
    return eval_if(expr[2], env)
  end

  assert(false)
end

M.core._init()

return M
