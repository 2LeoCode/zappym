import primitives

type
  GLEqOpKind = enum
    glEq
    glNe

  GLAsgnOpKind = enum
    glAsgn
    glAsgnAdd
    glAsgnMul
    glAsgnDiv
    glAsgnRem

  GLRelOpKind = enum
    glLt
    glGt
    glLe
    glGe

  GLLitKind = enum
    glBool
    glInt
    glUInt
    glFloat
    glDouble

  GLShiftOpKind = enum
    glShl
    glShr

  GLAddOpKind = enum
    glAdd
    glSub

  GLMulOpKind = enum
    glMul
    glDiv
    glRem

  GLUnaryOpKind = enum
    glInc
    glDec
    glPlus
    glMinus
    glNot
    glLNot

  GLPostfixOpKind = enum
    glPInc
    glPDec
    glBracket
    glDot

  GLOpKind = enum
    glokShl
    glokShr
    glokOr
    glokXor
    glokAnd
    glokLOr
    glokLXor
    glokLAnd
    glokAdd
    glokSub
    glokMul
    glokDiv
    glokRem

const
  glokBit = {glokShl, glokShr, glokOr, glokXor, glokAnd}
  glokLogical = {glokLOr, glokLXor, glokLAnd}

type
  GLNode* = object of RootObj

  GLIntExprNode* = object of GLNode

  GLExprNode* = object of GLIntExprNode

  GLAsgnExprNode* = object of GLExprNode
  GLChainExprNode* {.final.} = object of GLExprNode
    lhs: GLExprNode
    rhs: GLAsgnExprNode

  GLCondExprNode* = object of GLAsgnExprNode
  GLChainAsgnExprNode* {.final.} = object of GLAsgnExprNode
    opKind: GLAsgnOpKind
    lhs: GLUnaryExprNode
    rhs: GLAsgnExprNode

  GLLogicalOrExprNode* = object of GLCondExprNode
  GLTernaryExpr* {.final.} = object of GLCondExprNode
    cond: GLLogicalOrExprNode
    trueBranch: GLExprNode
    falseBranch: GLAsgnExprNode

  GLLogicalXorExprNode* = object of GLLogicalOrExprNode
  GLChainLogicalOrExprNode* {.final.} = object of GLLogicalOrExprNode
    lhs: GLLogicalOrExprNode
    rhs: GLLogicalXorExprNode

  GLLogicalAndExprNode* = object of GLLogicalXorExprNode
  GLChainLogicalXorExprNode* {.final.} = object of GLLogicalXorExprNode
    lhs: GLLogicalXorExprNode
    rhs: GLLogicalAndExprNode

  GLInclusiveOrExprNode* = object of GLLogicalAndExprNode
  GLChainLogicalAndExprNode* {.final.} = object of GLLogicalAndExprNode
    lhs: GLLogicalAndExprNode
    rhs: GLInclusiveOrExprNode

  GLExclusiveOrExprNode* = object of GLInclusiveOrExprNode
  GLChainInclusiveOrExprNode* {.final.} = object of GLInclusiveOrExprNode
    lhs: GLInclusiveOrExprNode
    rhs: GLExclusiveOrExprNode

  GLAndExprNode* = object of GLExclusiveOrExprNode
  GLChainExclusiveOrExprNode* {.final.} = object of GLExclusiveOrExprNode
    lhs: GLExclusiveOrExprNode
    rhs: GLAndExprNode

  GLEqExprNode* = object of GLAndExprNode
  GLChainAndExprNode* {.final.} = object of GLAndExprNode
    lhs: GLAndExprNode
    rhs: GLEqExprNode

  GLRelExprNode* = object of GLEqExprNode
  GLChainEqExprNode* {.final.} = object of GLEqExprNode
    opKind: GLEqOpKind
    lhs: GLEqExprNode
    rhs: GLRelExprNode

  GLShiftExprNode* = object of GLRelExprNode
  GLChainRelExprNode* {.final.} = object of GLRelExprNode
    opKind: GLRelOpKind
    lhs: GLRelExprNode
    rhs: GLShiftExprNode

  GLAddExprNode* = object of GLShiftExprNode
  GLChainShiftExprNode* {.final.} = object of GLShiftExprNode
    opKind: GLShiftOpKind
    lhs: GLShiftExprNode
    rhs: GLAddExprNode

  GLMulExprNode* = object of GLAddExprNode
  GLChainAddExprNode* {.final.} = object of GLAddExprNode
    opKind: GLAddOpKind
    lhs: GLAddExprNode
    rhs: GLMulExprNode

  GLUnaryExprNode* = object of GLMulExprNode
  GLChainMulExprNode* {.final.} = object of GLMulExprNode
    opKind: GLMulOpKind
    lhs: GLMulExprNode
    rhs: GLUnaryExprNode

  GLPostfixExprNode* = object of GLUnaryExprNode
  GLChainUnaryExprNode* {.final.} = object of GLUnaryExprNode
    opKind: GLUnaryOpKind
    expr: GLUnaryExprNode

  GLPrimaryExprNode* = object of GLPostfixExprNode
  GLBracketExprNode* {.final.} = object of GLPostfixExprNode
    lhs: GLPostfixExprNode
    rhs: GLIntExprNode

  GLDotExprNode* {.final.} = object of GLPostfixExprNode
    lhs: GLPostfixExprNode
    rhs: GLIdentNode # TODO: Make a field selection node

  GLCallNode* = object of GLPostfixExprNode
    funcIdent: GLFuncIdentNode
    argsHead: GLArgNode

  GLChainPostfixExprNode* = object of GLPostfixExprNode
    opKind: GLPostfixOpKind
    expr: GLPostfixExprNode

  GLIdentNode* = object of GLPrimaryExprNode
    name: string

  GLConstNode* = object of GLPrimaryExprNode
  GLParExprNode* {.final.} = object of GLPrimaryExprNode
    expr: GLExprNode

  GLVarIdentNode* {.final.} = object of GLIdentNode
  GLFuncIdentNode* = object of GLIdentNode
  GLTypeIdentNode* = object of GLFuncIdentNode

  GLArgNode* = object of GLExprNode

  GLChainArgNode* {.final.} = object of GLArgNode
    lhs: GLArgNode
    rhs: GLAsgnExprNode

  GLLitNode* = object of GLConstNode
    case litKind: GLLitKind
    of glBool:
      boolVal: Bool
    of glInt:
      intVal: Int
    of glUInt:
      uIntVal: UInt
    of glFloat:
      floatVal: Float
    of glDouble:
      doubleVal: Double
