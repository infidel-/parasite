package render.corp;

import three.Three;
import citygen.CityConfig;
import render.Textures;
import render.facility.ClutterSlot;
import render.facility.ClutterSlot.ClutterSlotTools;
import render.facility.FacilityDetail;
import render.facility.FacilityGeom;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.Models;
import render.world.VisionMask;

// the small FLAT things lying about on the tower's worktops — a laptop, a mug, a folder, a spread
// of paper on a desk; a carafe, a tray of cups, a folded towel on a counter or a vanity.
//
// RENDER-ONLY DRESSING, the contract render.facility.FacilityClutter opens with and the reason the
// rest of this file is shaped the way it is. These are not objects.Decoration: they carry no atlas
// frame, take no cell, block no movement and never enter a save. Every position, size, turn and
// choice of art is rolled off FacilityModel.mix on the CELL, so a floor plate comes back identical
// on every rebuild and no corp area already saved had to be migrated to get them.
//
// TWO SHEETS AND NOT ONE, picked off the cell's Surf: a keyboard and a document tray belong on a
// desk and a cafetiere and a hand towel do not. And two and not four — the kitchenette, the
// boardroom and the washroom would have filled about twenty cells each, and a PACK64 is 64 cells
// and ONE draw call whatever is on it.
//
// THE COMPOUND'S OWN FILE IS NOT REUSED AND COULD NOT BE. FacilityClutter spends most of its length
// on the CLUTTER SLOTS — the lid of every standing fitting the generator left in `m.deco`, the
// store's crates, the shelving's three plates — and a tower plate has no `m.deco` at all: its
// furniture is emitted quads off `m.table` and `m.fit`. What is left once that goes is the worktop
// scatter, which is this file, and the pack-cell arithmetic, which docs/3d-textures.md notes is
// already deliberately copied in four places rather than shared.
class CorpClutter
{
// every decal on the plate as TWO merged meshes, one per sheet. returns how many landed — a merged
// mesh has no instance count and this is the only handle on the family
  public static function build(scene:Scene, m:Facility, ?area:game.AreaGame):{ n:Int,
      props:Array<Models.InstancedProp> }
    {
      var desk = MeshBufTools.make();
      var util = MeshBufTools.make();
      // the exec office's own PACK16, and what its desks already carry — see CorpExec.claims
      var exec = MeshBufTools.make();
      var execClaims = CorpExec.claims(m, area);
      // and the staff kitchen's, off its counters and its dining tables — see CorpKitchen.tops
      var kitchen = MeshBufTools.make();
      // and the handful of cells that are PROPS rather than decals — see CorpStyle.CLUTTER_PROP_OF
      var props = [for (_ in 0...CorpStyle.CLUTTER_PROPS) new Array<Models.PropPlace>()];
      var n = 0;
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (!m.table[row][col])
              continue;
            if (m.surf[row][col] == Surf.EXEC)
              {
                n += execCell(m, col, row, exec, execClaims);
                continue;
              }
            if (CorpKitchen.cell(m, col, row))
              continue;
            n += cell(m, col, row, deskish(m.surf[row][col]) ? desk : util, props);
          }
      // and a thing or two on every exec lounge's low table
      for (t in CorpExec.lowTops(m, area))
        {
          var g = FacilityModel.mix((t.col * 1103515245) ^ (t.row * 12345) ^ 0x5bd1e995);
          n += scatter({
            b: exec,
            x: t.x,
            z: t.z,
            hw: t.hw - CorpStyle.CLUTTER_INSET,
            hd: t.hd - CorpStyle.CLUTTER_INSET,
            y: CorpStyle.TABLE_LOW_H + CorpStyle.CLUTTER_Y,
            want: 1 + g % CorpStyle.TABLE_LOW_CLUTTER,
            seed: g,
            spots: [],
            sz: CorpStyle.CLUTTER_EXEC_SZ,
            szVar: CorpStyle.CLUTTER_EXEC_SZ_VAR,
          });
        }
      // and the kitchen's: at least one on every dining table, and up to FRIDGE_TOP_MAX on a
      // fridge's top, where the roll reaches zero the way a desk's does
      for (t in CorpKitchen.tops(m, area))
        {
          var g = FacilityModel.mix((t.col * 1103515245) ^ (t.row * 12345));
          n += scatter({
            b: kitchen,
            x: t.x,
            z: t.z,
            hw: t.hw - CorpStyle.CLUTTER_INSET,
            hd: t.hd - CorpStyle.CLUTTER_INSET,
            y: t.y + CorpStyle.CLUTTER_Y,
            want: (t.table ? 1 + g % CorpStyle.CLUTTER_KITCHEN_TABLE :
              g % (CorpStyle.FRIDGE_TOP_MAX + 1)),
            seed: g,
            spots: t.spots,
            sz: CorpStyle.CLUTTER_KITCHEN_SZ,
            szVar: CorpStyle.CLUTTER_KITCHEN_SZ_VAR,
          });
        }
      // AND THE ARCHIVE'S UNITS: paper and folders lying on every level that took no load — a lid
      // or, on the racking, a shelf — off the desk sheet and into its buffer, so no draw call
      for (u in CorpFurniture.units)
        n += level(u, desk);
      // and the reception counters', laid out rather than rolled — see CorpReception.dress. Its
      // decals are desk-sheet cells into the desk buffer, its plants join the desks' own batch
      var rec = CorpReception.dress(m);
      for (d in rec.decals)
        {
          emit(desk, d.x, d.z, CorpStyle.CLUTTER_SZ, d.yaw, d.idx, d.y);
          n++;
        }
      for (p in rec.plants)
        props[CorpStyle.CLUTTER_PLANT].push(p);
      add(scene, desk, CorpStyle.CLUTTER_DESK_TEX);
      add(scene, util, CorpStyle.CLUTTER_UTIL_TEX);
      add(scene, exec, CorpStyle.CLUTTER_EXEC_TEX);
      add(scene, kitchen, CorpStyle.CLUTTER_KITCHEN_TEX);
      // and what the kitchen holds on its fridges, off their own sheet
      var magnets = MeshBufTools.make();
      for (f in CorpKitchen.fridges(m, area))
        n += fridge(f, magnets);
      add(scene, magnets, CorpStyle.MAGNET_TEX);
      // and the third sheet, which is not a worktop at all: what the people in the cubicle farm
      // have pinned to their own panels — and to the side of an archive run's end unit, where the
      // company has not hung its poster (CorpFurniture.archEndPoster, CorpSigns' side of the split)
      var panel = MeshBufTools.make();
      for (q in CorpFurniture.panels)
        n += face(q, panel);
      for (e in CorpFurniture.archEnds)
        if (!CorpFurniture.archEndPoster(e))
          n += pins(e, panel);
      add(scene, panel, CorpStyle.PANEL_TEX);
      // ONE BATCH PER PATH, which is what four props cost and the whole of what the promotion is
      // argued against: the two sheets above are two calls for sixty-odd kinds, and every glb here
      // is a call of its own however few land
      var out = [];
      out.push(CorpProps.clutterBatch(scene, RenderConfig.MODELS.corpRecPhone, rec.phones,
        CorpStyle.REC_PHONE_H));
      out.push(CorpProps.clutterBatch(scene, RenderConfig.MODELS.corpRecBoard, rec.boards,
        CorpStyle.REC_BOARD_H));
      out.push(CorpProps.clutterBatch(scene, RenderConfig.MODELS.corpRecBell, rec.bells,
        CorpStyle.REC_BELL_H));
      for (i in 0...CorpStyle.CLUTTER_PROPS)
        out.push(CorpProps.clutterBatch(scene, CorpStyle.CLUTTER_PROP_PATH[i], props[i],
          CorpStyle.CLUTTER_PROP_H[i]));
      return {
        n: n,
        props: out,
      };
    }

// which of the two sheets a worktop takes. a desk, a cubicle return, an exec desk and an archive's
// sorting table carry the office things; a kitchen counter, a boardroom slab and a washroom vanity
// carry the other
  static inline function deskish(s:Surf):Bool
    {
      return s == Surf.OPEN ||
        s == Surf.CUBICLE ||
        s == Surf.EXEC ||
        s == Surf.RECEPTION ||
        s == Surf.SERVER;
    }

// one worktop cell's worth. returns how many actually landed, which is not the rolled count: an
// item that cannot find room in CLUTTER_TRIES attempts is dropped rather than pushed somewhere it
// does not fit.
//
// THE ROLLED COUNT REACHES ZERO ON PURPOSE. `h % (CLUTTER_MAX + 1)` gives 0..3 evenly and the empty
// cells are what stop two hundred worktops reading as a grid again — which is the whole complaint
// this family answers. Flooring it at one would put something on every cell and rebuild the rhythm
  static function cell(m:Facility, col:Int, row:Int, b:MeshBuf,
      props:Array<Array<Models.PropPlace>>):Int
    {
      var g = FacilityModel.mix((col * 1103515245) ^ (row * 12345));
      var want = g % (CorpStyle.CLUTTER_MAX + 1);
      if (want == 0)
        return 0;
      // EVERYTHING ALREADY ON THIS WORKTOP, as boxes: the monitor and the keyboard, asked of
      // CorpProps rather than guessed at here. That call is a pure function of the saved grid, so
      // neither pass has to run before the other — and one oracle is what keeps a document tray
      // from landing under the screen
      var spots = CorpProps.claims(m, col, row);
      var c = CityConfig.cellToWorld(col, row);
      // the worktop is the cell pulled in by CorpFurniture's own inset, and a corp run is never
      // thinned the way a compound bench is (CorpFurniture.worktop fills its cell), so the rect is
      // the cell and this needs none of the open-hand arithmetic the compound's version carries
      var span = CityConfig.CELL / 2 - CorpStyle.FIT_INSET;
      var y = CorpFurniture.topH(m.surf[row][col]) + CorpStyle.CLUTTER_Y;
      var n = 0;
      for (i in 0...want)
        {
          var h = FacilityModel.mix(g ^ ((i + 1) * 668265263));
          var sz = CorpStyle.CLUTTER_SZ + ((h % 1000) / 1000) * CorpStyle.CLUTTER_SZ_VAR;
          var r = span - sz * 0.5 - CorpStyle.CLUTTER_INSET;
          if (r <= 0)
            continue;
          // a FREE yaw, which is the point of the family: a rank of square-on cut-outs reads as a
          // layout and a turned one reads as things somebody put down
          var yaw = ((h >>> 12) % 1000) / 1000 * 2 * Math.PI;
          var box = ClutterSlotTools.turned(c.x, c.z, sz, sz, yaw);
          var ok = false;
          for (t in 0...CorpStyle.CLUTTER_TRIES)
            {
              var hh = FacilityModel.mix(h ^ ((t + 1) * 83492791));
              box.x = c.x + (((hh % 1000) / 1000) * 2 - 1) * r;
              box.z = c.z + ((((hh >>> 10) % 1000) / 1000) * 2 - 1) * r;
              ok = !hits(spots, box);
              if (ok)
                break;
            }
          if (!ok)
            continue;
          spots.push(box);
          // A PROMOTED CELL STANDS A GLB INSTEAD, on the same roll, at the same place and the same
          // free yaw — so the scatter is untouched and a floor plate comes back identical either
          // way. `y` is the worktop's own top, which is where a decal lay and where a prop stands
          var idx = (h >>> 22) % CorpStyle.CLUTTER_CELLS;
          var prop = CorpStyle.CLUTTER_PROP_OF.exists(idx) ?
            CorpStyle.CLUTTER_PROP_OF.get(idx) : -1;
          if (prop >= 0)
            {
              props[prop].push({
                x: box.x,
                z: box.z,
                yaw: yaw,
                y: y,
              });
              // AND THE SHADOW IT STANDS IN. a decal IS its own contact — it lies on the worktop —
              // but a promoted cell stands a round or upright glb up there, and
              // render.world.ContactMask is one top-down field over the FLOOR and cannot reach a
              // mug 1.5 units up.
              //
              // SIZED OFF THE PROP AND NOT OFF `sz`, which is the fault this used to have: `sz` is
              // the DECAL's rolled edge, 0.55 to 0.95, and the plant it replaced is 0.182 across.
              // After POOL_GROW the quad came out 0.77-1.33 wide under a 0.18 pot — 4.2x to 7.3x —
              // and reported from the game as a huge square shadow.
              //
              // AND `deck` AND NOT `pool`, which is the other half of that report: `pool`'s ramp is
              // a rounded box at corner radius ZERO, i.e. a square, and all four of these props are
              // a lathe or a puck. `deck` passes the half-extent as the radius too, which collapses
              // the same generator to a circle. It is the tower's FIRST user of that mesh and so
              // costs one draw call — the compound has both in every scene and pays nothing
              var pr = CorpStyle.CLUTTER_PROP_R[prop] * CorpStyle.CLUTTER_PROP_H[prop];
              FacilityDetail.deck({
                cx: box.x,
                cz: box.z,
                hw: pr,
                hd: pr,
                yaw: yaw,
                y: y,
                plate: {
                  x0: c.x - span,
                  x1: c.x + span,
                  z0: c.z - span,
                  z1: c.z + span,
                },
              });
            }
          else
            emit(b, box.x, box.z, sz, yaw, idx, y);
          n++;
        }
      return n;
    }

// one exec desk cell's worth off the exec office's own sheet: fewer and bigger than a clerk's desk
// takes, and round the workstation render.corp.CorpExec stands on it
  static function execCell(m:Facility, col:Int, row:Int, b:MeshBuf,
      claims:Map<Int, Array<ClutterSlot>>):Int
    {
      var g = FacilityModel.mix((col * 1103515245) ^ (row * 12345));
      var want = g % (CorpStyle.CLUTTER_EXEC_MAX + 1);
      if (want == 0)
        return 0;
      var k = CorpExec.key(m, col, row);
      var spots = (claims.exists(k) ? claims.get(k).copy() : []);
      var c = CityConfig.cellToWorld(col, row);
      var r = CityConfig.CELL / 2 - CorpStyle.FIT_INSET - CorpStyle.CLUTTER_INSET;
      return scatter({
        b: b,
        x: c.x,
        z: c.z,
        hw: r,
        hd: r,
        y: CorpStyle.EXEC_DESK_H + CorpStyle.CLUTTER_Y,
        want: want,
        seed: g,
        spots: spots,
        sz: CorpStyle.CLUTTER_EXEC_SZ,
        szVar: CorpStyle.CLUTTER_EXEC_SZ_VAR,
      });
    }

// `o.want` decals off a PACK16 over a flat rect, each at a free yaw and clear of `o.spots` —
// `cell`'s own roll and placement. The exec sheet and the kitchen's are the same 4x4 with the same
// two reserved cells, so CLUTTER_EXEC_COLS / _CELLS read either. returns how many landed
  static function scatter(o:CorpScatterOpts):Int
    {
      var n = 0;
      for (i in 0...o.want)
        {
          var h = FacilityModel.mix(o.seed ^ ((i + 1) * 668265263));
          var sz = o.sz + ((h % 1000) / 1000) * o.szVar;
          var rx = o.hw - sz * 0.5, rz = o.hd - sz * 0.5;
          if (rx <= 0 ||
              rz <= 0)
            continue;
          var yaw = ((h >>> 12) % 1000) / 1000 * 2 * Math.PI;
          var box = ClutterSlotTools.turned(o.x, o.z, sz, sz, yaw);
          var ok = false;
          for (t in 0...CorpStyle.CLUTTER_TRIES)
            {
              var hh = FacilityModel.mix(h ^ ((t + 1) * 83492791));
              box.x = o.x + (((hh % 1000) / 1000) * 2 - 1) * rx;
              box.z = o.z + ((((hh >>> 10) % 1000) / 1000) * 2 - 1) * rz;
              ok = !hits(o.spots, box);
              if (ok)
                break;
            }
          if (!ok)
            continue;
          o.spots.push(box);
          emit(o.b, box.x, box.z, sz, yaw, (h >>> 22) % CorpStyle.CLUTTER_EXEC_CELLS, o.y,
            CorpStyle.CLUTTER_EXEC_COLS);
          n++;
        }
      return n;
    }

// ONE PANEL'S TWO FACES' WORTH, and the arithmetic is the worktop's turned on its side.
//
// a panel is a 0.1-thick slab standing on a cell boundary, so its two faces look into two
// DIFFERENT bays and each is one worker's own wall — which is why the roll is per face and not per
// panel. Nothing has to be claimed against: the only things on a panel are the ones this pass puts
// there, so the rejection sampling the worktop needs (a monitor and a keyboard are already
// standing on it) has no work to do here and the slots are simply spread along the run.
//
// `side` IS THE HAND AND NOTHING ELSE NOW. It used to gate the poster test while a separate roll
// off bit 22 picked which hand the quad actually landed on — so both passes of the loop could emit
// onto the SAME face, at the same slot (the spread is deterministic), differing only in y. Seen in
// the game as two decals sitting on top of each other, twice.
//
// A FACE CARRIES THINGS IF IT LOOKS AT ANYTHING AT ALL — at a desk, which is the worker's own
// wall, or at the passage, which is mostly his too. CorpFurniture.panelPoster is the shared
// predicate for the handful of passage faces the company takes for a poster instead; a face
// looking at masonry or a fitting carries nothing, and neither does a pod's BACK panel, which
// looks at a desk on both hands but has a monitor standing in front of each
  static function face(q:CorpFurniture.CorpPanel, b:MeshBuf):Int
    {
      var n = 0;
      // and the BACK panel carries nothing on either hand: a monitor stands against it on both.
      // NOT "a desk on both hands", which is also true of the side panel between two neighbours in
      // the same row — two workers' walls with nothing in front of either, and the first cut of
      // this guard took 56 panels where 18 are backs. NOR "the alongX one", which was true only
      // while every farm's bands ran across the room: gen.corp.CorpRooms.cubicle turns the layout
      // a quarter turn when that seats more people, and then the back is the z-running panel and
      // the guard had it exactly backwards. CorpFurniture.divider marks it, off the same
      // `podBack` the monitor is placed from
      if (q.back)
        return 0;
      for (side in 0...2)
        {
          var pod = CorpFurniture.podFace(q, side);
          if (!pod &&
              !CorpFurniture.aisleFace(q, side))
            continue;
          if (CorpFurniture.panelPoster(q, side))
            continue;
          var g = FacilityModel.mix(q.seed ^ ((side + 1) * 1103515245));
          var want = g % (CorpStyle.PANEL_MAX + 1);
          for (i in 0...want)
            {
              var h = FacilityModel.mix(g ^ ((i + 1) * 668265263));
              var sz = CorpStyle.PANEL_SZ + ((h % 1000) / 1000) * CorpStyle.PANEL_SZ_VAR;
              // along the run, spread the way CorpLamps and CorpSigns spread theirs: slot i sits
              // (i + 0.5) / want of the way down, so one item lands on the panel's own centre
              var lo = (q.alongX ? q.x0 : q.z0) + CorpStyle.PANEL_END;
              var hi = (q.alongX ? q.x1 : q.z1) - CorpStyle.PANEL_END;
              if (hi - lo < sz)
                continue;
              var at = lo + (hi - lo) * (i + 0.5) / want;
              var y = CorpStyle.PARTITION_H *
                (CorpStyle.PANEL_LO + (CorpStyle.PANEL_HI - CorpStyle.PANEL_LO) *
                  (((h >>> 12) % 1000) / 1000));
              // and the band is the CENTRE's, so the item's own half height has to clear the trim
              // rail on top of the panel — see CorpStyle.PANEL_TOP_GAP
              var top = CorpStyle.PARTITION_H - CorpStyle.PARTITION_T - CorpStyle.PANEL_TOP_GAP -
                sz * 0.5;
              if (y > top)
                y = top;
              // and the DESK is the bottom of it, on the face that has one: a 1.5 bench stands
              // against the panel with 0.12 of air between them, so anything pinned lower than
              // its top went behind it — reported as clutter going under the table
              var bot = CorpStyle.DESK_H + CorpStyle.PANEL_BOT_GAP + sz * 0.5;
              if (pod &&
                  y < bot)
                y = bot;
              emitFace(b, q, at, y, sz, side, (h >>> 4) % CorpStyle.PANEL_CELLS);
              n++;
            }
        }
      return n;
    }

// one pinned decal: a square quad standing PANEL_PROUD off one face of the panel, square on to it.
//
// no turn and no yaw roll, which is the opposite call to the worktop's: a thing lying on a desk was
// PUT DOWN and a thing pinned to a wall was HUNG, and a wall of jaunty angles reads as a collage.
//
// THE WINDING IS FacilityGeom.ends' AND NOT THIS FILE'S. A hand-rolled pair of quads got one hand
// right and one backwards on each axis — the material is DoubleSide so nothing vanished, the art
// simply came back MIRRORED on the far face, reported as decals "inverted for some reason".
// render.corp.CorpSigns.pane hangs a poster on the same two planes and has never had it, because
// it asks the one emitter that knows the order
  static function emitFace(b:MeshBuf, q:CorpFurniture.CorpPanel, at:Float, y:Float, sz:Float,
      side:Int, idx:Int):Void
    {
      var e = CorpStyle.PANEL_PROUD;
      // FacilityGeom's own direction order: 0 = -z, 1 = +z, 2 = -x, 3 = +x, so side 0 is the hand
      // at x0/z0 and side 1 the hand at x1/z1
      var dir = (q.alongX ? (side == 0 ? 0 : 1) : (side == 0 ? 2 : 3));
      var p = (q.alongX
        ? (side == 0 ? q.z0 - e : q.z1 + e)
        : (side == 0 ? q.x0 - e : q.x1 + e));
      upright(b, !q.alongX, p, at, y, sz, dir, idx);
    }

// one square sheet quad standing on the plane `p` — world x when `xPlane`, world z otherwise —
// centred `at` along that plane and `y` up it, looking `dir`
  static function upright(b:MeshBuf, xPlane:Bool, p:Float, at:Float, y:Float, sz:Float, dir:Int,
      idx:Int, cols:Int = CorpStyle.PANEL_COLS):Void
    {
      var hs = sz * 0.5;
      var y0 = y - hs, y1 = y + hs;
      var t = cols;
      var cc = idx % t, cr = Std.int(idx / t);
      var u0 = cc / t, u1 = (cc + 1) / t;
      var v0 = 1 - (cr + 1) / t, v1 = 1 - cr / t;
      var c = (xPlane
        ? FacilityGeom.ends(p, p, at - hs, at + hs, dir)
        : FacilityGeom.ends(at - hs, at + hs, p, p, dir));
      MeshBufTools.quad(b, [c[0], y0, c[1]], [c[2], y0, c[3]], [c[2], y1, c[3]], [c[0], y1, c[1]],
        [u0, v0, u1, v0, u1, v1, u0, v1]);
    }

// the things held on one fridge: 1 to MAGNET_FRONT on its door and up to MAGNET_SIDE on each of its
// sides, off corp/fridge-magnets, each clear of the others on its face. Hung square on, for
// emitFace's reason — a magnet holds a sheet the way a pin does.
//
// THEY USED TO BE MODELLED: two notes built into the fridge glb as label boxes, the same rota and
// the same drawing on every fridge in the tower, and reported as such
  static function fridge(f:CorpKitchen.KitchenStand, b:MeshBuf):Int
    {
      var n = 0;
      var face = f.dir ^ 1;
      // the door's across axis runs the model's +x the way its pull does, which is world +x facing
      // +z and world +z facing -x
      var sgn = (face == 1 || face == 2 ? 1 : -1);
      for (s in 0...3)
        {
          // the door, then the two sides across it
          var d = (s == 0 ? face : (face < 2 ? 2 : 0) + s - 1);
          var xPlane = (d >= 2);
          var off = (s == 0 ? CorpStyle.FRIDGE_FACE : CorpStyle.FRIDGE_SIDE) + CorpStyle.PANEL_PROUD;
          var p = (xPlane ? f.x : f.z) + (d % 2 == 0 ? -off : off);
          var mid = (xPlane ? f.z : f.x);
          var a0 = (s == 0 ? CorpStyle.MAGNET_ACROSS_LO : -CorpStyle.FRIDGE_FACE);
          var a1 = (s == 0 ? CorpStyle.MAGNET_ACROSS_HI : CorpStyle.FRIDGE_FACE);
          var lo = (s == 0 ? CorpStyle.FRIDGE_DOOR_LO : CorpStyle.MAGNET_SIDE_LO);
          var hi = CorpStyle.FRIDGE_DOOR_HI;
          var g = FacilityModel.mix((f.col * 1103515245) ^ (f.row * 12345) ^ ((s + 1) * 374761393));
          var want = (s == 0 ? 1 + g % CorpStyle.MAGNET_FRONT : g % (CorpStyle.MAGNET_SIDE + 1));
          var spots:Array<ClutterSlot> = [];
          for (i in 0...want)
            {
              var h = FacilityModel.mix(g ^ ((i + 1) * 668265263));
              var sz = CorpStyle.MAGNET_SZ + ((h % 1000) / 1000) * CorpStyle.MAGNET_SZ_VAR;
              var r0 = a0 + sz / 2, r1 = a1 - sz / 2;
              var y0 = lo + sz / 2, y1 = hi - sz / 2;
              if (r1 < r0 ||
                  y1 < y0)
                continue;
              // the slot, as a box in (across, up) on the face
              var box:ClutterSlot = {
                x: 0.0,
                z: 0.0,
                hw: sz / 2,
                hd: sz / 2,
              };
              var ok = false;
              for (t in 0...CorpStyle.CLUTTER_TRIES)
                {
                  var hh = FacilityModel.mix(h ^ ((t + 1) * 83492791));
                  box.x = r0 + ((hh % 1000) / 1000) * (r1 - r0);
                  box.z = y0 + (((hh >>> 10) % 1000) / 1000) * (y1 - y0);
                  ok = !hits(spots, box);
                  if (ok)
                    break;
                }
              if (!ok)
                continue;
              spots.push(box);
              upright(b, xPlane, p, mid + sgn * box.x, box.z, sz, d,
                (h >>> 22) % CorpStyle.MAGNET_CELLS, CorpStyle.MAGNET_COLS);
              n++;
            }
        }
      return n;
    }

// the paper pinned to one archive run end: up to ARCH_END_PIN_MAX squares, stacked up the side in
// the band between ARCH_END_LO and ARCH_END_TOP under the unit's top, each slid across it by its
// own roll. Hung square on, for emitFace's reason
  static function pins(e:CorpFurniture.CorpArchEnd, b:MeshBuf):Int
    {
      var want = (e.seed >>> 11) % (CorpStyle.ARCH_END_PIN_MAX + 1);
      var span = e.a1 - e.a0 - 2 * CorpStyle.ARCH_END_EDGE;
      var p = e.p + (e.dir == 0 || e.dir == 2 ? -1 : 1) * CorpStyle.PANEL_PROUD;
      for (i in 0...want)
        {
          var h = FacilityModel.mix(e.seed ^ ((i + 1) * 668265263));
          var sz = Math.min(CorpStyle.PANEL_SZ + ((h % 1000) / 1000) * CorpStyle.PANEL_SZ_VAR, span);
          var lo = CorpStyle.ARCH_END_LO + sz / 2;
          var hi = e.h - CorpStyle.ARCH_END_TOP - sz / 2;
          var y = lo + (hi - lo) * (i + 0.5) / want;
          var at = (e.a0 + e.a1) / 2 + (((h >>> 12) % 1000) / 1000 - 0.5) * (span - sz);
          upright(b, e.alongX, p, at, y, sz, e.dir, (h >>> 4) % CorpStyle.PANEL_CELLS);
        }
      return want;
    }

// the flat things lying on an archive unit's free levels: up to ARCH_DECAL_MAX per level that took
// no load (CorpArchive.loaded, the same roll its boxes are dealt off), one to a slot along the
// width, each at a free yaw and slid inside its slot. The promoted cells are skipped rather than
// stood up — a mug on a filing cabinet is somebody's desk, not the archive
  static function level(u:CorpFurniture.CorpArch, b:MeshBuf):Int
    {
      var f = CorpFurniture.ARCH[u.fam];
      // the width the unit stands along and the depth it looks down, off its yaw the way
      // CorpArchive.load reads them
      var wx = Math.cos(u.yaw), wz = -Math.sin(u.yaw);
      var nx = Math.sin(u.yaw), nz = Math.cos(u.yaw);
      var span = f.w - 2 * CorpStyle.ARCH_GAP;
      var n = 0;
      for (lv in 0...f.levels.length)
        {
          if (CorpArchive.loaded(u, lv))
            continue;
          var g = FacilityModel.mix(u.seed ^ ((lv + 1) * 1103515245));
          var want = g % (CorpStyle.ARCH_DECAL_MAX + 1);
          for (i in 0...want)
            {
              var h = FacilityModel.mix(g ^ ((i + 1) * 668265263));
              var idx = (h >>> 22) % CorpStyle.CLUTTER_CELLS;
              if (CorpStyle.CLUTTER_PROP_OF.exists(idx))
                continue;
              // a free yaw, so the square is capped by what its DIAGONAL fits in: the slot along
              // the width and the depth less the worktop's own edge inset across it
              var slot = span / want;
              var room = Math.min(slot, f.d - 2 * CorpStyle.CLUTTER_INSET);
              var sz = Math.min(CorpStyle.CLUTTER_SZ + ((h % 1000) / 1000) * CorpStyle.CLUTTER_SZ_VAR,
                room / 1.4142);
              var along = -span / 2 + (i + 0.5) * slot +
                (((h >>> 12) % 1000) / 1000 - 0.5) * (slot - sz * 1.4142);
              var deep = (((h >>> 2) % 1000) / 1000 - 0.5) * (f.d - 2 * CorpStyle.CLUTTER_INSET -
                sz * 1.4142);
              emit(b, u.x + wx * along + nx * deep, u.z + wz * along + nz * deep, sz,
                ((h >>> 5) % 1000) / 1000 * 2 * Math.PI, idx, f.levels[lv] + CorpStyle.CLUTTER_Y);
              n++;
            }
        }
      return n;
    }

// would this box land on something already claimed? the separating-axis test for two axis-aligned
// rects with ONE gap counted per PAIR — ClutterSlotTools.hits' own arithmetic, re-stated here only
// because that one reads the COMPOUND's clearance constant and a tower's worktops are tighter
  static function hits(slots:Array<ClutterSlot>, b:ClutterSlot):Bool
    {
      for (s in slots)
        if (Math.abs(b.x - s.x) < b.hw + s.hw + CorpStyle.CLUTTER_GAP &&
            Math.abs(b.z - s.z) < b.hd + s.hd + CorpStyle.CLUTTER_GAP)
          return true;
      return false;
    }

// one decal: a square quad lying flat on the worktop, TURNED about its own centre.
//
// it cannot go through FacilityGeom.cap, which takes an axis-aligned rect — and the turn is the
// point. The corners walk FacilityDeco.crate's cyclic order, wound to cap's own winding so the face
// looks UP, and the UV is the sheet's cell with v FLIPPED, the trap FacilitySink.emit records:
// three flips y, so the source's TOP row is the HIGH v and reading order across the sheet is the
// order the prompt listed its 64 subjects in
  static function emit(b:MeshBuf, x:Float, z:Float, sz:Float, yaw:Float, idx:Int, y:Float,
      cols:Int = CorpStyle.CLUTTER_COLS):Void
    {
      var hs = sz * 0.5;
      var cs = Math.cos(yaw), sn = Math.sin(yaw);
      var lx = [ -hs, hs, hs, -hs ];
      var lz = [ hs, hs, -hs, -hs ];
      var wx = [], wz = [];
      for (i in 0...4)
        {
          wx.push(x + lx[i] * cs - lz[i] * sn);
          wz.push(z + lx[i] * sn + lz[i] * cs);
        }
      var t = cols;
      var cc = idx % t, cr = Std.int(idx / t);
      var u0 = cc / t, u1 = (cc + 1) / t;
      var v0 = 1 - (cr + 1) / t, v1 = 1 - cr / t;
      MeshBufTools.quad(b,
        [wx[0], y, wz[0]], [wx[1], y, wz[1]], [wx[2], y, wz[2]], [wx[3], y, wz[3]],
        [u0, v0, u1, v0, u1, v1, u0, v1]);
    }

// one sheet's worth as one mesh. FacilityClutter.add's material exactly, for its three reasons: an
// opaque alphaTest draws DoubleSide in ONE pass, it still writes depth so nothing sorts against the
// worktop under it, and leaving `transparent` false keeps VisionMask on its darkening branch rather
// than the alpha-scaling one.
//
// NO CONTACT POOL, unlike everything that STANDS on a worktop. A pool is the shadow of a thing
// meeting the surface it rests on; this IS the surface it rests on, with nothing between
  static function add(scene:Scene, b:MeshBuf, tex:String):Void
    {
      if (b.idx.length == 0)
        return;
      var mesh = new Mesh(FacilityGeom.geom(b), VisionMask.patch(new MeshLambertMaterial({
        map: Textures.loadTexture(tex, 'wall', 1),
        alphaTest: CorpStyle.CLUTTER_CUT,
        side: THREE.DoubleSide,
      })));
      mesh.name = 'corp clutter ' + tex;
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
    }
}
