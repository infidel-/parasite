@:structInit
class _GeneratorInfo extends _SaveObject
{
  public var rooms: Array<_Room>;
  public var doors: Array<_Door>;
  @:optional public var missionHints: _GeneratorMissionHints;
  public function new(rooms: Array<_Room>, doors: Array<_Door>,
      ?missionHints: _GeneratorMissionHints)
    {
      this.rooms = rooms;
      this.doors = doors;
      this.missionHints = missionHints;
    }

// find room that this x,y belongs to
  public function getRoomAt(x: Int, y: Int): _Room
    {
      for (r in rooms)
        if (x >= r.x1 && x <= r.x2 &&
            y >= r.y1 && y <= r.y2)
          return r;
      return null;
    }

// find room by room id
  public function getRoom(roomID: Int): _Room
    {
      for (r in rooms)
        if (r.id == roomID)
          return r;
      return null;
    }

  public function init()
    {
      rooms = [];
      doors = [];
      missionHints = null;
    }
}
