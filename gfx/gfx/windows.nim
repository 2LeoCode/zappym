import nimgl/[glfw, opengl], context, errors {.all.}

type Window = object
  title: string
  glfwWindow: GLFWWindow

proc init*(self: var Window, width, height: sink uint, title: sink string) =
  once:
    initContext()

  self.title = title

  glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3)
  glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3)
  glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE)

  self.glfwWindow = glfwCreateWindow(width.int32, height.int32, title)
  self.glfwWindow.makeContextCurrent

  gfxPropagateError()

  if not glInit():
    let code = glGetError()

    var error = (ref GfxError)()
    error[].initFromGlError(code)

    raise error

proc newWindow*(width, height: sink uint, title: sink string): Window =
  result.init(width, height, title)
