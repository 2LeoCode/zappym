import macros, sequtils, sugar

dumpTree:
  var c = 0

  proc foo(a: int, b: string) =
    echo "foo"
    echo a
    echo c
    c = 42
