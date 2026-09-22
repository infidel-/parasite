package render.corp;

import Const;
import citygen.CityConfig;
import three.Three;
import render.facility.FacilityCable;
import render.facility.FacilityDeco;
import render.facility.FacilityGeom;
import render.facility.FacilityGeom.Rect;
import render.facility.FacilityStyle;
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
  var partitions: Int;  // cubicle panels, one per boundary between two pods
  var racks: Int;       // server cabinets
  var basins: Int;      // washroom vanity cells
  var stalls: Int;      // WC cubicle cells
  var mirrors: Int;     // mirror panels over the vanity
  var leds: Int;        // blinking status specks on the rack fronts
  var cables: Int;      // cable drapes between the cabinets of a rank
}

// ONE EMITTED CUBICLE PANEL, for the two passes that dress it.
//
// collected as it is drawn rather than re-derived, because the boundary arithmetic belongs in the
// one file that owns it — render.corp.CorpClutter pins things to these and render.corp.CorpSigns
// hangs the occasional poster
typedef CorpPanel = {
  var x0: Float;      // the panel's world rect, PARTITION_T thick across its short axis
  var x1: Float;
  var z0: Float;
  var z1: Float;
  var alongX: Bool;   // does the run follow x? false means it follows z
  var seed: Int;      // the panel's own roll, off its cell and the hand it stands on
  var pod0: Bool;     // is the cell on the - hand a worker's desk? false means open floor
  var pod1: Bool;     // and the cell on the + hand
  var aisle0: Bool;   // is the cell on the - hand floor somebody walks on? masonry says no
  var aisle1: Bool;   // and the cell on the + hand
}

// what a cubicle panel is, apart from its rect: the run's axis and which of its two hands looks at
// a worker's desk rather than at the passage. ONE ARG AND NOT THREE — it is the whole of what
// `podPanel` copies into the CorpPanel it pushes, and the dressing passes read nothing else
typedef PodHands = {
  var alongX: Bool;   // does the run follow x? false means it follows z
  var lo: Bool;       // the - hand (z0 for an x run, x0 for a z run): a desk, or open floor?
  var hi: Bool;       // and the + hand
  var loOpen: Bool;   // and if it is not a desk, is it the PASSAGE rather than masonry or a fitting?
  var hiOpen: Bool;
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
  // the furniture codes ShellOpts.fitOf deals into Facility.fit. 0 is nothing.
  //
  // 1 WAS `FIT_SPINE`, a cubicle partition standing on a cell of its own, and both it and the cell
  // are gone: gen.corp.CorpRooms.cubicle puts the two desk rows back to back and `divider` emits
  // the panel on the boundary they share. The code is left unused rather than renumbered, because
  // 2 and 3 are read out of grids that already exist
  public static inline var FIT_RACK = 2;     // a server cabinet
  public static inline var FIT_FIXTURE = 3;  // a washroom basin or WC cubicle

  // the buffers, keyed by the texture they will be merged under
  static var bufs:Map<String, MeshBuf>;
  // and the two the server room adds, which are NOT keyed by texture because neither is a mapped
  // lambert: the lights are one additive vertex-coloured mesh with a blink folded into it, and the
  // cable is the compound's own ribbon art (the one reuse the port's brief allows outright)
  static var leds:MeshBuf;
  static var cables:MeshBuf;
  // and what the decoration pass emitted into them, read back by CorpArea for __corp()
  public static var deco(default, null):CorpDeco.CorpDecoSet;
  // every cubicle panel this build emitted, for the two passes that dress it. REBUILT here rather
  // than drained by its readers, because both of them want the whole list
  public static var panels(default, null):Array<CorpPanel> = [];

// emit every fitting on the floor plate
  public static function build(scene:Scene, m:Facility, ?area:game.AreaGame):CorpFit
    {
      bufs = new Map();
      leds = MeshBufTools.make();
      cables = MeshBufTools.make();
      panels = [];
      var n:CorpFit = {
        desks: 0,
        counters: 0,
        tables: 0,
        partitions: 0,
        racks: 0,
        basins: 0,
        stalls: 0,
        mirrors: 0,
        leds: 0,
        cables: 0,
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
                case FIT_RACK:
                  rack(m, col, row);
                  n.racks++;

                case FIT_FIXTURE:
                  washroom(m, col, row, n);

                default:
              }
          }
      // the casework the tower's own decoration objects stand for, into these SAME buffers so a
      // cabinet, a fridge and a vending machine cost no draw call of their own — see CorpDeco
      deco = {
        silenced: CorpDeco.silenced(area),
        cabinets: 0,
        fridges: 0,
        vendings: 0,
        boards: 0,
        bins: 0,
      };
      CorpDeco.casework(m, area, deco);
      // AND ALL OF IT CASTS. The tower has no moon over it, which is why every glb batch on the
      // plate opted out — but the ceiling fixtures are real SpotLights out of the shared pool and
      // eight of its twelve slots carry a shadow map. A cubicle farm is a maze of 2.8-unit walls
      // under a lattice of downlights and it was throwing nothing at all.
      //
      // it is not a per-frame cost: render.particles.LampLights holds the caster slots at
      // shadow.autoUpdate = false, so a map re-renders only when its slot changes owner
      for (tex in bufs.keys())
        FacilityGeom.add(scene, bufs.get(tex), tex, true, true);
      // ONE additive mesh for every blinking speck in the room and ONE for every cable in it, both
      // shared with the compound: render.facility.FacilityDeco.lamps folds in the blink shader and
      // the clock it references BY IDENTITY, so the whole server room's lights cost one draw call
      // and no per-frame work beyond FacilityDeco.tick
      n.leds = Std.int(leds.idx.length / 6);
      n.cables = Std.int(cables.idx.length / 6);
      FacilityDeco.lamps(scene, leds);
      FacilityGeom.add(scene, cables, FacilityStyle.CABLE_TEX, true, false);
      bufs = null;
      leds = null;
      cables = null;
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
      var endTile = CorpStyle.DESK_TILE;
      switch (s)
        {
          case KITCHEN:
            top = CorpStyle.COUNTER_TOP;
            side = CorpStyle.COUNTER_FRONT;
            end = CorpStyle.COUNTER_FRONT;
            tile = CorpStyle.COUNTER_TILE;
            sideTile = CorpStyle.COUNTER_TILE;
            endTile = CorpStyle.COUNTER_TILE;
            n.counters++;

          // A BOARDROOM TABLE COMES BACK Surf.CARPET AND NOT Surf.MEETING, which is why this
          // branch was dead for its whole life: the table is laid as DARK_TABLE_CARPET_3X3, a
          // table tile whose FLOOR is carpet, so FacilityModel.themeRooms spreads CARPET over its
          // cells — measured, 0 of 245 worktop cells on a plate are MEETING while 109 are CARPET.
          // Every boardroom table in the tower was wearing the DESK laminate, at the desk's own
          // tile period, with its two end faces at DESK_FRONT_TILE — a drawer pitch on a table edge
          case MEETING | CARPET:
            top = CorpStyle.TABLE_TOP;
            side = CorpStyle.TABLE_SIDE;
            end = CorpStyle.TABLE_SIDE;
            tile = CorpStyle.TABLE_TILE;
            sideTile = CorpStyle.TABLE_TILE;
            endTile = CorpStyle.TABLE_TILE;
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
      // AN OPEN-PLAN OR CUBICLE DESK IS A GLB NOW and emits nothing here — render.corp.CorpProps
      // stands `corp/desk-bench` on this cell instead. Reported from the game as "just a cuboid",
      // which a slab of quads is: a desk is a thin top on a frame with a void under it, and no
      // amount of per-face art puts a void in a box. The cell is still counted and still stamps
      // the contact field, because both are about the FOOTPRINT and not about who draws it.
      //
      // `!slabTop` IS LOAD-BEARING and its absence was a reported bug: render.corp.CorpProps.tables
      // stands the bench on `deskCell && !slabTop` and falls through to the blade leg otherwise,
      // so a cell that is BOTH bailed out here and took no bench there — nothing drawn at all,
      // while CorpClutter (which asks m.table alone) went on laying decals at the desk's own top
      // height. Seen from the game as clutter floating over empty floor. The two predicates have
      // to be the same one
      if (deskCell(m, col, row) &&
          !slabTop(m, col, row))
        {
          ContactMask.prop(r.x0, r.x1, r.z0, r.z1);
          if (s == Surf.CUBICLE)
            divider(m, col, row, n);
          return;
        }
      FacilityGeom.cap(buf(top), r.x0, r.x1, r.z0, r.z1, h, tile);
      // a run's LONG faces take the drawer front and its two ENDS the blank carcass side, because a
      // desk run's short face is not its drawer bank — the same split FacilityTables records for the
      // compound's own desks. which faces those are is read off the run's neighbours
      //
      // and a BOARDROOM or EXECUTIVE slab shows only a FASCIA. Those tables are 3x2 and 3x3 blocks
      // of table tile, i.e. one big top, and a box under a 6 m top is a plinth the size of a car.
      // The slab keeps its cap and TABLE_FASCIA of edge; `corp/table-leg` stands under it
      var alongX = m.table[row][col - 1] || m.table[row][col + 1];
      var y0 = (slabTop(m, col, row) ? h - CorpStyle.TABLE_FASCIA : 0.0);
      for (dir in 0...4)
        {
          // CULL AGAINST A NEIGHBOUR THAT ACTUALLY DRAWS THE SAME BOX, not merely against
          // `m.table`. A cell whose worktop is a glb emits nothing at all, and a counter at
          // COUNTER_H 1.8 beside a desk at 1.5 does not close one either — in both cases the face
          // was skipped and the carcass came out open-ended, with `rect`'s own inset dropped on
          // that hand too, so the top cap runs to the cell boundary with nothing under its edge
          if (meets(m, col + dx(dir), row + dz(dir), h, y0))
            continue;
          var isEnd = alongX ? (dir >= 2) : (dir < 2);
          FacilityGeom.face(buf(isEnd ? end : side),
            r.x0, r.x1, r.z0, r.z1, dir, y0, h, isEnd ? endTile : sideTile);
        }
      ContactMask.prop(r.x0, r.x1, r.z0, r.z1);
    }

// THE PANELS ROUND ONE POD, and none of them costs a cell.
//
// a cubicle desk is walled on THREE hands — its back, shared with the worker sitting the other way
// in the same block, and both sides, shared with the neighbours beside him. The fourth is the one
// his chair is on, which render.corp.CorpProps.backHand derives from the same grid by taking the
// first hand that is not clear floor: the two agree by construction and neither has to be told.
//
// THE BACK USED TO BE A SPINE ON A CELL OF ITS OWN and the sides were emitted only BETWEEN two
// pods, so the outermost desk of every block had open flanks and the two rows were four units
// apart with a tenth of a unit of panel floating in the middle of the gap. Every boundary a pod
// owns is panelled now, drawn exactly once: the + hands always, the - x hand only where the
// neighbour is not itself a pod (an interior boundary is its neighbour's + hand)
  static function divider(m:Facility, col:Int, row:Int, n:CorpFit):Void
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var t = CorpStyle.PARTITION_T / 2;
      var b = buf(CorpStyle.PARTITION);
      var x0 = col * CELL - half;
      var x1 = (col + 1) * CELL - half;
      var z0 = row * CELL - half;
      var z1 = (row + 1) * CELL - half;
      // the two side panels, and the back, which is the + z hand for the row facing - z and the
      // neighbour's own + z hand for the row facing + z.
      //
      // THE BACK STOPS AT THE SIDE PANELS' OUTER FACES (x0 + t .. x1 - t) and does not span the
      // whole cell. Its lid and theirs both sit at PARTITION_H, so a full-cell back put a
      // 0.1 x 0.1 coplanar square at every crossing and the two trim rails z-fought there. The
      // corner it gives up is already covered: a side panel spans the FULL z cell, and the next
      // row's own side panel picks the run up on the other side of the boundary
      if (!podCell(m, col - 1, row))
        n.partitions += podPanel(b, { x0: x0 - t, x1: x0 + t, z0: z0, z1: z1 },
          seed(col, row, 2), {
            alongX: false,
            lo: false,
            hi: true,
            loOpen: walkCell(m, col - 1, row),
            hiOpen: false,
          });
      n.partitions += podPanel(b, { x0: x1 - t, x1: x1 + t, z0: z0, z1: z1 },
        seed(col, row, 3), {
          alongX: false,
          lo: true,
          hi: podCell(m, col + 1, row),
          loOpen: false,
          hiOpen: walkCell(m, col + 1, row),
        });
      if (podCell(m, col, row + 1))
        n.partitions += podPanel(b, { x0: x0 + t, x1: x1 - t, z0: z1 - t, z1: z1 + t },
          seed(col, row, 1), {
            alongX: true,
            lo: true,
            hi: true,
            loOpen: false,
            hiOpen: false,
          });
    }

// one panel's own roll, off the cell it hangs on and which hand of it. the dressing passes are
// pure functions of this list, so nothing they choose may come off Math.random or off the order
// they happened to run in
  static inline function seed(col:Int, row:Int, hand:Int):Int
    {
      return FacilityModel.mix((col * 668265263) ^ (row * 1103515245) ^ (hand * 40503));
    }

// WHICH WAY DOES THIS FACE LOOK — at a worker's desk, or at the passage?
//
// the two dressing passes split on this and on nothing else: the desk side is that worker's own
// wall and carries what he pinned to it, the passage side is the company's and carries the
// propaganda. It used to be an 8% roll off the panel's seed, which hung posters facing a monitor
// half a metre away and left aisle faces blank.
//
// still asked by BOTH passes and cached by neither, the discipline CorpProps.claims' own header
// sets out — but now the shared thing is the GRID, which cannot drift from itself the way a
// shared hash could
  public static inline function podFace(p:CorpPanel, side:Int):Bool
    {
      return (side == 0 ? p.pod0 : p.pod1);
    }

// and the other half of the same question: does this face look at the PASSAGE?
//
// not the complement of `podFace` — the third answer is masonry or a fitting, which the block on
// the edge of a farm has on its outer flank and which carries nothing at all
  public static inline function aisleFace(p:CorpPanel, side:Int):Bool
    {
      return (side == 0 ? p.aisle0 : p.aisle1);
    }

// does this face carry the COMPANY'S poster rather than the worker's own pinned clutter?
//
// the one predicate both dressing passes split the passage side on, so neither can put its own
// thing where the other already has: render.corp.CorpSigns hangs a poster where this is true and
// render.corp.CorpClutter scatters where it is false. Every eligible face used to take one, which
// is 50 posters in a farm and reads as a gallery — see CorpStyle.PANEL_POSTER_PCT
  public static inline function panelPoster(p:CorpPanel, side:Int):Bool
    {
      return aisleFace(p, side) &&
        FacilityModel.mix(p.seed ^ ((side + 1) * 374761393)) % 100 <
          CorpStyle.PANEL_POSTER_PCT;
    }

// is this cell one worker's desk in a cubicle farm?
  static inline function podCell(m:Facility, col:Int, row:Int):Bool
    {
      return FacilityModel.inside(m, col, row) &&
        m.table[row][col] &&
        m.surf[row][col] == Surf.CUBICLE;
    }

// is this cell floor somebody can walk on — the passage, rather than masonry or a fitting?
  static inline function walkCell(m:Facility, col:Int, row:Int):Bool
    {
      return FacilityModel.inside(m, col, row) &&
        !FacilityModel.isWall(m, col, row) &&
        !m.table[row][col] &&
        m.fit[row][col] == 0;
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
      // the status lights, on the SAME face the equipment art is on and over its own painted dots
      FacilityDeco.lights(leds, {
        x0: r.x0,
        x1: r.x1,
        z0: r.z0,
        z1: r.z1,
        y: CorpStyle.LED_Y0,
        h: CorpStyle.LED_H,
        dir: front,
        col: col,
        row: row,
        u0: CorpStyle.LED_U0,
        u1: CorpStyle.LED_U1,
        rows: CorpStyle.LED_ROWS,
        cols: CorpStyle.LED_COLS,
        size: CorpStyle.LED_SIZE,
      });
      drape(m, r, col, row);
      ContactMask.prop(r.x0, r.x1, r.z0, r.z1);
    }

// the cable drape from this cabinet's lid to the next one's along the rank.
//
// ON THE TOPS AND NOT ON THE FLOOR, which is the one decision here: a raised-access computer room
// runs its cable UNDER the floor by definition, so the only cable a server room actually shows is
// what is patched between cabinet and cabinet over the top — and the floor is where the player
// walks. Emitted from the LOWER cell of each pair only (+x and +z), so a rank of five draws four
// runs and not eight.
//
// ponytail: no drop to a tray and no run to the wall. Those want a tray to hang off, which is a
// fitting the room does not have yet; add both with it
  static function drape(m:Facility, r:Rect, col:Int, row:Int):Void
    {
      var y = CorpStyle.RACK_H + CorpStyle.CABLE_Y;
      var cx = (r.x0 + r.x1) / 2;
      var cz = (r.z0 + r.z1) / 2;
      for (i in 0...2)
        {
          var nc = col + (i == 0 ? 1 : 0);
          var nr = row + (i == 0 ? 0 : 1);
          if (!rackAt(m, nc, nr))
            continue;
          for (k in 0...CorpStyle.CABLE_N)
            FacilityCable.strip(cables, {
              a: [cx, y + k * 0.02, cz],
              c: [cx + (i == 0 ? CELL : 0.0), y + k * 0.02, cz + (i == 0 ? 0.0 : CELL)],
              // the ribbon lies FLAT, because this camera looks down at it: widened across the run
              // in the horizontal plane and bowed sideways within it. no sag — see CABLE_BOW
              n: [0.0, 1.0, 0.0],
              bow: CorpStyle.CABLE_BOW * (1.0 - k * 0.3),
              wave: CorpStyle.CABLE_WAVE,
              seed: FacilityModel.mix((col * 374761393) ^ (row * 668265263) ^ (i * 7 + k)),
            });
        }
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
      // A WC CUBICLE: two dividers, the back panel against the masonry and a door leaf on the
      // aisle. NO LID over it — at this camera's 51 degrees the top is most of what is read, so a
      // cap would hide the pan inside and the whole thing would come out a closed slab
      // (docs/3d-geometry.md).
      //
      // The header used to say "two dividers and a back" and emit neither the back nor the leaf,
      // which is what was reported: 1.12 world units of daylight behind every stall (the fixture
      // cell's own FIT_INSET 0.12 plus the unit of the WALL CELL that belongs to the room — see
      // `wallFaceAt`), and no door on the cubicle at all
      var alongX = FacilityModel.isWall(m, col, row - 1) || FacilityModel.isWall(m, col, row + 1);
      var b = buf(CorpStyle.STALL_PANEL);
      var t = CorpStyle.STALL_T / 2;
      // which hand the masonry is on, and so which one the player walks up to
      var back = (alongX
        ? (FacilityModel.isWall(m, col, row - 1) ? 0 : 1)
        : (FacilityModel.isWall(m, col - 1, row) ? 2 : 3));
      var w = wallFaceAt(m, col, row, back);
      switch (back)
        {
          case 0: r.z0 = w;
          case 1: r.z1 = w;
          case 2: r.x0 = w;
          default: r.x1 = w;
        }
      for (dir in 0...4)
        {
          // the two dividers stand on the cell's own sides, across the run — and now run all the
          // way back to the masonry, because `r` was widened onto it above
          if (alongX != (dir >= 2))
            continue;
          panel(b, side(r, dir, 2 * t), 0, CorpStyle.STALL_H);
        }
      // the back, on the masonry hand
      panel(b, side(r, back, 2 * t), 0, CorpStyle.STALL_H);
      // and the LEAF, inset a reveal at each jamb and stopped short of the floor.
      //
      // ponytail: every leaf is shut. One standing ajar wants a box turned off the axes, which is
      // the one thing FacilityGeom.face cannot emit — it would take the door leaves' own instanced
      // batch, and a row of cubicles reads perfectly well closed
      var leaf = side(r, back ^ 1, 2 * t);
      var e = CorpStyle.STALL_DOOR_REVEAL;
      if (alongX)
        {
          leaf.x0 += e;
          leaf.x1 -= e;
        }
      else
        {
          leaf.z0 += e;
          leaf.z1 -= e;
        }
      panel(b, leaf, CorpStyle.STALL_DOOR_GAP, CorpStyle.STALL_H);
      n.stalls++;
      ContactMask.prop(r.x0, r.x1, r.z0, r.z1);
    }

// one upright box of panelling: four faces and a lid, in the one buffer
  static function panel(b:MeshBuf, p:Rect, y0:Float, y1:Float):Void
    {
      for (dir in 0...4)
        FacilityGeom.face(b, p.x0, p.x1, p.z0, p.z1, dir, y0, y1, CorpStyle.PARTITION_TILE);
      FacilityGeom.cap(b, p.x0, p.x1, p.z0, p.z1, y1, CorpStyle.PARTITION_TILE);
    }

// one cubicle panel, standing on a boundary between two cells: four faces, the trim rail on top,
// its footprint in the contact field and its rect in the list the dressing passes read. returns 1,
// so a caller can count panels by summing
  static function podPanel(b:MeshBuf, p:Rect, key:Int, h:PodHands):Int
    {
      for (dir in 0...4)
        FacilityGeom.face(b, p.x0, p.x1, p.z0, p.z1, dir, 0, CorpStyle.PARTITION_H,
          CorpStyle.PARTITION_TILE);
      capTrim(b, p, CorpStyle.PARTITION_H, h.alongX);
      ContactMask.prop(p.x0, p.x1, p.z0, p.z1);
      panels.push({
        x0: p.x0,
        x1: p.x1,
        z0: p.z0,
        z1: p.z1,
        alongX: h.alongX,
        seed: key,
        pod0: h.lo,
        pod1: h.hi,
        aisle0: h.loOpen,
        aisle1: h.hiOpen,
      });
      return 1;
    }

// THE PANEL'S LID, which FacilityGeom.cap cannot draw and was drawing anyway.
//
// `cap` is world-aligned on BOTH axes (u = x / t, v = z / t), which is right for a floor and wrong
// for a 0.1-thick rail: the top came out wearing a 0.036-wide slice of the panel's own ELEVATION,
// taken at whatever world z the run happened to sit at. Probed in the game at u 8.571..10.0,
// v -44.964..-45.036 — an elevation lying down, the fault art/textures.json records the washroom
// counter's lid hitting from the other end.
//
// corp/partition is drawn with "a slim darker aluminium trim strip along the very TOP edge only",
// so the strip the lid wants is already on the sheet. u follows the RUN and world-tiles as the
// faces do; v is pinned to that top band, as deep in texels as the panel is thick in world. No
// second texture and no second buffer, which is what the counter's lid had to buy
  static function capTrim(b:MeshBuf, p:Rect, y:Float, alongX:Bool):Void
    {
      var t = CorpStyle.PARTITION_TILE;
      // flipY puts the image's own TOP edge at v = 1
      var v0 = 1 - CorpStyle.PARTITION_T / t;
      var u0 = (alongX ? p.x0 : p.z0) / t;
      var u1 = (alongX ? p.x1 : p.z1) / t;
      // cap's winding, so the face looks UP; the uv of vertex i is the pair at 2i
      MeshBufTools.quad(b, [p.x0, y, p.z1], [p.x1, y, p.z1], [p.x1, y, p.z0], [p.x0, y, p.z0],
        alongX ?
          [u0, v0, u1, v0, u1, 1.0, u0, 1.0] :
          [u1, v0, u1, 1.0, u0, 1.0, u0, v0]);
    }

// the slice of a rect `d` thick along one of its hands — the panel that closes that side
  static function side(r:Rect, dir:Int, d:Float):Rect
    {
      return switch (dir)
        {
          case 0: { x0: r.x0, x1: r.x1, z0: r.z0, z1: r.z0 + d };
          case 1: { x0: r.x0, x1: r.x1, z0: r.z1 - d, z1: r.z1 };
          case 2: { x0: r.x0, x1: r.x0 + d, z0: r.z0, z1: r.z1 };
          default: { x0: r.x1 - d, x1: r.x1, z0: r.z0, z1: r.z1 };
        };
    }

// WHERE THE MASONRY ACTUALLY IS on one hand of a cell, in world.
//
// NOT the cell boundary, which is the trap this whole file's fittings share: a corp wall is
// WALL_T 2.0 thick in a CELL 4.0 cell, so FacilityGeom.slab leaves a unit of the WALL cell to
// each room beside it and the painted face stands a unit past the boundary. A panel run to the
// boundary stops 1.0 short of it, and with the fitting's own FIT_INSET on top that is the 1.12
// of daylight the stalls were reported to have
  static function wallFaceAt(m:Facility, col:Int, row:Int, dir:Int):Float
    {
      var s = FacilityGeom.slab(m, col + dx(dir), row + dz(dir));
      return switch (dir)
        {
          case 0: s.z1;
          case 1: s.z0;
          case 2: s.x1;
          default: s.x0;
        };
    }

// is this worktop cell drawn as a glb desk rather than emitted?
//
// OPEN and CUBICLE are the two the generator lays as desk RUNS and they were always glb — a
// kitchen counter, a boardroom slab and a washroom vanity are runs with a continuous top, where a
// module per cell would put a seam between every pair.
//
// THE THIRD CASE IS A LONE WORKTOP, and it is the one reported back as a quad desk that still
// looks like one: a single table cell with no neighbour on any hand emitted a CLOSED CUBOID of
// 3.76 x 3.76 x 1.5 — two metres square and three quarters of a metre high, solid. A desk is a
// thin top on a frame with a void under it and no per-face art puts a void in a box, which is the
// verdict that moved the open-plan desks to a glb in the first place. A counter and a vanity are
// excluded: a plinthed carcass IS a box and is right as one
  public static function deskCell(m:Facility, col:Int, row:Int):Bool
    {
      var s = m.surf[row][col];
      if (s == Surf.OPEN ||
          s == Surf.CUBICLE)
        return true;
      if (s == Surf.KITCHEN ||
          s == Surf.WASHROOM)
        return false;
      return !tableAt(m, col - 1, row) &&
        !tableAt(m, col + 1, row) &&
        !tableAt(m, col, row - 1) &&
        !tableAt(m, col, row + 1);
    }

// does the neighbour on this hand CLOSE the carcass — an emitted worktop at the same height with
// the same fascia line? see the call site for the three ways `m.table` alone got this wrong
  static function meets(m:Facility, col:Int, row:Int, h:Float, y0:Float):Bool
    {
      if (!tableAt(m, col, row) ||
          deskCell(m, col, row))
        return false;
      var hh = topH(m.surf[row][col]);
      var yy = (slabTop(m, col, row) ? hh - CorpStyle.TABLE_FASCIA : 0.0);
      return Math.abs(hh - h) < 0.001 &&
        Math.abs(yy - y0) < 0.001;
    }

// and is this cell part of a big SLAB — a table two cells deep in BOTH axes — which keeps only a
// fascia with a blade leg under it?
//
// THE TEST IS THE SHAPE AND NOT THE SURFACE, which cost a build to find: a boardroom table is laid
// as DARK_TABLE_CARPET_3X3, a table tile whose FLOOR is carpet, so its cells come back
// Surf.CARPET and a `s == MEETING` test matched NOTHING — measured, 0 of 245 worktop cells on this
// plate are Surf.MEETING while 109 are CARPET. Two-dimensional IS the distinction anyway: a desk
// run, a kitchen counter and a vanity are all one cell deep, and a 1x1 credenza against a wall has
// no neighbour at all, so only a real table block answers true
  public static function slabTop(m:Facility, col:Int, row:Int):Bool
    {
      // A DESK IS NEVER A SLAB, WHATEVER ITS SHAPE, and the two-dimensional test below used to
      // take the shape as proof on its own. The cubicle farm's two rows are BACK TO BACK now, so
      // every pod has a table neighbour in both axes and a whole block came out as one boardroom
      // slab — fascia, blade legs, and no partitions on it at all, because `worktop`'s desk branch
      // is also what calls `divider`. Seen in the game as four bare tables with monitors on them
      var s = m.surf[row][col];
      if (s == Surf.OPEN ||
          s == Surf.CUBICLE)
        return false;
      var x = tableAt(m, col - 1, row) || tableAt(m, col + 1, row);
      var z = tableAt(m, col, row - 1) || tableAt(m, col, row + 1);
      if (x && z)
        return true;
      // ...OR A ONE-CELL-DEEP TABLE RUN, which the two-dimensional test misses and which is a real
      // shape: gen.corp.CorpRooms.meetingTable takes `min(room.w - 4, TABLE_W_MAX)` on each axis,
      // so a 5-wide boardroom gets a table ONE cell deep and every cell of it failed this test —
      // full-height sides, no leg, and a 2 m x 0.75 m solid block of table-side art where a
      // boardroom table should be. A DESK run (OPEN/CUBICLE, which stand their own glb per cell)
      // and a COUNTER or VANITY run (a plinthed carcass, correctly a box) are not tables
      if (s != Surf.MEETING &&
          s != Surf.CARPET &&
          s != Surf.EXEC)
        return false;
      return x || z;
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
  public static function buf(tex:String):MeshBuf
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
