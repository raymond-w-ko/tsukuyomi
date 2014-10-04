local tsukuyomi = tsukuyomi
local PushbackReader = tsukuyomi.lang.PushbackReader
local PersistentList = tsukuyomi.lang.PersistentList
local PersistentVector = tsukuyomi.lang.PersistentVector
local PersistentHashMap = tsukuyomi.lang.PersistentHashMap
local Symbol = tsukuyomi.lang.Symbol
local tsukuyomi_core = tsukuyomi.lang.Namespace.GetNamespaceSpace('tsukuyomi.core')
local tsukuyomi_lang = tsukuyomi.lang.Namespace.GetNamespaceSpace('tsukuyomi.lang')

--------------------------------------------------------------------------------

local kWhitespaces = {
  [' '] = true,
  ['\t'] = true,
  ['\r'] = true,
  ['\n'] = true
}
local function IsWhitespace(ch)
  return kWhitespaces[ch]
end

--------------------------------------------------------------------------------

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
local function IsDigit(ch)
  return kDigits[ch]
end

--------------------------------------------------------------------------------

local EOF = ''

local LispReader = {}
LispReader.macros = {}
local macros = LispReader.macros

local function IsMacro(ch)
  return macros[ch] ~= nil
end

local function IsTerminatingMacro(ch)
  return ch ~= '\'' and ch ~= '#' and IsMacro(ch)
end

--------------------------------------------------------------------------------

local function read1(r)
  return r:read()
end

local function unread(r, ch)
  if ch ~= EOF then
    r:unread(ch)
  end
end

--------------------------------------------------------------------------------

local function read_number(r, initch)
  local buf = {initch, nil, nil, nil}; local nextslot = 2

  while true do
    local ch = read1(r)
    if ch == EOF or IsWhitespace(ch) or IsMacro(ch) then
      unread(r, ch)
      break
    end
    buf[nextslot] = ch; nextslot = nextslot + 1
  end

  local s = table.concat(buf)
  local num = tonumber(s)
  if num == nil then
    assert(false, 'invalid number: ' .. s)
  end
  return num
end

local function read_token(r, initch)
  local buf = {initch, nil, nil, nil}; local nextslot = 2

  while true do
    local ch = read1(r)
    if ch == EOF or IsWhitespace(ch) or IsTerminatingMacro(ch) then
      unread(r, ch)
      return table.concat(buf)
    end
    buf[nextslot] = ch; nextslot = nextslot + 1
  end
end

local function interpret_token(s)
  if s == 'nil' then return nil
  elseif s == 'true' then return true
  elseif s == 'false' then return false
  else
    if s:sub(1, 1) == ':' then
      -- TODO: determine how to support keywords, our PersistentHashMap can
      -- only support strings as keys anyways, and we has no universal
      -- Object.getHashCode()
      return s:sub(1)
    else
      local slash = s:find('/')
      if slash then
        return Symbol.intern(s:sub(1, slash - 1), s:sub(slash + 1))
      else
        return Symbol.intern(s)
      end
    end
  end
end

local function read(r, eofIsError, eofValue, isRecursive)
  -- TODO: do not rely on this
  if type(r) == 'string' then r = PushbackReader.new(r) end

  while true do
    local ch = read1(r)

    while IsWhitespace(ch) do ch = read1(r) end

    if ch == EOF then
      if eofIsError then
        assert(false, 'EOF while reading')
      end
      return eofValue
    end

    if IsDigit(ch) then
      return read_number(r, ch)
    end

    local fn = macros[ch]
    if fn ~= nil then
      local ret = fn(r, ch)
      if ret ~= r then
        return ret
      end
    else
      if ch == '+' or ch == '-' then
        local ch2 = read1(r)
        if IsDigit(ch2) then
          unread(r, ch2)
          return read_number(r, ch)
        end
        unread(r, ch2)
      end

      local token = read_token(r, ch)
      return interpret_token(token)
    end
  end
end
LispReader.read = read

local function read_string(r, initch)
  local buf = {nil, nil, nil, nil}; local nextslot = 2

  local ch = read1(r)
  while ch ~= '"' do
    if ch == EOF then assert(false, 'EOF while reading string') end

    -- TODO: support escaped chars

    buf[nextslot] = ch; nextslot = nextslot + 1

    ch = read1(r)
  end

  return table.concat(buf)
end

local function read_unmatched_delimiter(r, ch)
  assert(false, 'unmatched delimiter: ' .. ch)
end
macros[')'] = read_unmatched_delimiter
macros[']'] = read_unmatched_delimiter
macros['}'] = read_unmatched_delimiter

local function read_delimited_list(delim, r, isRecursive)
  local arr = {nil, nil, nil, nil}; local nextslot = 1

  while true do
    local ch = read1(r)

    while IsWhitespace(ch) do ch = read1(r) end

    if ch == EOF then
      assert(false, 'EOF encountered in read_delimited_list() with delimiter: ' .. delim)
    elseif ch == delim then
      break
    else
      local fn = macros[ch]
      if fn ~= nil then
        local datum = fn(r, ch)
        if datum ~= r then
          arr[nextslot] = datum; nextslot = nextslot + 1
        end
      else
        unread(r, ch)
        local datum = read(r, true, nil, isRecursive)
        if datum ~= r then
          arr[nextslot] = datum; nextslot = nextslot + 1
        end
      end
    end
  end

  return arr
end

local function read_list(r, ch)
  local array = read_delimited_list(')', r, true)
  if #array == 0 then
    return PersistentList.EMPTY
  else
    return PersistentList.FromLuaArray(array)
  end
end
macros['('] = read_list

local function read_vector(r, ch)
  local array = read_delimited_list(']', r, true)
  return PersistentVector.FromLuaArray(array)
end
macros['['] = read_vector

local function read_map(r, ch)
  local array = read_delimited_list('}', r, true)
  if #array % 2 == 1 then
    assert(false, 'Map literal must contain an even number of forms')
  end
  return PersistentHashMap.FromLuaArray(array)
end
macros['{'] = read_map

-- TODO: fix location to be in tsukuyomi.lang
tsukuyomi.read = read
