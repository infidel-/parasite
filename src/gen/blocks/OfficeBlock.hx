// the ROOM level of a corp tower floor: which template fills a dealt room, and the zones it leaves
// behind
//
// one file per LEVEL of the tree, the same shape gen.blocks.RoomBlock has for the facility — the
// switch is the whole of it, and the templates themselves live in gen.corp.CorpRooms beside the
// rest of the corp generator. A zone kind reaching this switch is a leaf that writes nothing: the
// template that pushed it has already laid those cells, and the node is there so the finished tree
// records WHERE the furniture went.

package gen.blocks;

import gen.corp.CorpRooms;
import gen.corp._CorpState;

class OfficeBlock
{
// fill one dealt room. `node.roomID` is what gen.blocks.CorpBlocks.assign stamped on it
  public static function fill(state: _CorpState, node: _GenNode)
    {
      var room = null;
      for (r in state.rooms)
        if (r.id == node.roomID)
          {
            room = r;
            break;
          }
      if (room == null)
        return;
      switch (node.kind)
        {
          case CorpBlocks.ROOM_CUBICLE:
            CorpRooms.cubicle(state, node, room);
          case CorpBlocks.ROOM_MEETING:
            CorpRooms.meeting(state, node, room);
          case CorpBlocks.ROOM_KITCHEN:
            CorpRooms.kitchen(state, node, room);
          case CorpBlocks.ROOM_TOILET:
            CorpRooms.toilet(state, node, room);
          case CorpBlocks.ROOM_SERVERS:
            CorpRooms.servers(state, node, room);
          case CorpBlocks.ROOM_ARCHIVE:
            CorpRooms.archive(state, node, room);
          case CorpBlocks.ROOM_RECEPTION:
            CorpRooms.reception(state, node, room);
          case CorpBlocks.ROOM_SECURITY:
            CorpRooms.security(state, node, room);
          default:
            CorpRooms.exec(state, node, room);
        }
    }

// is this node kind a room? the filler table asks before it dispatches, and so does the oracle
  public static function isRoom(kind: String): Bool
    {
      return kind == CorpBlocks.ROOM_CUBICLE ||
        kind == CorpBlocks.ROOM_MEETING ||
        kind == CorpBlocks.ROOM_KITCHEN ||
        kind == CorpBlocks.ROOM_EXEC ||
        kind == CorpBlocks.ROOM_TOILET ||
        kind == CorpBlocks.ROOM_SERVERS ||
        kind == CorpBlocks.ROOM_ARCHIVE ||
        kind == CorpBlocks.ROOM_RECEPTION ||
        kind == CorpBlocks.ROOM_SECURITY;
    }
}
