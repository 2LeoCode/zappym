import std/[macros, strutils, sugar, sequtils, options, lists]

macro yieldFrom*(iter: untyped): untyped =
  quote:
    for x in `iter`:
      yield x

macro escalate*(Excepts: varargs[typed], body): untyped =
  expectKind body, nnkStmtList

  let exceptBranch = newTree nnkExceptBranch
  if Excepts.len == 0:
    exceptBranch.add newIdentNode "CatchableError"
  else:
    for i in 0 ..< Excepts.len:
      Excepts[i].expectKind nnkSym
      if Excepts[i].getType.typeKind != ntyTypedesc:
        error "Excepts should be a list of types"
      exceptBranch.add newIdentNode $Excepts[i]
  exceptBranch.add:
    quote:
      raise Defect.newException getCurrentExceptionMsg()

  newTree(nnkTryStmt, body, exceptBranch)

macro with*(value: typed, body): untyped =
  newTree body.kind:
    collect:
      for n in body:
        if n.kind == nnkCall:
          var c = n[1 ..^ 1].toSeq
          c.add value
          newCall(n[0], c)
        else:
          n

macro dedent*(lit: static[string]): untyped =
  newLit dedent(lit)

func symToIdent(n: NimNode): NimNode =
  if n.kind == nnkSym:
    ident($n)
  elif n.len != 0:
    unpackVarargs(newTree, n.kind, n.children.toSeq.mapIt(symToIdent it))
  else:
    n.copyNimNode

template isSomeAnd*(opt: Option, cb: typed): bool =
  opt.isSome and cb(opt.unsafeGet)

template isSomeAndIt*(opt: Option, expr): bool =
  opt.isSome and (
    block:
      let it {.inject.} = opt.unsafeGet
      expr
  )

func popFront*[T](self: var SinglyLinkedList[T]): T =
  template head: untyped = self.head

  result = head.value
  head = head.next

func isEmpty*(self: SomeLinkedList): bool =
  self.head == nil

macro are*(T: typedesc[typed], exprs: untyped{nkStmtList}): untyped =
  result = newStmtList()
  for expr in exprs:
    result.add:
      quote:
        `expr` is `T`

type Orientation = enum
  oNorth = 1
  oEast
  oSouth
  oWest

# macro wrapperObject*(WrappedType: typedesc[typed]) =
#   newTree(
#     nnkObjectTy,
#     newEmptyNode(),
#     newEmptyNode(),
#     newTree(
#       nnkRecList,
#       newTree(nnkIdentDefs, ident("wrapped"), symToIdent(WrappedType), newEmptyNode()),
#     ),
#   )
