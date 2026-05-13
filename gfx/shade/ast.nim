import primitives, utils, std/[strformat, tables, sequtils, strutils, sugar]

type
  Ident = object
    id: uint
    name: string

  NodeKind* = enum
    nkEmpty
    nkIdent
    nkBoolLit
    nkIntLit
    nkUIntLit
    nkFloatLit
    nkDoubleLit
    nkStmtList
    nkQualList
    nkVarDefs
    nkPrefix
    nkPostfix
    nkInfix
    nkIndex
    nkDotExpr
    nkCall
    nkFuncDef
    nkParams
    nkReturn
    nkBreak
    nkContinue
    nkStructDef
    nkTernary
    nkIfStmt
    nkElifBranch
    nkElseBranch
    nkSwitchStmt
    nkCaseBranch
    nkDefaultBranch
    nkForStmt
    nkWhileStmt
    nkDoWhileStmt
    nkInitList
    nkBlockStmt
    nkStorageBlockDef
    nkPPVersion
    nkPPLine
    nkPPDef
    nkPPUndef
    nkPPIf
    nkPPElifDef
    nkPPElif
    nkPPElse
    nkPPPragma
    nkPPGlue
    nkPPStr
    nkPPTok
    nkPPDefined
    nkPPParams

  Node* = object
    case kind*: NodeKind
    of nkIdent:
      identVal: Ident
    of nkBoolLit:
      boolVal*: Bool
    of nkIntLit:
      intVal*: Int
    of nkUIntLit:
      uintVal*: UInt
    of nkFloatLit:
      floatVal*: Float
    of nkDoubleLit:
      doubleVal*: Double
    of nkPPTok:
      pptokText*: string
    of nkEmpty, nkBreak, nkContinue:
      discard
    else:
      children*: seq[Node]

generateStrictUnionOps Node

type LitNode* = BoolLitNode or IntLitNode or FloatLitNode or DoubleLitNode
type ExprNode* =
  LitNode or PrefixNode or PostfixNode or InfixNode or IndexNode or DotExprNode or
  CallNode or TernaryNode or IdentNode

type PPExprNode* = PPGlueNode or PPStrNode or PPTokNode

const nkLiterals* = {nkBoolLit, nkIntLit, nkUIntLit, nkFloatLit, nkDoubleLit}
const nkExpr* =
  nkLiterals +
  {nkPrefix, nkPostfix, nkInfix, nkIndex, nkDotExpr, nkCall, nkTernary, nkIdent}
const nkPPExpr* = {nkPPGlue, nkPPStr, nkPPTok}

using
  kind: NodeKind
  node: Node
  nodes, children: varargs[Node]
  name, text: string
  names: varargs[string]

proc `$`(kind: NodeKind): string {.memo.} =
  kind.repr.dup(removePrefix("nk"))

proc getIdent(name): Ident {.memo.} =
  var id {.global.} = 0u
  defer:
    inc id

  Ident(id: id, name: name)

func expectKind*(
    self: Node,
    kinds: set[NodeKind],
    msg = fmt "{astToStr(self)} is {self.kind}, but expected either {kinds.mapIt($it).join(\" or \")}",
) =
  assert(self.kind in kinds, msg)

func expectKind*(
    self: Node, kind; msg = fmt "{astToStr(self)} is {self.kind}, but expected {kind}"
) =
  self.expectKind({kind}, msg)

proc add*(self: var Node, nodes) =
  when nodes.varargsLen != 0:
    self.expectKind(domain(NodeKind) - nkLiterals - {nkIdent})
    self.children.add(nodes)

template add*(self: var Node, nodes: iterable[Node]) =
  for node in nodes:
    self.children.add(node)

template initTree*(kind: NodeKind, children: iterable[Node]): Node =
  result = Node(kind: kind)
  result.add(children)

proc initTree*(kind, children): Node =
  result = Node(kind: kind)
  result.add(children)

func initNode*(kind): Node =
  Node(kind: kind)

proc initIdentNode*(name): IdentNode =
  initIdentNode(getIdent(name))

proc initIdentNode*(other: IdentNode): IdentNode =
  other

func initLitNode*(value: Bool): BoolLitNode =
  initBoolLitNode(value)

func initLitNode*(value: Int): IntLitNode =
  initIntLitNode(value)

func initLitNode*(value: UInt): UIntLitNode =
  initUIntLitNode(value)

func initLitNode*(value: Float): FloatLitNode =
  initFloatLitNode(value)

func initLitNode*(value: Double): DoubleLitNode =
  initDoubleLitNode(value)

func initLitNode*[T: LitNode](other: T): T =
  other

func initStmtListNode*(children: varargs[Node]): StmtListNode

proc flattened*(self: StmtListNode): StmtListNode =
  result = initStmtListNode()
  for node in self.children:
    var nodes = @[node]
    node.ifStmtListNode:
      nodes = node.flattened.children
    cast[ptr Node](addr result)[].add(nodes)

proc flatten*(self: var StmtListNode) =
  self = self.flattened

func initStmtListNode*(children: varargs[Node]): StmtListNode =
  initStmtListNode(children.toSeq)

template initStmtListNode*(children: iterable[Node]): StmtListNode =
  initStmtListNode(children.toSeq)

func initQualNode*(qual: string or IdentNode): IdentNode =
  initIdentNode(qual)

func initQualNode*(qual: CallNode): CallNode =
  qual

func initQualListNode*(qualifiers: varargs[Node, initQualNode]): QualListNode =
  initQualListNode(qualifiers.toSeq)

template initQualListNode*(qualifiers: iterable[typed]): QualListNode =
  result = initQualListNode(@[])
  for qual in qualifiers:
    result.add(initQualNode(qual))

func initQualListNode*(other: QualListNode): QualListNode =
  other

proc initVarDefsNode*(
    typeVal: string or IdentNode,
    qualifiers: QualListNode,
    varNames: varargs[Node, initIdentNode],
): VarDefsNode =
  initVarDefsNode(
    @[initIdentNode(typeVal).toNode, qualifiers] & varNames & @[initEmptyNode().toNode]
  )

proc initVarDefsNode*(
    typeVal: string or IdentNode,
    qualifiers: QualListNode,
    varNames: openArray[string or IdentNode],
    val: ExprNode,
): VarDefsNode =
  initVarDefsNode(
    @[initIdentNode(typeVal).toNode, qualifiers] &
      varNames.map((n) => initIdentNode(n).toNode) & @[val.toNode]
  )

proc initExprNode*(other: ExprNode): ExprNode =
  other

proc initPrefixNode*(op: string or IdentNode, expr: ExprNode): PrefixNode =
  initPrefixNode(@[initIdentNode(op).toNode, expr])

proc initPostfixNode*(expr: ExprNode, op: string or IdentNode): PostfixNode =
  initPostfixNode(@[expr.toNode, initIdentNode(op)])

proc initInfixNode*(lhs: ExprNode, op: string or IdentNode, rhs: ExprNode): InfixNode =
  initInfixNode(@[lhs.toNode, initIdentNode(op), rhs])

proc initIndexNode*(expr, id: ExprNode, ids: varargs[ExprNode]): IndexNode =
  initIndexNode:
    if ids.len == 0:
      @[expr.toNode, id]
    else:
      @[expr.toNode, initIndexNode(id, ids[0], ids[1 .. ^1])]

proc initDotExprNode*(
    expr: ExprNode, field: string or IdentNode, fields: varargs[Node, initIdentNode]
): DotExprNode =
  initDotExprNode(@[expr.toNode, initIdentNode(field)] & fields)

proc initCallNode*(
    fn: string or IdentNode, args: varargs[Node, initExprNode]
): CallNode =
  initCallNode(@[fn.toNode] & args)

func initParamsNode*(defs: varargs[VarDefsNode]) =
  initParamsNode(defs.map(toNode).toSeq)

proc initFuncDefNode*(
    name: string or IdentNode,
    retType: IdentNode,
    params: openArray[VarDefsNode] or ParamsNode,
    body: varargs[Node] or StmtListNode,
): FuncDefNode =
  initFuncDefsNode(
    @[
      initIdentNode(name).toNode,
      retType,
      initParamsNode(params),
      initStmtListNode(body),
    ]
  )

proc initStructDefNode*(
    name: string or IdentNode, fields: varargs[VarDefsNode]
): StructDefNode =
  initStructDefNode(@[initIdentNode(name).toNode] & fields.map(toNode).toSeq)

func initIfStmtNode*(elifBranches: varargs[ElifBranchNode]): IfStmtNode =
  initIfStmtNode(elifBranches.map(toNode).toSeq & @[initEmptyNode().toNode])

func initIfStmtNode*(
    elifBranches: openArray[ElifBranchNode], elseBranch: ElseBranchNode
): IfStmtNode =
  initIfStmtNode(elifBranches.map(toNode).toSeq & @[elseBranch.toNode])

func initElifBranchNode*(
    pred: ExprNode, body: varargs[Node] or StmtListNode
): ElifBranchNode =
  initElifBranchNode(@[pred.toNode, initStmtListNode(body)])

func initElseBranchNode*(body: varargs[Node] or StmtListNode): ElseBranchNode =
  initElseBranchNode(@[initStmtListNode(body).toNode])

func initReturnNode*(): ReturnNode =
  initReturnNode(@[initEmptyNode().toNode])

func initReturnNode*(val: ExprNode): ReturnNode =
  initReturnNode(@[val.toNode])

func initSwitchStmtNode*(
    val: ExprNode, caseBranches: varargs[CaseBranchNode]
): SwitchStmtNode =
  initSwitchStmtNode(
    @[val.toNode] & caseBranches.map(toNode).toSeq & @[initEmptyNode().toNode]
  )

func initSwitchStmtNode*(
    val: ExprNode,
    caseBranches: openArray[CaseBranchNode],
    defaultBranch: DefaultBranchNode,
): SwitchStmtNode =
  initSwitchStmtNode(
    @[val.toNode] & caseBranches.map(toNode).toSeq & @[defaultBranch.toNode]
  )

func initCaseBranchNode*(
    valRef: ExprNode, body: varargs[Node] or StmtListNode
): CaseBranchNode =
  initCaseBranchNode(@[valRef.toNode, initStmtListNode(body)])

func initDefaultBranchNode*(body: varargs[Node] or StmtListNode): DefaultBranchNode =
  initDefaultBranchNode(@[initStmtListNode(body).toNode])

func initForStmtNode*(
    initExpr: VarDefsNode,
    cond: ExprNode,
    updateExpr: Node,
    body: varargs[Node] or StmtListNode,
): ForStmtNode =
  initForStmtNode(@[initExpr.toNode, cond, updateExpr, initStmtListNode(body)])

func initWhileStmtNode*(
    cond: ExprNode, body: varargs[Node] or StmtListNode
): WhileStmtNode =
  initWhileStmtNode(@[cond.toNode, initStmtListNode(body)])

func initDoWhileStmtNode*(
    body: openArray[Node] or StmtListNode, cond: ExprNode
): DoWhileStmtNode =
  initDoWhileStmtNode(@[initStmtListNode(body).toNode, cond])

func initBlockStmtNode*(body: varargs[Node] or StmtListNode): BlockStmtNode =
  initBlockStmtNode(@[initStmtListNode(body).toNode])

proc initStorageBlockInstanceNode*(name: string or IdentNode): IdentNode =
  initIdentNode(name)

proc initStorageBlockInstanceNode*(idx: IndexNode): IndexNode =
  idx

proc initStorageBlockDefNode*(
    name: string or IdentNode,
    instance: string or IdentNode or IndexNode,
    qualifiers: QualListNode,
    fields: varargs[VarDefsNode],
): StorageBlockDefNode =
  initStorageBlockDefNode(
    @[initIdentNode(name).toNode, initStorageBlockInstanceNode(instance), qualifiers] &
      fields.map(toNode).toSeq
  )

func initPPVersionNode*(
    version: UInt or UIntLitNode, profileOpt: string or IdentNode
): PPVersionNode =
  initPPVersionNode(@[initLitNode(version).toNode, initIdentNode(profileOpt)])

func initPPLineNode*(lineNo: Uint or Node): PPLineNode =
  initPPLineNode(@[initLitNode(lineNo).toNode])

func initPPGlueNode*(
    lhs: PPTokNode or PPGlueNode, rhs: PPTokNode or PPGlueNode
): PPGlueNode =
  initPPGlueNode(@[lhs.toNode, rhs])

proc initPPStrNode*(ident: IdentNode): PPStrNode =
  initPPStrNode(@[ident.toNode])

proc initPPParamsNode*(params: varargs[Node, initIdentNode]): PPParamsNode =
  initPPParamsNode(params.map(toNode).toSeq)

func initPPParamsNode*(other: PPParamsNode): PPParamsNode =
  other

func initPPExprNode*(other: PPExprNode): PPExprNode =
  expr

proc initPPDefNode*(
    name: string or IdentNode,
    params: openArray[string or IdentNode] or PPParamsNode,
    body: varargs[Node, initPPExprNode],
): PPDefNode =
  initPPDefNode(@[initIdentNode(name).toNode, initPPParamsNode(params)] & body)

proc initPPDefNode*(
    name: string or IdentNode, body: varargs[Node, initPPExprNode]
): PPDefNode =
  initPPDefNode(@[initIdentNode(name).toNode, initEmptyNode()] & body)

proc initPPUndefNode*(name: string or IdentNode): PPUndefNode =
  initPPUndefNode(@[initIdentNode(name).toNode])

proc initPPElifDefNode*(
    name: string or IdentNode, body: varargs[Node, initPPExprNode]
): PPElifDefNode =
  initPPElifDefNode(@[initIdentNode(name).toNode] & body)

func initPPElifNode*(
    pred: InlineExprNode, body: varargs[Node, initPPExprNode]
): PPElifNode =
  initPPElifNode(@[pred.toNode] & body)

func initPPIfNode*(
    elifBranches: openArray[PPElifNode], elseBranch: PPElseNode
): PPIfNode =
  initPPIfNode(elifBranches.map(toNode).toSeq & @[elseBranch.toNode])

func initPPIfNode*(elifBranches: varargs[PPElifNode, initPPElifNode]): PPIfNode =
  initPPIfNode(elifBranches.map(toNode).toSeq)

func initPPIfNode*(
    elifDefBranch: PPElifDefNode,
    elifBranches: openArray[PPElifNode],
    elseBranch: PPElseNode,
): PPIfNode =
  initPPIfNode(
    @[elifDefBranch.toNode] & elifBranches.map(toNode).toSeq & @[elseBranch.toNode]
  )

func initPPIfNode*(
    elifDefBranch: PPElifDefNode, elifBranches: varargs[Node, initPPElifNode]
): PPIfNode =
  initPPIfNode(@[elifDefBranch.toNode] & elifBranches)

func initPPElseNode*(body: varargs[Node, initPPExprNode]): PPElseNode =
  initPPElseNode(@[body.toNode])

func initPPPragmaNode*(pragmas: varargs[Node, initPPExprNode]): PPPragmaNode =
  initPPPragmaNode(pragmas.toSeq)
