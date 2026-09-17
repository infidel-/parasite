// console `go block` — the compound's blocks, and where you can stand inside one
//
// DERIVED FROM THE SAVED GRID AND NOT FROM THE BLOCK TREE, because there is no tree to read.
// gen._GenNode says it outright: the tree is in-memory only, deliberately, on the grounds that
// "the renderer, the lighting and the missions all re-derive what they need from the saved cell
// grid" — so by the time anyone can type a command it has been thrown away, and a loaded save never
// had one at all. What does survive is the cell grid plus area.generatorInfo's rooms, and
// render.facility.FacilityModel.fromArea is already this repo's one reader of both. It is a pure
// function of the area, so asking it here is both cheaper and safer than a second copy of `surfOf`
// and `findStructures` living in the console.
//
// WHAT THAT COSTS IS GRANULARITY, and it is worth knowing before reading the list: the block level
// and the room level come back exactly, `study-pad` comes back because FacilityModel.findPads
// recovers it from the SHAPE of the unwalkable concrete, and the room ZONES (bay, slot, lounge,
// stall-run, hangar-machine) leave no mark of their own on the grid and are not offered. The other
// `parking` against `yard` used to be one block here called `lot`, because both are the alley fill
// and both resolve to Surf.LOT. Const.TILE_PARKING is the tile that tells them apart, so they are
// two blocks now and the yard is everything else the surface still calls a lot.
package console;

import game.Game;
import gen.blocks.FacilityBlocks;
import gen.blocks.HangarBlock;
import gen.blocks.RoomBlock;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.facility.FacilityStyle;

// one teleport target: which block it is, and every cell of it you may land on
typedef _GoBlock = {
  // the generator's OWN kind string, so `go block` and docs/area-gen.md's tree diagram agree on
  // what a thing is called
  var kind: String;
  // the walkable cells of it. a block with none is never offered, which is what keeps `go block`
  // from reporting a target it cannot take you to
  var cells: Array<{ x: Int, y: Int }>;
}

class GoBlock
{
// every block of the current map. empty off a facility compound, which is the only area type whose
// layout is a block tree.
//
// DERIVED EVERY CALL AND NOT CACHED, which was measured rather than assumed: the whole of this
// walk is 1.03 ms on a 65x60 compound (fromArea itself 0.85), and ConsoleCompletion asks for the
// kind list once per hint render. A cache keyed on area.id would have been the obvious shape and
// it is a stale-data bug — AreaGame.regenerate rewrites the grid and KEEPS the id, so the one
// workflow this command is for would be served a list of the layout it just replaced
  public static function list(game: Game): Array<_GoBlock>
    {
      if (game.location != LOCATION_AREA ||
          game.area == null ||
          game.area.typeID != AREA_FACILITY)
        return [];
      var m = FacilityModel.fromArea(game.area);
      var out = [];
      // the two kinds of structure, on the INTERIOR box and not the one the roof spans. `ox*` is
      // the outer box and it reaches PAST the wall ring on at least one hand — measured on the
      // shed at 3,4..15,28, whose ox1 is 2 and whose whole x = 2 column is the pavement outside
      // it — so `go block hangar` put the player on the lot. The interior box is 301 walkable
      // cells of shed floor out of 325
      for (st in m.structures)
        add(out, game, st.hangar ? FacilityBlocks.HANGAR : FacilityBlocks.BUILDING,
          st.x1, st.y1, st.x2, st.y2);
      // the study pad, whose own square is unwalkable concrete with a podium standing on it — `add`
      // grows every rect by one cell, which is exactly the apron round it
      var r = Std.int(FacilityStyle.PODIUM_PAD / 2);
      for (p in m.pads)
        add(out, game, HangarBlock.PAD, p.col - r, p.row - r, p.col + r, p.row + r);
      // and the rooms, named by the kind that BUILT them rather than by the role they persist —
      // RoomBlock.kindOf is that mapping and is shared rather than repeated here.
      //
      // EXCEPT THE SHED, WHICH IS A ROOM IN THAT LIST. gen.blocks.HangarBlock records the whole
      // hangar floor as one role-less _Room — gen.GenCheck.hangarSane walks `rooms` to find it —
      // and a role-less room is a LABORATORY to kindOf, so the shed was offered as `room-lab` as
      // well as `hangar` and inflated that count. Asked of m.owner, which is the same derivation
      // the render side tells the shed from a lab building with
      for (room in m.rooms)
        {
          var si = m.owner[room.y1][room.x1];
          if (si >= 0 &&
              m.structures[si].hangar)
            continue;
          add(out, game, RoomBlock.kindOf(room), room.x1, room.y1, room.x2, room.y2);
        }
      // the three outdoor fills, one block each and read off the surface grid. no rect: a fill is
      // whatever shape the split left it, so the cells ARE the block
      surface(out, game, m, FacilityBlocks.PARK, Surf.GRASS);
      // and the two lot fills, which used to be ONE block called `lot`. Const.TILE_PARKING marks the
      // car park now, so the yard is whatever else answers Surf.LOT — the gaps between plots
      // included, which is what the filler kind always was
      surface(out, game, m, FacilityBlocks.PARKING, Surf.LOT, true);
      surface(out, game, m, FacilityBlocks.YARD, Surf.LOT, false);
      surface(out, game, m, FacilityBlocks.ROAD, Surf.ROAD);
      return out;
    }

// the kinds present on this map, sorted — the completion table's candidate list
  public static function kinds(game: Game): Array<String>
    {
      var out = [];
      for (b in list(game))
        if (out.indexOf(b.kind) < 0)
          out.push(b.kind);
      out.sort(Reflect.compare);
      return out;
    }

// `kind n, kind n` over every kind on the map, for the bare `go block`
  public static function summary(game: Game): String
    {
      var n = new Map<String, Int>();
      for (b in list(game))
        n.set(b.kind, (n.exists(b.kind) ? n.get(b.kind) : 0) + 1);
      var out = [];
      for (k in kinds(game))
        out.push(k + ' ' + n.get(k));
      return out.join(', ');
    }

// one block of `kind` over a rect: its own walkable cells, and only if it has none, the ring one
// cell outside it.
//
// THE FALLBACK IS THE STUDY PAD and it has to be a fallback rather than a margin. A pad is solid
// unwalkable concrete under a podium, so its own rect yields nothing and the apron round it is the
// answer — while a BUILDING's rect is its wall ring, whose outside is the pavement, so growing that
// one unconditionally dropped `go block hangar` on the corner of the lot instead of on the shed
// floor. Measured: it landed at 2,3 against a shed at 3,4..15,28
  static function add(out: Array<_GoBlock>, game: Game, kind: String,
      x1: Int, y1: Int, x2: Int, y2: Int)
    {
      var cells = walkable(game, x1, y1, x2, y2);
      if (cells.length == 0)
        cells = walkable(game, x1 - 1, y1 - 1, x2 + 1, y2 + 1);
      if (cells.length == 0)
        return;
      out.push({
        kind: kind,
        cells: cells,
      });
    }

// every cell of a rect somebody could stand on
  static function walkable(game: Game, x1: Int, y1: Int, x2: Int, y2: Int):
      Array<{ x: Int, y: Int }>
    {
      var out = [];
      for (y in y1...y2 + 1)
        for (x in x1...x2 + 1)
          if (game.area.isWalkable(x, y))
            out.push({ x: x, y: y });
      return out;
    }

// and one block per outdoor SURFACE class, over the whole map
  static function surface(out: Array<_GoBlock>, game: Game, m: Facility,
      kind: String, surf: Surf, ?parking: Null<Bool>)
    {
      var cells = [];
      for (y in 0...m.h)
        for (x in 0...m.w)
          if (m.surf[y][x] == surf &&
              (parking == null || FacilityModel.isParking(m, x, y) == parking) &&
              game.area.isWalkable(x, y))
            cells.push({ x: x, y: y });
      if (cells.length == 0)
        return;
      out.push({
        kind: kind,
        cells: cells,
      });
    }
}
