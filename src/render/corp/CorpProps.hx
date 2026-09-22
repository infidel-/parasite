package render.corp;

import three.Three;
import citygen.CityConfig;
import render.Models;
import render.RenderConfig;
import render.facility.ClutterSlot;
import render.facility.FacilityDetail;
import render.facility.FacilityGeom;
import render.facility.FacilityGeom.Rect;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.ContactMask;
import render.world.VisionMask;

// what the pass placed, for __corp()
typedef CorpPropSet = {
  var chairs:Int;      // one per manned desk cell
  var monitors:Int;    // and one workstation each, monitor + keyboard
  var plants:Int;
  var coolers:Int;
  var printers:Int;
  var pans:Int;        // WC pans, one per stall
  var desks:Int;       // bench desk modules, one per open-plan / cubicle worktop cell
  var legs:Int;        // blade legs, one per boardroom / executive slab cell
  var bins:Int;        // waste bins, one per CORP_TRASH decoration
};

// one floor-standing family and where it is allowed to stand
typedef FloorProp = {
  var path:String;
  var h:Float;         // world height; render.Models.instanced scales by HEIGHT alone
  var d:Float;         // depth ACROSS the wall it backs onto
  var w:Float;         // and width ALONG it — the other half of the footprint the field darkens
  var on:Surf;         // the floor surface its own scatter fills
  // and the render.corp.CorpDeco kind whose DRESSED cells it also stands on, K_NONE for none.
  // those cells come off the generator's own decoration and are not gated on `on`
  var deco:Int;
  // does the fake indoor reflection go on it? see `batch` — TRUE for anything that is supposed to
  // be metal or lacquer, FALSE for anything organic
  var env:Bool;
};

// the seven glb props of the corp tower: the workstation on a desk, the chair at it, the WC pan in
// a stall, and the three things that stand against a wall.
//
// ONE PASS AND NOT FIVE, which is the same call render.corp.CorpFurniture made for the emitted
// families. A prop pass is a walk of the grid, a hand test and a placement list; splitting it per
// family would clone the walk five times to save nothing, and every one of these has to agree with
// the others about which cell is taken.
//
// WALL-HUGGING, like every standing prop indoors: an actor may clip one only by walking into a
// wall, never by crossing a room. The placement comes off FacilityGeom.slab's own FACE and never
// off the cell boundary — a corp wall slab is centred in its cell, so a prop put on the boundary
// stands a whole unit inside the masonry.
//
// RENDER-ONLY AND UNSTAMPED, the contract render.facility.FacilityKit and FacilityDebris run on:
// nothing is written to the tiles, so a plant is walked straight through and every corp area
// already saved gets its props the moment it is drawn again.
class CorpProps
{
  static inline var CELL = CityConfig.CELL;

  // the four cell-edge directions, in FacilityGeom.face's numbering: 0 = -z, 1 = +z, 2 = -x, 3 = +x
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

  // the three that stand against a wall, each gated on ONE floor surface so no two families can
  // ever want the same cell however they are tuned later — the same no-arbitration trick
  // FacilityKit's header argues for
  static final FLOOR:Array<FloorProp> = [
    {
      path: RenderConfig.MODELS.corpPlant,
      h: CorpStyle.PLANT_H,
      d: CorpStyle.PLANT_W,
      w: CorpStyle.PLANT_W,
      on: Surf.CARPET,
      // AND THE CELLS THE GENERATOR ITSELF DRESSED with a plant — see `standing`
      deco: CorpDeco.K_PLANT,
      // NO REFLECTION ON A PLANT. render.world.PropEnv is a fake environment plus a specular
      // GLINT LOBE and its own header says it is for "the handful of materials that are supposed
      // to be METAL" — applied to a ficus it put a moving highlight across the leaves as the
      // camera turned, reported as the plant glistening. Measured first, because the obvious
      // suspect was the bake: the built albedo is p50 108 / p99 139 / max 162 with 0.0000 of it
      // over 184, the MR map is a rough dielectric (mean 0/253/0, metal max 0) and
      // render.Models.toLambert drops it anyway — there is no specular speck in the ART at all
      env: false,
    },
    {
      path: RenderConfig.MODELS.corpCooler,
      h: CorpStyle.COOLER_H,
      d: CorpStyle.COOLER_W,
      w: CorpStyle.COOLER_W,
      on: Surf.KITCHEN,
      deco: CorpDeco.K_COOLER,
      env: true,
    },
    {
      path: RenderConfig.MODELS.corpPrinter,
      h: CorpStyle.PRINTER_H,
      d: CorpStyle.PRINTER_D,
      w: CorpStyle.PRINTER_W,
      on: Surf.OPEN,
      // AND THE CELLS THE GENERATOR DEALT A PRINTER ONTO. Const.CORP_TABLE_PRINTER is dealt two
      // ways: onto a TABLE tile in the copy room, where the worktop under it is what draws, and
      // onto bare floor in the cubicle farm, where this is. The `standing` loop tells them apart
      // by asking whether the cell is a worktop at all
      deco: CorpDeco.K_PRINTER,
      env: true,
    },
  ];

// every glb batch on the floor plate, and the census of what went into them
  public static function build(scene:Scene, m:Facility, ?area:game.AreaGame):{
      batches:Array<Models.InstancedProp>, n:CorpPropSet }
    {
      var n:CorpPropSet = {
        chairs: 0,
        monitors: 0,
        plants: 0,
        coolers: 0,
        printers: 0,
        pans: 0,
        desks: 0,
        legs: 0,
        bins: 0,
      };
      var chairs = [];
      var mons = [];
      var keys = [];
      var pans = [];
      var benches = [];
      var legs = [];
      var floors = [for (_ in FLOOR) new Array<Models.PropPlace>()];
      var binp = CorpDeco.bins(m, area);
      podBins(m, binp);
      // WHERE THE OLD COMPUTER ICONS STOOD, which is what "put the new ones in their places"
      // asks for literally: gen.corp deals a CORP_COMPUTERS decoration onto the middle cell of
      // every manned desk, and a hash of its own would have put the workstation somewhere else on
      // the same run. A tower with no such objects (an old save, the warm's demo model) falls back
      // to the stride, so the pass is never empty
      var work = new Map<Int, Bool>();
      for (c in CorpDeco.cells(area, CorpDeco.K_WORK))
        work.set(c.row * m.w + c.col, true);
      desks(m, chairs, mons, keys, work);
      tables(m, benches, legs);
      stalls(m, pans);
      standing(m, floors, area);
      n.chairs = chairs.length;
      n.monitors = mons.length;
      n.pans = pans.length;
      n.plants = floors[0].length;
      n.coolers = floors[1].length;
      n.printers = floors[2].length;
      n.desks = benches.length;
      n.legs = legs.length;
      n.bins = binp.length;

      var out = [];
      out.push(batch(scene, RenderConfig.MODELS.corpChair, chairs, CorpStyle.CHAIR_H));
      out.push(batch(scene, RenderConfig.MODELS.corpMonitor, mons, CorpStyle.MON_H));
      out.push(batch(scene, RenderConfig.MODELS.corpKeyboard, keys, CorpStyle.KEY_H));
      out.push(batch(scene, RenderConfig.MODELS.corpWc, pans, CorpStyle.WC_H));
      out.push(batch(scene, RenderConfig.MODELS.corpDesk, benches, CorpStyle.DESK_GLB_H));
      out.push(batch(scene, RenderConfig.MODELS.corpTableLeg, legs, CorpStyle.LEG_H));
      out.push(batch(scene, RenderConfig.MODELS.corpBin, binp, CorpStyle.BIN_H));
      for (i in 0...FLOOR.length)
        out.push(batch(scene, FLOOR[i].path, floors[i], FLOOR[i].h, FLOOR[i].env));
      return {
        batches: out,
        n: n,
      };
    }

// the same batch, for render.corp.CorpClutter's four promoted cells. public only because that pass
// runs AFTER this one (it asks `claims`, which must not depend on having run first) and so cannot
// hand its places back here to be batched with the rest
  public static function clutterBatch(scene:Scene, path:String,
      places:Array<Models.PropPlace>, h:Float):Models.InstancedProp
    {
      return batch(scene, path, places, h);
    }

// one instanced batch, and the three things every indoor batch in this game does behind the loader
// callback — the mesh does not exist until the glb resolves
  static function batch(scene:Scene, path:String, places:Array<Models.PropPlace>,
      h:Float, env:Bool = true):Models.InstancedProp
    {
      var p = Models.instanced(scene, path, places, h, SOLID);
      if (places.length > 0)
        Models.get(path, function(_)
          {
            VisionMask.patchMesh(p.mesh);
            // the room reflected in it — and NOT on everything, which is what `env` is for. the
            // inject works on Lambert (PropEnv's own header says so, twice), so "only the ones
            // that stayed MeshStandard" was never true of it
            if (env)
              render.world.PropEnv.apply(p.mesh.material);
            // AND IT CASTS, off the CEILING FIXTURES. the original reasoning here was the moon's
            // — an instanced batch drawn into a shadow map is a second call the moment the batch is
            // on screen — and a tower floor has no moon over it. True, and it skipped the lights it
            // does have: render.corp.CorpLamps hands render.particles.LampLights a real SpotLight
            // per fitting and eight of the pool's twelve slots cast. Those maps are static
            // (shadow.autoUpdate = false), so the second draw happens when a slot changes owner and
            // not every frame, and a chair with no shadow under it stood in mid air
            p.mesh.castShadow = true;
          });
      return p;
    }

// the workstation and the seat at every manned desk cell.
//
// A DESK'S BACK IS NOT ALWAYS A WALL, which is the one thing this cannot borrow from the compound:
// an open-plan run backs onto a CUBICLE SPINE or onto the next desk, and FacilityTables.wallHand
// only knows about masonry. `backHand` takes the first hand that is not clear floor, so a spine
// serves exactly as a wall does, and the seat is the opposite hand — a desk nobody can sit at is
// not a desk, so it carries nothing at all rather than a monitor with no chair
  static function desks(m:Facility, chairs:Array<Models.PropPlace>, mons:Array<Models.PropPlace>,
      keys:Array<Models.PropPlace>, work:Map<Int, Bool>):Void
    {
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (!m.table[row][col])
              continue;
            var s = m.surf[row][col];
            if (s != Surf.OPEN &&
                s != Surf.CUBICLE &&
                s != Surf.EXEC)
              continue;
            var dir = backHand(m, col, row);
            if (dir < 0 ||
                !clear(m, col + DC[dir ^ 1], row + DR[dir ^ 1]))
              continue;
            var hash = FacilityModel.mix((col * 374761393) ^ (row * 40503));
            var c = CityConfig.cellToWorld(col, row);
            // the seat, in the cell in FRONT of the desk and pulled back toward it. it FACES the
            // desk, which is the hand the desk's back is on
            var cx = c.x + DC[dir ^ 1] * CorpStyle.CHAIR_OUT;
            var cz = c.z + DR[dir ^ 1] * CorpStyle.CHAIR_OUT;
            chairs.push({
              x: cx,
              z: cz,
              yaw: Math.atan2(DC[dir], DR[dir]) +
                (((hash >>> 8) % 1000) / 1000 - 0.5) * 2 * CorpStyle.CHAIR_YAW_JIT,
            });
            ContactMask.prop(cx - CorpStyle.CHAIR_W / 2, cx + CorpStyle.CHAIR_W / 2,
              cz - CorpStyle.CHAIR_W / 2, cz + CorpStyle.CHAIR_W / 2);
            if (!manned(m, work, col, row, hash))
              continue;
            // and the workstation ON the top, which is the room's worktop height and not a
            // constant — a kitchen counter and a boardroom slab are the same table grid
            var y = CorpFurniture.topH(s);
            var back = CorpStyle.DESK_TOP_D / 2 - CorpStyle.MON_BACK;
            mons.push({
              x: c.x + DC[dir] * back,
              z: c.z + DR[dir] * back,
              // the screen's BACK is on the desk's back hand, so its front looks the other way
              yaw: Math.atan2(DC[dir ^ 1], DR[dir ^ 1]),
              y: y,
            });
            keys.push({
              x: c.x + DC[dir] * (back - CorpStyle.KEY_FWD),
              z: c.z + DR[dir] * (back - CorpStyle.KEY_FWD),
              yaw: Math.atan2(DC[dir ^ 1], DR[dir ^ 1]),
              y: y,
            });
            // AND THE SHADOW EACH OF THEM SITS IN. Nothing on this plate casts (see `batch`), and
            // render.world.ContactMask is one top-down field over the FLOOR, so it cannot reach a
            // screen standing 1.5 units up on a desk — the monitor was the one thing in the room
            // with no contact of any kind under it. render.facility.FacilityDetail.pool is the
            // square-cornered ramp the compound's own workstation uses, and square is the point:
            // FacilityWork's header records a round one on a 16:9 panel reading as no shadow at
            // all. `claims` is the oracle for the two footprints, so neither pass may drift
            var plate:Rect = {
              x0: c.x - CELL / 2 + CorpStyle.FIT_INSET,
              x1: c.x + CELL / 2 - CorpStyle.FIT_INSET,
              z0: c.z - CELL / 2 + CorpStyle.FIT_INSET,
              z1: c.z + CELL / 2 - CorpStyle.FIT_INSET,
            };
            for (b in claims(m, col, row))
              FacilityDetail.pool({
                cx: b.x,
                cz: b.z,
                hw: b.hw,
                hd: b.hd,
                // the extents come off `claims` already turned into world axes, so the quad must
                // not be turned a second time
                yaw: 0.0,
                y: y,
                plate: plate,
              });
          }
    }

// A BIN BESIDE EVERY CUBICLE DESK, in the corner of the aisle it faces.
//
// the farm used to get ONE bin per block, on an unwalkable cell of its own where the passage met
// the aisle, at a 50% roll — a piece of floor spent on a piece of dressing. This is render-only:
// no cell, no decoration, no save, and it rides the batch CorpDeco.bins already fills, so it costs
// no draw call either.
//
// IT USED TO STAND UNDER THE DESK, WHERE NOTHING COULD SEE IT. `corp/desk-bench` is not a top on
// legs: models-src/corp/desk_build.py hangs a PED_W 1.06 pedestal off one end of a 3.76 carcass,
// and an offset of CELL / 2 - BIN_W / 2 - FIT_INSET = 1.57 stands a 0.62 bin inside it. It goes in
// the AISLE cell now, past the desk's own boundary and off to one hand so it misses the chair —
// which is where an office really keeps it. The hand is the WORLD's and not the desk's, because a
// farm whose bins mirror with each row's facing reads as clutter rather than as an office
  static function podBins(m:Facility, out:Array<Models.PropPlace>):Void
    {
      // just past the desk cell's boundary, and off to one hand by the inset the seat keeps
      var fwd = CELL / 2 + CorpStyle.BIN_W / 2;
      var off = CELL / 2 - CorpStyle.BIN_W / 2 - CorpStyle.FIT_INSET;
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (!FacilityModel.inside(m, col, row) ||
                !m.table[row][col] ||
                m.surf[row][col] != Surf.CUBICLE)
              continue;
            var dir = backHand(m, col, row);
            if (dir < 0 ||
                !clear(m, col + DC[dir ^ 1], row + DR[dir ^ 1]))
              continue;
            var c = CityConfig.cellToWorld(col, row);
            // dir ^ 1 is the hand the chair is on; the bin's own offset is ACROSS it
            var px = (dir < 2 ? -1.0 : 0.0);
            var pz = (dir < 2 ? 0.0 : -1.0);
            var x = c.x + DC[dir ^ 1] * fwd + px * off;
            var z = c.z + DR[dir ^ 1] * fwd + pz * off;
            out.push({
              x: x,
              z: z,
              yaw: 0.0,
            });
            ContactMask.prop(x - CorpStyle.BIN_W / 2, x + CorpStyle.BIN_W / 2,
              z - CorpStyle.BIN_W / 2, z + CorpStyle.BIN_W / 2);
          }
    }

// a WC pan in every stall, backed onto the cubicle's own masonry.
//
// the stall is the fixture cell that is NOT part of a run — the same contiguity test CorpFurniture
// .washroom splits basins from cubicles with, asked again rather than cached, because both passes
// are pure functions of the saved grid and neither may depend on having run first
  static function stalls(m:Facility, pans:Array<Models.PropPlace>):Void
    {
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (!CorpFurniture.fixture(m, col, row) ||
                CorpFurniture.run(m, col, row))
              continue;
            var dir = -1;
            for (d in 0...4)
              if (FacilityModel.isWall(m, col + DC[d], row + DR[d]))
                {
                  dir = d;
                  break;
                }
            if (dir < 0)
              continue;
            // off the wall's own slab face, with the cistern's back on it: WC_D is what the mesh
            // was built to, so half of it plus the gap is where the centre goes
            var sl = FacilityGeom.slab(m, col + DC[dir], row + DR[dir]);
            var off = CorpStyle.WC_D / 2 + CorpStyle.PROP_GAP;
            var c = CityConfig.cellToWorld(col, row);
            var x = (dir == 2 ? sl.x1 + off : (dir == 3 ? sl.x0 - off : c.x));
            var z = (dir == 0 ? sl.z1 + off : (dir == 1 ? sl.z0 - off : c.z));
            pans.push({
              x: x,
              z: z,
              yaw: Math.atan2(DC[dir ^ 1], DR[dir ^ 1]),
            });
            var pw = (dir < 2 ? CorpStyle.WC_W : CorpStyle.WC_D) / 2;
            var pd = (dir < 2 ? CorpStyle.WC_D : CorpStyle.WC_W) / 2;
            ContactMask.prop(x - pw, x + pw, z - pd, z + pd);
          }
    }

// the three wall-hugging families, thinned by a stride over the whole candidate list
  static function standing(m:Facility, places:Array<Array<Models.PropPlace>>,
      ?area:game.AreaGame):Void
    {
      for (i in 0...FLOOR.length)
        {
          var p = FLOOR[i];
          var cand = [];
          for (row in 0...m.h)
            for (col in 0...m.w)
              {
                var dir = wall(m, col, row, p.on);
                if (dir < 0)
                  continue;
                cand.push({
                  col: col,
                  row: row,
                  dir: dir,
                });
              }
          var step = Std.int(Math.ceil(cand.length / CorpStyle.FLOOR_MAX));
          if (step > 1)
            cand = [for (k in 0...cand.length) if (k % step == 0) cand[k]];
          // AND THE CELLS THE GENERATOR ASKED FOR, which are NOT thinned and are not gated on the
          // floor surface. The scatter above is a dressing of its own — it fills free floor by
          // surface — and it is why a plant dealt into an exec office's corner drew nothing: the
          // generator wrote an unwalkable twin on a MARBLE1 cell and this family only ever looks
          // at CARPET. These are the cells that already carry a decoration saying so
          if (p.deco != CorpDeco.K_NONE)
            for (c in CorpDeco.cells(area, p.deco))
              {
                // NOT ONTO A WORKTOP. the same frame is dealt onto a table tile elsewhere in the
                // tower (a copy room's printers stand on a bench), and there the bench is what
                // draws it — a glb on the floor of that cell would stand inside the carcass
                if (m.table[c.row][c.col] ||
                    m.fit[c.row][c.col] != 0)
                  continue;
                var dir = CorpDeco.backHandOf(m, c.col, c.row);
                if (dir < 0)
                  continue;
                cand.push({
                  col: c.col,
                  row: c.row,
                  dir: dir,
                });
              }
          for (c in cand)
            {
              var sl = FacilityGeom.slab(m, c.col + DC[c.dir], c.row + DR[c.dir]);
              var off = p.d / 2 + CorpStyle.PROP_GAP;
              var w = CityConfig.cellToWorld(c.col, c.row);
              var x = (c.dir == 2 ? sl.x1 + off : (c.dir == 3 ? sl.x0 - off : w.x));
              var z = (c.dir == 0 ? sl.z1 + off : (c.dir == 1 ? sl.z0 - off : w.z));
              places[i].push({
                x: x,
                z: z,
                yaw: Math.atan2(DC[c.dir ^ 1], DR[c.dir ^ 1]),
              });
              var pw = (c.dir < 2 ? p.w : p.d) / 2;
              var pd = (c.dir < 2 ? p.d : p.w) / 2;
              ContactMask.prop(x - pw, x + pw, z - pd, z + pd);
              // and the shadow on the masonry behind it, which a top-down field cannot reach
              FacilityDetail.stand({
                col: c.col,
                row: c.row,
                dir: c.dir,
                a0: (c.dir < 2 ? x : z) - p.w / 2,
                a1: (c.dir < 2 ? x : z) + p.w / 2,
                len: 1,
                y: 0.0,
                h: p.h,
              });
            }
        }
    }

// may a floor prop of this family stand on this cell, and against which wall? the first hand that
// answers is taken: a cell with masonry on two hands is a room corner and either face puts the
// prop in the same corner
  static function wall(m:Facility, col:Int, row:Int, on:Surf):Int
    {
      if (!FacilityModel.inside(m, col, row) ||
          m.surf[row][col] != on ||
          m.table[row][col] ||
          m.fit[row][col] != 0 ||
          FacilityModel.nearDoor(m, col, row))
        return -1;
      for (dir in 0...4)
        {
          var c = col + DC[dir];
          var r = row + DR[dir];
          if (!FacilityModel.isSolidWall(m, c, r))
            continue;
          // and the wall line has to RUN ON past this cell BOTH ways, or FacilityGeom.slab insets
          // that face by a unit and the prop hangs off the end of the wall it backs onto
          var sc = (dir < 2 ? 1 : 0);
          var sr = (dir < 2 ? 0 : 1);
          if (FacilityGeom.carries(m, c - sc, r - sr) &&
              FacilityGeom.carries(m, c + sc, r + sr))
            return dir;
        }
      return -1;
    }

// is this desk cell MANNED — does a monitor and a keyboard stand on it?
//
// SHARED, because the two callers used to answer it differently and that was a bug in the open:
// `desks` preferred the generator's own K_WORK cells whenever any existed while `claims` always
// rolled the hash, so on a freshly generated tower (where the map is never empty) CorpClutter was
// scattering around a workstation that was not there, and vice versa. `work` is null from the
// pure-function side, which takes the roll.
//
// AND A CUBICLE IS ALWAYS MANNED. WORK_EVERY exists so an open-plan run does not read as a bank of
// screens down a wall; a cubicle is one worker's own cell with a panel round it, and an empty one
// reads as a farm nobody works in
  public static function manned(m:Facility, work:Map<Int, Bool>, col:Int, row:Int,
      hash:Int):Bool
    {
      if (m.surf[row][col] == Surf.CUBICLE)
        return true;
      if (work != null &&
          work.keys().hasNext())
        return work.exists(row * m.w + col);
      return hash % CorpStyle.WORK_EVERY == 0;
    }

// what the WORKSTATION on this worktop cell claims, as boxes, or empty for a cell carrying none.
//
// A PURE RE-RUN OF `desks` AND NOT A CACHED LIST, the discipline every other pure-function-of-the-
// grid pass in this layer keeps: render.corp.CorpClutter has to scatter AROUND the monitor and the
// keyboard, and neither pass may depend on having run first. The alternative is a shared claim
// list, which is a second thing to keep in step
  public static function claims(m:Facility, col:Int, row:Int):Array<ClutterSlot>
    {
      if (!m.table[row][col])
        return [];
      var s = m.surf[row][col];
      if (s != Surf.OPEN &&
          s != Surf.CUBICLE &&
          s != Surf.EXEC)
        return [];
      var dir = backHand(m, col, row);
      if (dir < 0 ||
          !clear(m, col + DC[dir ^ 1], row + DR[dir ^ 1]))
        return [];
      var hash = FacilityModel.mix((col * 374761393) ^ (row * 40503));
      if (!manned(m, null, col, row, hash))
        return [];
      var c = CityConfig.cellToWorld(col, row);
      var back = CorpStyle.DESK_TOP_D / 2 - CorpStyle.MON_BACK;
      // the two boxes, each at the yaw it is really drawn at: a monitor runs WIDE across the desk
      // and a keyboard likewise, so which of the two world axes each spans is what `dir` says
      var alongX = (dir < 2);
      var mw = (alongX ? CorpStyle.MON_W : CorpStyle.MON_D) / 2;
      var md = (alongX ? CorpStyle.MON_D : CorpStyle.MON_W) / 2;
      var kw = (alongX ? CorpStyle.KEY_W : CorpStyle.KEY_D) / 2;
      var kd = (alongX ? CorpStyle.KEY_D : CorpStyle.KEY_W) / 2;
      return [
        {
          x: c.x + DC[dir] * back,
          z: c.z + DR[dir] * back,
          hw: mw,
          hd: md,
        },
        {
          x: c.x + DC[dir] * (back - CorpStyle.KEY_FWD),
          z: c.z + DR[dir] * (back - CorpStyle.KEY_FWD),
          hw: kw,
          hd: kd,
        },
      ];
    }

// the two hand-modelled tables: a bench desk on every open-plan and cubicle worktop cell, and a
// blade leg under every boardroom and executive one.
//
// THE YAW IS THE DESK'S BACK HAND, which is the same question CorpProps.desks already asks of the
// seat: the module is built with its pedestal and its frame across x and its front on +y, so it
// has to be turned to face the way the desk faces. A cell with no usable back (an island of
// worktop with nothing behind it) takes yaw 0 rather than being skipped — the top is gone either
// way and a desk facing an arbitrary direction beats a hole in the run.
//
// A LEG IS TURNED ACROSS THE SLAB'S LONG AXIS, so a row of them reads as trestles under one top
// rather than as a line of fins pointing down it
  static function tables(m:Facility, benches:Array<Models.PropPlace>,
      legs:Array<Models.PropPlace>):Void
    {
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (!m.table[row][col])
              continue;
            var s = m.surf[row][col];
            var c = CityConfig.cellToWorld(col, row);
            if (CorpFurniture.deskCell(m, col, row) &&
                !CorpFurniture.slabTop(m, col, row))
              {
                var dir = backHand(m, col, row);
                benches.push({
                  x: c.x,
                  z: c.z,
                  yaw: (dir < 0 ? 0.0 : Math.atan2(DC[dir], DR[dir])),
                });
                continue;
              }
            if (!CorpFurniture.slabTop(m, col, row))
              continue;
            // EVERY OTHER CELL, on a checkerboard. A leg under all nine cells of a 3x3 table is
            // a forest under a top nobody can see past; on the diagonal they land ~2.8 units
            // apart, which is a trestle spacing and half the instances
            if ((col + row) % 2 != 0)
              continue;
            // the slab's long axis is whichever hand carries on being table
            var alongX = m.table[row][col - 1] || m.table[row][col + 1];
            legs.push({
              x: c.x,
              z: c.z,
              yaw: (alongX ? Math.PI / 2 : 0.0),
            });
          }
    }

// which hand a worktop cell has its back on — masonry, a cubicle spine, or the next worktop.
//
// A POD ANSWERS OFF THE PAIR AND NOT OFF THIS ORDER. "The first hand that is not clear floor" reads
// the back of a cubicle correctly only while the farm's bands run across the room: turn the layout
// a quarter turn (gen.corp.CorpRooms.cubicle does, when that seats more people) and the first
// non-clear hand of a pod at the end of a block is the neighbour BESIDE him. CorpFurniture.podBack
// is the shared oracle, and it is the same one the panel emitter splits its faces on
  static function backHand(m:Facility, col:Int, row:Int):Int
    {
      if (m.surf[row][col] == Surf.CUBICLE)
        return CorpFurniture.podBack(m, col, row);
      for (d in 0...4)
        if (!clear(m, col + DC[d], row + DR[d]))
          return d;
      return -1;
    }

// is this cell floor somebody can stand on?
  static inline function clear(m:Facility, col:Int, row:Int):Bool
    {
      return FacilityModel.inside(m, col, row) &&
        !FacilityModel.isWall(m, col, row) &&
        !m.table[row][col] &&
        m.fit[row][col] == 0;
    }
}
