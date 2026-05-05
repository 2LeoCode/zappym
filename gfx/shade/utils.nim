import std/[tables, macros, sugar, sequtils, strutils, sets]

template `yield`*(iter: iterable): untyped =
  for x in iter:
    yield x

template map*[T](iter: iterable[T], transform: proc(x: sink T): T): iterable[T] =
  iterator (): T =
    for it in iter:
      yield transform(it)

template mapIt*[T](iter: iterable[T], expr): iterable[T] =
  iterator (): T =
    for it {.inject.} in iter:
      yield expr

template filter*[T](iter: iterable[T], cond: proc(x: sink T): bool): iterable[T] =
  iterator (): T =
    for it in iter:
      if not cond(it):
        yield it

template filterIt*[T](iter: iterable[T], expr): iterable[T] =
  iterator (): T =
    for it {.inject.} in iter:
      if not expr:
        yield it

template domain*[UT: Ordinal](T: typedesc[UT]): set[UT] =
  {low(UT) .. high(UT)}

macro memo*(def: typed): untyped =
  def.expectKind {nnkProcDef, nnkTemplateDef, nnkMacroDef, nnkConverterDef}

  result = copyNimTree(def)
  let
    body = def[6]
    returnType = def[3][0]
  var
    argsType = newTree(nnkTupleTy)
    argsAsTuple = newTree(nnkTupleConstr)

  def[3][0].expectKind(nnkSym)
  for argDefs in def[3][1 .. ^1]:
    for argDef in argDefs[0 .. ^3]:
      argsType.add(newTree(nnkIdentDefs))
      argsType[^1].add(ident argDef.strVal, argDef.getType, newEmptyNode())
      argsAsTuple.add(argDef)

  result[6] = quote:
    var memos {.global.} = initTable[`argsType`, `returnType`]()
    let args = `argsAsTuple`

    if args in memos:
      return memos[args]
    defer:
      memos[args] = result
    `body`

macro distinctVariants*(def: untyped): untyped =
  def[1].expectKind(nnkEmpty)
  def[2].expectKind(nnkObjectTy)
  def[2][2].expectKind(nnkRecList)

  let
    pragmaExpr = def[0]
    remainingPragmas = pragmaExpr[1]
    objectTy = def[2]
    recList = objectTy[2]
  echo pragmaExpr[0].treeRepr
  let decoratedTypeName = pragmaExpr[0][1].strVal

  var
    DecoratedType = pragmaExpr[0]
    DecoratedTypeDecl = DecoratedType
    recCase: NimNode = nil

  if DecoratedType.kind == nnkPostfix:
    DecoratedType = DecoratedType[1]
  if remainingPragmas.len != 0:
    DecoratedTypeDecl = newTree(nnkPragmaExpr, DecoratedType, remainingPragmas)

  for rec in recList:
    if rec.kind == nnkRecCase:
      assert recCase == nil
      recCase = rec

  assert recCase != nil

  var
    discriminantField = recCase[0][0]
    discriminantFieldDecl = discriminantField
  if discriminantField.kind == nnkPostfix:
    discriminantField = discriminantField[1]
  let
    discriminantFieldName = discriminantField.strVal
    Discriminant = recCase[0][1]
    discriminants = collect:
      for br in recCase[1 .. ^1]:
        if br.kind == nnkOfBranch:
          for dis in br[0 .. ^2]:
            (dis.strVal, br[^1])
    discriminantNames = discriminants.mapIt(it[0]).toSeq

  var commonPrefix = ""
  block computeCommonPrefix:
    while commonPrefix.len < discriminantNames[0].len:
      let largePrefix = commonPrefix & discriminantNames[0][commonPrefix.len]
      for dis in discriminantNames:
        if not dis.startsWith(largePrefix):
          break computeCommonPrefix
      commonPrefix = largePrefix

  result = newTree(
    nnkTypeSection, newTree(nnkTypeDef, DecoratedTypeDecl, newEmptyNode(), objectTy)
  )

  let caseMacroId = newTree(nnkAccQuoted, ident "case")
  var caseMacro = quote:
    macro `caseMacroId`*(val: `Discriminant`): untyped =
      let selector = val[0]

      selector.expectKind(nnkDotExpr)
      selector[0].expectKind {nnkIdent, nnkSym}
      selector[1].expectKind {nnkIdent, nnkSym}

      let
        orig = selector[0]
        shadow = ident orig.strVal

      result = copyNimTree(val[1])

      assert selector[1].strVal == `discriminantFieldName`

      for i in 1 .. result.len:
        var br = result[i]
        if br.kind == nnkOfBranch and br.len == 2 and br[0].strVal in `discriminantNames`:
          let Variant = ident br[0].strVal.dup(removePrefix(`commonPrefix`))
          var body = br[1]
          body = newStmtList(
            newTree(
              nnkLetSection,
              newTree(nnkIdentDefs, shadow, newEmptyNode(), newCall(Variant, orig)),
            ),
            body,
          )

      echo result.treeRepr

  var injectedCode = newTree(nnkStmtListType)

  for (dis, recList) in discriminants:
    let
      disId = ident dis
      resId = ident "result"
      origConstrCall = newTree(
        nnkObjConstr, DecoratedType, newTree(nnkExprColonExpr, discriminantField, disId)
      )
      typeName = dis.dup(removePrefix(commonPrefix)).capitalizeAscii
      Variant = ident(typeName & decoratedTypeName)
      converterName = ident("to" & decoratedTypeName)
      constrName = ident("init" & Variant.strVal)
    var
      constrParams = newTree(nnkFormalParams, Variant)
      constrBody = newStmtList(newTree(nnkCall, Variant, origConstrCall))
      constrDef = newTree(
        nnkFuncDef,
        postfix(constrName, "*"),
        newEmptyNode(),
        newEmptyNode(),
        constrParams,
        newEmptyNode(),
        newEmptyNode(),
        constrBody,
      )
      getters = newTree(nnkStmtList)
      setters = newTree(nnkStmtList)

    for entry in recList:
      var outEntry = copyNimTree(entry)
      for i in 0 .. outEntry.len - 3:
        if outEntry[i].kind == nnkPostFix:
          outEntry[i] = outEntry[i][1]

      constrParams.add(outEntry)
      for arg in entry[0 .. ^3]:
        let
          getterId = arg
          T = entry[^2]
        var
          setterId: NimNode
          argId: NimNode
        if arg.kind == nnkPostfix:
          argId = arg[1]
          setterId = postfix(newTree(nnkAccQuoted, ident(argId.strVal & "=")), "*")
        else:
          argId = arg
          setterId = newTree(nnkAccQuoted, ident(argId.strVal & "="))
        getters.add:
          quote:
            func `getterId`(self: `Variant`): `T` =
              cast[`DecoratedType`](self).`argId`

        setters.add:
          quote:
            func `setterId`(self: var `Variant`, val: `T`) =
              var tmp = cast[`DecoratedType`](self)
              tmp.`argId` = val
        origConstrCall.add newTree(nnkExprColonExpr, argId, argId)
    result.add newTree(
      nnkTypeDef, Variant, newEmptyNode(), newTree(nnkDistinctTy, DecoratedType)
    )
    injectedCode.add:
      quote:
        func `discriminantFieldDecl`(self: `Variant`): `Discriminant` =
          cast[`DecoratedType`](self).`discriminantField`
    injectedCode.add(getters, setters, constrDef)

    injectedCode.add:
      quote:
        converter `converterName`*(val: `Variant`): `DecoratedType` =
          cast[`DecoratedType`](val)

  injectedCode.add(caseMacro)
  injectedCode.add(ident "void")

  result.add newTree(nnkTypeDef, genSym(nskType), newEmptyNode(), injectedCode)

type NodeKind = enum
  nkA
  nkB
  nkC

type Node* {.distinctVariants.} = object
  case kind*: NodeKind
  of nkA:
    a: int
  of nkB:
    b*: int
  of nkC:
    c: int

let foo: Node = initANode(1)

proc processANode(nodeValue: ANode) =
  echo nodeValue

case foo.kind
of nkA:
  processANode(foo)
of nkB:
  echo "too bad"
else:
  echo "too too bad"
