import std/[strformat, options, macros, parseopt, sugar, sequtils, strutils, tables]

template opt*(shortName = none(char)): untyped {.pragma.}
template arg*(): untyped {.pragma.}

type CmdFieldKind = enum
  cfkOpt
  cfkArg

type CmdField = object
  case kind: CmdFieldKind
  of cfkOpt:
    shortName: char
  else:
    discard
  typeName: string
  typeGenerics: seq[string]
  name: string

func getRecListR(n: NimNode): NimNode =
  n.expectKind nnkObjectTy
  result = n[2].copyNimTree
  if n[1].kind != nnkEmpty:
    result.add getRecListR(n[1][0].getImpl[2]).children.toSeq

macro parseArgs*(T: typedesc[typed]): untyped =
  let obj = T.getTypeImpl[1].getImpl[2]
  let fields = collect:
    for n in getRecListR(obj):
      if n[0].kind != nnkPragmaExpr or n[0][1].kind != nnkPragma:
        continue

      let pragmaExpr = n[0]
      let fieldName = nimIdentNormalize $pragmaExpr[0]
      let pragmaNode = pragmaExpr[1]

      var pragmaCall = none[NimNode]()
      var pragmaName {.noInit.}: string
      for p in pragmaNode:
        p.expectKind nnkCall
        p[0].expectKind nnkSym
        let name = nimIdentNormalize $p[0]
        if name in ["opt", "arg"].map nimIdentNormalize:
          if pragmaCall.isSome:
            error "You should use either the 'opt' or 'arg' pragma once and not both"
          pragmaCall = some(p)
          pragmaName = $p[0]

      if pragmaCall.isNone:
        continue

      let callNode = pragmaCall.get
      var field =
        if pragmaName == "opt":
          let optionCall = callNode[1]
          let shortName =
            if optionCall[0].kind == nnkSym and $optionCall[0] == "some":
              char(optionCall[1].intVal)
            else:
              fieldName[0]
          CmdField(kind: cfkOpt, shortName: shortName)
        else:
          CmdField(kind: cfkArg)
      field.name = fieldName
      field.typeName = nimIdentNormalize:
        if n[1].kind == nnkSym:
          $n[1]
        elif n[1].kind == nnkBracket:
          field.typeGenerics = n[1][1 .. ^1].mapIt $it
          $n[1][0]
        elif n[2].kind in nnkLiterals:
          n[2].getTypeInst.repr
        elif n[2].kind == nnkObjConstr:
          n[2][0].getTypeInst.repr
        elif n[2].kind == nnkBracket:
          if n[2].len == 0:
            error fmt"Cannot determine the type of field {fieldName}"
          n[2][0].getTypeInst.repr
        else:
          error fmt"Cannot determine the type of field {fieldName}"
      field

  let shortToName = newTable:
    collect:
      for field in fields:
        if field.kind == cfkOpt:
          (field.shortName, field.name)

  let nameToType = newTable:
    collect:
      for field in fields:
        (field.name, field.typeName)

  let typeToGenerics = newTable:
    collect:
      for field in fields:
        if field.typeGenerics.len != 0:
          (field.typeName, field.typeGenerics)

  let optNames = collect:
    for field in fields:
      if field.kind == cfkOpt:
        field.name

  let argNames = collect:
    for field in fields:
      if field.kind == cfkArg:
        field.name

  func parser(typeName, val: string): NimNode =
    result =
      if typeName == "string":
        newTree(nnkPrefix, ident("$"))
      else:
        var parseFn = ident("parse" & typeName)
        if typeName in typeToGenerics:
          var children = @[parseFn]
          children.add(typeToGenerics[typeName].mapIt(ident it))
          parseFn = unpackVarargs(newTree, nnkBracket, children)
        newCall(ident("parse" & typeName))
    result.add ident(val)

  func assignField(fieldName, val: string): NimNode =
    newStmtList(
      newTree(
        nnkAsgn,
        newDotExpr(ident("instance"), ident(fieldName)),
        parser(nameToType[fieldName], val),
      )
    )

  let shortCaseStmt =
    newTree(nnkCaseStmt, newTree(nnkBracketExpr, ident("key"), newIntLitNode(0)))
  for c, name in shortToName:
    shortCaseStmt.add(newTree(nnkOfBranch, newLit(c), assignField(name, "val")))
  let invalidShortName = quote:
    raise KeyError.newException fmt"Invalid short option: {key}"
  shortCaseStmt.add(newTree(nnkElse, invalidShortName))

  let longCaseStmt =
    newTree(nnkCaseStmt, newDotExpr(ident("key"), ident("nimIdentNormalize")))
  for name in optNames:
    longCaseStmt.add(
      newTree(nnkOfBranch, newStrLitNode(name), assignField(name, "val"))
    )
  let invalidOptName = quote:
    raise KeyError.newException fmt"Invalid option name: {key}"
  longCaseStmt.add(newTree(nnkElse, invalidOptName))

  let argCaseStmt = newTree(nnkCaseStmt, newCall(ident("pred"), ident("argIdx")))
  for i, name in argNames:
    argCaseStmt.add(newTree(nnkOfBranch, newIntLitNode(i), assignField(name, "key")))
  let extraArg = quote:
    raise ValueError.newException fmt"Extra argument: {key}"
  argCaseStmt.add(newTree(nnkElse, extraArg))

  let missingArg = quote:
    raise ValueError.newException fmt"Missing positional arguments"
  let missingArgCheck = newTree(
    nnkIfStmt,
    newTree(
      nnkElifBranch,
      infix(ident("argIdx"), "<", newIntLitNode(argNames.len)),
      missingArg,
    ),
  )

  quote:
    block:
      var instance {.inject.} = `T`()
      var argIdx {.inject.} = 0

      for kind {.inject.}, key {.inject.}, val {.inject.} in getopt():
        case kind
        of cmdShortOption:
          `shortCaseStmt`
        of cmdLongOption:
          `longCaseStmt`
        of cmdArgument:
          inc argIdx
          `argCaseStmt`
        else:
          continue
      `missingArgCheck`
      instance
