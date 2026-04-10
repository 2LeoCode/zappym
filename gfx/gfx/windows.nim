import nimgl/[glfw, opengl], errors, std/[importutils]

type Window = object
  title: string
  glfwWindow: GLFWWindow

proc init*(self: var Window, width, height: sink uint, title: sink string) =
  self.title = title

  glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3)
  glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3)
  glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE)

  self.glfwWindow = glfwCreateWindow(width.int32, height.int32, title)
  self.glfwWindow.makeContextCurrent

  privateAccess:
    gfxPromoteError()

  if not glInit():
    let code = glGetError()
    let error = new GfxError

    error[].initFromGlError(code)
    raise error

proc newWindow*(width, height: sink uint, title: sink string): Window =
  result.init(width, height, title)
