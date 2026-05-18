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

type Orientation = enum
  oNorth = 1
  oEast
  oSouth
  oWest

type PlayerLevel = distinct range[0 .. 6]

func `$`(self: PlayerLevel): string {.borrow.}

type PlayerId = distinct uint

func `==`(lhs, rhs: PlayerId): bool {.borrow.}
func `$`(self: PlayerId): string {.borrow.}

type TeamName = distinct string

func hash(self: TeamName): Hash {.borrow.}
func `==`(lhs: TeamName, rhs: TeamName): bool {.borrow.}
func `$`(self: TeamName): string {.borrow.}

type
  WorldTile = object
    resources: array[ItemKind, uint]

  GfxClient = object
    socket: AsyncSocket

  Player = object
    socket: AsyncSocket
    team: ptr Team
    position: Position
    orientation: Orientation
    level: PlayerLevel
    inventory: array[ItemKind, uint]

  Config = object
    port {.opt.} = 4242
    width {.opt(shortName = some('x')).} = 2048
    height {.opt(shortName = some('y')).} = 2048
    teamNames {.opt(shortName = some('n')).}: TeamNameSeq
    startPlayerLimit {.opt(shortName = some('c')).} = 18
    timeUnit {.opt.} = 1

  Team = object
    name: ptr TeamName
    players: array[PLAYERS_PER_TEAM, ref Player]
    births = 0
    deaths = 0

  Position = tuple[x: int, y: int]
  TeamNameSeq = seq[TeamName]

  GameServer = object
    socket: AsyncSocket
    players: seq[ref Player]
    removedPlayerIds: SinglyLinkedList[PlayerId]
    gfxClients: SinglyLinkedList[GfxClient]
    teams: Table[TeamName, Team]
    world: seq[WorldTile]

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
  gameServer.teams[name] = Team(name: addr name)

proc addPlayer(socket: sink AsyncSocket, teamName: TeamName): PlayerId =
  var id =
    if gameServer.removedPlayerIds.head == nil:
      let length = gameServer.players.len
      gameServer.players.setLen(length + 1)
      PlayerId(length)
    else:
      template head(): untyped =
        gameServer.removedPlayerIds.head

      defer:
        head = head.next
      head.value
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

  let gfx = GfxClient(socket: client)

  await gfx.mct()
  while true:
    # gfx loop
    discard

proc handlePlayer(playerId: PlayerId) =
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

  var player = addPlayer(client, teamName)

  handlePlayer(player)

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
