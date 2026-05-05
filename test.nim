import macros

type NodeKind = enum
  nkLeaf
  nkA
  nkB

type Node = object
  case kind: NodeKind
  of nkLeaf:
    val: int
  else:
    children: seq[Node]

proc foo(node: Node) =
  echo node.val

macro dumpTyped(v: typed) =
  echo v.treeRepr

var v: Node = Node(kind: nkA)
case v.kind
of nkA:
  echo v.val
else:
  discard
dumpTyped(v)
foo(v)
case v.kind
of nkLeaf:
  foo(v)
else:
  discard
