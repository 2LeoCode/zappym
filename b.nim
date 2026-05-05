type Foo = object

func processFoo*(foo: Foo) =
  debugEcho "processing Foo"

func createFoo*(): Foo =
  Foo()
