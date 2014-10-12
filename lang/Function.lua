local tsukuyomi = tsukuyomi
local PersistentList = tsukuyomi.lang.PersistentList
local ArraySeq = tsukuyomi.lang.ArraySeq

local Function = {}
tsukuyomi.lang.Function = Function

function Function.new()
  return setmetatable({}, Function)
end

local kNumArgsBeforeGeneralizedRest = 8

-- eventually will be _rest_fn_creators[rest_arg_index][function_arity]
Function._rest_fn_creators = {}
for i = 1, kNumArgsBeforeGeneralizedRest do
  Function._rest_fn_creators[i] = {}
end
-- eventually will be _general_rest_fn_creators[rest_arg_index]
Function._general_rest_fn_creators = {}

local function make_fn(base_fn, arity, rest_arg_index)
  assert(rest_arg_index <= arity)
  local text = {}
  local slot = 1
  local rest_size = arity - rest_arg_index + 1

  text[slot] = 'local ArraySeq = tsukuyomi.lang.ArraySeq\n'; slot = slot + 1
  text[slot] = 'tsukuyomi.lang.Function._rest_fn_creators'; slot = slot + 1
  text[slot] = '['; slot = slot + 1
  text[slot] = tostring(rest_arg_index); slot = slot + 1
  text[slot] = ']'; slot = slot + 1
  text[slot] = '['; slot = slot + 1
  text[slot] = tostring(arity); slot = slot + 1
  text[slot] = '] = '; slot = slot + 1
  text[slot] = 'function (base_fn)\n'; slot = slot + 1

  text[slot] = '\treturn function('; slot = slot + 1
  for i = 1, arity do
    text[slot] = 'arg'; slot = slot + 1
    text[slot] = tostring(i); slot = slot + 1
    text[slot] = ', '; slot = slot + 1
  end
  -- remove extra ', '
  slot = slot - 1; text[slot] = nil;
  text[slot] = ')\n'; slot = slot + 1

  text[slot] = '\t\treturn base_fn('; slot = slot + 1

  for i = 1, rest_arg_index - 1 do
    text[slot] = 'arg'; slot = slot + 1
    text[slot] = tostring(i); slot = slot + 1
    text[slot] = ', '; slot = slot + 1
  end

  text[slot] = 'ArraySeq.new(nil, {'; slot = slot + 1
  for i = rest_arg_index, arity do
    text[slot] = 'arg'; slot = slot + 1
    text[slot] = tostring(i); slot = slot + 1
    text[slot] = ', '; slot = slot + 1
  end
  -- remove extra ', '
  slot = slot - 1; text[slot] = nil;

  text[slot] = '}, 1, '; slot = slot + 1
  text[slot] = tostring(rest_size); slot = slot + 1
  text[slot] = ')'; slot = slot + 1

  text[slot] = ')\n'; slot = slot + 1

  text[slot] = '\tend\n'; slot = slot + 1
  text[slot] = 'end'; slot = slot + 1

  text = table.concat(text)
  loadstring(text)()
  --print(text)
end
for arity = 1, kNumArgsBeforeGeneralizedRest do
  for rest_arg_index = 1, arity do
    make_fn(nil, arity, rest_arg_index)
  end
end

local function make_general_rest_fn(rest_arg_index)
  local text = {}; local slot = 1
  local chunk = [[
local ArraySeq = tsukuyomi.lang.ArraySeq
tsukuyomi.lang.Function._general_rest_fn_creators[]]
  text[slot] = chunk; slot = slot + 1

  text[slot] = tostring(rest_arg_index); slot = slot + 1

local chunk = [[] = function (base_fn)
  return function(...)
    local args = {...}

    local restargs = {}
    local rest_args_len = 0
    for k, v in pairs(args) do
      local index = k - ]]
    text[slot] = chunk; slot = slot + 1
    text[slot] = tostring(rest_arg_index - 1); slot = slot + 1

    local chunk = [[

      if index > 0 then
        restargs[index] = v
        rest_args_len = rest_args_len + 1
      end
    end

    return base_fn(]]
    text[slot] = chunk; slot = slot + 1

    for i = 1, rest_arg_index - 1 do
      text[slot] = 'args['; slot = slot + 1
      text[slot] = tostring(i); slot = slot + 1
      text[slot] = ']'; slot = slot + 1
      text[slot] = ', '; slot = slot + 1
    end

local chunk = [[
ArraySeq.new(nil, restargs, 1, rest_args_len))
  end
end
]]
  text[slot] = chunk; slot = slot + 1

  text = table.concat(text)
  loadstring(text)()
  --print(text)
end
for rest_arg_index = 1, 20 do
  make_general_rest_fn(rest_arg_index)
end

function Function:make_functions_for_rest(rest_arg_index)
  local base_fn = self[rest_arg_index]

  for i = rest_arg_index, kNumArgsBeforeGeneralizedRest do
    self[i] = Function._rest_fn_creators[rest_arg_index][i](base_fn)
  end

  self.rest_arg_index = rest_arg_index
  self.general_rest_fn = Function._general_rest_fn_creators[rest_arg_index](base_fn)
end

Function.__index = function(t, key)
  if type(key) == 'number' then
    if t.rest_arg_index and key >= kNumArgsBeforeGeneralizedRest then
      return rawget(t, 'general_rest_fn')
    elseif key < t.rest_arg_index then
      return rawget(t, key)
    else
      assert(false)
    end
  else
    local value = rawget(t, key)
    if value then
      return value
    end

    return rawget(Function, key)
  end
end
