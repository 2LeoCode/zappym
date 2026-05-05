import nimgl/glfw, errors {.all.}

type GfxContext = object

var context: GfxContext

proc init(self: var GfxContext) {.raises: [GfxError].} =
  discard glfwSetErrorCallback glfwErrorCallback
  discard glfwInit()

  gfxPropagateError()

proc `=destroy`(self: var GfxContext) =
  glfwTerminate()

proc initContext*() =
  context.init
