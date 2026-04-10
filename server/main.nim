import
  std/[
    asyncnet, strformat, options, parseopt, sugar, sequtils, strutils, tables, sets,
    asyncdispatch, hashes, posix, lists,
  ],
  utils,
  argparse

static:
  doAssert isMainModule, "This file is not a module"

const PLAYERS_PER_TEAM = 6

type ItemKind = enum
  ikNourriture
  ikLinemate
  ikDeraumere
  ikSibur
  ikMendiane
  ikPhiras
  ikThystame

type PlayerLevel = distinct range[0 .. 6]

type TeamName = distinct string

func hash(self: TeamName): Hash {.borrow.}
func `==`(lhs: TeamName, rhs: TeamName): bool {.borrow.}
func `$`(self: TeamName): string {.borrow.}

defineWrapperObject(WorldTile, array[ItemKind, uint])

type
  Config = object
    port {.opt.} = 4242
    width {.opt(shortName = some('x')).} = 2048
    height {.opt(shortName = some('y')).} = 2048
    teamNames {.opt(shortName = some('n')).}: TeamNameSeq
    startPlayerLimit {.opt(shortName = some('c')).} = 18
    timeUnit {.opt.} = 1

  Player = ref object
    team: Team
    position: Position
    socket: AsyncSocket
    level: PlayerLevel
    inventory: array[ItemKind, uint]

  Team = ref object
    name: TeamName
    players: array[PLAYERS_PER_TEAM, Option[Player]]
    births = 0
    deaths = 0

  Position = tuple[x: int, y: int]
  TeamNameSeq = seq[TeamName]

  GameServer = ref object
    players: SinglyLinkedList[Player]
    teams: ref Table[TeamName, Team]
    world: seq[WorldTile]

defineWrapperObject(Gfx, AsyncSocket)
defineWrapperObject(GfxServer, GameServer)
defineWrapperObject(PlayerServer, GameServer)

func parseTeamNameSeq(value: string): TeamNameSeq =
  let teamNames = value.split(',')
  let uniqueTeamNames = teamNames.toHashSet

  if teamNames.len != uniqueTeamNames.len:
    raise ValueError.newException "Duplicate team names are not allowed"

  if "" in uniqueTeamNames:
    raise ValueError.newException "Empty team names are not allowed"

  teamNames.mapIt TeamName($it)

let conf =
  try:
    Config.parseArgs
  except CatchableError as e:
    echo fmt"Error: {e.msg}"
    quit(1)

func playerCount(self: Team): int =
  len:
    collect:
      for p in self.players:
        if p.isSome:
          true

func addPlayer(self: GameServer, socket: AsyncSocket, team: Team): Player =
  let player = Player(team: team, socket: socket)
  self.players.add(player)
  for p in team.players.mitems:
    if p.isNone:
      p = some(player)
      return p.get()
  raise Defect.newException "Team is full"

proc getWorldTile(self: GameServer, x: int, y: int): lent WorldTile =
  self.world[y * conf.width + x]

proc msz(self: GfxServer, gfx: Gfx) {.async.} =
  ## Get world size

  await gfx.wrapped.send fmt "msz {conf.width} {conf.height}\n"

proc bct(self: GfxServer, gfx: Gfx, x: int, y: int) {.async.} =
  ## Get world tile contents

  let contents = self.wrapped.getWorldTile(x, y).wrapped.mapIt($it).join(" ")
  await gfx.wrapped.send fmt "bct {x} {y} {contents}"

proc mct(self: GfxServer, gfx: Gfx) {.async.} =
  ## Get all world tile contents

  let
    bctChunkSize = 16
    area = conf.width * conf.height
  var i = 0

  while i < area:
    let chunk = collect:
      for j in 0 ..< min(bctChunkSize, area - i):
        let
          i = i + j
          y = int(i / conf.width)
          x = i - y * conf.width
          content = self.wrapped.world[i].mapIt($it).join(" ")

        fmt"bct {x} {y} {content}"

    await gfx.wrapped.send chunk.join("\n") & "\n"
    i += bctChunkSize

proc handleGfxConnection(server: GameServer, client: AsyncSocket) {.async.} =
  block:
    let tnaContent = conf.teamNames.join " "
    await:
      client.send:
        fmt:
          dedent:
            """
            msz {conf.width} {conf.height}
            sgt {conf.timeUnit}
            tna {tnaContent}
            """

  let gfxServer = GfxServer(wrapped: server)
  let gfx = Gfx(wrapped: client)

  await gfxServer.mct(gfx)
  while true:
    # gfx loop
    discard

proc handlePlayer(server: PlayerServer, player: var Player) =
  while true:
    discard

proc handlePlayerConnection(server: GameServer, client: AsyncSocket) {.async.} =
  let teamNameRaw = await client.recvLine
  let teamName = TeamName(teamNameRaw)

  template endConnectionIf(expr: bool): untyped =
    if expr:
      client.close
      return

  endConnectionIf teamName notin conf.teamNames

  let team = server.teams[teamName]

  let nbClients = PLAYERS_PER_TEAM - team.playerCount

  endConnectionIf nbClients == 0

  await:
    client.send:
      fmt:
        dedent:
          """
          {nbClients}
          {conf.width} {conf.height}
          """

  var player = server.addPlayer(client, team)

  PlayerServer(wrapped: server).handlePlayer(player)

proc handleClient(gameServer: GameServer, client: AsyncSocket) {.async.} =
  await client.send "BIENVENUE\n"

  let res = await client.recvLine
  if res == "GRAPHICS":
    await handleGfxConnection(gameServer, client)
  elif res == "PLAYER":
    await handlePlayerConnection(gameServer, client)
  else:
    client.close

proc runServer(conf: Config) {.async.} =
  escalate ValueError:
    let server = newAsyncSocket()
    server.setSockOpt(OptReuseAddr, true)
    server.bindAddr Port(conf.port)

    let gameServer = GameServer(world: newSeq[WorldTile](conf.width * conf.height))

    server.listen

    while true:
      let client = await server.accept
      asyncCheck handleClient(gameServer, client)

setControlCHook:
  proc() {.noconv.} =
    echo "\b\bInterrupt"
    quit(1)

try:
  waitFor runServer(conf)
except CatchableError as e:
  echo fmt"Error: {e.msg}"
