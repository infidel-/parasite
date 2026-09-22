// console `area room` — what the generator built where the player is standing
//
// TWO SOURCES AND THEY SURVIVE DIFFERENTLY, which is the whole reason this file says so out loud.
// `area.generatorInfo` is a _SaveObject and comes back off any save, so the ROOM (its rect, its
// role, and so the block that dealt it) is always answerable. The TREE is not: gen._GenNode is
// in-memory only by design, game.AreaGame.genTree keeps the root alive for this command alone and
// a loaded save never had one — so the ZONES (a pod block, a desk run, a rack row) are reported
// only on a floor this session generated, and the report says which case it is rather than going
// quiet. Same for the seed, which used to exist only in a trace line.
package console;

import game.Game;
import gen._GenNode;
import gen.blocks.CorpBlocks;
import gen.blocks.RoomBlock;

class AreaRoom
{
// the whole report, ready to log and to copy. null when the player is not in an area
  public static function report(game: Game): String
    {
      if (game.location != LOCATION_AREA ||
          game.area == null)
        return null;
      var area = game.area;
      var x = game.playerArea.x;
      var y = game.playerArea.y;
      var out = [
        'area ' + area.id + ' (' + area.name + ') ' + area.typeID +
          ' ' + area.width + 'x' + area.height,
        'seed ' + (area.genSeed >= 0 ? '' + area.genSeed : '? (loaded save)'),
        'cell ' + x + ',' + y + ' tile ' + area.getCellType(x, y),
      ];

      // the room, off the saved half
      var info = area.generatorInfo;
      var room = (info != null && info.rooms != null ? info.getRoomAt(x, y) : null);
      if (room == null)
        out.push('room: none here (corridor, fill or outside every room rect)');
      else
        out.push('room ' + room.id + ' ' + blockOf(area.typeID, room) +
          ' role ' + (room.role != null ? room.role : '-') +
          ' rect ' + room.x1 + ',' + room.y1 + '..' + room.x2 + ',' + room.y2 +
          ' (' + room.w + 'x' + room.h + ')');

      // and the blocks, off the half that does not survive
      if (area.genTree == null)
        out.push('blocks: tree not available (loaded save) — `area regen` to see them');
      else
        {
          var path = [];
          descend(area.genTree, x, y, path);
          if (path.length == 0)
            out.push('blocks: nothing in the tree covers this cell');
          else
            {
              out.push('blocks: ' + [for (n in path) n.kind].join(' > '));
              var leaf = path[path.length - 1];
              if (leaf.children.length == 0)
                out.push('  (leaf, no zones)');
              for (c in leaf.children)
                out.push('  ' + c.kind + ' ' + c.x1 + ',' + c.y1 + '..' + c.x2 + ',' + c.y2 +
                  (c.tags != null ? ' [' + c.tags.join(',') + ']' : ''));
            }
        }
      return out.join('\n');
    }

// which block kind built this room, asked of the generator that owns the area type
  static function blockOf(typeID: _AreaType, room: _Room): String
    {
      return switch (typeID)
        {
          case AREA_CORP: CorpBlocks.kindOf(room);
          case AREA_FACILITY: RoomBlock.kindOf(room);
          default: '?';
        }
    }

// walk down the tree to the deepest node covering this cell, recording the path.
// BREADTH IS NOT NEEDED HERE — the children of a node partition its rect, so the first child that
// covers the cell is the only one that can
  static function descend(node: _GenNode, x: Int, y: Int, path: Array<_GenNode>)
    {
      if (x < node.x1 ||
          x > node.x2 ||
          y < node.y1 ||
          y > node.y2)
        return;
      path.push(node);
      for (c in node.children)
        {
          if (x < c.x1 ||
              x > c.x2 ||
              y < c.y1 ||
              y > c.y2)
            continue;
          descend(c, x, y, path);
          return;
        }
    }
}
