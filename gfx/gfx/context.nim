type GfxContext = object

var context: GfxContext

proc init(self: var GfxContext) {.raises: [GfxError].} =
  discard glfwSetErrorCallback glfwErrorCallback
  discard glfwInit()

  gfxPromoteError()

proc `=destroy`(self: var GfxContext) =
  glfwTerminate()
