import std/[tables, macros, sugar, sequtils, strutils, sets, options]

template `yield`*(iter: iterable): untyped =
  for x in iter:
    yield x

template map*[T](iter: iterable[T], transform: typed): iterable[untyped] =
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
      argsType[^1].add(ident argDef.strVal, argDef.getTypeInst, newEmptyNode())
      argsAsTuple.add(argDef)

  result[6] = quote:
    var memos {.global.} = initTable[`argsType`, `returnType`]()
    let args = `argsAsTuple`

    if args in memos:
      return memos[args]
    defer:
      memos[args] = result
    `body`

macro generateStrictUnionOps*(T: typedesc): untyped =
  T.getImpl[1].expectKind(nnkEmpty)
  T.getImpl[2].expectKind(nnkObjectTy)
  T.getImpl[2][0].expectKind(nnkEmpty)
  T.getImpl[2][1].expectKind(nnkEmpty)
  T.getImpl[2][2].expectKind(nnkRecList)

  let
    objTy = T.getImpl[2]
    recList = objTy[2]
    caseRec = block:
      var caseRec: NimNode
      for rec in recList:
        if rec.kind == nnkRecCase:
          assert caseRec == nil
          caseRec = rec
      assert caseRec != nil
      caseRec
    kindField =
      if caseRec[0][0].kind == nnkPostfix:
        caseRec[0][0][1]
      else:
        caseRec[0][0]
    kindFieldName = kindField.strVal
    K = caseRec[0][1]
    kName = K.strVal
    commonPrefix = block:
      var commonPrefix: string
      block getCommonPrefix:
        while commonPrefix.len < K.getImpl[2][1].strVal.len:
          let acc = commonPrefix & K.getImpl[2][1].strVal[commonPrefix.len]
          for rec in K.getImpl[2][2 .. ^1]:
            if not rec.strVal.startsWith(acc):
              break getCommonPrefix
          commonPrefix = acc
      commonPrefix
    commonFields = collect:
      for rec in recList:
        if rec.kind == nnkIdentDefs:
          rec
    SomeK = ident "Some" & K.strVal

    toSomeK = ident "to" & SomeK.strVal
    toSomeKImpl = quote:
      converter `toSomeK`*(val: `K`): `SomeK` =
        `SomeK`(value: val)

    toK = ident "to" & K.strVal
    toKImpl = quote:
      converter `toK`*(val: `SomeK`): `K` =
        val.value

    kindProxyImpl = quote:
      func kind*(self: `T`): `SomeK` =
        self.kind

    variantCase = newTree(nnkAccQuoted, ident "case")
    variantCaseImpl = quote:
      macro `variantCase`*(k: `SomeK`): untyped =
        let
          selector = k[0]
          parentObj =
            case selector.kind
            of nnkDotExpr:
              selector[0]
            of nnkCall:
              selector[1]
            else:
              error("kind must be an expression in the form a.b or b(a)")
          K = bindSym `kName`
          kindValues = collect:
            for val in K.getImpl[2][1 .. ^1]:
              val.strVal
          shadowSection =
            case parentObj.symKind
            of nskVar: nnkVarSection
            of nskConst: nnkConstSection
            else: nnkLetSection
          shadow = ident parentObj.strVal

        result = newTree(
          nnkCaseStmt, newDotExpr(newCall(ident "kind", parentObj), ident "value")
        )

        for br in k[1 .. ^1]:
          if br.kind == nnkOfBranch:
            if br.len == 2:
              let
                val = br[0]
                Variant = ident val.strVal.dup(removePrefix(`commonPrefix`)) & "Node"
                shadowImpl = newTree(
                  shadowSection,
                  newIdentDefs(shadow, Variant, newCall(Variant, parentObj)),
                )

              result.add newTree(nnkOfBranch, val, newStmtList(shadowImpl, br[1]))
              continue
            else:
              for val in br[0 .. ^2]:
                assert val.strVal in kindValues, "expected NodeKind values in of branch"
          result.add copyNimTree(br)

  K.getImpl[1].expectKind(nnkEmpty)
  K.getImpl[2].expectKind(nnkEnumTy)

  result = newStmtList()
  for enumVal in K.getImpl[2][1 .. ^1]:
    let
      variantName = enumVal.strVal.dup(removePrefix(commonPrefix)) & T.strVal
      Variant = ident variantName
      individualFields = block:
        var found: NimNode
        for br in caseRec[1 .. ^1]:
          case br.kind
          of nnkOfBranch:
            for val in br[0 .. ^2]:
              if val.strVal == enumVal.strVal:
                assert found == nil
                found = br[^1]
          of nnkElse:
            if found == nil:
              found = br[0]
          else:
            discard
        if found == nil:
          @[]
        else:
          found.children.toSeq

      variantBorrow = newTree(nnkAccQuoted, ident ".")
      initVariant = ident "init" & Variant.strVal
      initVariantImpl = newTree(
        nnkFuncDef,
        postfix(initVariant, "*"),
        newEmptyNode(),
        newEmptyNode(),
        newTree(
          nnkFormalParams,
          @[Variant] &
            (commonFields & individualFields).mapIt(
              block:
                let id =
                  if it[0].kind == nnkPostfix:
                    it[0][1]
                  else:
                    it[0]
                newTree(nnkIdentDefs, @[id] & it[1 .. ^1])
            ),
        ),
        newEmptyNode(),
        newEmptyNode(),
        newCall(
          Variant,
          newTree(
            nnkObjConstr,
            @[T, newTree(nnkExprColonExpr, ident kindField.strVal, enumVal)] &
              (commonFields & individualFields).mapIt(
                block:
                  let id =
                    if it[0].kind == nnkPostfix:
                      it[0][1]
                    else:
                      it[0]
                  newTree(nnkExprColonExpr, ident id.strVal, ident id.strVal)
              ).toSeq,
          ),
        ),
      )
      toT = ident "to" & T.strVal
      toTImpl = quote:
        converter `toT`*(val: `Variant`): `T` =
          cast[`T`](val)

      expectingVariant = ident "expecting" & Variant.strVal
      expectingVariantImpl = quote:
        macro `expectingVariant`*(self: `T`, bl): untyped =
          self.expectKind(nnkSym)

          let
            sectionKind =
              case self.symKind
              of nskVar: nnkVarSection
              of nskConst: nnkConstSection
              else: nnkLetSection
            shadow = ident self.strVal
            shadowImpl = newTree(
              sectionKind,
              newTree(
                nnkIdentDefs,
                shadow,
                newEmptyNode(),
                newCall(bindSym `variantName`, self),
              ),
            )

          newBlockStmt(
            newStmtList(
              newCall(
                bindSym "assert",
                infix(newDotExpr(self, ident `kindFieldName`), "==", newLit `enumVal`),
              ),
              shadowImpl,
              bl,
            )
          )

      ifVariant = ident "if" & Variant.strVal
      ifVariantImpl = quote:
        macro `ifVariant`*(self: `T`, bl): untyped =
          let
            selfSym =
              if self.kind == nnkHiddenDeref:
                self[0]
              else:
                self
            sectionKind =
              case selfSym.symKind
              of nskVar: nnkVarSection
              of nskConst: nnkConstSection
              else: nnkLetSection
            shadow = ident selfSym.strVal
            shadowImpl = newTree(
              sectionKind,
              newTree(
                nnkIdentDefs,
                shadow,
                newEmptyNode(),
                newCall(bindSym `variantName`, self),
              ),
            )

          newTree(
            nnkIfStmt,
            newTree(
              nnkElifBranch,
              infix(newDotExpr(self, ident `kindFieldName`), "==", newLit `enumVal`),
              newStmtList(shadowImpl, bl),
            ),
          )

    result.add:
      quote:
        type `Variant` {.borrow: `variantBorrow`.} = distinct `T`

        `initVariantImpl`
        `toTImpl`
        `expectingVariantImpl`
        `ifVariantImpl`
  result.add:
    quote:
      type `SomeK` = object
        value: `K`

      `toSomeKImpl`
      `toKImpl`
      `kindProxyImpl`
      `variantCaseImpl`
