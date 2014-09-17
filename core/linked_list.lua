--------------------------------------------------------------------------------
-- standard doubly-linked list
--
-- so far, just used for IR list, so that is why ll_new_node accepts op
--------------------------------------------------------------------------------
function tsukuyomi.ll_new_node(op, env)
  assert(op)
  assert(env)

  local node = {}
  node.op = op
  node.environment = env
  return node
end

function tsukuyomi.ll_insert_after(node, new_node)
  new_node.prev = node
  new_node.next = node.next
  if node.next then
    node.next.prev = new_node
  end
  node.next = new_node
end

function tsukuyomi.ll_insert_before(node, new_node)
  new_node.prev = node.prev
  new_node.next = node
  if node.prev then
    node.prev.next = new_node
  end
  node.prev = new_node
end

function tsukuyomi.ll_remove(node)
  node.prev.next = node.next
  node.next.prev = node.prev
end
