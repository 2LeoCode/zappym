import
  std/[
    macros, sugar, strformat, sequtils, strutils, sets, math, algorithm, parseutils,
    math,
  ],
  utils,
  primitives

const posCharset = "xyzw"
const colCharset = "rgba"
const texCharset = "stpq"

macro vecType(dataType: static[PrimitiveKind], dim: static[range[2 .. 4]]): typedesc =
  let
    fieldType = ident $dataType
    fieldDefs = collect:
      for i in 0 ..< dim:
        let fieldName = ident $posCharset[i]
        newIdentDefs(fieldName.postfix "*", fieldType)

  newTree(
    nnkObjectTy,
    newEmptyNode(),
    newEmptyNode(),
    newTree.unpackVarargs(nnkRecList, fieldDefs),
  )

macro defineVecTypes(): untyped =
  let typeDefs = collect:
    for dataType in PrimitiveKind:
      for dim in 2 .. 4:
        let
          typeName = ident fmt "{dataType.toTypePrefix}Vec{dim}"
          typeDef = quote:
            vecType(`dataType`, `dim`)
        newTree(nnkTypeDef, typeName.postfix("*"), newEmptyNode(), typeDef)

  newTree.unpackVarargs(nnkTypeSection, typeDefs)

macro defineVecProperties(): untyped =
  result = newStmtList()

  for dt in PrimitiveKind:
    for dim in 2 .. 4:
      let
        vecType = ident fmt "{dt.toTypePrefix}Vec{dim}"
        dataType = ident $dt

      for i in 0 .. 3:
        for charset in [posCharset, colCharset, texCharset]:
          var indices = collect (;
            for _ in 0 .. i:
              0
          )

          func collectProperties(): seq[NimNode] =
            let
              name = indices.mapIt($charset[it]).join ""
              getter = ident name
              setter = newTree(nnkAccQuoted, ident name & "=")

            if indices.len == 1:
              if charset != posCharset:
                let field = ident $posCharset[indices[0]]
                result.add:
                  quote:
                    func `getter`*(self: `vecType`): `dataType` =
                      self.`field`

                    func `setter`*(self: var `vecType`, val: sink `dataType`) =
                      self.`field` = val
            else:
              let
                valueType = ident fmt "{dt.toTypePrefix}Vec{indices.len}"
                selfParam = ident "self"

              var constructorCall = newTree(nnkObjConstr, valueType)

              constructorCall.add:
                collect:
                  for i, idx in indices:
                    let
                      field = ident $posCharset[i]
                      value = ident $posCharset[idx]
                    newTree(
                      nnkExprColonExpr, field, newTree(nnkDotExpr, selfParam, value)
                    )

              result.add:
                quote:
                  func `getter`*(`selfParam`: `vecType`): `valueType` =
                    `constructorCall`

              if name.toHashSet.len == name.len:
                var assignmentStmts = newStmtList()

                let
                  selfParam = ident "self"
                  valueParam = ident "value"
                assignmentStmts.add:
                  collect:
                    for i, idx in indices:
                      let
                        field = ident $posCharset[i]
                        value = ident $posCharset[idx]
                      newAssignment(
                        newTree(nnkDotExpr, selfParam, value),
                        newTree(nnkDotExpr, valueParam, field),
                      )
                result.add:
                  quote:
                    func `setter`*(
                        `selfParam`: var `vecType`, `valueParam`: sink `valueType`
                    ) =
                      `assignmentStmts`

            var j = indices.len - 1
            while j >= 0 and indices[j] == dim - 1:
              indices[j] = 0
              dec j
            if j != -1:
              inc indices[j]
              result.add collectProperties()

          result.add unpackVarargs(newStmtList, collectProperties())

macro defineVecConstructors(): untyped =
  result = newStmtList()

  for dt in PrimitiveKind:
    for dim in 2 .. 4:
      let
        vecType = ident fmt "{dt.toTypePrefix}Vec{dim}"
        dataType = ident $dt
        funcId = postfix(ident fmt "{dt.toTypePrefix.toLower}vec{dim}", "*")

      block:
        let
          params = newTree(nnkFormalParams, vecType)
          body = newStmtList()
        for i in 0 ..< dim:
          let name = ident $posCharset[i]
          let res = ident "result"
          params.add newTree(nnkIdentDefs, name, dataType, newEmptyNode())
          body.add:
            quote:
              `res`.`name` = `name`

        result.add newTree(
          nnkFuncDef,
          funcId,
          newEmptyNode(),
          newEmptyNode(),
          params,
          newEmptyNode(),
          newEmptyNode(),
          body,
        )

      block:
        let
          fillParam = ident "fill"
          params = newTree(
            nnkFormalParams,
            vecType,
            newTree(nnkIdentDefs, fillParam, dataType, newEmptyNode()),
          )
        var body = newStmtList()

        body.add:
          collect:
            for i in 0 ..< dim:
              let
                name = ident $posCharset[i]
                res = ident "result"
              quote:
                `res`.`name` = `fillParam`

        result.add newTree(
          nnkFuncDef,
          funcId,
          newEmptyNode(),
          newEmptyNode(),
          params,
          newEmptyNode(),
          newEmptyNode(),
          body,
        )

      for i in 2 .. dim:
        let subVecType = ident fmt "{dt.toTypePrefix}Vec{i}"

        for subVecCnt in 1 .. int(dim / i):
          var subVecPos = 0
          while subVecPos + subVecCnt * i <= dim:
            let
              params = newTree(nnkFormalParams, vecType)
              body = newStmtList()
              res = ident "result"

            for j in 0 ..< subVecPos:
              let name = ident $posCharset[j]

              params.add newTree(nnkIdentDefs, name, dataType, newEmptyNode())
              body.add:
                quote:
                  `res`.`name` = `name`

            for j in 0 ..< subVecCnt:
              let name = ident $posCharset[subVecPos + i * j ..< subVecPos + i * j + i]

              params.add newTree(nnkIdentDefs, name, subVecType, newEmptyNode())
              body.add:
                quote:
                  `res`.`name` = `name`

            for j in subVecPos + i * subVecCnt ..< dim:
              let name = ident $posCharset[j]

              params.add newTree(nnkIdentDefs, name, dataType, newEmptyNode())
              body.add:
                quote:
                  `res`.`name` = `name`

            result.add newTree(
              nnkFuncDef,
              funcId,
              newEmptyNode(),
              newEmptyNode(),
              params,
              newEmptyNode(),
              newEmptyNode(),
              body,
            )

            subVecPos += 1

macro defineVecOperators(): untyped =
  result = newStmtList()
  let mathOps = ["+", "-", "*", "/", "mod"]

  # func resolveIdx(i: int | BackwardsIndex, dim: static[int]): range[0 .. dim] =
  #   when i is BackwardsIndex:
  #     dim - i.int
  #   else:
  #     i

  # func diffIdx(i, j: int | BackwardsIndex, dim: static[int]): range[0 .. dim] =
  #   abs(resolveIdx(j, dim) - resolveIdx(i, dim)) + 1

  for dt in PrimitiveKind:
    for dim in 2 .. 4:
      let
        vecType = ident fmt "{dt.toTypePrefix}Vec{dim}"
        dataType = ident $dt
        max = newLit dim - 1
        idxFuncName = newTree(nnkAccQuoted, ident "[]")

      result.add:
        quote "1":
          macro `1 idxFuncName`*(
              self: `1 vecType`, i: static range[0 .. `1 max`]
          ): `1 dataType` =
            result = newStmtList()
            var
              stmts = result
              selfId: NimNode
            if self.kind == nnkSym:
              selfId = self
            else:
              selfId = genSym(nskLet, "tmp")
              stmts.add:
                quote "2":
                  block:
                    let `2 selfId` = `2 self`
              stmts = stmts[0][0]
            let fieldId = ident $posCharset[i]
            stmts.add selfId.newDotExpr(fieldId)

          macro `1 idxFuncName`*(
              self: var `1 vecType`, i: static range[0 .. `1 max`]
          ): var `1 dataType` =
            result = newStmtList()
            let fieldId = ident $posCharset[i]
            result.add self.newDotExpr(fieldId)

          func `1 idxFuncName`*(
              self: `1 vecType`, i: range[0 .. `1 max`]
          ): `1 dataType` =
            var j = 0
            for field in self.fields:
              if j == i.int:
                return field
              inc j
            raiseAssert "unreachable"

          func `1 idxFuncName`*(
              self: var `1 vecType`, i: range[0 .. `1 max`]
          ): var `1 dataType` =
            var j = 0
            for field in self.fields:
              if j == i.int:
                return field
              inc j
            raiseAssert "unreachable"

          func `1 idxFuncName`*(
              self: `1 vecType`,
              i: static range[BackwardsIndex(1) .. BackwardsIndex(`1 dim`)],
          ): `1 dataType` =
            self[range[0 .. `1 max`](`1 dim` - i.int)]

          func `1 idxFuncName`*(
              self: var `1 vecType`,
              i: static range[BackwardsIndex(1) .. BackwardsIndex(`1 dim`)],
          ): var `1 dataType` =
            self[range[0 .. `1 max`](`1 dim` - i.int)]

          func `1 idxFuncName`*(
              self: `1 vecType`, i: range[BackwardsIndex(1) .. BackwardsIndex(`1 dim`)]
          ): `1 dataType` =
            self[range[0 .. `1 max`](`1 dim` - i.int)]

          func `1 idxFuncName`*(
              self: var `1 vecType`,
              i: range[BackwardsIndex(1) .. BackwardsIndex(`1 dim`)],
          ): var `1 dataType` =
            self[range[0 .. `1 max`](`1 dim` - i.int)]

      for op in mathOps:
        let
          opId = ident $op
          opIdQuoted = newTree(nnkAccQuoted, opId)
          opAsgnId = ident $op & "="
          opAsgnIdQuoted = newTree(nnkAccQuoted, opAsgnId)
          lhsParam = ident "lhs"
          rhsParam = ident "rhs"
          selfParam = ident "self"
          otherParam = ident "other"
        var whenSupported = newTree(
          nnkWhenStmt, newTree(nnkElifBranch, newCall(ident "compiles"), newStmtList())
        )
        whenSupported[0][0].add:
          quote:
            block:
              discard `opIdQuoted`(`dataType`(1), `dataType`(1))

        block:
          let body = newStmtList()

          for i in 0 ..< dim:
            let field = ident $posCharset[i]
            body.add:
              quote:
                result.`field` =
                  `dataType`(`opIdQuoted`(`lhsParam`.`field`, `rhsParam`))

          whenSupported[0][^1].add:
            quote:
              func `opIdQuoted`*(
                  `lhsParam`: `vecType`, `rhsParam`: `dataType`
              ): `vecType` =
                `body`

              func `opAsgnIdQuoted`*(
                  `selfParam`: var `vecType`, `otherParam`: `dataType`
              ) =
                `selfParam` = `opIdQuoted`(`selfParam`, `otherParam`)

              func `opIdQuoted`*(
                  `lhsParam`: `dataType`, `rhsParam`: `vecType`
              ): `vecType` =
                `opIdQuoted`(`rhsParam`, `lhsParam`)

        block:
          let body = newStmtList()

          for i in 0 ..< dim:
            let field = ident $posCharset[i]
            body.add:
              quote:
                result.`field` =
                  `dataType`(`opIdQuoted`(`lhsParam`.`field`, `rhsparam`.`field`))
          whenSupported[0][^1].add:
            quote:
              func `opIdQuoted`*(`lhsParam`, `rhsParam`: `vecType`): `vecType` =
                `body`

              func `opAsgnIdQuoted`*(
                  `selfParam`: var `vecType`, `otherParam`: var `vecType`
              ) =
                `selfParam` = `opIdQuoted`(`selfParam`, `otherParam`)

        result.add whenSupported

macro matType(
    dataType: static[PrimitiveKind], dimX, dimY: static[range[2 .. 4]]
): typedesc =
  let vecType = ident fmt "{dataType.toTypePrefix}Vec{dimY}"

  newTree(
    nnkObjectTy,
    newEmptyNode(),
    newEmptyNode(),
    newTree(
      nnkRecList,
      newTree(
        nnkIdentDefs,
        ident "contents",
        newTree(nnkBracketExpr, ident "array", newLit dimX, vecType),
        newEmptyNode(),
      ),
    ),
  )

macro defineMatTypes(): untyped =
  result = newTree(nnkTypeSection)

  for dt in PrimitiveKind:
    for dimX in 2 .. 4:
      for dimY in 2 .. 4:
        let
          t = quote:
            matType(`dt`, `dimX`, `dimY`)
          tId = ident fmt "{dt.toTypePrefix}Mat{dimX}x{dimY}"
        result.add newTree(nnkTypeDef, postfix(tId, "*"), newEmptyNode(), t)

        if dimX == dimY:
          let aliasId = ident fmt "{dt.toTypePrefix}Mat{dimX}"
          result.add newTree(nnkTypeDef, postfix(aliasId, "*"), newEmptyNode(), tId)

macro defineMatConstructors(): untyped =
  result = newStmtList()

  for dt in PrimitiveKind:
    for dim1 in 2 .. 4:
      for dim2 in 2 .. 4:
        let
          matTypeText = fmt "{dt.toTypePrefix}Mat{dim1}x{dim2}"
          matType = ident matTypeText
          matConstr = ident fmt "{dt.toTypePrefix.toLower}mat{dim1}x{dim2}"

        let sz = dim1 * dim2

        result.add:
          quote "1":
            macro `1 matConstr`*(args: varargs[typed]): `1 matType` =
              var i = 0
              var x = 0
              var y = 0
              let instanceId = genSym(nskVar, "instance")
              result = quote "2":
                block:
                  var `2 instanceId`: `1 matType`

              for arg in args:
                let t = arg.getTypeInst.repr

                var stmts = result[0][1]
                var argId: NimNode
                if arg.kind in nnkLiterals + {nnkSym}:
                  argId = arg
                else:
                  argId = genSym(nskLet, "tmp")
                  stmts.add:
                    quote "2":
                      let `2 argId` = `2 arg`

                if t.startsWith `1 dt`.toTypePrefix & "Vec":
                  let vDim = parseInt $t[^1]

                  for j in 0 ..< vDim:
                    doAssert i < `1 sz`

                    y = int(i / `1 dim1`)
                    x = int(i mod `1 dim1`)
                    inc i
                    stmts.add:
                      quote "2":
                        `2 instanceId`.contents[`2 y`][`2 x`] = `2 argId`[`2 j`]
                else:
                  doAssert i < `1 sz`

                  y = int(i / `1 dim1`)
                  x = int(i mod `1 dim1`)
                  inc i
                  stmts.add:
                    quote "2":
                      `2 instanceId`.contents[`2 y`][`2 x`] = `2 argId`
              doAssert i == `1 sz`
              result[0][1].add instanceId

defineVecTypes()
defineMatTypes()
defineVecProperties()
defineVecOperators()
defineVecConstructors()
defineMatConstructors()

let foo = Float(1) * Float(1)

let tmp = vec2(2, 3)
var foo = vec3(1, tmp)
var baz = vec4(1)
baz.xyzw = vec4(1, 2, 3, 4)
echo baz
echo baz.bar
echo baz * 2
baz.rg = baz.rg / 2
echo baz
echo foo
echo foo[^1]
echo foo[2 .. ^2]
echo foo[^1 .. 1]
echo 0.5 * foo * vec3(3, 1, 2) / 2

let fooM = mat3x3(1, vec3(2, 3, 4), vec2(5, 6), 7, vec2(8, 9))
echo $fooM

type Shader = object
macro shader(code: untyped): Shader =
  raise Defect.newException("unimplemented")

template glsl*(body) =
  ShaderSource(toGlsl body)
