package render.facility;

import three.Three;
import citygen.CityConfig;
import render.Models;
import render.RenderConfig;
import render.facility.ClutterSlot.ClutterSlotTools;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.ContactMask;
import render.world.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// the workstation standing on a researcher's desk: a monitor on a stand, a tower beside it, a
// keyboard in front, two leads between them and a pair of status lights on the tower.
//
// THIS FAMILY HAS BEEN A GLB, THEN QUADS, THEN A GLB AGAIN, and the three verdicts do not contradict
// each other. The GENERATED facility/computer.glb was wrong and stays dead: 1,200 triangles rounding
// the corners off three axis-aligned slabs, reported as blocky, which is CLAUDE.md's "a box is not a
// prop" answered late. The 22 emitted quads that replaced it were right about everything the
// generator got wrong — FacilityStyle's proportions exactly, the game's own art at full texel
// density, one draw call for the compound — and could state no silhouette at all: five flat faces,
// a screen with no tilt and no bezel, a keyboard that is a 0.1-tall box.
//
// What ships now is the third answer, HAND-MODELLED IN BLENDER off those same constants
// (models-src/facility/computer_build.py, docs/3d-models.md's fourth route): 268 + 116 + 44 tris for
// a screen that tilts 8° back on a real bezel, a tower with its front panel recessed, and a keyboard
// that is a wedge. It keeps the quads' art — the UVs land on the same facility/workstation cells —
// so the only thing that changed is the shape, which is the only thing that was wrong.
//
// THREE PROPS AND NOT ONE. The tower stands on a hand rolled per desk (WorkSpot.side), so a fused
// set could stand on one of them only. The cost is three instanced batches where the quads were one
// merged mesh; the leads and the lights still cost nothing, being pushed into buffers two other
// families already merge (render.facility.FacilityCable's ribbon and FacilityDeco's additive LED
// mesh). The chair behind the desk was a glb through all three passes — a shaped back on a five-star
// base is a silhouette whichever way the rest of the set went
class FacilityWork
{
  static inline var CELL = CityConfig.CELL;

  // the four cell-edge directions, in FacilityGeom.face's order: 0 = -z, 1 = +z, 2 = -x, 3 = +x
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

  // the plane a ribbon lying on a desk is bowed in
  static var UP = [0.0, 1.0, 0.0];

  // the chair the flag picks, resolved once so the batch and its warm row cannot disagree
  public static final CHAIR_PATH = FacilityStyle.CHAIR_BLENDER ?
    RenderConfig.MODELS.facilityChairHand : RenderConfig.MODELS.facilityChair;

// where the workstation on this office desk cell stands, or null for a cell that carries none.
//
// A PURE FUNCTION OF THE SAVED GRID, and deliberately so: three passes ask it and none of them may
// depend on having run first — FacilityTables for the contact pool under the screen, FacilityClutter
// for the footprint its paper has to keep clear of, and `build` below for the geometry itself. The
// same discipline FacilityPoint.places and FacilityDeco.rectOf already keep
  public static function at(m:Facility, col:Int, row:Int):WorkSpot
    {
      if (!m.table[row][col] ||
          m.surf[row][col] != Surf.OFFICE ||
          m.tableSink[row][col])
        return null;
      var h = FacilityModel.mix((col * 374761393) ^ (row * 40503));
      if (h % FacilityStyle.WORK_EVERY != 0)
        return null;
      var dir = FacilityTables.wallHand(m, col, row);
      if (dir < 0)
        return null;
      var c = CityConfig.cellToWorld(col, row);
      // back of the desk = the wall hand, measured from the CELL's own edge on that side
      var back = CELL / 2 - FacilityStyle.WORK_BACK;
      var x = c.x + DC[dir] * back;
      var z = c.z + DR[dir] * back;
      // and which hand the TOWER stands on, off the same hash `set` rolls it from — asked for here
      // rather than re-derived, because FacilityClutter puts the desk's paperwork on the OTHER end and
      // a second copy of this roll is a second place for it to drift
      var g = FacilityModel.mix((col * 971658137) ^ (row * 1266489917));
      var ts = (g % 2 == 0 ? 1.0 : -1.0);
      var tx = (dir < 2 ? 1.0 : 0.0), tz = (dir < 2 ? 0.0 : 1.0);
      return {
        x: x,
        z: z,
        dir: dir,
        tx: x + tx * ts * FacilityStyle.WORK_TOWER_OFF,
        tz: z + tz * ts * FacilityStyle.WORK_TOWER_OFF,
        side: ts,
      };
    }

// THE TWO SLOTS ONE DESK HAS, and the whole of the free worktop on a 4.0 x 2.6 one: the END the tower
// is not on, at the BACK of it and at the FRONT. Empty for a cell carrying no workstation.
//
// MEASURED RATHER THAN CHOSEN. The screen takes the centre line, the tower one end of the back row
// and the keyboard 1.5 of the front row's middle; what is left is a strip 1.13 wide down the far end,
// and two objects is what fits in it once each keeps its own box clear of the next. Both used to be on
// the BACK row 0.6 apart, where a mug and a 1.00-wide document tray overlapped by construction.
//
// PUBLIC BECAUSE THE FRONT ONE IS SHARED. render.facility.FacilityClutter's paperwork takes it when no
// mug rolled in — a slot is one piece's whatever draws it, and two families cannot arbitrate that
// without agreeing where the slot IS. Index 0 is the back, 1 the front
  public static function spots(m:Facility, col:Int, row:Int):Array<{ x:Float, z:Float }>
    {
      var p = at(m, col, row);
      if (p == null)
        return [];
      // along the wall, away from the tower — `at` has already rolled which hand that is
      var ax = (p.dir < 2 ? 1.0 : 0.0), az = (p.dir < 2 ? 0.0 : 1.0);
      var s = -p.side;
      var out = p.dir ^ 1;
      var ex = p.x + ax * s * FacilityStyle.WORK_TRINKET_RUN;
      var ez = p.z + az * s * FacilityStyle.WORK_TRINKET_RUN;
      return [
        {
          x: ex - DC[out] * FacilityStyle.WORK_TRINKET_BACK,
          z: ez - DR[out] * FacilityStyle.WORK_TRINKET_BACK,
        },
        {
          x: ex + DC[out] * FacilityStyle.WORK_TRINKET_FWD,
          z: ez + DR[out] * FacilityStyle.WORK_TRINKET_FWD,
        },
      ];
    }

// every footprint on this worktop cell that nothing rolls: the decoration the generator stood there,
// and the three machines of a workstation, each on its OWN box.
//
// THE ORDER IS THE PRIORITY and the list is the only one there is. What cannot be moved goes in first
// — a decoration is in the save and the machines are geometry — and everything rolled afterwards
// reads it. See ClutterSlot for why three keep-clear CIRCLES could not do this job on a 2.6-deep desk
  static function base(m:Facility, col:Int, row:Int):Array<ClutterSlot>
    {
      var out:Array<ClutterSlot> = [];
      var c = CityConfig.cellToWorld(col, row);
      // the STANDING sprite's own footprint, off the contact circle FacilityModel.tableDeco measured
      // from the icon's alpha box — so a flask whose opaque box sits to one side still leaves the
      // other side usable. A cell that is taken with NO pool is one of the three frames that LIE DOWN
      // (Const.FACILITY_FLAT_DECO): nothing flat casts a shadow so it has no entry, but it is still
      // art on the worktop and gets a nominal footprint instead of being read as empty
      var pool = m.tableDeco[row][col];
      if (pool != null)
        out.push({
          x: c.x + pool.dx,
          z: c.z + pool.dz,
          hw: pool.r,
          hd: pool.r,
        });
      else if (m.tableTaken[row][col])
        out.push({
          x: c.x,
          z: c.z,
          hw: FacilityStyle.CLUTTER_FLAT_R,
          hd: FacilityStyle.CLUTTER_FLAT_R,
        });
      var p = at(m, col, row);
      if (p == null)
        return out;
      // and the three machines. `dir < 2` is the whole of their rotation — a desk hugs a wall and a
      // wall runs on an axis — so each box is the glb's authored W and D read onto the world axes,
      // exactly as FacilityWork.pools lays the contact ramp under it
      var alongX = (p.dir < 2);
      var fwd = p.dir ^ 1;
      out.push(ClutterSlotTools.flat(p.x, p.z, FacilityStyle.WORK_FOOT_W,
        FacilityStyle.WORK_FOOT_D, alongX));
      out.push(ClutterSlotTools.flat(p.tx, p.tz, FacilityStyle.WORK_TOWER_W,
        FacilityStyle.WORK_TOWER_D, alongX));
      out.push(ClutterSlotTools.flat(p.x + DC[fwd] * FacilityStyle.WORK_KEY_FWD,
        p.z + DR[fwd] * FacilityStyle.WORK_KEY_FWD,
        FacilityStyle.WORK_KEY_W, FacilityStyle.WORK_KEY_D, alongX));
      return out;
    }

// and the WHOLE list: that, plus every trinket that actually landed. what
// render.facility.FacilityClutter starts its own rejection from, so no decal of its can be laid where
// one of these stands — the single shared claim list this family used to do without
  public static function claims(m:Facility, col:Int, row:Int):Array<ClutterSlot>
    {
      var out = base(m, col, row);
      for (t in trinket(m, col, row))
        out.push(ClutterSlotTools.turned(t.x, t.z, TRINKETS[t.kind].w, TRINKETS[t.kind].d,
          t.yaw));
      return out;
    }

// the four things that stand on a desk BESIDE the machines, and which of them this cell carries.
//
// PURE, LIKE `at` ITSELF, and that is the point of it being here rather than inside `props`: the
// placement is a function of the saved grid alone, so render.facility.FacilityClutter can ask for it
// and keep its paperwork off them without either pass having to run first.
//
// THE BIG ONE AT THE BACK AND THE MUG AT THE FRONT, each ROLLED. Which way round matters: the rolled
// kind reaches 1.00 wide (the tray) and the back row has 1.5 of clear worktop beside the screen,
// where the front row has the keyboard across its middle — put the tray at the front and it is
// rejected by the keyboard at half the yaws it rolls. A mug near the person and a lamp at the back of
// the desk is also simply where they are. Returns kind (an index into TRINKETS), where, and which way
// round.
//
// EITHER MAY BE ABSENT and a mug used to be on every desk of the compound. Two objects at two fixed
// offsets at one fixed yaw on every desk is the rank this family was added to break, and the empty
// roll is what makes a desk somebody's rather than stock — FacilityClutter's own argument for letting
// its count reach zero, applied to the placed half
  public static function trinket(m:Facility, col:Int, row:Int):Array<TrinketSpot>
    {
      var sp = spots(m, col, row);
      if (sp.length == 0)
        return [];
      var taken = base(m, col, row);
      var g = FacilityModel.mix((col * 668265263) ^ (row * 83492791));
      var out:Array<TrinketSpot> = [];
      if ((g >>> 7) % 100 < FacilityStyle.WORK_TRINKET_PCT)
        place(out, taken, 1 + (g >>> 14) % 3, sp[0].x, sp[0].z,
          FacilityModel.mix(g ^ 0x5bf03635));
      if (g % 100 < FacilityStyle.WORK_MUG_PCT)
        place(out, taken, 0, sp[1].x, sp[1].z, g);
      return out;
    }

// jitter one trinket off its nominal spot, turn it, and drop it if the box it lands on is CLAIMED —
// by the decoration standing on the cell, by one of the three machines, or by the trinket placed
// before it. `taken` grows as they go down, which is the whole of what makes a slot one piece's.
//
// Reported from the game twice before this test existed: the plant standing on the decoration every
// time (the old far spot and the icon's own box were both at the back of the desk, so they overlapped
// by construction) and the lamp on the desk's paperwork
  static function place(out:Array<TrinketSpot>, taken:Array<ClutterSlot>, kind:Int,
      x:Float, z:Float, g:Int):Void
    {
      var j = FacilityStyle.WORK_TRINKET_JIT;
      var px = x + (((g % 1000) / 1000) * 2 - 1) * j;
      var pz = z + ((((g >>> 10) % 1000) / 1000) * 2 - 1) * j;
      var yaw = ((g >>> 20) % 1000) / 1000 * 2 * Math.PI;
      var b = ClutterSlotTools.turned(px, pz, TRINKETS[kind].w, TRINKETS[kind].d, yaw);
      if (ClutterSlotTools.hits(taken, px, pz, b.hw, b.hd))
        return;
      taken.push(b);
      out.push({
        kind: kind,
        x: px,
        z: pz,
        yaw: yaw,
      });
    }

// the four of them, index-aligned with `trinket`'s kind — so render.facility.FacilityGround.EXTRA and
// FacilityWarm both derive their rows off this table and a fifth trinket needs no edit in either
  public static final TRINKETS:Array<{ path:String, h:Float, w:Float, d:Float }> = [
    {
      path: RenderConfig.MODELS.facilityDeskMug,
      h: FacilityStyle.WORK_MUG_H,
      w: FacilityStyle.WORK_MUG_W,
      d: FacilityStyle.WORK_MUG_W,
    },
    {
      path: RenderConfig.MODELS.facilityDeskPlant,
      h: FacilityStyle.WORK_PLANT_H,
      w: FacilityStyle.WORK_PLANT_W,
      d: FacilityStyle.WORK_PLANT_W,
    },
    {
      path: RenderConfig.MODELS.facilityDeskLamp,
      h: FacilityStyle.WORK_LAMP_H,
      w: FacilityStyle.WORK_LAMP_W,
      d: FacilityStyle.WORK_LAMP_W,
    },
    {
      path: RenderConfig.MODELS.facilityDeskTray,
      h: FacilityStyle.WORK_TRAY_H,
      w: FacilityStyle.WORK_TRAY_W,
      d: FacilityStyle.WORK_TRAY_D,
    },
  ];

// the contact shade under one desk's set: three quads, one per object, each on its own footprint.
//
// ONE ROUND POOL WAS WRONG AND THE SHAPE IS WHY. render.facility.FacilityTables used to lay a single
// FacilityDetail.deck of radius WORK_R here — the ROUND ramp, which is right for a flask or a
// microscope standing alone on a bench and is a MAT under three rectangular machines spread
// WORK_TOWER_OFF apart. Reported from the game as the monitor having no contact shadow at all, which
// is what a gradient whose edge is nowhere near the object reads as. `pool` is the square-cornered
// ramp and takes the object's own half extents, so each of the three meets its own footprint.
//
// EMITTED HERE AND DRAINED THERE: the collector is FacilityDetail's and the PLATE is the worktop's
// grown rect, which only FacilityTables knows, so it hands it in and this decides the rest off `at`
  public static function pools(m:Facility, col:Int, row:Int, plate:FacilityGeom.Rect):Void
    {
      var p = at(m, col, row);
      if (p == null)
        return;
      var out = p.dir ^ 1;
      var yaw = Math.atan2(DC[out], DR[out]);
      // the half extents are in each glb's OWN frame, before `yaw` turns it — authored front +z, so
      // width is x and depth is z, exactly as the constants are written
      lay(plate, p.x, p.z, FacilityStyle.WORK_FOOT_W, FacilityStyle.WORK_FOOT_D, yaw);
      lay(plate, p.tx, p.tz, FacilityStyle.WORK_TOWER_W, FacilityStyle.WORK_TOWER_D, yaw);
      lay(plate, p.x + DC[out] * FacilityStyle.WORK_KEY_FWD,
        p.z + DR[out] * FacilityStyle.WORK_KEY_FWD,
        FacilityStyle.WORK_KEY_W, FacilityStyle.WORK_KEY_D, yaw);
      // and one under each trinket, off the same table the batches are sized by — at the trinket's OWN
      // yaw and not the desk's, because these turn freely where the three machines do not
      for (t in trinket(m, col, row))
        lay(plate, t.x, t.z, TRINKETS[t.kind].w, TRINKETS[t.kind].d, t.yaw);
    }

// one of those three. `pooled` clamps per side to the plate, so a keyboard near the desk's open edge
// keeps its gradient on the worktop instead of hanging it off the front
  static function lay(plate:FacilityGeom.Rect, cx:Float, cz:Float, w:Float, d:Float,
      yaw:Float):Void
    {
      FacilityDetail.pool({
        cx: cx,
        cz: cz,
        hw: w / 2,
        hd: d / 2,
        yaw: yaw,
        y: FacilityStyle.BENCH_H,
        plate: plate,
      });
    }

// the LEADS and the LIGHTS of every workstation in the compound. `leds` and `cab` belong to other
// families and are borrowed: the lights go in render.facility.FacilityDeco's additive mesh and the
// leads in FacilityCable's ribbon, so this pass costs NO draw call of its own however many desks it
// dresses. The three objects on the worktop are props and come out of `props` below. Returns how
// many desks it dressed
  public static function build(m:Facility, leds:MeshBuf, cab:MeshBuf):Int
    {
      var n = 0;
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            var p = at(m, col, row);
            if (p == null)
              continue;
            set(leds, cab, m, col, row, p);
            n++;
          }
      return n;
    }

// the three objects standing on those desks, one instanced batch each. a SECOND walk of the grid
// rather than a second return value out of `build`: `at` is a pure function of the saved grid and
// four passes already ask it that way (FacilityTables, FacilityClutter, FacilityClues, `build`), and
// the batches have to be made where FacilityArea's cull list is, which is long after the two
// borrowed buffers have to be filled
  public static function props(scene:Scene, m:Facility):Array<Models.InstancedProp>
    {
      var mon:Array<Models.PropPlace> = [];
      var tow:Array<Models.PropPlace> = [];
      var key:Array<Models.PropPlace> = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            var p = at(m, col, row);
            if (p == null)
              continue;
            // every piece faces the way the screen looks — away from the wall and at whoever sits
            // there. a glb's authored front is +z, so this is the chairs' own yaw convention
            var out = p.dir ^ 1;
            var yaw = Math.atan2(DC[out], DR[out]);
            mon.push({
              x: p.x,
              z: p.z,
              yaw: yaw,
              y: FacilityStyle.BENCH_H,
            });
            tow.push({
              x: p.tx,
              z: p.tz,
              yaw: yaw,
              y: FacilityStyle.BENCH_H,
            });
            key.push({
              x: p.x + DC[out] * FacilityStyle.WORK_KEY_FWD,
              z: p.z + DR[out] * FacilityStyle.WORK_KEY_FWD,
              yaw: yaw,
              y: FacilityStyle.BENCH_H,
            });
          }
      // the heights are the constants and not the meshes' own bboxes, which differ by the bevel: the
      // monitor measures 1.7751 against the 1.77 its three constants sum to and the keyboard 0.0992
      // against 0.1, so the batch scale lands at 0.997 and 1.008. Feeding the measured number instead
      // would put a second copy of the model's dimensions in this file, where they would drift the
      // first time the bevel changes
      var out = [
        batch(scene, RenderConfig.MODELS.facilityMonitor, mon, FacilityStyle.WORK_FOOT_H +
          FacilityStyle.WORK_STAND_H + FacilityStyle.WORK_SCREEN_H),
        batch(scene, RenderConfig.MODELS.facilityTower, tow, FacilityStyle.WORK_TOWER_H),
        batch(scene, RenderConfig.MODELS.facilityKeyboard, key, FacilityStyle.WORK_KEY_H),
      ];
      // and the trinkets, one batch per kind — a second walk of the same grid, because `trinket` is
      // pure and asking it twice is cheaper than carrying its answer through this function
      var tr = [for (_ in TRINKETS) new Array<Models.PropPlace>()];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            for (t in trinket(m, col, row))
              tr[t.kind].push({
                x: t.x,
                z: t.z,
                yaw: t.yaw,
                y: FacilityStyle.BENCH_H,
              });
          }
      for (i in 0...TRINKETS.length)
        out.push(batch(scene, TRINKETS[i].path, tr[i], TRINKETS[i].h));
      return out;
    }

// one of those batches. behind the loader callback because the mesh does not exist until the glb
// resolves, and only for a batch that placed something. NOT CASTING and MASK-PATCHED, both
// FacilityKit's own findings: an instanced batch is drawn into the moon's shadow map as many times
// as into the frame, and these stand on a desk indoors under a roof that fades
  static function batch(scene:Scene, path:String, places:Array<Models.PropPlace>,
      h:Float):Models.InstancedProp
    {
      var p = Models.instanced(scene, path, places, h, SOLID);
      if (places.length > 0)
        Models.get(path, function(_)
          {
            VisionMask.patchMesh(p.mesh);
            p.mesh.castShadow = false;
          });
      return p;
    }

// one desk's leads and lights. everything here is axis-aligned, because a desk hugs a wall and a
// wall runs on an axis — so both borrowed buffers take world coordinates with no transform, which is
// what lets them merge into the two meshes they belong to
  static function set(leds:MeshBuf, cab:MeshBuf, m:Facility, col:Int, row:Int,
      p:WorkSpot):Void
    {
      var cx = p.x, cz = p.z, dir = p.dir;
      // `out` is the way the screen looks, i.e. away from the wall and at whoever sits there — the
      // bug this pass was opened on was a screen facing the masonry
      var out = dir ^ 1;
      var nx = DC[out] * 1.0, nz = DR[out] * 1.0;
      // and the run axis, which is the one the wall hand is NOT on. the tower goes along it
      var tx = (dir < 2 ? 1.0 : 0.0), tz = (dir < 2 ? 0.0 : 1.0);
      var y = FacilityStyle.BENCH_H;
      var g = FacilityModel.mix((col * 971658137) ^ (row * 1266489917));
      // the tower's status lights, on the front face of the prop standing at `at`'s tower centre —
      // `at` rolled that hand off this same hash and hands it over, so the lights and the batch that
      // draws the case cannot disagree about which end it is on
      var wx = p.tx, wz = p.tz;
      lights(leds, wx, y, wz, nx, nz, tx, tz, g);
      // and the screen itself, into the same buffer and so onto the same one draw call
      screen(leds, cx, y, cz, nx, nz, tx, tz, g);

      var kx = cx + nx * FacilityStyle.WORK_KEY_FWD;
      var kz = cz + nz * FacilityStyle.WORK_KEY_FWD;
      // the two leads. both leave the keyboard's BACK edge and both lie on the worktop, so the bow
      // rides the horizontal perpendicular of their own chord — see FacilityCable.strip, whose
      // `side` hint is what decides which way a run curves when the seed would otherwise
      var ky = y + FacilityStyle.WORK_CABLE_Y;
      var ka = [kx - nx * FacilityStyle.WORK_KEY_D / 2, ky, kz - nz * FacilityStyle.WORK_KEY_D / 2];
      FacilityCable.strip(cab, {
        a: ka,
        c: [cx, ky, cz],
        n: UP,
        side: null,
        bow: FacilityStyle.WORK_CABLE_BOW,
        wave: FacilityStyle.WORK_CABLE_WAVE,
        seed: g,
      });
      FacilityCable.strip(cab, {
        a: ka,
        c: [wx, ky, wz],
        n: UP,
        side: null,
        bow: FacilityStyle.WORK_CABLE_BOW,
        wave: FacilityStyle.WORK_CABLE_WAVE,
        seed: g ^ 40503,
      });
    }

// the tower's status lights: a column of specks on its front face, each with its own blink phase.
//
// pushed into render.facility.FacilityDeco's OWN additive buffer, so they join the server racks'
// mesh and the machines' — one draw call for every blinking thing in the compound, and no per-frame
// work at all beyond the clock that family already ticks. `b` in 0..1 picks the RACK branch of the
// shader patch there, which is a square wave at DECO_LED_RATE: one blink per ~3 turn-durations,
// which is a machine at rest rather than a sequencer running
  static function lights(b:MeshBuf, cx:Float, y:Float, cz:Float, nx:Float, nz:Float,
      tx:Float, tz:Float, g:Int):Void
    {
      var d = FacilityStyle.WORK_TOWER_D / 2 + FacilityStyle.WORK_LED_EPS;
      var s = FacilityStyle.WORK_LED_SIZE / 2;
      var fx = cx + nx * d, fz = cz + nz * d;
      for (i in 0...FacilityStyle.WORK_LED_N)
        {
          var hh = FacilityModel.mix(g ^ (i * 40503));
          // up the face, in its top third where a case carries its ports
          var yc = y + FacilityStyle.WORK_TOWER_H * (0.72 + 0.1 * i);
          var ac = 0.0 - FacilityStyle.WORK_TOWER_W * 0.25;
          var px = fx + tx * ac, pz = fz + tz * ac;
          var lvl = 0.7 + ((hh % 1000) / 1000) * 0.3;
          var ph = ((hh >>> 11) % 1000) / 1000;
          var hue = ((hh >>> 21) % 3 == 0 ? 0.0 : 1.0);
          MeshBufTools.quadRGB(b,
            [px - tx * s, yc - s, pz - tz * s],
            [px + tx * s, yc - s, pz + tz * s],
            [px + tx * s, yc + s, pz + tz * s],
            [px - tx * s, yc + s, pz - tz * s],
            [0, 0, 1, 0, 1, 1, 0, 1], lvl, ph, hue);
        }
    }

// the glow of a screen that is ON: one quad lying on the monitor's own glass, in the same additive
// mesh as the tower's lights and burning that mesh's THIRD pattern (see FacilityDeco.blink) — two
// sines with no common period, shallow, so it wobbles and never loops. A monitor blinking like a rack
// port would be a fault light and a monitor running a chase would be a sequencer; what a screen does
// is neither, and it is three instructions on a mesh that already exists.
//
// THE FACE IS TILTED AND SO IS THIS. The shell leans WORK_SCREEN_TILT back about its own base, so the
// glass has an up axis and an outward normal that are not the world's — both are built here off the
// one constant the model was authored with, which is why that angle stopped being a number private to
// computer_build.py. The quad is the art's LIT rect and not the screen's full face: the glass ends
// where the modelled bezel begins and lighting the frame would read as a glowing slab
  static function screen(b:MeshBuf, cx:Float, y:Float, cz:Float, nx:Float, nz:Float,
      tx:Float, tz:Float, g:Int):Void
    {
      var a = FacilityStyle.WORK_SCREEN_TILT * Math.PI / 180;
      var ct = Math.cos(a), st = Math.sin(a);
      // the glass's own frame: `n` out of it, `u` up it, and the run axis across it unturned
      var n = [nx * ct, st, nz * ct];
      var u = [-nx * st, ct, -nz * st];
      var hw = FacilityStyle.WORK_SCREEN_W * FacilityStyle.WORK_SCREEN_GLOW_W / 2;
      var hh = FacilityStyle.WORK_SCREEN_H * FacilityStyle.WORK_SCREEN_GLOW_H / 2;
      // the shell turns about its base, so its centre rides `u` up from there — and the glass sits a
      // half depth out of that, plus the standoff every additive quad in this family keeps
      var d = FacilityStyle.WORK_SCREEN_D / 2 + FacilityStyle.WORK_LED_EPS;
      var by = y + FacilityStyle.WORK_FOOT_H + FacilityStyle.WORK_STAND_H;
      var mh = FacilityStyle.WORK_SCREEN_H / 2;
      var c = [cx + u[0] * mh + n[0] * d,
               by + u[1] * mh + n[1] * d,
               cz + u[2] * mh + n[2] * d];
      inline function at(s:Float, t:Float)
        return [c[0] + tx * hw * s + u[0] * hh * t,
                c[1] + u[1] * hh * t,
                c[2] + tz * hw * s + u[2] * hh * t];
      // a phase of its own per desk, so no two screens in a room wobble together
      var ph = ((FacilityModel.mix(g ^ 971658137) >>> 7) % 1000) / 1000;
      MeshBufTools.quadRGB(b, at(-1, -1), at(1, -1), at(1, 1), at(-1, 1),
        [0, 0, 1, 0, 1, 1, 0, 1], FacilityStyle.WORK_SCREEN_LEVEL, ph, 4.0);
    }

// the chairs, one instanced batch for the compound. one per workstation and none anywhere else: a
// chair at a desk nobody works at is furniture, a chair at a workstation is somebody's seat
  public static function chairs(scene:Scene, m:Facility):Models.InstancedProp
    {
      var places:Array<Models.PropPlace> = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            var p = at(m, col, row);
            if (p == null)
              continue;
            var out = p.dir ^ 1;
            var c = CityConfig.cellToWorld(col, row);
            // MEASURED OFF THE DESK'S OWN FACE, not off the cell edge, and the difference is 1.2.
            // An office desk is DESK_D 2.6 deep in a 4.0 cell — thinned on the OPEN side alone, so
            // the run hugs the wall — plus a BENCH_LIP overhang past that. Placing the chair off the
            // CELL edge therefore left it 1.2 further out than it looked, which is a gap wider than
            // the chair is deep and put it in the walkway rather than at the desk
            var face = FacilityStyle.DESK_D + FacilityStyle.BENCH_LIP - CELL / 2;
            var x = c.x + DC[out] * (face + FacilityStyle.CHAIR_OUT);
            var z = c.z + DR[out] * (face + FacilityStyle.CHAIR_OUT);
            // the cell it would stand in has to be clear floor — a desk run facing another run, or
            // one against the far side of a narrow room, has nowhere to put a seat
            var nc = col + DC[out], nr = row + DR[out];
            if (!FacilityModel.isIndoor(m, nc, nr) ||
                FacilityModel.isTable(m, nc, nr) ||
                m.deco[nr][nc] > 0)
              continue;
            var g = FacilityModel.mix((col * 1266489917) ^ (row * 971658137));
            places.push({
              x: x,
              z: z,
              // facing the desk, with a little play either side so a room of them is not a showroom
              yaw: Math.atan2(DC[p.dir], DR[p.dir]) +
                (((g % 1000) / 1000) - 0.5) * 2 * FacilityStyle.CHAIR_YAW_JIT,
              y: 0.0,
            });
            ContactMask.prop(x - CELL / 4, x + CELL / 4, z - CELL / 4, z + CELL / 4);
          }
      var prop = Models.instanced(scene, CHAIR_PATH, places,
        FacilityStyle.CHAIR_H, SOLID);
      // NOT CASTING, the indoor drums' own finding: an instanced batch is drawn into the moon's
      // shadow map as many times as into the frame, and these stand under a faded roof
      if (places.length > 0)
        Models.get(CHAIR_PATH, function(_)
          {
            VisionMask.patchMesh(prop.mesh);
            prop.mesh.castShadow = false;
          });
      return prop;
    }
}
