// the compound's hangar, and what stands inside it
//
// one open shed: a wall ring, a run of fake bay doors along the face away from the road, one real
// side door, and a concrete floor. On top of that the shed now walks a tree of its own, the same way
// gen.facility.FacilityBuilding walks its rooms: the floor is one node, its zones are its children,
// and gen.Quota deals them. See docs/area-gen.md.
//
// THE ZONES ARE NOT ALL DEALT, and that is deliberate. The study pad is the reason the building
// exists, so it is CARVED first — centred, at a fixed size — and the machine banks that feed it are
// carved with it, because a cable fan only reads if its far ends are arranged around the thing it
// feeds. Only the WALL RUNS go to gen.Quota, which is where "server racks in the corners" and
// "computers near a wall" are statements about a bay rather than about the shed.

package gen.blocks;

import Const;
import game.AreaGenerator.*;
import gen.GenTree;
import gen.Quota;
import gen.Deco;
import gen.facility._FacilityState;
import gen.facility.FacilityRooms;
import gen.facility.FacilityTemp.*;

class HangarBlock
{
  // cells of open lot left between the hangar and the nearest building's pavement apron. the hangar
  // is the one structure with no apron of its own, and its wall is a blank storey-and-a-half face:
  // at the game's camera pitch that face SILHOUETTES the cell in front of it, so a gap of two read
  // as one on screen and the yard between the lab and the hangar looked like a slot.
  //
  // public because FacilityGen.build reads it to place the hangar, not just to draw it
  public static inline var HANGAR_GAP = 3;

  // the hangar's FOOTPRINT, wall ring included — a cap, not a plot.
  //
  // it used to take its whole plot minus the inset, and gen.Subdivide hands out plots 16..34 on
  // each axis, so the shed came out anywhere from 14x14 to 32x32 and at the top of that range it
  // dwarfed both lab buildings. The retired arithmetic in game.FacilityAreaGenerator sized it
  // `Std.int(area.width * 0.2)` = 13..15 wide, and this lands back on that. Whatever the plot has
  // over the cap stays the open lot the grid was blanked to, which is the apron the hangar has
  // never had one of its own.
  //
  // the INTERIOR FLOOR is HANGAR_W - 2 by HANGAR_H - 2 — the wall ring takes one cell per side
  public static inline var HANGAR_W = 16;
  public static inline var HANGAR_H = 14;

  // the sub-block kinds. strings, and named the same way gen.blocks.RoomBlock names its own, so one
  // filler table can switch on them and `--stats` counts them with no edit
  public static inline var FLOOR = 'hangar-floor';
  public static inline var PAD = 'study-pad';
  public static inline var MACHINE = 'hangar-machine';
  public static inline var RACK_BAY = 'hangar-rack-bay';
  public static inline var CONSOLE = 'hangar-console';
  public static inline var SLOT = 'hangar-slot';
  public static inline var GENERATOR = 'hangar-generator';

  // the study pad, on a side. ODD, so it has a true centre cell for the podium to stand on, and 5
  // against a 14x12 floor leaves a 4-cell annulus on x and 3 on y — enough for the cable fan to
  // cross and be seen, which is the whole reason the machine banks are not up against it
  public static inline var PAD_SZ = 5;

  // how far out of the pad a machine bank stands, measured from the pad edge. 2 puts exactly one
  // clear cell between the two, which is the cable
  static inline var MACHINE_OUT = 2;
  // how often a machine bank is the tall analyser console rather than the cube. Even-ish, because
  // the point of the second shape is that four banks do not read as one object repeated — and with
  // four banks a 50/50 roll leaves both shapes in the shed most of the time
  static inline var ANALYSER_PCT = 50;

  // cells per bay along a wall run, and the shortest run that can carry the computers
  static inline var BAY = 3;
  public static inline var CONSOLE_MIN = 3;

  // how much of what the deal did not want gets dressed at all. LOW against
  // gen.blocks.RoomBlock.SLOT_FILL_PCT's 70 on purpose: a hangar is mostly floor, and the brief for
  // this one is "some empty space"
  static inline var SLOT_FILL_PCT = 30;

  // the power generators on the open floor: at least two, a third this often, never more than three.
  // the corner server racks are cabled to them (render.facility.FacilityHangar), so a corner holding
  // racks gets the one nearest it first
  static inline var GEN_MIN = 2;
  static inline var GEN_MAX = 3;
  static inline var GEN_THIRD_PCT = 50;
  // how far into the floor off its corner a generator stands, in cells on both axes. 2 leaves the
  // ring a corner rack bay stands on and a walkable lane inside it, and stops short of the machine
  // banks the pad carves at the compass points
  static inline var GEN_INSET = 2;

  // the pad's rect and the interior's, for the walk. MODULE STATE, the same shape and for the same
  // reason as gen.facility.FacilityToilet's stall budget: the pad is carved in one pass and the
  // zones are filled a tree level later, and a zone has to be able to ask where the pad is
  static var padX1 = 0;
  static var padY1 = 0;
  static var padX2 = 0;
  static var padY2 = 0;
  // the interior row the one real door opens onto, so nothing stands in its lane. the door is
  // always in the WEST wall, so the column is the floor's own x1 and only the row varies
  static var doorRow = -1;

// generate a hangar of a given size at given coordinates, and walk what stands in it
  public static function generateHangar(state: _FacilityState, node: _GenNode,
      bx: Int, by: Int, bw: Int, bh: Int)
    {
      var area = state.area;
      var cells = area.getCells();
      // draw outer walls
      for (y in by - 2...by + bh + 2)
        for (x in bx - 2...bx + bw + 2)
          {
            if (x < 0 || y < 0 || x >= area.width || y >= area.height)
              continue;
            if (x > bx && x < bx + bw - 1 && y > by && y < by + bh - 1)
              {
                cells[x][y] = TEMP_CONCRETE;
                continue;
              }
            if (x < bx || x >= bx + bw || y < by || y >= by + bh)
              continue;
            if (x == bx || x == bx + bw - 1 || y == by || y == by + bh - 1)
              cells[x][y] = TEMP_BUILDING_WALL;
          }

      // draw fake doors
      var len = 0;
      var y = (state.mainRoadNorth ? (by + bh - 1) : by);
      for (x in bx + 1...bx + bw - 1)
        {
          if (len < 0)
            {
              len++;
              continue;
            }
          cells[x][y] = TEMP_HANGAR_DOOR;
          len++;
          if (len == 3)
            len = -1;
        }

      // draw side door
      cells[bx][by + Std.int(bh / 2)] = TEMP_HANGAR_SIDE_DOOR;
      doorRow = by + Std.int(bh / 2);

      // the hangar is ONE open space, so it is one room. it has no inner walls and therefore never
      // went through makeDoors, which is why it used to contribute nothing to generatorInfo at all —
      // and a room-less structure gets no ceiling light and no room reveal
      var roomID = state.nextRoomID;
      state.allRooms.push({
        id: roomID,
        x1: bx + 1,
        y1: by + 1,
        x2: bx + bw - 2,
        y2: by + bh - 2,
        w: bw - 2,
        h: bh - 2,
      });
      state.nextRoomID++;

      // and now the floor walks a tree of its own. the node hangs off the area's hangar node, so
      // GenTree.all and the `--stats` counters reach it, but the walk is started HERE rather than
      // left to the area walk — the same split gen.facility.FacilityBuilding makes for its rooms,
      // and for the same reason: the contents have to be standing before anything asks about them
      var floor = GenTree.add(node, FLOOR, bx + 1, by + 1, bx + bw - 2, by + bh - 2);
      floor.roomID = roomID;
      GenTree.build(floor, function(n) fill(state, n));
    }

// build one node of the hangar's tree.
//
// the filler table for the HANGAR level, and the whole of it — gen.facility.FacilityGen.fill has no
// case for any of these kinds and must not grow one, because the area walk meets them a level later
// and would fill them twice
  static function fill(state: _FacilityState, node: _GenNode)
    {
      switch (node.kind)
        {
          case FLOOR:
            zones(state, node);

          case PAD:
            pad(state, node);

          case MACHINE:
            // PER BANK AND NOT PER CELL. There are four banks of two cells each and two machines to
            // deal into them, and rolling the cells independently gives a bank a cube beside a
            // console — a pair of unrelated machines standing shoulder to shoulder, which is what a
            // compass point should NOT read as. Rolled off the bank's own corner instead, so each
            // bank is a matched pair and the four of them disagree with each other
            standing(state, node,
              (state.area.chance(ANALYSER_PCT) ? FIT_ANALYSER : FIT_MACHINE));

          case RACK_BAY:
            standing(state, node, FIT_RACK);

          case CONSOLE:
            console(state, node);

          case SLOT:
            slot(state, node);

          case GENERATOR:
            standing(state, node, FIT_GENERATOR);

          default:
        }
    }

// carve the study pad, arrange the machine banks around it, and deal the wall runs.
//
// ORDER IS LOAD-BEARING and it is the washroom's: gen.facility.FacilityToilet puts its divider in
// before it measures the wall runs, so the divider removes cells rather than fighting them. Here the
// pad and the machine banks go in first for the same reason, and the bays the deal then sees are
// only ever cells nothing has claimed
  static function zones(state: _FacilityState, node: _GenNode)
    {
      var w = GenTree.width(node);
      var h = GenTree.height(node);
      // the pad, centred. a floor too small to carry it and still have a wall run gets none, which
      // is the washroom's rule again: no candidate passing is survivable, relaxing onto it is not
      if (w < PAD_SZ + 4 ||
          h < PAD_SZ + 4)
        {
          padX1 = padY1 = 1;
          padX2 = padY2 = 0;
        }
      else
        {
          padX1 = node.x1 + Std.int((w - PAD_SZ) / 2);
          padY1 = node.y1 + Std.int((h - PAD_SZ) / 2);
          padX2 = padX1 + PAD_SZ - 1;
          padY2 = padY1 + PAD_SZ - 1;
          var p = GenTree.add(node, PAD, padX1, padY1, padX2, padY2);
          p.roomID = node.roomID;
          // the machine banks, one per compass point, each a pair of cells MACHINE_OUT clear of the
          // pad edge. carved and not dealt: the cable fan is the set piece and a fan needs its far
          // ends spread around the thing it feeds, which no `must` can ask for
          var cx = Std.int((padX1 + padX2) / 2);
          var cy = Std.int((padY1 + padY2) / 2);
          bank(state, node, cx - 1, padY1 - MACHINE_OUT, cx, padY1 - MACHINE_OUT);
          bank(state, node, cx - 1, padY2 + MACHINE_OUT, cx, padY2 + MACHINE_OUT);
          bank(state, node, padX1 - MACHINE_OUT, cy - 1, padX1 - MACHINE_OUT, cy);
          bank(state, node, padX2 + MACHINE_OUT, cy - 1, padX2 + MACHINE_OUT, cy);
        }

      // then the wall runs, cut into bays and dealt. SLOT is the filler, which is what "some empty
      // space" is made of: a bay no demand's `must` accepted gets the low roll and mostly nothing
      var bays = [];
      walls(node, bays);
      Quota.deal(bays, HangarZones.demands(state, node, bays), SLOT, state.area.rng);
      for (b in bays)
        node.children.push(b);
      generators(state, node, bays);
    }

// stand two or three power generators on the open floor, one inset off a corner each.
//
// CARVED AND NOT DEALT, for the machine banks' reason: they stand on the FLOOR and not in a wall
// bay, and gen.Quota only deals bays. And carved AFTER the deal, because which corners carry server
// racks is what decides which corners get one first — a rack is cabled to its nearest generator, and
// a generator off a corner with nothing in it would be cabled to nothing
  static function generators(state: _FacilityState, node: _GenNode, bays: Array<_GenNode>)
    {
      var corners = [
        { x: node.x1, y: node.y1, dx: 1, dy: 1 },
        { x: node.x2, y: node.y1, dx: -1, dy: 1 },
        { x: node.x1, y: node.y2, dx: 1, dy: -1 },
        { x: node.x2, y: node.y2, dx: -1, dy: -1 },
      ];
      var racked = function(c: { x: Int, y: Int, dx: Int, dy: Int }): Bool
        {
          for (b in bays)
            if (b.kind == RACK_BAY &&
                c.x >= b.x1 &&
                c.x <= b.x2 &&
                c.y >= b.y1 &&
                c.y <= b.y2)
              return true;
          return false;
        };
      // racked corners first, the rest after them in a rolled order
      var order = [ for (c in corners) if (racked(c)) c ];
      var rest = [ for (c in corners) if (!racked(c)) c ];
      while (rest.length > 0)
        order.push(rest.splice(state.area.random(rest.length), 1)[0]);
      var racks = 0;
      for (c in corners)
        if (racked(c))
          racks++;
      var want = Std.int(Math.min(GEN_MAX, Math.max(GEN_MIN, racks) +
        (state.area.chance(GEN_THIRD_PCT) ? 1 : 0)));
      var n = 0;
      for (c in order)
        {
          if (n >= want)
            break;
          // the inset cell, and one step further along either axis when that one is taken
          for (o in [ [ 0, 0 ], [ 1, 0 ], [ 0, 1 ] ])
            {
              var x = c.x + c.dx * (GEN_INSET + o[0]);
              var y = c.y + c.dy * (GEN_INSET + o[1]);
              if (!clear(state, node, x, y))
                continue;
              var g = GenTree.add(node, GENERATOR, x, y, x, y);
              g.roomID = node.roomID;
              n++;
              break;
            }
        }
    }

// may a generator stand here? bare, inside the floor, with nothing standing on any of its eight
// neighbours, and a clear cell between it and anything the pad carved — the pad itself, so the
// walkable ring the rig's console and slots are worked from stays whole, a machine bank, or another
// generator.
// It is the only fitting in the compound with no wall behind it, so the lane round all four sides of
// it is what keeps the floor walkable. The carved nodes are asked by RECT because none of them has
// been filled yet — `bare` alone would see concrete where a bank is about to stand
  static function clear(state: _FacilityState, node: _GenNode, x: Int, y: Int): Bool
    {
      if (x <= node.x1 ||
          y <= node.y1 ||
          x >= node.x2 ||
          y >= node.y2)
        return false;
      for (dy in -1...2)
        for (dx in -1...2)
          if (!bare(state, x + dx, y + dy))
            return false;
      for (c in node.children)
        {
          var m = 1;
          if ((c.kind == PAD ||
               c.kind == MACHINE ||
               c.kind == GENERATOR) &&
              x >= c.x1 - m &&
              x <= c.x2 + m &&
              y >= c.y1 - m &&
              y <= c.y2 + m)
            return false;
        }
      return true;
    }

// one machine bank, if both its cells are inside the floor and still bare
  static function bank(state: _FacilityState, node: _GenNode, x1: Int, y1: Int, x2: Int, y2: Int)
    {
      if (x1 < node.x1 || y1 < node.y1 || x2 > node.x2 || y2 > node.y2)
        return;
      var n = GenTree.add(node, MACHINE, x1, y1, x2, y2);
      n.roomID = node.roomID;
    }

// cut the floor's perimeter ring into bays, tagging the ones that turn a corner.
//
// the ring and not the whole floor: everything a hangar stands against a wall is against a wall
// because that is where the room's clear span has to stay. The bays are pushed UNDEALT, exactly as
// gen.blocks.RoomBlock.glazeWall pushes its own
  static function walls(node: _GenNode, out: Array<_GenNode>)
    {
      run(node, out, node.x1, node.y1, 1, 0, GenTree.width(node));
      run(node, out, node.x1, node.y2, 1, 0, GenTree.width(node));
      run(node, out, node.x1, node.y1 + 1, 0, 1, GenTree.height(node) - 2);
      run(node, out, node.x2, node.y1 + 1, 0, 1, GenTree.height(node) - 2);
    }

// cut one wall's run into bays of BAY cells, the tail kept however short it came out
  static function run(node: _GenNode, out: Array<_GenNode>, x: Int, y: Int,
      dx: Int, dy: Int, len: Int)
    {
      var i = 0;
      while (i < len)
        {
          var n = (i + BAY <= len ? BAY : len - i);
          // UNATTACHED, the way gen.blocks.RoadBlock.entryRect hands its mouth back: these are
          // still undealt, and only `zones` pushes the named list onto the tree
          var b = GenTree.root(RoomBlock.BAY,
            x + dx * i, y + dy * i,
            x + dx * (i + n - 1), y + dy * (i + n - 1));
          b.roomID = node.roomID;
          b.tags = [];
          // a bay holding a corner of the ring is the one thing a server bay wants, and the one
          // thing the computers do not: a desk in a corner faces a wall
          if (corner(node, b))
            b.tags.push(RoomBlock.TAG_END);
          // and the bay the one real door opens into carries nothing but the filler
          if (b.x1 == node.x1 &&
              dy != 0 &&
              b.y1 <= doorRow &&
              b.y2 >= doorRow)
            b.tags.push(RoomBlock.TAG_DOOR);
          out.push(b);
          i += n;
        }
    }

// does this bay hold a corner of the floor's ring?
  static function corner(node: _GenNode, b: _GenNode): Bool
    {
      for (c in RoomBlock.cellsOf(b))
        if ((c.x == node.x1 || c.x == node.x2) &&
            (c.y == node.y1 || c.y == node.y2))
          return true;
      return false;
    }

// the study pad itself: the cells the podium and its dais stand on.
//
// STAMPED AS A FINAL TILE ID and not a temp one, which is what keeps it out of finalizeTiles' map —
// the same channel a room template uses to write a themed floor. Nothing else is written: the podium
// is derived render-side from this cluster, the way the roof and the parked cars are derived, so it
// costs no new tile id, no atlas frame and nothing in the save but the floor it already had
  static function pad(state: _FacilityState, node: _GenNode)
    {
      var cells = state.area.getCells();
      for (c in RoomBlock.cellsOf(node))
        cells[c.x][c.y] = Const.TILE_FLOOR_CONCRETE_UNWALKABLE;
    }

// stand a row of ONE kind of furniture along this bay, on concrete.
//
// gen.blocks.RoomBlock.standing is the lab's version of this and cannot be borrowed: it asks
// `solid`, which tests for TEMP_BUILDING_ROOM, and a hangar floor is TEMP_CONCRETE. It also leaves
// one cell of every bay, which a room needs because its runs ring a small space and a hangar does
// not. What IS shared is the repaint afterwards — FacilityRooms.placeFitting writes the lab's
// unwalkable tile and the hangar floor is concrete
  static function standing(state: _FacilityState, node: _GenNode, kind: _FittingKind)
    {
      for (c in RoomBlock.cellsOf(node))
        {
          if (!bare(state, c.x, c.y))
            continue;
          FacilityRooms.placeFitting(state, c.x, c.y, kind);
          state.area.getCells()[c.x][c.y] = floorUnder(state, c.x, c.y);
        }
    }

// the computers: a run of worktop against a wall, which render.facility.FacilityWork then stands a
// monitor, a tower and a keyboard on.
//
// the same worktop tiles a laboratory bench is made of, and deliberately — the workstation pass is
// already a pure function of those tiles and of the wall behind them, so a hangar console needs no
// second pass and no second model. What it needed was for that pass to look at a hangar at all,
// which is the one line added to FacilityWork.at
  static function console(state: _FacilityState, node: _GenNode)
    {
      var cells = state.area.getCells();
      var vertical = (GenTree.width(node) == 1);
      var tiles = (vertical ?
        [ Const.TILE_LABS_TABLE_1X3_1, Const.TILE_LABS_TABLE_1X3_2, Const.TILE_LABS_TABLE_1X3_3 ] :
        [ Const.TILE_LABS_TABLE_3X1_1, Const.TILE_LABS_TABLE_3X1_2, Const.TILE_LABS_TABLE_3X1_3 ]);
      var n = 0;
      for (c in RoomBlock.cellsOf(node))
        {
          if (!bare(state, c.x, c.y))
            continue;
          cells[c.x][c.y] = tiles[n % tiles.length];
          n++;
        }
    }

// dress a bay nothing wanted: mostly nothing, and a low piece where it is not.
//
// LOW ONLY. A hangar's walls carry the bay doors and the shed's whole read is its clear span, so a
// 2.8-tall cabinet against one is the same mistake a fitting beside glazing is
  static function slot(state: _FacilityState, node: _GenNode)
    {
      var area = state.area;
      var cells = area.getCells();
      for (c in RoomBlock.cellsOf(node))
        {
          if (!bare(state, c.x, c.y) ||
              !area.chance(SLOT_FILL_PCT))
            continue;
          var fr = Deco.pick(area, Deco.MOUNT_FLOOR_LOW, Deco.BLOCK_LAB);
          area.addDecoration(c.x, c.y, fr.row, fr.col);
          cells[c.x][c.y] = floorUnder(state, c.x, c.y);
        }
    }

// the floor left under a fitting just stood on this cell: walkable when it backs onto masonry,
// unwalkable concrete when it stands in the open.
//
// A FITTING AGAINST THE SHELL IS DRAWN IN THE WALL'S RECESS, NOT ON ITS OWN CELL. The wall slab is
// WALL_T thick centred in a 4-unit cell, so its face stands a whole unit back from the boundary, and
// render.facility.FacilityDeco stands a 1.2-deep rack or drum off that face — 0.2 of it reaches its
// own cell and the rest of the cell is bare concrete. Marked unwalkable, that read as empty floor the
// player could not step on, which is how it was reported. Only TEMP_BUILDING_WALL counts: the shutter
// is not masonry a rack backs onto, and a fitting with nothing behind it stands mid-cell and blocks
  static function floorUnder(state: _FacilityState, x: Int, y: Int): Int
    {
      var cells = state.area.getCells();
      for (i in 0...Const.dir4x.length)
        if (cells[x + Const.dir4x[i]][y + Const.dir4y[i]] == TEMP_BUILDING_WALL)
          return TEMP_CONCRETE;
      return Const.TILE_FLOOR_CONCRETE_UNWALKABLE;
    }

// may something stand on this hangar cell? bare concrete, nothing on it, and clear of the one real
// door's lane — the shed has no inner doors, so that lane is the whole of the door test
  static function bare(state: _FacilityState, x: Int, y: Int): Bool
    {
      return (state.area.getCells()[x][y] == TEMP_CONCRETE &&
        !state.area.hasObjectAt(x, y) &&
        !nextTo(state.area.getCells(), x, y, TEMP_HANGAR_SIDE_DOOR));
    }
}
