function tsukuyomi.compile(datum)
  -- convert cons cell linked list to lua doubly-linked list
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

  tsukuyomi.compile_to_ir(head_node)
  return tsukuyomi.compile_to_lua(head_node)
end
