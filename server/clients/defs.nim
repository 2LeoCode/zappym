import std/[asyncnet, asyncdispatch]

type
  SomeGameClient* = concept x
    x.sendLine(string) is Future[void]
