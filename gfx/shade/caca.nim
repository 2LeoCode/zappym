import macros, strutils

macro foo{
  type
    T = tDef
    TKind = tKindDef}(

    T: untyped{sym},
    TKind: untyped{sym},
    tDef: untyped{nkObjectTy},
    tKindDef: untyped{nkEnumTy},
) =
  if TKind.strVal.startsWith T.strVal:
    echo "match found"
  else:
    echo "not found"
  quote:
    {.noRewrite.}:
      type
        `T` = `tDef`
        `TKind` = `tKindDef`

type
  Foo = object
  FooKind = enum
    A
