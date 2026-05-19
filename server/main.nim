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
const PLAYER_MAX_TIME_TO_DIE = 3 * 126

type ItemKind = enum
  ikNourriture
  ikLinemate
  ikDeraumere
  ikSibur
  ikMendiane
  ikPhiras
  ikThystame

type Orientation = enum
  oNorth = 1
  oEast
  oSouth
  oWest

type PlayerLevel = distinct range[0 .. 6]

func `$`(self: PlayerLevel): string {.borrow.}

type
  PlayerId = distinct uint
  EggId = distinct uint

func `==`(lhs, rhs: PlayerId): bool {.borrow.}
func `$`(self: PlayerId): string {.borrow.}

type
  TeamName = distinct string
  TeamNameSeq = seq[TeamName]

func hash(self: TeamName): Hash {.borrow.}
func `==`(lhs: TeamName, rhs: TeamName): bool {.borrow.}
func `$`(self: TeamName): string {.borrow.}

func parseTeamNameSeq(value: string): TeamNameSeq =
  let teamNames = value.split(',')
  let uniqueTeamNames = teamNames.toHashSet

  if teamNames.len != uniqueTeamNames.len:
    raise ValueError.newException "Duplicate team names are not allowed"

  if "" in uniqueTeamNames:
    raise ValueError.newException "Empty team names are not allowed"

  collect:
    for name in teamNames:
      TeamName(name)

type
  WorldTile = object
    resources: array[ItemKind, uint]

  SomeGameClient = concept x
    x.sendLine(string) is Future[void]

  GameClient = object of RootObj
    socket: AsyncSocket

  SomeGfxClient = concept x, SomeGameClient
    x.msz is Future[void]
    x.bct(int, int) is Future[void]
    x.mct is Future[void]
    x.tna is Future[void]
    x.pnw(PlayerId) is Future[void]
    x.ppo(PlayerId) is Future[void]
    x.plv(PlayerId) is Future[void]
    x.pin(PlayerId) is Future[void]
    x.pex(PlayerId) is Future[void]
    x.pbc(PlayerId) is Future[void]
    x.pic(int, int, PlayerLevel, PlayerId, varargs[PlayerId]) is Future[void]
    x.pie(int, int, bool) is Future[void]
    x.pfk(PlayerId) is Future[void]
    x.pdr(PlayerId, ItemKind) is Future[void]
    x.pgt(PlayerId, ItemKind) is Future[void]
    x.pdi(PlayerId) is Future[void]

  GfxClient = object of GameClient

  Player = object of GameClient
    team: ptr Team
    position: Position
    orientation: Orientation
    level: PlayerLevel
    timeToDie: uint
    inventory: array[ItemKind, uint]
  
  Config = object
    port {.opt.} = 4242
    width {.opt(shortName = some('x')).} = 2048
    height {.opt(shortName = some('y')).} = 2048
    teamNames {.opt(shortName = some('n')).}: TeamNameSeq
    startPlayerLimit {.opt(shortName = some('c')).} = 18
    timeUnit {.opt.} = 1

  Egg = object
    case hatched: bool
    of true:
      hatchTime: uint
    of false:
      discard


  Team = object
    name: ptr TeamName
    players: array[PLAYERS_PER_TEAM, ref Player]
    eggs: seq[Egg]
    removedEggIds: SinglyLinkedList[EggId]
    births = 0
    deaths = 0

  Position = tuple[x: int, y: int]

  GameServer = object
    socket: AsyncSocket
    players: seq[ref Player]
    removedPlayerIds: SinglyLinkedList[PlayerId]
    gfxClients: SinglyLinkedList[GfxClient]
    teams: Table[TeamName, Team]
    world: seq[WorldTile]

proc `=copy`(self: var Player, other: Player) {.error.}

let conf =
  try:
    Config.parseArgs
  except CatchableError as e:
    echo fmt"Error: {e.msg}"
    quit(1)



proc initGameServer(conf: Config): GameServer =
  escalate ValueError:
    let socket = newAsyncSocket()
    socket.setSockOpt(OptReuseAddr, true)
    socket.bindAddr Port(conf.port)

    GameServer(socket: socket, world: newSeq[WorldTile](conf.width * conf.height))

var gameServer = initGameServer(conf)

func playerCount(self: Team): int =
  for p in self.players:
    if p != nil:
      inc result

proc addTeam(name: sink TeamName): Team =
  if gameServer.teams.hasKeyOrPut(name, Team(name: addr name)):
    raise Defect.newException "Team already exists"

proc removeTeam(name: TeamName) =
  if not gameServer.teams.hasKey(name):
    raise Defect.newException "Team doesn't exist"
  gameServer.teams.del(name)

proc addPlayer(socket: sink AsyncSocket, teamName: TeamName): PlayerId =
  var id =
    if gameServer.removedPlayerIds.isEmpty:
      defer:
        gameServer.players.add nil
      PlayerId(gameServer.players.len)
    else:
      gameServer.removedPlayerIds.popFront()
  var team = gameServer.teams[teamName]
  for p in team.players.mitems:
    if p == nil:
      p = (ref Player)(team: addr gameServer.teams[teamName], socket: socket)
      gameServer.players[uint(id)] = p
      return id
  raise Defect.newException "Team is full"

proc getPlayer(id: PlayerId): lent Player =
  let player = gameServer.players[uint(id)]
  if player == nil:
    raise Defect.newException "Player not found"
  player[]

proc mgetPlayer(id: PlayerId): var Player =
  let player = gameServer.players[uint(id)]
  if player == nil:
    raise Defect.newException "Player not found"
  player[]

proc removePlayer(id: PlayerId) =
  let player = gameServer.players[uint(id)]
  if player == nil:
    raise Defect.newException "Player not found"
  
  gameServer.removedPlayerIds.add(id)
  gameServer.players[uint(id)] = nil
  for p in player.team.players.mitems:
    if p == player:
      p = nil
      break

proc addGfx(socket: sink AsyncSocket): lent GfxClient =
  gameServer.gfxClients.add(GfxClient(socket: socket))
  gameServer.gfxClients.tail.value

proc getWorldTile(x: int, y: int): lent WorldTile =
  gameServer.world[y * conf.width + x]

proc msz(gfx: GfxClient) {.async.} =
  ## Get world size

  await gfx.socket.send fmt "msz {conf.width} {conf.height}\n"

proc bct(gfx: GfxClient, x: int, y: int) {.async.} =
  ## Get world tile contents

  let contents = collect(
    for tile in getWorldTile(x, y).resources:
      $tile
  ).join " "

  await gfx.socket.send fmt "bct {x} {y} {contents}"

proc mct(gfx: GfxClient) {.async.} =
  ## Get all world tile contents

  const bctChunkSize = 16
  let area = conf.width * conf.height
  var i = 0

  while i < area:
    let chunk = collect:
      for j in 0 ..< min(bctChunkSize, area - i):
        let
          i = i + j
          y = int(i / conf.width)
          x = i - y * conf.width
          content = gameServer.world[i].resources.mapIt($it).join(" ")

        fmt "bct {x} {y} {content}"

    await gfx.socket.send chunk.join("\n") & "\n"
    i += bctChunkSize

proc tna(gfx: GfxClient) {.async.} =
  ## Get team names

  const tnaChunkSize = 16

  var
    chunk: array[tnaChunkSize, string]
    i: int
  for name in gameServer.teams.keys:
    chunk[i] = fmt "tna {name}"
    inc i
    if i == tnaChunkSize:
      await gfx.socket.send chunk.join("\n") & "\n"
      i = 0
  if i != tnaChunkSize:
    await gfx.socket.send chunk[0 ..< i].join("\n") & "\n"

proc pnw(gfx: GfxClient, playerId: PlayerId) {.async.} =
  ## New player connection

  let
    player = gameServer.players[uint(playerId)]
    (posX, posY) = player.position
    orientation = ord player.orientation
    level = player.level
    teamName = player.team[].name[]

  await gfx.socket.send fmt "pnw #{playerId} {posX} {posY} {orientation} {level} {teamName}\n"

proc ppo(gfx: GfxClient, playerId: PlayerId) {.async.} =
  ## Get player position and orientation

  let player = getPlayer(playerId)

  await gfx.socket.send fmt "ppo #{playerId} {player.position.x} {player.position.y} {player.orientation}\n"

proc plv(gfx: GfxClient, playerId: PlayerId) {.async.} =
  ## Get player level

  let player = getPlayer(playerId)
  await gfx.socket.send fmt "plv #{playerId} {ord player.level}\n"

proc pin(gfx: GfxClient, playerId: PlayerId) {.async.} =
  ## Get player inventory

  let
    player = getPlayer(playerId)
    contents = collect(
      for item in player.inventory:
        $item
    ).join(" ")

  await gfx.socket.send fmt "pin #{playerId} {contents}\n"
  
proc pex(gfx: GfxClient, playerId: PlayerId) {.async.} =
  ## A player is expelled

  await gfx.socket.send fmt "pex #{playerId}\n"

proc pbc(gfx: GfxClient, playerId: PlayerId, msg: string) {.async.} = 
  ## A player broadcasts a message

  await gfx.socket.send fmt "pbc #{playerId} {msg}\n"

proc handleGfx(gfx: GfxClient) {.async.} =
  await gfx.mct()
  while true:
    # gfx loop
    discard

proc handleGfxConnection(client: AsyncSocket) {.async.} =
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

  let gfx = addGfx(client)
  await handleGfx(gfx)

proc handlePlayer(playerId: PlayerId) {.async.} =
  while true:
    discard

proc handlePlayerConnection(client: AsyncSocket) {.async.} =
  let teamNameRaw = await client.recvLine
  let teamName = TeamName(teamNameRaw)

  template endConnectionIf(expr: bool): untyped =
    if expr:
      client.close
      return

  endConnectionIf teamName notin conf.teamNames

  let team = addr(gameServer.teams[teamName])

  let nbClients = PLAYERS_PER_TEAM - team[].playerCount

  endConnectionIf nbClients == 0

  await:
    client.send:
      fmt:
        dedent:
          """
          {nbClients}
          {conf.width} {conf.height}
          """

  var playerId = addPlayer(client, teamName)

  for gfx in gameServer.gfxClients:
    await gfx.pnw(playerId)

  await handlePlayer(playerId)

proc handleClient(client: AsyncSocket) {.async.} =
  await client.send "BIENVENUE\n"

  let res = await client.recvLine
  if res == "GRAPHICS":
    await handleGfxConnection(client)
  elif res == "PLAYER":
    await handlePlayerConnection(client)
  else:
    client.close

proc startServer() {.async.} =
  gameServer.socket.listen

  while true:
    let client = await gameServer.socket.accept
    asyncCheck handleClient(client)

setControlCHook:
  proc() {.noconv.} =
    echo "\b\bInterrupt"
    quit(1)

try:
  waitFor startServer()
except CatchableError as e:
  echo fmt"Error: {e.msg}"
