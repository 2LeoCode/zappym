import nimgl/[glfw, opengl], std/[options, macros, sugar], utils, shady

type Shader = object
  vertex: Option[GLUint]
  fragment: GLUint
  program: GLUint

proc addFragment*(self: var Shader, fragment: proc): var Shader =
  let source = fragment.toGlsl
  let sourceC = source.cstring

  self.fragment = glCreateShader GL_FRAGMENT_SHADER
  glShaderSource(self.fragment, 1, sourceC.addr, nil)
  glCompileShader self.fragment

  gfxPromoteError()
  self

proc addVertex*(self: var Shader, vertex: proc): var Shader =
  let source = vertex.toGlsl
  let sourceC = source.cstring

  self.vertex = some glCreateShader GL_VERTEX_SHADER
  glShaderSource(self.vertex, 1, sourceC.addr, nil)

  gfxPromoteError()
  self

proc init*(self: var Shader): var Shader =
  self.program = glCreateProgram()

  gfxPromoteError()
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

  gfxPromoteError()
