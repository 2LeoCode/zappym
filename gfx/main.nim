import argparse, utils, nimgl/[glfw, opengl], std/[strformat], shady, vmath

static:
  doAssert isMainModule, "This file is not a module"

const WINDOW_TITLE = "zappy"

proc handleKeyEvent(window: GLFWWindow, key, scancode, action, mods: int32) {.cdecl.} =
  if key == GLFWKey.ESCAPE and action == GLFWPress:
    window.setWindowShouldClose true

proc handleFrameBufferSizeEvent(window: GLFWWindow, width, height: GLSizei) {.cdecl.} =
  glViewPort(0, 0, width, height)

proc handleGlfwError(code: int32, description: cstring): void {.cdecl, noReturn.} =
  stderr.writeLine fmt "GLFW Fatal Error - code: {code}, description: {description}"
  glfwTerminate()
  quit QuitFailure

proc exampleVertexShader(aCol: Vec3, aPos: Vec3, vertColor: var Vec3) =
  glPosition = vec4(aPos, 1)
  vertColor = aCol

proc exampleFragmentShader(fragColor: var Vec4, vertColor: Vec3) =
  fragColor = vec4(vertColor, 1.0f)

discard glfwInit()

glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3)
glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3)
glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE)

let window = glfwCreateWindow(800, 600, WINDOW_TITLE)

window.makeContextCurrent

if not glInit():
  let code = cast[int](glGetError())
  stderr.writeLine fmt "OpenGL Initialization: Fatal Error - code: {code}"
  quit QuitFailure

var VBO: GLUint
var VAO: GLUint
let vertices =
  [-0.5f, -0.5, 0.0, 1, 0, 0, 0.5, -0.5, 0.0, 0, 1, 0, 0.0, 0.5, 0.0, 0, 0, 1]

let vertexShader = block:
  let vertexShader = glCreateShader GL_VERTEX_SHADER
  let vertexSource = exampleVertexShader.toGLSL
  echo fmt "=== VERTEX SHADER ===\n{vertexSource}\n====================="
  let vertexSourceC = vertexSource.cstring
  glShaderSource(vertexShader, 1, vertexSourceC.addr, nil)
  glCompileShader vertexShader
  vertexShader

let fragmentShader = block:
  let fragmentShader = GL_FRAGMENT_SHADER.glCreateShader
  let fragmentSource = exampleFragmentShader.toGLSL
  echo fmt "=== FRAGMENT SHADER ===\n{fragmentSource}\n======================="
  let fragmentSourceC = fragmentSource.cstring
  glShaderSource(fragmentShader, 1, fragmentSourceC.addr, nil)
  glCompileShader fragmentShader
  fragmentShader

let shaderProgram = glCreateProgram()
glAttachShader(shaderProgram, vertexShader)
glAttachShader(shaderProgram, fragmentShader)
glLinkProgram shaderProgram

block:
  const INFO_LOG_BUFSIZE = 1024
  var success: GLInt
  var infoLog: array[INFO_LOG_BUFSIZE, char]
  let infoLogC = cast[cstring](infoLog.addr)

  glGetShaderiv(vertexShader, GL_COMPILE_STATUS, success.addr)

  if success == 0:
    glGetProgramInfoLog(vertexShader, INFO_LOG_BUFSIZE, nil, infoLogC)
    stderr.writeLine fmt "Failed to compile vertex shader:\n{infoLogC}\n"
    quit QuitFailure

  glGetShaderiv(fragmentShader, GL_COMPILE_STATUS, success.addr)

  if success == 0:
    glGetProgramInfoLog(vertexShader, INFO_LOG_BUFSIZE, nil, infoLogC)
    stderr.writeLine fmt "Failed to compile fragment shader:\n{infoLogC}\n"
    quit QuitFailure

  glGetProgramiv(shaderProgram, GL_LINK_STATUS, success.addr)

  if success == 0:
    glGetProgramInfoLog(vertexShader, INFO_LOG_BUFSIZE, nil, infoLogC)
    stderr.writeLine fmt "Failed to link shaders:\n{infoLogC}\n"
    quit QuitFailure

glGenBuffers(1, VBO.addr)
glBindBuffer(GL_ARRAY_BUFFER, VBO)
glGenVertexArrays(1, VAO.addr)
glBindVertexArray VAO
glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices.addr, GL_STATIC_DRAW)

let aPosLocation = glGetAttribLocation(shaderProgram, "aPos").GLUint
glVertexAttribPointer(aPosLocation, 3, EGL_FLOAT, false, 6 * sizeof float32, nil)
glEnableVertexAttribArray aPosLocation

let aColLocation = glGetAttribLocation(shaderProgram, "aCol").GLUint
glVertexAttribPointer(
  aColLocation,
  3,
  EGL_FLOAT,
  false,
  6 * sizeof float32,
  cast[pointer](3 * sizeof float32),
)
glEnableVertexAttribArray aColLocation

discard window.setKeyCallback handleKeyEvent
discard window.setFramebufferSizeCallback handleFrameBufferSizeEvent
discard glfwSetErrorCallback handleGlfwError

while not window.windowShouldClose:
  glfwPollEvents()
  glClearColor(1, 1, 1, 1)
  glClear GL_COLOR_BUFFER_BIT
  glUseProgram shaderProgram
  glBindVertexArray VAO
  glDrawArrays(GL_TRIANGLES, 0, 3)
  glBindVertexArray 0
  window.swapBuffers

window.destroyWindow
glfwTerminate()
glEnd()
