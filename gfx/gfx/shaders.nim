import
  nimgl/[glfw, opengl],
  std/[options, sequtils, tables, macros, sugar],
  shady,
  errors {.all.},
  ../utils

type ShaderKind* = enum
  skVertex
  skFragment

func toGlEnum(self: sink ShaderKind): GLEnum =
  case self
  of skVertex: GL_VERTEX_SHADER
  of skFragment: GL_FRAGMENT_SHADER

type Shader*[kind: static[ShaderKind], Code: proc] = ref object
  parent: Option[Shader[kind, Code]]
  code: Code
  id: GLUint

type ShaderProgram*[Shaders: tuple] = object
  shaders: Shaders

proc wrapCalls[Code: proc](firstProcs: Code, procs: varargs[Code]): NimNode =
  var calls = newStmtList()
  calls.add:
    collect:
      for p in procs:
        var call = newCall(ident p.strVal)
        call.add:
          collect:
            for arg in procs[0].getImpl[3][1 ..^ 1]:
              ident arg[0].strVal
        call

  newTree(
    nnkProcDef,
    newEmptyNode(),
    newEmptyNode(),
    newEmptyNode(),
    params,
    newEmptyNode(),
    newEmptyNode(),
    calls,
  )

macro init*(self: var Shader) =
  quote:
    var codeChain: seq[typeof `self`.code] = @[]

    func collectCodeChain(node = self) =
      if node.parent.isSome:
        collectCodeChain(node.parent.unsafeGet)

      codeChain.add node.code

    collectCodeChain()
    let source = unpackVarargs(wrapCalls)

  let source = unpackVarargs(wrapCalls, codeChain[0], codeChain[1 ..^ 1])
  let sourceC = source.cstring

  self.id = glCreateShader kind.toGlEnum
  glShaderSource(self.id, 1, sourceC.addr, nil)
  glCompileShader self.id
  gfxPropagateError()

macro newShader*(kind: static[ShaderKind], code: typed) =
  assert code.kind == nnkSym
  assert code.getImpl.kind == nnkProcDef
  assert code.getImpl[3][0].kind == nnkEmpty

  let codeType = code.getTypeInst
  let codeName = code.getImpl[0].strVal
  let codeArgs = code.getImpl[3]

  var args = newTree(nnkFormalParams, newEmptyNode())
  args.add:
    collect:
      for arg in codeArgs[1 ..^ 1]:
        newTree(nnkIdentDefs, ident arg[0].strVal, ident arg[1].strVal, newEmptyNode())

  let argIdents = collect:
    for arg in codeArgs[1 ..^ 1]:
      ident arg[0].strVal

  let wrapper = newTree(
    nnkProcDef,
    ident fmt "shader_{codeName}",
    newEmptyNode(),
    newEmptyNode(),
    args,
    newEmptyNode(),
    newEmptyNode(),
    newStmtList(unpackVarargs(newCall, code.getImpl[0], argIdents)),
  )

  quote:
    block:
      var instance = Shader[`kind`, `codeType`]()
      instance.code = `wrapper`

      var source = instance.code.toGlsl
      var sourceC = source.cstring

      instance.id = glCreateShader `kind`.toGlEnum
      glShaderSource(instance.id, 1, sourceC.addr, nil)
      glCompileShader instance.id
      gfxPropagateError()

      instance.init

macro newShader*(kind: static[ShaderKind], code: typed, parent: typed) =
  assert code.kind == nnkSym
  assert code.getImpl.kind == nnkProcDef
  assert code.getImpl[3][0].kind == nnkEmpty

  let codeType = code.getTypeInst
  let codeName = code.getImpl[0].strVal
  let codeArgs = code.getImpl[3]

  var args = newTree(nnkFormalParams, newEmptyNode())
  args.add:
    collect:
      for arg in codeArgs[1 ..^ 1]:
        newTree(nnkIdentDefs, ident arg[0].strVal, ident arg[1].strVal, newEmptyNode())

  let argIdents = collect:
    for arg in codeArgs[1 ..^ 1]:
      ident arg[0].strVal

  let wrapper = newTree(
    nnkProcDef,
    ident fmt "shader_{codeName}",
    newEmptyNode(),
    newEmptyNode(),
    args,
    newEmptyNode(),
    newEmptyNode(),
    newStmtList(
      unpackVarargs(newCall, code.getImpl[0], argIdents), unpackVarargs(newCall)
    ),
  )

  quote:
    block:
      var instance = Shader[`kind`, `codeType`]()
      instance.code = `wrapper`

      var source = instance.code.toGlsl
      var sourceC = source.cstring

      instance.id = glCreateShader `kind`.toGlEnum
      glShaderSource(instance.id, 1, sourceC.addr, nil)
      glCompileShader instance.id
      gfxPropagateError()

      instance.init

func makeCodeChain(chain: varargs[proc]): NimNode =
  newTree()

proc testFoo(foo: int, bar: char) =
  echo "foo"
  echo foo

proc testBar(foo: int, bar: char) =
  echo "bar"
  echo bar

let foo = newShader(skFragment, testFoo)
let bar = newShader(skFragment, testBar, foo)

echo foo.code.repr
echo bar.code.repr

macro newShaderProgram*(shaders: varargs[typed]) =
  echo shaders[0].treeRepr

let shader = Shader[skFragment, proc(a: int, b: string)]()
newShaderProgram(shader)

proc addFragment*(self: var Shader, fragment: proc): var Shader =
  let source = fragment.toGlsl
  let sourceC = source.cstring

  self.fragment = glCreateShader GL_FRAGMENT_SHADER
  glShaderSource(self.fragment, 1, sourceC.addr, nil)
  glCompileShader self.fragment

  gfxPropagateError()
  self

proc addVertex*(self: var Shader, vertex: proc): var Shader =
  let source = vertex.toGlsl
  let sourceC = source.cstring

  self.vertex = some glCreateShader GL_VERTEX_SHADER
  glShaderSource(self.vertex, 1, sourceC.addr, nil)

  gfxPropagateError()
  self

proc init*(self: var Shader): var Shader =
  self.program = glCreateProgram()

  gfxPropagateError()
  self

proc newShader*(fragment: proc): Shader =
  result.addFragment fragment

proc newShader*(fragment: proc, vertex: proc): Shader =
  result = newShader fragment
  result.addVertex vertex

proc compile*(self: Shader) =
  glCompileShader self.fragment
  glAttachShader(self.program, self.fragment)
  self.vertex.map do(shader: GLUint):
    glCompileShader(shader)
    glAttachShader(self.program, shader)

  glLinkProgram(self.program)

  gfxPropagateError()
