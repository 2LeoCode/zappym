template foo(iter: varargs[int]) =
  for i in iter:
    echo i

iterator test(): int =
  for i in 0 .. 10:
    yield i

foo(test())

macro `case`(node: Node): untyped =
  var distinctNodeKinds = {"LeafNode": nkLeaf, "ANode": nkA, "BNode": nkB}.toTable
  assert(distinctNodeKinds.len == NodeKind.enumLen, "Not all variant cases are handled")

  result = newTree(nnkCaseStmt)

  let selector = node[0]

  result.add(newDotExpr(selector, ident "kind"))

  let shadowIdent = ident selector.strVal
  let shadowSectionKind =
    case selector.symKind
    of nskVar: nnkVarSection
    of nskConst: nnkConstSection
    else: nnkLetSection
  let shadowDefTemplate =
    newTree(shadowSectionKind, newTree(nnkIdentDefs, shadowIdent, newEmptyNode()))

  for i in 1 ..< node.len:
    let it = node[i]
    case it.kind
    of nnkOfBranch:
      let distinctType = it[0]
      let distinctTypeName = distinctType.strVal
      assert(distinctTypeName in distinctNodeKinds, "Invalid case branch value")

      let enumValue = distinctNodeKinds[distinctTypeName]
      var caseBr = newTree(nnkOfBranch, newLit(enumValue))
      var shadowDef = copyNimTree(shadowDefTemplate)
      shadowDef[0].add(newCall(distinctType, selector))
      caseBr.add(newStmtList(shadowDef, copyNimTree(it[1])))
      result.add(caseBr)
    of nnkElse, nnkElifBranch, nnkElifExpr, nnkElseExpr:
      result.add(it)
    else:
      error "Ill-formed AST"
