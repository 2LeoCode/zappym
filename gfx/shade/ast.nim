import primitives, std/[strformat, tables, sequtils]

type
  GLIdent* = object
    id: uint
    name: string

  GLNodeKind* = enum
    glkEmpty
    glkIdent
    glkBoolLit
    glkIntLit
    glkUIntLit
    glkFloatLit
    glkDoubleLit
    glkStmtList
    glkQualList
    glkVarDefs
    glkAsgnExpr
    glkPrefix
    glkPostfix
    glkInfix
    glkIndex
    glkDotExpr
    glkCall
    glkArgList
    glkFuncDef
    glkStructDef
    glkTernary
    glkIfStmt
    glkElifBranch
    glkElseBranch
    glkSwitchStmt
    glkCaseBranch
    glkDefaultBranch
    glkForStmt
    glkWhileStmt
    glkDoWhileStmt
    glkInitList
    glkBlockStmt
    glkStorageBlockDef
    glkPPVersion
    glkPPLine
    glkPPDef
    glkPPUndef
    glkPPIf
    glkPPElifDef
    glkPPElif
    glkPPElse
    glkPPPragma
    glkPPGlue
    glkPPStr
    glkPPTok
    glkPPDefined
    glkPPParams

  GLNode* = object
    case kind*: GLNodeKind
    of glkIdent:
      identVal: GLIdent
    of glkBoolLit:
      boolVal*: Bool
    of glkIntLit:
      intVal*: Int
    of glkUIntLit:
      uintVal*: UInt
    of glkFloatLit:
      floatVal*: Float
    of glkDoubleLit:
      doubleVal*: Double
    of glkPPTok:
      pptokText*: string
    else:
      children*: seq[GLNode]

const glkLiterals* = {glkBoolLit, glkIntLit, glkUIntLit, glkFloatLit, glkDoubleLit}
const glkInlineExpr* =
  glkLiterals + {
    glkAsgnExpr, glkPrefix, glkPostfix, glkInfix, glkIndex, glkDotExpr, glkCall,
    glkTernary,
  }
const glkPPExpr* = {glkPPGlue, glkPPStr, glkPPTok}

using
  kind: GLNodeKind
  node: GLNode
  nodes, children: varargs[GLNode]
  name, text: string
  names: varargs[string]

proc `$`(kind): string {.memo.} =
  self.repr.removePrefix("glk")

proc getIdent(name): GLIdent {.memo.} =
  var id {.global.} = 0u
  defer:
    inc id

  GLIdent(id: id, name: name)

func glNode*(kind): GLNode =
  glTree(kind)

func expectKind*(
    self, kind, msg = fmt "{astToStr(self)} is {self.kind}, but expected {kind}"
) =
  self.expectKind({kind}, msg)

func expectKind*(
    self: GLNode,
    kinds: set[GLNodeKind],
    msg = fmt "{astToStr(self)} is {self.kind}, but expected either {kinds.mapIt($it).join(\" or \")}",
) =
  assert(self in kinds, msg)

func add*(self: var GLNode, nodes) =
  when nodes.varargsLen != 0:
    self.expectKind(domain(GLNodeKind) - glkLiterals - {glkIdent})
    self.children.add(nodes)

template add*(self: var GLNode, nodes: iterable[GLNode]) =
  self.add(nodes.toSeq)

template glTree*(kind: GLNodeKind, children: iterable[GLNode]): GLNode =
  result = GLNode(kind: kind)
  result.add(children)

func glTree*(kind, children): GLNode =
  result = GLNode(kind: kind)
  result.add(children)

func glEmpty*(): GLNode =
  glTree(glkEmpty)

proc glIdent*(name): GLNode =
  GLNode(kind: glkIdent, identVal: getIdent(name))

proc ensureIdent(name): GLNode =
  glIdent(name)

func ensureIdent(node): lent GLNode =
  node.expectKind(glkIdent)
  node

func glLit*(value: Bool): GLNode =
  GLNode(kind: glkBoolLit, boolVal: value)

func glLit*(value: Int): GLNode =
  GLNode(kind: glkIntLit, intVal: value)

func glLit*(value: UInt): GLNode =
  GLNode(kind: glkUIntLit, uintVal: value)

func glLit*(value: Float): GLNode =
  GLNode(kind: glkFloatLit, floatVal: value)

func glLit*(value: Double): GLNode =
  GLNode(kind: glkDoubleLit, doubleVal: value)

func ensureLit(value: Primitive) =
  glLit(value)

func ensureLit(node): lent GLNode =
  node.expectKind(glkLiterals)
  node

iterator stmtListFlatten(nodes): GLNode =
  for child in chilren:
    if child.kind == glkStmtList:
      yield glStmtListFlatten(child.children)
    else:
      yield child

func glStmtList*(children): GLNode =
  glTree(glkStmtList, stmtListFlatten(children))

template glStmtList*(children: iterable): GLNode =
  glStmtList(children.toSeq)

    # glkAsgnExpr
    # glkPrefix
    # glkPostfix
    # glkInfix
    # glkIndex
    # glkDotExpr
    # glkCall
    # glkArgList
    # glkFuncDef
    # glkStruct

func glQualList*(qualifiers: varargs[GLNode]): GLNode =
  result = glTree(glkQualList)
  when not defined(danger):
    for qual in qualifiers:
      qual.expectKind {glkIdent, glkCall}
  result.add(qualifiers)

proc glQualList*(qualifiers: varargs[string]): GLNode =
  glQualList(qualifiers.map(glIdent))

template glQualList*(qualifiers: iterable[string or GLNode]): GLNode =
  glQualList(qualifiers.toSeq)

proc ensureQualList(qualifiers: openArray[string or GLNode]): GLNode =
  glQualList(qualifiers)

func ensureQualList(node): lent GLNode =
  node.expectKind(glkQualList)
  node

func glVarDefs*(
    typ: string or GLNode,
    qualifiers: openArray[string or GLNode] or GLNode,
    varNames: varargs[string or GLNode],
): GLNode =
  glTree(
    glkVarDefs, ensureIdent(typ), ensureQualList(qualifiers), varNames.map(ensureIdent)
  )

proc glPPVersion*(version: Uint or GLNode, profileOpt: string or GLNode): GLNode =
  glTree(glkPPVersion, ensureLit(version), ensureIdent(profileOpt))

func glPPLine*(lineNo: Uint or GLNode): GLNode =
  glTree(glkPPLine, ensureLit(lineNo))

func glPPTok*(text): GLNode =
  GLNode(kind: glkPPTok, pptokText: text)

func glPPGlue*(lhs, rhs: GLNode): GLNode =
  lhs.expectKind {glkPPTok, glkPPGlue}
  rhs.expectKind {glkPPTok, glkPPGlue}
  glTree(glkPPGlue, lhsPPExpr, rhsPPExpr)

func glPPStr*(tok: GLNode): GLNode =
  tok.expectKind {glkPPTok}
  glTree(glkPPStr, tok)

proc glPPParams*(params: varargs[string or GLNode]): GLNode =
  let paramIdents = params.map(ensureIdent)
  glTree(glkPPParams, paramIdents)

proc ensurePPParams(params: openArray[string or GLNode]) =
  glPPParams(params)

proc ensurePPParams(node): GLNode =
  node.expectKind {glkPPParams, glkEmpty}
  node

proc glPPDef*(
    name: string or GLNode, params: openArray[string or GLNode] or GLNode, body: GLNode
): GLNode =
  body.expectKind(glkPPExpr)
  glPPDef(ensureIdent(name), ensurePPParams(params), body)

func glPPUndef*(name: string or GLNode) =
  glTree(glkPPUndef, ensureIdent(name))

func glPPIf*(elifBranches: openArray[GLNode], elseBranch: GLNode = glEmpty()): GLNode =
  when not defined(danger):
    elifBranches.applyIt(it.expectKind(glkPPElif))
  result = glTree(glkPPIf, elifBranches)
  if elseBranch.kind != glkEmpty:
    elseBranch.expectKind(glkPPElse)
    result.add(elseBranch)

func glPPIfdef*(
    elifDefBranch: GLNode,
    elifBranches: openArray[GLNode],
    elseBranch: GLNode = glEmpty(),
): GLNode =
  elifDefBranch.expectKind(glkPPElifDef)
  when not defined(danger):
    elifBranches.applyIt(it.expectKind(glkPPElif))
  result = glTree.unpackVarargs(glkPPIf, defBranch, elifBranches)
  if elseBranch.kind != glkEmpty:
    elseBranch.expectKind(glkPPElse)
    result.add(elseBranch)

func glPPElif*(pred: GLNode, body: GLNode): GLNode =
  pred.expectKind(glkInlineExpr)
  glTree(glkPPElif, pred, glStmtList(body))

func glPPElse*(body: GLNode): GLNode =
  glTree(glkPPElse, glStmtList(body))
