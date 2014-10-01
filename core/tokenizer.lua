local kDelimiters = {
  ["("] = true, [")"] = true,
  ["["] = true, ["]"] = true,
  -- TODO: support this in reader
  ["{"] = true, ["}"] = true,

  ["'"] = true,

  -- TODO: should I use Clojure macros or old-school Lisp macros ???
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
function tsukuyomi.tokenize(text)
  local tokens = {}

  local token_line_numbers = {}
  local next_line_number_slot = 1

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
      local string_buffer = {nil, nil, nil, nil, nil, nil, nil}
      local next_str_buf_slot = 1
      string_buffer[next_str_buf_slot] = ch; next_str_buf_slot = next_str_buf_slot + 1
      local j = i + 1
      while j <= #text do
        local ch = text:sub(j, j)
        if ch == '"' then
          string_buffer[next_str_buf_slot] = ch; next_str_buf_slot = next_str_buf_slot + 1

          -- done, string_buffer == string
          pending_token = table.concat(string_buffer)
          i = j
          break
        elseif ch == '\\' then
          string_buffer[next_str_buf_slot] = text:sub(j, j + 1); next_str_buf_slot = next_str_buf_slot + 1
          j = j + 1
        else
          string_buffer[next_str_buf_slot] = ch; next_str_buf_slot = next_str_buf_slot + 1
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
      symbol_buffer = {}

      token_line_numbers[next_line_number_slot] = line_number
      next_line_number_slot = next_line_number_slot + 1
    end

    if pending_token then
      table.insert(tokens, pending_token)

      token_line_numbers[next_line_number_slot] = line_number
      next_line_number_slot = next_line_number_slot + 1
    end

    i = i + 1
  end

  return tokens, token_line_numbers
end
