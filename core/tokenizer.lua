local kDelimiters = {
  ["("] = true,
  [")"] = true,

  ["'"] = true,

  -- elisp macro characters
  ["`"] = true,
  [","] = true,
  ["@"] = true,
}
local kWhitespaces = {
  -- since this increments line numbers we handle it specially
  --['\n'] = true,
  [' '] = true,
  ['\r'] = true,
  ['\t'] = true,
}

-- splits Lisp source code as a raw input string into an Lua array of tokens suitable for parsing
-- TODO: somehow store line numbers with tokens
function tsukuyomi.tokenize(text)
  local tokens = {}
  local token_line_numbers = {}
  local symbol_buffer = {}
  local line_number = 1
  local in_comment = false

  local i = 1
  while i <= #text do
    local ch = text:sub(i, i)
    local pending_token
    local building_symbol = false

    if in_comment then
      if ch == '\n' then
        in_comment = false
        line_number = line_number + 1
      end
    elseif ch == ';' then
      in_comment = true
    elseif ch == '"' then
      -- string parsing, i.e. "some words" "some \"quoted\" words"
      local string_buffer = {}
      table.insert(string_buffer, ch)
      local j = i + 1
      while j <= #text do
        local ch = text:sub(j, j)
        if ch == '"' then
          table.insert(string_buffer, ch)

          -- done, string_buffer == string
          pending_token = table.concat(string_buffer)
          i = j
          break
        elseif ch == '\\' then
          table.insert(string_buffer, text:sub(j, j + 1))
          j = j + 1
        else
          table.insert(string_buffer, ch)
        end
        j = j + 1
      end
    elseif ch == '\n' then
      line_number = line_number + 1
    elseif kWhitespaces[ch] then
      -- insignificant whitespace
    elseif kDelimiters[ch] then
      pending_token = ch
    else
      -- build symbol
      building_symbol = true
      table.insert(symbol_buffer, ch)
    end

    if not building_symbol and #symbol_buffer > 0 then
      table.insert(tokens, table.concat(symbol_buffer))
      table.insert(token_line_numbers, line_number)
      symbol_buffer = {}
    end

    if pending_token then
      table.insert(tokens, pending_token)
      table.insert(token_line_numbers, line_number)
    end

    i = i + 1
  end

  return tokens, token_line_numbers
end
