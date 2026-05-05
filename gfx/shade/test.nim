import std/[macros, with, tables, hashes, sequtils, sugar, wrapnils]

macro dumpTyped(bl: typed): NimNode =
  echo bl.treeRepr

dumpTyped:
  a = 3

# dumpTree:
#   const (foo, bar) = (3, 4)
# const fr = 4
# # hello
# using foo: int
# import strutils as sty
# for i, j in (0..10).toSeq.pairs():
#   echo i
# let v = 1 + (2 - 3)
# let foo = @[1]
# let bar = foo[1..^1]
# let (a, b): (int, int) = (1, 2)
#
# proc someFunc[T: tuple](foo: T, cb: proc (p: int): int) = echo cb(foo)
#
# let lambda = func (p: sink int): int = discard
#
# type
#   FooObj = object
#     a: int
#     b: string
#
#   FooTuple = tuple[a: int, b: string]
#   FooDistinct = distinct int
#   FooEnum = enum
#     feFoo
#     feBar
#     feBaz
#
#   FooAlias[T] = FooObj
#   FooRefObj = ref object
#     a: int
#     b: string
#
#   FooConcept =
#     concept type X, Y
#         proc foo(arg: X, arg2: Y): int
#
# proc `==`(lhs: FooObj, rhs: FooObj): bool = lhs.a == rhs.a
#
# let _ = feFoo
#
# let inst = FooObj()
# let prop = inst.a

type ScopedNode = object
  node: NimNode
  scope: uint

using
  node: NimNode
  symbolKind: NimSymKind
  freshSymbols: ref Table[string, seq[ScopedNode]]
  scope: uint

func toScopedNode(node, scope): ScopedNode =
  ScopedNode(node: node, scope: scope)

proc withFreshSymbolsRoot(
    node;
    freshSymbols = newTable[string, seq[ScopedNode]](),
    scope = 0u,
    parent: NimNode = nil,
    grandParent: NimNode = nil,
): NimNode =
  case node.kind
  of nnkIdent, nnkLiterals, nnkEmpty, nnkContinueStmt, nnkTupleClassTy, nnkCommentStmt,
      nnkNone, nnkNilRodNode, nnkOpenSym:
    copyNimNode(node)
  of nnkSym:
    let symKind =
      case ?.parent.kind
      of nnkProcDef, nnkLambda, nnkDo:
        nskProc
      of nnkFuncDef:
        nskFunc
      of nnkIteratorDef:
        nskIterator
      of nnkConverterDef:
        nskConverter
      of nnkMethodDef:
        nskMethod
      of nnkTemplateDef:
        nskTemplate
      of nnkMacroDef:
        nskMacro
      of nnkBlockStmt, nnkBlockExpr:
        nskLabel
      of nnkForStmt, nnkParForStmt:
        nskVar
      of nnkConstDef:
        nskConst
      of nnkIdentDefs:
        case ?.grandParent.kind
        of nnkVarSection:
          nskVar
        of nnkLetSection:
          nskLet
        of nnkGenericParams:
          nskGenericParam
        of nnkFormalParams:
          nskParam
        else:
          error("Ill-formed AST")
      of nnkImportStmt:
        nskModule
      else:
        nskUnknown
    if symKind == nskUnknown:
      # already defined symbol
      let choice = freshSymbols.getOrDefault(signatureHash(node), @[])
      if choice.len == 0:
        copyNimNode(node)
      else:
        choice[^1].node
    else:
      # new symbol
      let freshSymbol = genSym(symKind, node.strVal)
      let hash = signatureHash(node)

      freshSymbols.mgetOrPut(hash, @[]).add result.toScopedNode(scope)
      freshSymbol
  of nnkStmtList, nnkStmtListExpr, nnkPar, nnkTypeSection, nnkDotCall, nnkCommand,
      nnkCall, nnkCallStrLit, nnkInfix, nnkPrefix, nnkPostfix, nnkExprEqExpr,
      nnkExprColonExpr, nnkVarTuple, nnkTupleConstr, nnkObjConstr, nnkTableConstr,
      nnkCurly, nnkCurlyExpr, nnkBracket, nnkBracketExpr, nnkPragmaExpr, nnkPragmaBlock,
      nnkPragma, nnkRange, nnkDotExpr, nnkDerefExpr, nnkElifExpr, nnkElifBranch,
      nnkOfBranch, nnkElseExpr, nnkElse, nnkAccQuoted, nnkCast, nnkAsgn, nnkSinkAsgn,
      nnkFastAsgn, nnkOfInherit, nnkAsmStmt, nnkBindStmt, nnkMixinStmt, nnkYieldStmt,
      nnkDefer, nnkRaiseStmt, nnkReturnStmt, nnkBreakStmt, nnkDiscardStmt,
      nnkImportStmt, nnkFromStmt, nnkImportExceptStmt, nnkIncludeStmt, nnkExportStmt,
      nnkExportExceptStmt, nnkUsingStmt, nnkIdentDefs, nnkTypeOfExpr, nnkObjectTy,
      nnkEnumTy, nnkTupleTy, nnkDistinctTy, nnkStaticTy, nnkVarTy, nnkProcTy, nnkRefTy,
      nnkOutTy, nnkConstTy, nnkPtrTy, nnkIteratorTy, nnkTypeClassTy, nnkRecList,
      nnkRecCase, nnkRecWhen, nnkArgList, nnkHiddenCallConv, nnkHiddenStdConv,
      nnkHiddenAddr, nnkHiddenDeref, nnkClosedSymChoice, nnkOpenSymChoice,
      nnkCheckedFieldExpr, nnkType, nnkComesFrom, nnkBind, nnkHiddenSubConv, nnkConv,
      nnkAddr, nnkObjDownConv, nnkObjUpConv, nnkChckRangeF, nnkChckRange64,
      nnkChckRange, nnkStringToCString, nnkCStringToString, nnkImportAs,
      nnkStmtListType, nnkWith, nnkWithout, nnkEnumFieldDef, nnkPattern, nnkGotoState,
      nnkState, nnkBreakState, nnkModuleRef, nnkReplayAction, nnkBlockType, nnkError,
      nnkGenericParams, nnkFormalParams, nnkVarSection, nnkLetSection, nnkConstSection,
      nnkConstDef, nnkTypeDef:
    let tmp = copyNimNode(node)
    for child in node:
      tmp.add child.withFreshSymbolsRoot(freshSymbols, scope, node, parent)
    tmp
  of nnkIfStmt, nnkIfExpr, nnkWhenStmt, nnkCaseStmt, nnkWhileStmt, nnkBlockStmt,
      nnkBlockExpr, nnkLambda, nnkFuncDef, nnkProcDef, nnkIteratorDef, nnkConverterDef,
      nnkMethodDef, nnkTemplateDef, nnkMacroDef, nnkClosure, nnkForStmt, nnkParForStmt,
      nnkTryStmt, nnkHiddenTryStmt, nnkExceptBranch, nnkFinally, nnkDo, nnkStaticStmt,
      nnkStaticExpr:
    let tmp = copyNimNode(node)
    for child in node:
      tmp.add child.withFreshSymbolsRoot(freshSymbols, succ scope, node, parent)
    for signature, choice in freshSymbols.mpairs:
      if choice[^1].scope == succ scope:
        choice.setLen(choice.len - 1)
        if choice.len == 0:
          freshSymbols.del signature
    tmp

proc withFreshSymbols*(node): NimNode =
  node.withFreshSymbolsRoot

proc foo(a: var int) =
  echo "foo: ", a
  a += 2

proc bar(a: int, b: int) =
  echo "bar: ", a, ' ', b

macro mergeBlocks(bl1, bl2: typed): untyped =
  echo bl1.getImpl.treeRepr
  newLit 1

let foo = mergeBlocks(foo, bar)

# echo toUntyped(1)

# macro test1(): untyped =
#   let foo = ident "foo"
#   let t = newTree(nnkHiddenAddr, foo)
#   let bar = newTree(nnkCheckedFieldExpr)
#
#   quote:
#     var `foo`: int = 5
#     var i = `t`
#     echo i[]
#
# test1()

#[
  node kinds

  nnkNone = No kind
  nnkEmpty = Empty
  nnkIdent  = Identifier
  nnkLiterals (nnkCharLit, nnkIntLit,
  nnkInt8Lit, nnkInt16Lit, nnkInt32Lit, nnkInt64Lit, nnkUIntLit, nnkUInt8Lit,
  nnkUInt16Lit, nnkUInt32Lit, nnkUInt64Lit, nnkFloatLit, nnkFloat32Lit,
  nnkFloat64Lit, nnkFloat128Lit, nnkStrLit, nnkRStrLit, nnkTripleStrLit,
  nnkNilLit) = Literal
  nnkDotCall, nnkCommand, nnkCall, nnkCallStrLit = Function invocation
  nnkInfix, nnkPrefix, nnkPostfix = Operator invocation
  nnkExprEqExpr = named argument
  nnkExprColonExpr = constructor named argument
  nnkIdentDefs, nnkConstDef,  nnkTypeDef = Variable / constant / type definition
  nnkVarTuple = Tuple variable definition
  nnkPar = Expression parentheses
  nnkObjConstr, nnkTableConstr, nnkTupleConstr = Object / table / tuple constructor
  nnkCurly = Curly braces block
  nnkCurlyExpr = Curly braces as a suffix
  nnkBracket = Bracket block
  nnkBracketExpr = Bracket as a suffix
  nnkPragmaExpr, nnkPragmaBlock = Pragma expression / standalone block
  nnkPragma = Pragma entry
  nnkRange = Range expression
  nnkDotExpr = Property access
  nnkDerefExpr = Deref (empty bracket expr)
  nnkIfStmt, nnkIfExpr = If statement / expression
  nnkWhenStmt, nnkWhenExpr = when statement / expression
  nnkCaseStmt = case statement
  nnkElifBranch, nnkElifExpr = Elif branch / expression
  nnkOfBranch = case .. of branch
  nnkElseBranch, nnkElseExpr = Else branch / expression
  nnkForStmt, nnkParForStmt, nnkWhileStmt = for loop / parallel for loop / while loop
  nnkLambda = Lambda function
  nnkDo = Do function
  nnkAccQuoted = Quoted identifier
  nnkCast = Cast expression
  nnkAsgn, nnkSinkAsgn, nnkFastAsgn = assignment / sink assignment / fast assignment (fast asgn gets inserted by the compiler for optimization but can also be forced by a macro)
  nnkGenericParams, nnkFormalParams = function generic / formal parameters
  nnkOfInherit = inherited objects of object type
  nnkProcDef, nnkMethodDef, nnkConverterDef, nnkMacroDef, nnkTemplateDef, nnkIteratorDef, nnkFuncDef = function definitions
  nnkTryStmt , nnkTryExpr = try statement / expression
  nnkExceptBranch = try .. except branch
  nnkFinally = try .. finally block
  nnkAsmStmt = asm statement
  nnkTypeSection, nnkVarSection, nnkLetSection, nnkConstSection = type / var / let / const section
  nnkStaticStmt, nnkStaticExpr, nnkStaticTy = Static statement /expression / type
  nnkBind, nnkBindStmt = bind single line / bind statement (roughly)
  nnkMixin, nnkMixinStmt = mixin single line / mixin statememnt (roughly)
  nnkYieldStmt = yield statement
  nnkDefer = defer statement
  nnkRaiseStmt = raise statmement
  nnkReturnStmt = return statment
  nnkBreakStmt = break statement
  nnkContinueStmt = continue statement
  nnkBlockStmt, nnkBlockExpr = block statement / expression
  nnkDiscardStmt = discard statement
  nnkStmtList, nnkStmtListExpr, nnkStmtListType = statement list, statement list returning expr, statement list of type declarations
  nnkImportStmt, nnkFromStmt, nnkImportAs,nnkImportExceptStmt = import statement / from .. import / import .. as / import all except
  nnkIncludeStmt = include statement
  nnkExportStmt, nnkExportExceptStmt = export statement / export all except
  nnkUsingStmt = using stmt
  nnkTypeOfExpr = typeof
  nnkObjectTy = object type definition
  nnkTypeClassTy = type constrain
  nnkTupleTy, nnkTupleClassTy = tuple type / tuple constarain
  nnkRecList = record list (object fields for example)
  nnkRecCase, nnkRecWhen = case statement / when statement inside object type
  nnkRefTy, nnkPtrTy, nnkVarTy, nnkConstTy, nnkOutTy, nnkDistinctTy, nnkProcTy, nnkIteratorTy, nnkEnumTy = ref, ptr, var, const, out, distinct, iterator, enum type
  nnkEnumFieldDef = enum field def
  nnkArgList = argument list (on call site)


  nnkSym = Symbol
  nnkHiddenCallConv = Hidden call
  nnkClosedSymChoice = Symbol lookup candidates (closed)
  nnkOpenSymChoice = Symbol lookup candidates (open)
  nnkHiddenStdConv = Implicit conversion of standard type (eg string to cstring)
  nnkHiddenSubConv = Implicit conversion of child class to parent class
  nnkConv = Explicit type conversion
  nnkAddr = call to addr
  nnkHiddenAddr = hidden call to addr (example var argument)
  nnkHiddenDeref = hidden dereference (example reading or writing to a var parameter)
  nnkCheckedFieldExpr = Variant property access
  nnkHiddenTryStmt = hidden try statement inserted by sem (for defer for example)
]#

#[
  special kinds

  nnkType = type information node (returned by getType)
  nnkComesFrom = internal, maybe metadata
  nnkBlockType = block metadata (returned by getImpl, maybe ?)
  nnkClosure = closure function (getTypeImpl)
  nnkGotoState, nnkState, nnkBreakState = under the hood of iterators / async to jump between contexts (getImpl) 
  
  nnkObjDownConv, nnkObjUpConv = Internal, refer to Conv
  nnkChckRangeF, nnkChckRange64, nnkChckRange, nnkStringToCString = Internal, refer to hiddenStdConv
  nnkCStringToString = internal / legacy
  nnkCommentStmt = comment , internal
  nnkWith, nnkWithout = internal / legacy
  nnkPattern = internal / legacy ?
  nnkError = erroneous node
  nnkModuleRef, nnkReplayAction, nnkNilRodNode = internal
  nnkOpenSym = legacy -> see nnkOpenSymChoice
]#
