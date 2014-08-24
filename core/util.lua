function tsukuyomi.cons_to_lua_array(datum)
  local arr = {}
  while datum and datum[1] do
    table.insert(arr, datum[1])
    datum = datum[2]
  end
  return arr
end
