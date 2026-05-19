import std/[asyncnet, asyncdispatch, streams], utils

type
  SomeGfxInput = concept x
    are Future[void]:
      x.getMapSize
      x.getTileContent(uint, uint)
      x.getMapContent
      x.getTeamNames
      x.getPlayerPosition(PlayerId)
      x.getPlayerLevel(PlayerId)
      x.getPlayerInventory(PlayerId)
      x.getTimeUnit
      x.setTimeUnit(uint)

  SomeGfxOutput = concept x
    are string:
      x.mapSize
      x.tileContent(uint, uint)
      x.teamName(TeamName)
      x.playerConnection(PlayerId)
      x.playerPosition(PlayerId)
      x.playerLevel(PlayerId)
      x.playerInventory(PlayerId)
      x.playerExpellation(PlayerId)
      x.playerBroadcast(PlayerId, string)
      x.playerIncantationStart(PlayerId)
      x.playerIncantationEnd(uint, uint, bool)
      x.playerFuck(PlayerId)
      x.playerDrop(PlayerId, ItemKind)
      x.playerPickup(PlayerId, ItemKind)
      x.playerDeath(PlayerId)
      x.eggLaying(EggId, PlayerId)
      x.eggHatching(EggId)
      x.eggPosession(EggId)
      x.eggDeath(EggId)
      x.timeUnit
      x.gameOver(TeamName)
      x.serverMessage(string)
      x.unknownCommand
      x.badCommandParameters

  GfxClient = object
    socket: AsyncSocket
