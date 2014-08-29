local function prepare_data(datum)
  -- convert cons cell linked list (list of Lisp data) to Lua doubly-linked list
  local head_node
  local node
  while datum and datum[1] do
    local new_node = tsukuyomi.ll_new_node('LISP')
    new_node.args = { datum[1] }

    if node then
      tsukuyomi.ll_insert_after(node, new_node)
    else
      head_node = new_node
    end
    node = new_node

    datum = datum[2]
  end

  return head_node
end

function tsukuyomi.compile(datum)
  local list = prepare_data(datum)
  tsukuyomi.compile_to_ir(list)
  if true then return end
  return tsukuyomi.compile_to_lua(list)
end
