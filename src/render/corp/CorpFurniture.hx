package render.corp;

import Const;
import citygen.CityConfig;
import three.Three;
import render.facility.FacilityGeom;
import render.facility.FacilityGeom.Rect;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.ContactMask;
import render.world.MeshBuf;
import render.world.MeshBuf.MeshBufTools;

// what a tower floor reports having emitted, for __corp()
typedef CorpFit = {
  var desks: Int;       // worktop cells: open-plan and cubicle desks, exec desks, wall benches
  var counters: Int;    // kitchen counter cells
  var tables: Int;      // boardroom table cells
  var partitions: Int;  // cubicle spine panels
  var racks: Int;       // server cabinets
  var basins: Int;      // washroom vanity cells
  var stalls: Int;      // WC cubicle cells
  var mirrors: Int;     // mirror panels over the vanity
}

// every piece of corp furniture that is EMITTED GEOMETRY rather than a glb.
//
// the triage is docs/3d-models.md's and it comes out one way for the whole set: a desk, a counter,
// a boardroom slab, a cubicle spine, a server cabinet, a vanity and a WC divider are all
// axis-aligned slabs whose read is a MATERIAL or a RHYTHM and not a silhouette. So none of them is
// a glb, and each one is a box of quads wearing ONE TEXTURE PER FACE (docs/3d-geometry.md — a top
// is a different surface from a front, and one sheet over both puts laminate grain down a drawer).
//
// IT IS ONE FILE AND NOT FIVE because the buffers are keyed by TEXTURE and not by object kind: an
// exec desk and a cubicle desk really are the same laminate, so they share a draw call for free,
// and splitting them across files could only take that back. Eight families, nine textures, nine
// merged meshes.
//
// WHAT IT READS is the saved grid and nothing else, which is what makes it retroactive to every
// corp save already written:
//   - `m.table` — the worktop tiles gen.corp's templates lay. the FINISH comes off the room's own
//     Surf, so the same tile is a desk in the open plan, a counter in the kitchen and a slab in the
//     boardroom;
//   - `m.fit` — the three ids the surface grid cannot name, dealt by CorpModel.fitOf: a cubicle
//     SPINE, a server CABINET and a washroom FIXTURE. Each is a floor tile's unwalkable twin, so
//     all three paint their room's own floor and only the raw tile told them apart.
//
// a FIXTURE is a BASIN where it has a fixture neighbour and a STALL where it stands alone, and that
// test is not a guess: gen.corp.CorpRooms.toilet lays the basins as a continuous run along the
// room's top wall and the stalls every OTHER cell along its bottom one, so contiguity IS the
// distinction and nothing had to be persisted to carry it.
class CorpFurniture
{
  // the furniture codes ShellOpts.fitOf deals into Facility.fit. 0 is nothing
  public static inline var FIT_SPINE = 1;    // a cubicle partition spine
  public static inline var FIT_RACK = 2;     // a server cabinet
  public static inline var FIT_FIXTURE = 3;  // a washroom basin or WC cubicle

  // the buffers, keyed by the texture they will be merged under
  static var bufs:Map<String, MeshBuf>;

// emit every fitting on the floor plate
  public static function build(scene:Scene, m:Facility):CorpFit
    {
      bufs = new Map();
      var n:CorpFit = {
        desks: 0,
        counters: 0,
        tables: 0,
        partitions: 0,
        racks: 0,
        basins: 0,
        stalls: 0,
        mirrors: 0,
      };
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (!FacilityModel.inside(m, col, row))
              continue;
            if (m.table[row][col])
              {
                worktop(m, col, row, n);
                continue;
              }
            switch (m.fit[row][col])
              {
                case FIT_SPINE:
                  partition(m, col, row);
                  n.partitions++;

                case FIT_RACK:
                  rack(m, col, row);
                  n.racks++;

                case FIT_FIXTURE:
                  washroom(m, col, row, n);

                default:
              }
          }
      for (tex in bufs.keys())
        FacilityGeom.add(scene, bufs.get(tex), tex, true, false);
      bufs = null;
      return n;
    }

// how high the fitting on a cell stands, or 0 where there is none.
//
// THIS IS WHAT PUTS A KEYBOARD ON ITS DESK. gen.corp writes a decoration onto the SAME cell as the
// worktop tile it belongs to, so without this hook every monitor, phone and mug on the floor plate
// sits at y = 0 with three quarters of a metre of carcass in front of it — which is exactly what
// the corp office looked like the first time it was drawn in 3D. Routed through WorldCtx.ground, so
// the actors, the decals, the path line, the tactical grid and the cursor pick all follow for free
  public static function groundY(m:Facility, x:Float, z:Float):Float
    {
      var c = CityConfig.worldToCell(x, z);
      if (!FacilityModel.inside(m, c.col, c.row))
        return 0.0;
      if (m.table[c.row][c.col])
        return topH(m.surf[c.row][c.col]);
      // a basin's tap stands ON the vanity for the same reason; a WC pan stands on the floor, and
      // `fit` cannot tell the two apart — so this asks the same contiguity test the emitter does
      if (m.fit[c.row][c.col] == FIT_FIXTURE &&
          run(m, c.col, c.row))
        return CorpStyle.VANITY_H;
      return 0.0;
    }

// the height of the worktop a room's Surf calls for
  public static inline function topH(s:Surf):Float
    {
      return switch (s)
        {
          case KITCHEN: CorpStyle.COUNTER_H;
          case MEETING: CorpStyle.TABLE_H;
          case WASHROOM: CorpStyle.VANITY_H;
          default: CorpStyle.DESK_H;
        }
    }

// one worktop cell: the slab on top and whatever of its four sides is not buried.
//
// the finish is the ROOM's and not the tile's, which is the whole reason this is one function: the
// generator lays the boardroom slab, the kitchen run and every desk on the floor with the SAME
// table tiles, so the only thing separating a 90 cm counter in dark stone from a 75 cm desk in pale
// laminate is the surface the cell stands on
  static function worktop(m:Facility, col:Int, row:Int, n:CorpFit):Void
    {
      var s = m.surf[row][col];
      var top = CorpStyle.DESK_TOP;
      var side = CorpStyle.DESK_FRONT;
      var end = CorpStyle.DESK_SIDE;
      var tile = CorpStyle.DESK_TILE;
      var sideTile = CorpStyle.DESK_FRONT_TILE;
      switch (s)
        {
          case KITCHEN:
            top = CorpStyle.COUNTER_TOP;
            side = CorpStyle.COUNTER_FRONT;
            end = CorpStyle.COUNTER_FRONT;
            tile = CorpStyle.COUNTER_TILE;
            sideTile = CorpStyle.COUNTER_TILE;
            n.counters++;

          case MEETING:
            top = CorpStyle.TABLE_TOP;
            side = CorpStyle.TABLE_SIDE;
            end = CorpStyle.TABLE_SIDE;
            n.tables++;

          case WASHROOM:
            top = CorpStyle.VANITY_TOP;
            side = CorpStyle.COUNTER_FRONT;
            end = CorpStyle.COUNTER_FRONT;
            sideTile = CorpStyle.COUNTER_TILE;
            // a worktop cell in a washroom is the corner BENCH decorateCorners lays, not part of
            // the basin run — that one is a FIXTURE and is counted where it is emitted
            n.desks++;

          default:
            n.desks++;
        }
      var h = topH(s);
      var r = rect(m, col, row, CorpStyle.FIT_INSET, tableAt);
      FacilityGeom.cap(buf(top), r.x0, r.x1, r.z0, r.z1, h, tile);
      // a run's LONG faces take the drawer front and its two ENDS the blank carcass side, because a
      // desk run's short face is not its drawer bank — the same split FacilityTables records for the
      // compound's own desks. which faces those are is read off the run's neighbours
      var alongX = m.table[row][col - 1] || m.table[row][col + 1];
      for (dir in 0...4)
        {
          if (m.table[row + dz(dir)][col + dx(dir)])
            continue;
          var isEnd = alongX ? (dir >= 2) : (dir < 2);
          FacilityGeom.face(buf(isEnd ? end : side),
            r.x0, r.x1, r.z0, r.z1, dir, 0, h, isEnd ? CorpStyle.DESK_TILE : sideTile);
        }
      ContactMask.prop(r.x0, r.x1, r.z0, r.z1);
    }

// one cubicle spine: a thin fabric panel standing along the pod row's own axis.
//
// the axis is read off the neighbours rather than off the room, because a spine is a three-cell run
// laid by gen.corp.CorpRooms.cubicle and its two desks sit ACROSS it — so the panel has to stand
// along the run, or every pod is divided the wrong way
  static function partition(m:Facility, col:Int, row:Int):Void
    {
      var alongX = spine(m, col - 1, row) || spine(m, col + 1, row);
      var r = rect(m, col, row, 0.0, never);
      var t = CorpStyle.PARTITION_T / 2;
      var cx = (r.x0 + r.x1) / 2;
      var cz = (r.z0 + r.z1) / 2;
      var p = alongX
        ? { x0: r.x0, x1: r.x1, z0: cz - t, z1: cz + t }
        : { x0: cx - t, x1: cx + t, z0: r.z0, z1: r.z1 };
      var b = buf(CorpStyle.PARTITION);
      for (dir in 0...4)
        FacilityGeom.face(b, p.x0, p.x1, p.z0, p.z1, dir, 0, CorpStyle.PARTITION_H,
          CorpStyle.PARTITION_TILE);
      // the trim rail on top is the panel art's own top edge seen end-on, so it takes the same
      // sheet rather than a second one — 0.4 of a unit of it, which is what a cap this thin shows
      FacilityGeom.cap(b, p.x0, p.x1, p.z0, p.z1, CorpStyle.PARTITION_H, CorpStyle.PARTITION_TILE);
      ContactMask.prop(p.x0, p.x1, p.z0, p.z1);
    }

  public static inline function spine(m:Facility, col:Int, row:Int):Bool
    {
      return FacilityModel.inside(m, col, row) && m.fit[row][col] == FIT_SPINE;
    }

// one server cabinet: the equipment face toward the aisle, plain perforated steel everywhere else.
//
// the FRONT maps 0..1 over the face and everything else tiles, which is the split
// docs/3d-geometry.md draws: the front is one authored composition (three cabinets of eight units,
// with placed status lights) and the sides are a material. That locks the front face's aspect to
// the art's, and the art is square — which is why RACK_H is CELL, i.e. 2 m, a real cabinet height
  static function rack(m:Facility, col:Int, row:Int):Void
    {
      // the aisle is whichever neighbour is open floor, and the search order is not arbitrary: +z
      // FIRST, because this camera rests with no yaw of its own and a rank whose equipment face
      // looks any other way shows the player its back. The rows run across the room's short axis,
      // so there is an aisle on at least one side by construction
      var front = 1;
      for (dir in FRONTS)
        if (!rackAt(m, col + dx(dir), row + dz(dir)) &&
            FacilityModel.inside(m, col + dx(dir), row + dz(dir)))
          {
            front = dir;
            break;
          }
      var r = rect(m, col, row, CorpStyle.FIT_INSET, rackAt);
      // pulled back off the aisle so the rank stands against the wall it backs onto and the front
      // face is the one the player walks up to
      var d = CELL - CorpStyle.RACK_D - 2 * CorpStyle.FIT_INSET;
      switch (front)
        {
          case 0: r.z1 -= d;
          case 1: r.z0 += d;
          case 2: r.x1 -= d;
          default: r.x0 += d;
        }
      var side = buf(CorpStyle.RACK_SIDE);
      FacilityGeom.cap(buf(CorpStyle.RACK_TOP), r.x0, r.x1, r.z0, r.z1, CorpStyle.RACK_H,
        CorpStyle.RACK_TILE);
      for (dir in 0...4)
        {
          if (dir == front)
            continue;
          if (rackAt(m, col + dx(dir), row + dz(dir)))
            continue;
          FacilityGeom.face(side, r.x0, r.x1, r.z0, r.z1, dir, 0, CorpStyle.RACK_H,
            CorpStyle.RACK_TILE);
        }
      FacilityGeom.pane(buf(CorpStyle.RACK_FRONT), r.x0, r.x1, r.z0, r.z1, front, 0,
        CorpStyle.RACK_H);
      ContactMask.prop(r.x0, r.x1, r.z0, r.z1);
    }

  // the order a rack looks for its aisle in: toward the camera, then the two sides, then away
  static final FRONTS = [ 1, 3, 2, 0 ];

  static inline function rackAt(m:Facility, col:Int, row:Int):Bool
    {
      return FacilityModel.inside(m, col, row) && m.fit[row][col] == FIT_RACK;
    }

// one washroom fixture: a vanity where the run carries on beside it, a WC cubicle where it does not
  static function washroom(m:Facility, col:Int, row:Int, n:CorpFit):Void
    {
      var r = rect(m, col, row, CorpStyle.FIT_INSET, fixture);
      if (run(m, col, row))
        {
          // the basin counter, and the mirror band on the masonry behind it
          var alongX = fixture(m, col - 1, row) || fixture(m, col + 1, row);
          FacilityGeom.cap(buf(CorpStyle.VANITY_TOP), r.x0, r.x1, r.z0, r.z1, CorpStyle.VANITY_H,
            CorpStyle.COUNTER_TILE);
          for (dir in 0...4)
            {
              if (fixture(m, col + dx(dir), row + dz(dir)))
                continue;
              FacilityGeom.face(buf(CorpStyle.COUNTER_FRONT), r.x0, r.x1, r.z0, r.z1, dir, 0,
                CorpStyle.VANITY_H, CorpStyle.COUNTER_TILE);
            }
          n.basins++;
          // the mirror goes on whichever face looks at masonry, which is the run's own back. it
          // hangs on FacilityGeom.slab's face and not on the cell boundary — a corp wall slab is a
          // unit inside its cell, and a quad on the boundary would float half a cell off it
          for (dir in 0...4)
            {
              if (alongX == (dir >= 2))
                continue;
              if (!FacilityModel.isWall(m, col + dx(dir), row + dz(dir)))
                continue;
              var f = FacilityGeom.plane(FacilityGeom.slab(m, col, row), dir, MIRROR_EPS);
              FacilityGeom.face(buf(CorpStyle.MIRROR), f.x0, f.x1, f.z0, f.z1, dir ^ 1,
                CorpStyle.MIRROR_Y0, CorpStyle.MIRROR_Y1, CorpStyle.MIRROR_TILE);
              n.mirrors++;
            }
          ContactMask.prop(r.x0, r.x1, r.z0, r.z1);
          return;
        }
      // a WC cubicle: two dividers and a back, and NO LID over it — at this camera's 51 degrees the
      // top is most of what is read, so a cap would hide the pan inside and the whole thing would
      // come out a closed slab (docs/3d-geometry.md)
      var alongX = FacilityModel.isWall(m, col, row - 1) || FacilityModel.isWall(m, col, row + 1);
      var b = buf(CorpStyle.STALL_PANEL);
      var t = CorpStyle.STALL_T / 2;
      for (dir in 0...4)
        {
          // the two dividers stand on the cell's own sides, across the run
          if (alongX != (dir >= 2))
            continue;
          var p = dir == 2
            ? { x0: r.x0, x1: r.x0 + 2 * t, z0: r.z0, z1: r.z1 }
            : (dir == 3
              ? { x0: r.x1 - 2 * t, x1: r.x1, z0: r.z0, z1: r.z1 }
              : (dir == 0
                ? { x0: r.x0, x1: r.x1, z0: r.z0, z1: r.z0 + 2 * t }
                : { x0: r.x0, x1: r.x1, z0: r.z1 - 2 * t, z1: r.z1 }));
          for (d2 in 0...4)
            FacilityGeom.face(b, p.x0, p.x1, p.z0, p.z1, d2, 0, CorpStyle.STALL_H,
              CorpStyle.PARTITION_TILE);
          FacilityGeom.cap(b, p.x0, p.x1, p.z0, p.z1, CorpStyle.STALL_H, CorpStyle.PARTITION_TILE);
        }
      n.stalls++;
      ContactMask.prop(r.x0, r.x1, r.z0, r.z1);
    }

  public static inline function fixture(m:Facility, col:Int, row:Int):Bool
    {
      return FacilityModel.inside(m, col, row) && m.fit[row][col] == FIT_FIXTURE;
    }

// is this fixture part of a RUN, i.e. a basin counter rather than a WC cubicle? gen.corp.CorpRooms
// .toilet lays the basins as a continuous run along the room's top wall and the stalls every OTHER
// cell along its bottom one, so contiguity IS the distinction and nothing has to be persisted
  public static inline function run(m:Facility, col:Int, row:Int):Bool
    {
      return fixture(m, col - 1, row) ||
        fixture(m, col + 1, row) ||
        fixture(m, col, row - 1) ||
        fixture(m, col, row + 1);
    }

  // how far the mirror stands proud of the wall slab. over FacilityGrime's damp band and under
  // FacilityDetail's halos, so it draws over the wall and nothing draws over it
  static inline var MIRROR_EPS = 0.06;

  static inline var CELL = CityConfig.CELL;

// one cell's world rect, pulled in by `inset` on every OPEN hand and on none of the hands where
// the same fitting carries on.
//
// THE PREDICATE IS WHY THIS IS NOT A CONSTANT INSET. A boardroom slab is five cells by five and a
// desk run is three, and with every cell pulled in on all four hands the top caps stop touching:
// the first build drew the boardroom as a GRID OF SEPARATE SLABS with a dark groove between each
// pair. Inset only where the run really ends and a run is one unbroken top again
  static function rect(m:Facility, col:Int, row:Int, inset:Float,
      same:(Facility, Int, Int) -> Bool):Rect
    {
      var half = (CityConfig.GRID * CELL) / 2;
      return {
        x0: col * CELL - half + (same(m, col - 1, row) ? 0 : inset),
        x1: (col + 1) * CELL - half - (same(m, col + 1, row) ? 0 : inset),
        z0: row * CELL - half + (same(m, col, row - 1) ? 0 : inset),
        z1: (row + 1) * CELL - half - (same(m, col, row + 1) ? 0 : inset),
      };
    }

// the run predicates the rect above is cut against, one per family
  static inline function tableAt(m:Facility, col:Int, row:Int):Bool
    {
      return FacilityModel.inside(m, col, row) && m.table[row][col];
    }

  static inline function never(m:Facility, col:Int, row:Int):Bool
    {
      return false;
    }

// the neighbour a face direction looks at — FacilityGeom.ends' own numbering (0 -z, 1 +z, 2 -x, 3 +x)
  static inline function dx(dir:Int):Int
    {
      return (dir == 2 ? -1 : (dir == 3 ? 1 : 0));
    }

  static inline function dz(dir:Int):Int
    {
      return (dir == 0 ? -1 : (dir == 1 ? 1 : 0));
    }

// the buffer for one texture, made on first use. keyed by TEXTURE and not by family, so two
// fittings in the same material share a draw call
  static function buf(tex:String):MeshBuf
    {
      var b = bufs.get(tex);
      if (b == null)
        {
          b = MeshBufTools.make();
          bufs.set(tex, b);
        }
      return b;
    }
}
