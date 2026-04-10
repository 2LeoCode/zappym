import macros

type Foo = object of RootObj

type Bar = object of Foo

let foo: ref Foo = Bar.new

dumptree:
  if foo of Bar:
    echo "foo"
