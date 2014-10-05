local tsukuyomi_lang = tsukuyomi.lang.Namespace.GetNamespaceSpace('tsukuyomi.lang')

local PushbackReader = {}
tsukuyomi_lang.PushbackReader = PushbackReader
PushbackReader.__index = PushbackReader

function PushbackReader.new(text, filename)
  local t = {}
  t.text = text
  t.i = 1
  t.push_back_buffer = {}
  t.filename = filename
  return setmetatable(t, PushbackReader)
end

function PushbackReader:read()
  if #self.push_back_buffer > 0 then
    return table.remove(self.push_back_buffer)
  else
    local i = self.i
    local ch = self.text:sub(i, i)
    -- EOF
    if ch == '' then
      return ch
    end

    self.i = i + 1
    return ch
  end
end

function PushbackReader:unread(ch)
  table.insert(self.push_back_buffer, ch)
end
