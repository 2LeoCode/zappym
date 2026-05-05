import std/[options, sugar], nimgl/[glfw, opengl], ../utils

type GfxErrorKind* = enum
  gekGlfwPlatformError
  gekGlfwNotInitialized
  gekGlfwInvalidEnum
  gekGlfwInvalidValue
  gekGlfwApiUnavailable
  gekGlfwVersionUnavailable
  gekGlfwFormatUnavailable
  gekGlfwNoWindowContext
  gekGlfwUnknownError
  gekGlInvalidEnum
  gekGlInvalidValue
  gekGlInvalidOperation
  gekGlStackOverflow
  gekGlStackUnderflow
  gekGlOutOfMemory
  gekGlUnknownError
  gekUnknownError

const gekGlfwError* = {
  gekGlfwPlatformError, gekGlfwNotInitialized, gekGlfwInvalidEnum, gekGlfwInvalidValue,
  gekGlfwApiUnavailable, gekGlfwVersionUnavailable, gekGlfwFormatUnavailable,
  gekGlfwNoWindowContext, gekGlfwUnknownError,
}

const gekGlError* = {
  gekGlInvalidEnum, gekGlInvalidValue, gekGlInvalidOperation, gekGlStackOverflow,
  gekGlStackUnderflow, gekGlOutOfMemory, gekGlUnknownError,
}

type GfxError* = object of CatchableError
  case kind: GfxErrorKind
  of gekGlfwError:
    glfwErrorDescription: string
  of gekGlError:
    glErrorDescription: string
  else:
    discard

var lastError: Option[ref GfxError]

func initFromGlfwError(self: var GfxError, code: sink int32, description: sink string) =
  let kind =
    case code
    of GLFW_PLATFORM_ERROR: gekGlfwPlatformError
    of GLFW_NOT_INITIALIZED: gekGlfwNotInitialized
    of GLFW_INVALID_ENUM: gekGlfwInvalidEnum
    of GLFW_INVALID_VALUE: gekGlfwInvalidValue
    of GLFW_API_UNAVAILABLE: gekGlfwApiUnavailable
    of GLFW_VERSION_UNAVAILABLE: gekGlfwVersionUnavailable
    of GLFW_FORMAT_UNAVAILABLE: gekGlfwFormatUnavailable
    of GLFW_NO_WINDOW_CONTEXT: gekGlfwNoWindowContext
    else: gekGlfwUnknownError

  self =
    case kind
    of gekGlfwError:
      GfxError(kind: kind, glfwErrorDescription: description)
    else:
      unreachable()

func initFromGlError(self: var GfxError, code: sink GLEnum) =
  let (kind, description) =
    case code
    of GL_INVALID_ENUM:
      (
        gekGlInvalidEnum,
        "An unacceptable value is specified for an enumerated argument.",
      )
    of GL_INVALID_VALUE:
      (gekGlInvalidValue, "A numeric argument is out of range.")
    of GL_INVALID_OPERATION:
      (
        gekGlInvalidOperation,
        "The specified operation is not allowed in the current state.",
      )
    of GL_STACK_OVERFLOW:
      (gekGlStackOverflow, "This function would cause a stack overflow.")
    of GL_STACK_UNDERFLOW:
      (gekGlStackUnderflow, "This function would cause a stack underflow.")
    of GL_OUT_OF_MEMORY:
      (gekGlOutOfMemory, "There is not enough memory left to execute the function.")
    else:
      (gekGlUnknownError, "An unknown OpenGL error occured.")

  self =
    case kind
    of gekGlError:
      GfxError(kind: kind, glErrorDescription: description)
    else:
      unreachable()

proc gfxPropagateError() =
  if lastError.isSome:
    let err = lastError.unsafeGet
    lastError = none(ref GfxError)
    raise err

proc glfwErrorCallback(code: int32, description: cstring) {.cDecl.} =
  lastError = some:
    block:
      let err = (ref GfxError)()
      err[].initFromGlfwError(code, $description)
      err
