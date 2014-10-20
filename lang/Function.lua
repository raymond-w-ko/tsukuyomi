local tsukuyomi = tsukuyomi
local PersistentList = tsukuyomi.lang.PersistentList
local ArraySeq = tsukuyomi.lang.ArraySeq

local Function = {}
tsukuyomi.lang.Function = Function

function Function.new()
  return {}
end

local kNumArgsBeforeGeneralizedRest = 20
-- I really ant to see code that has (fn [arg1 arg2 .. arg32 & rest])
local kMaxArgsBeforeRestArg = 20

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
  local desc = '%d arg fn with rest @ %d'
  desc = desc:format(arity, rest_arg_index)
  local lua_chunk = loadstring(text, desc)
  lua_chunk()
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
  local desc = 'inf arg fn(...) arg fn with rest @ %d'
  desc = desc:format(rest_arg_index)
  local lua_chunk = loadstring(text, desc)
  lua_chunk()
end
for rest_arg_index = 1, kMaxArgsBeforeRestArg do
  make_general_rest_fn(rest_arg_index)
end

local FunctionWithRestArgsMetatable = {}

FunctionWithRestArgsMetatable.__index = function(t, key)
  if type(key) == 'number' then
    local rest_arg_index = t.rest_arg_index
    if rest_arg_index and key >= kNumArgsBeforeGeneralizedRest then
      return rawget(t, 'general_rest_fn')
    end

    -- check for empty rest args
    -- being here in the metamethod means that a concrete one does not exists,
    -- so upgrade it to the general rest fn
    --
    -- not sure if I am wise enough to say whether this should be allowed or not.
    -- is a nil [& rest] really acceptable?
    --
    -- example:
    --
    -- ((fn ([] "foo") ([& args] "bar")) ) == "foo"
    -- ((fn ([& args] "bar")) ) == "bar"
    if key + 1 == t.rest_arg_index then
      return rawget(t, 'general_rest_fn')
    end
  end

  assert(false, 'function with requested arity does not exist')
end

function Function.make_functions_for_rest(fn, rest_arg_index)
  local base_fn = fn[rest_arg_index]

  for i = rest_arg_index, kNumArgsBeforeGeneralizedRest do
    fn[i] = Function._rest_fn_creators[rest_arg_index][i](base_fn)
  end

  fn.rest_arg_index = rest_arg_index
  fn.general_rest_fn = Function._general_rest_fn_creators[rest_arg_index](base_fn)

  setmetatable(fn, FunctionWithRestArgsMetatable)
end

