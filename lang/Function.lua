local PersistentList = require('tsukuyomi.lang.PersistentList')
local ArraySeq = require('tsukuyomi.lang.ArraySeq')

local Function = {}
-- let's hope this doesn't cause any problems
package.loaded['tsukuyomi.lang.Function'] = Function

function Function.new()
  return {}
end

local kNumArgsBeforeGeneralizedRest = 20
Function.kNumArgsBeforeGeneralizedRest = kNumArgsBeforeGeneralizedRest

-- I really ant to see code that has (fn [arg1 arg2 .. arg32 & rest])
local kMaxArgsBeforeRestArg = 21
Function.kMaxArgsBeforeRestArg = kMaxArgsBeforeRestArg

-- eventually will be _rest_fn_creators[rest_arg_index][function_arity]
Function._rest_fn_creators = {}
for i = 0, kMaxArgsBeforeRestArg do
  Function._rest_fn_creators[i] = {}
end
-- eventually will be _general_rest_fn_creators[rest_arg_index]
Function._general_rest_fn_creators = {}

local function make_fn(arity, rest_arg_index)
  --assert(rest_arg_index <= arity)
  local text = {}
  local slot = 1
  local rest_size = arity - rest_arg_index + 1

  text[slot] = 'local ArraySeq = require("tsukuyomi.lang.ArraySeq")\n'; slot = slot + 1
  text[slot] = 'local Function = require("tsukuyomi.lang.Function")\n'; slot = slot + 1
  text[slot] = 'Function._rest_fn_creators'; slot = slot + 1
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
  if text[slot - 1] == ', ' then
    -- remove extra ', '
    slot = slot - 1; text[slot] = nil;
  end
  text[slot] = ')\n'; slot = slot + 1

  text[slot] = '\t\treturn base_fn('; slot = slot + 1

  for i = 1, rest_arg_index - 1 do
    text[slot] = 'arg'; slot = slot + 1
    text[slot] = tostring(i); slot = slot + 1
    text[slot] = ', '; slot = slot + 1
  end

  if rest_arg_index <= arity then
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
  else
    text[slot] = 'nil'; slot = slot + 1
  end


  text[slot] = ')\n'; slot = slot + 1

  text[slot] = '\tend\n'; slot = slot + 1
  text[slot] = 'end'; slot = slot + 1

  text = table.concat(text)
  --print(text)
  local desc = '%d arg fn with rest @ %d'
  desc = desc:format(arity, rest_arg_index)
  --print(desc)
  local lua_chunk = loadstring(text, desc)
  lua_chunk()
end
for rest_arg_index = 1, kMaxArgsBeforeRestArg do
  for arity = rest_arg_index - 1, kNumArgsBeforeGeneralizedRest do
    make_fn(arity, rest_arg_index)
  end
end

local function make_general_rest_fn(rest_arg_index)
  local text = {}; local slot = 1
  local chunk = [[
local ArraySeq = require("tsukuyomi.lang.ArraySeq")
local ConcatSeq = require("tsukuyomi.lang.ConcatSeq")
local Function = require("tsukuyomi.lang.Function")
Function._general_rest_fn_creators[]]
  text[slot] = chunk; slot = slot + 1

  text[slot] = tostring(rest_arg_index); slot = slot + 1

  local chunk = [[] = function (base_fn)
  return function(]]
  text[slot] = chunk; slot = slot + 1
  for i = 1, kMaxArgsBeforeRestArg do
    text[slot] = 'arg'; slot = slot + 1
    text[slot] = tostring(i); slot = slot + 1
    text[slot] = ', '; slot = slot + 1
  end
  slot = slot - 1; text[slot] = nil
  text[slot] = ')\n'; slot = slot + 1

  local chunk = [[
    local part1 = ]]
  text[slot] = chunk; slot = slot + 1

  if 20 - rest_arg_index + 1 > 0 then
    local chunk = [[ArraySeq.new(nil, {]]
    text[slot] = chunk; slot = slot + 1

    for i = rest_arg_index, kNumArgsBeforeGeneralizedRest do
      text[slot] = 'arg'; slot = slot + 1
      text[slot] = tostring(i); slot = slot + 1
      text[slot] = ', '; slot = slot + 1
    end
    if rest_arg_index <= kNumArgsBeforeGeneralizedRest then
      slot = slot - 1; text[slot] = nil
    end

    local chunk = '}, 1, '
    text[slot] = chunk; slot = slot + 1

    local chunk = tostring(20 - rest_arg_index + 1)
    text[slot] = chunk; slot = slot + 1
    text[slot] = ')\n'; slot = slot + 1
  else
    slot = slot - 1; text[slot] = nil
  end

  if 20 - rest_arg_index + 1 > 0 then
    local chunk = [[
      local concat_seq = ConcatSeq.new(nil, part1, arg21)
  ]]
    text[slot] = chunk; slot = slot + 1
  else
    local chunk = [[
      local concat_seq = arg21
  ]]
    text[slot] = chunk; slot = slot + 1
  end

  local chunk = [[
    return base_fn(]]
  text[slot] = chunk; slot = slot + 1
  for i = 1, rest_arg_index - 1 do
    text[slot] = 'arg'; slot = slot + 1
    text[slot] = tostring(i); slot = slot + 1
    text[slot] = ', '; slot = slot + 1
  end

  local chunk = [[concat_seq)
  end
end]]
  text[slot] = chunk; slot = slot + 1

  text = table.concat(text)
  --print(text)
  local desc = 'max arg fn() arg fn with rest @ %d'
  desc = desc:format(rest_arg_index)
  --print(desc)
  local lua_chunk = loadstring(text, desc)
  lua_chunk()
end
for rest_arg_index = 1, kMaxArgsBeforeRestArg do
  make_general_rest_fn(rest_arg_index)
end

local FunctionWithRestArgsMetatable = {}

--[[
FunctionWithRestArgsMetatable.__index = function(t, key)
  assert(false)
  if type(key) == 'number' then
    local rest_arg_index = t.rest_arg_index
    --if rest_arg_index and key >= kNumArgsBeforeGeneralizedRest then
      --return rawget(t, 'general_rest_fn')
    --end

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
      return rawget(t, rest_arg_index)
    end
  end

  assert(false, 'function with arity ' .. tostring(key) .. ' does not exist')
end
]]--

function Function.make_functions_for_rest(fn, rest_arg_index)
  local base_fn = fn[rest_arg_index]

  local index = rest_arg_index - 1
  if fn[index] == nil then
    fn[index] = Function._rest_fn_creators[rest_arg_index][index](base_fn)
  end

  for i = rest_arg_index, kNumArgsBeforeGeneralizedRest do
    fn[i] = Function._rest_fn_creators[rest_arg_index][i](base_fn)
  end
  fn[kMaxArgsBeforeRestArg] = Function._general_rest_fn_creators[rest_arg_index](base_fn)

  --fn.rest_arg_index = rest_arg_index
  --setmetatable(fn, FunctionWithRestArgsMetatable)
end

return Function
