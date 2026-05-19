import utils

type
  PlayerLevel = distinct range[0..6]
  PlayerId = distinct uint
  EggId = distinct uint

  Player = object
    socket: AsyncSocket
    team: ptr Team
    position: Position
    orientation: Orientation
    level: PlayerLevel
    inventory: array[ItemKind, uint]

  TeamName = distinct string
  TeamNameSeq = seq[TeamName]
