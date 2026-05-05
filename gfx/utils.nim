import std/[macros, strutils, sugar, sequtils]

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
    unpackVarargs(
      newTree,
      n.kind,
      n.children.toSeq.map proc(it: NimNode): NimNode =
        symToIdent it
      ,
    )
  else:
    n.copyNimNode

template defineWrapperObject*(Name; WrappedType: typedesc[typed]) =
  type Name = object
    wrapped: WrappedType

template `?.`*(obj: typed, field: typed): untyped =
  if obj.isNil: nil else: obj.field

template `!.`*(obj: typed, field: typed): untyped {.warning[StrictNotNil]: off.} =
  obj.field

template `?:`*(obj: typed, index: typed): untyped =
  if obj.isNil:
    nil
  else:
    obj[index]

template `!:`*(obj: typed, index: typed): untyped {.warning[StrictNotNil]: off.} =
  obj[index]

macro ensureValidIdent(ident: typed): untyped =
  ident $ident

func newExceptionByNameExpr(msg: NimNode, expr: sink NimNode): NimNode =
  expr.expectKind nnkStmtList

  result = expr.copyNimTree
  var lastExpr = result[^1]

  lastExpr =
    case lastExpr.kind
    of nnkStrLit:
      let exceptionName = ident lastExpr.strVal
      newCall(
        newDotExpr(ident "system", ident "newException"),
        ensureValidIdent(exceptionName),
        msg,
      )
    of nnkIfStmt:
      var children = collect:
        for branch in lastExpr[0 ..^ 2]:
          newTree(nnkElifExpr, branch !: 0, newExceptionByNameExpr(msg, branch !: 1))

      children.add:
        let lastBranch = lastExpr[^1]

        expectKind(lastBranch, nnkElse)

        newTree(nnkElseExpr, newExceptionByNameExpr(msg, lastBranch[0]))

      unpackVarargs(newTree, nnkIfExpr, children)
    of nnkCaseStmt:
      debugecho lastExpr.treeRepr
      var children = collect:
        for branch in lastExpr[1 ..^ 2]:
          newTree(nnkOfBranch, branch !: 0, newExceptionByNameExpr(msg, branch !: 1))

      children.insert(lastExpr[0], 0)
      children.add:
        let lastBranch = lastExpr[^1]

        case lastBranch.kind
        of nnkOfBranch:
          newTree(
            nnkOfBranch, lastBranch[0], newExceptionByNameExpr(msg, lastBranch[1])
          )
        of nnkElse:
          newTree(nnkElse, newExceptionByNameExpr(msg, lastBranch[0]))
        else:
          error "Invalid node kind"

      unpackVarargs(newTree, nnkCaseStmt, children)
    of nnkStmtList:
      newExceptionByNameExpr(msg, lastExpr)
    else:
      debugecho lastExpr.treerepr
      error "Invalid node kind"
  result[^1] = lastExpr

macro newExceptionByName*(msg: string, expr: untyped): untyped =
  case expr.kind
  of nnkStrLit:
    let exceptionType = ident expr.strVal
    quote:
      system.newException(`exceptionType`, `msg`)
  of nnkStmtList:
    newExceptionByNameExpr(msg, expr)
  else:
    error "Invalid node kind"

macro narrowAssert*(instance: typed, typ: typed, expr): untyped =
  let narrowed = ident $instance
  quote:
    assert(`instance` of `typ`, "Invalid type")
    block:
      let `narrowed` {.inject.} = cast[ref `typ`](`instance`)
      `expr`

macro narrowIf*(instance: typed, typ: typed, expr): untyped =
  let narrowed = ident $instance
  quote:
    if `instance` of `typ`:
      let `narrowed` {.inject.} = cast[ref `typ`](`instance`)
      `expr`

func unreachable*() {.noReturn.} =
  discard
