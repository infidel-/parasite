package render.facility;

import three.Three;
import citygen.CityConfig;
import render.Textures;
import render.facility.ClutterSlot.ClutterSlotTools;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// the small FLAT things lying about on the laboratory worktops — a clipboard, a petri dish, a coiled
// cable, a scatter of screws. Scattered at free positions and free yaw over every bench cell, around
// whatever already stands there.
//
// RENDER-ONLY DRESSING, and that is the decision the rest of this file follows from. These are not
// objects.Decoration: they carry no atlas frame, take no cell, block no movement and never enter a
// save. Every position, size, turn and choice of art is rolled off FacilityModel.mix on the cell, the
// discipline FacilityDeco.boxes and FacilitySink.pick already keep — so an area comes back identical
// on every rebuild and nothing had to be migrated to add them.
//
// AN 8x8 SHEET, WHICH IS THE WRONG GRID FOR A BILLBOARD AND THE RIGHT ONE HERE. docs/3d-textures.md
// carries the measurement: a 1024 generation cut into 64 cells hands each object ~89 px of art, and
// over the 2.43 world units a bench SPRITE spans that is 52.7 texels per unit — under
// facility/floor-tile's 73 and back inside the band the game reported as blurry. Over the 0.8 units
// one of THESE is drawn at it is 111, half again past the floor tile. Density is art px over the size
// a thing is DRAWN at, never over the cell it was cut from, and that second step is the whole reason
// 64 subjects fit on one $0.053 sheet.
//
// AND ONE MERGED MESH, so the whole family is ONE draw call however many decals land. That is the
// other half of why the pack is a pack: 64 separate textures would be 64 materials and 64 calls, and
// the sprite pool next door already pays one call per quad (docs/3d-render.md: "every pooled quad is
// a draw call"). A u/v sub-rect is four numbers.
//
// WHAT IT DODGES IS NOT THIS PASS'S LIST ANY MORE. A SINK owns its cell outright —
// FacilityStyle.SINK_BASIN_W is 2.5 of a 4.0 cell, so there is no worktop left beside one and the cell
// is skipped whole (m.tableSink, which FacilitySink fills as it emits). Everything else standing on
// the worktop comes back from render.facility.FacilityWork.claims as a list of BOXES — the
// generator's decoration, the three machines, the trinkets — and this appends its own to the same
// list as they go down. One shared claim list in one priority order is the model; see ClutterSlot for
// what it replaced and why a radius could not do it. Cross-cell overlap cannot happen: an item's
// offset is inset by its own half size, so nothing ever crosses a cell boundary.
class FacilityClutter
{
  // the four cell-edge directions, in FacilityGeom.face's order: 0 = -z, 1 = +z, 2 = -x, 3 = +x
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

  // the sheet cells actually dealt, built once off FacilityStyle.CLUTTER_SKIP. derived rather than
  // written out so the skip list stays the one place the measurement lives — see its comment for why
  // seven of the 64 read as a hole in the worktop and why a lift cannot fix them
  static var PICK:Array<Int> = [
    for (i in 0...FacilityStyle.CLUTTER_CELLS)
      if (FacilityStyle.CLUTTER_SKIP.indexOf(i) < 0) i
  ];
  // and the office desks' own sheet, cut the same 8x8 way. a second SHEET and not more cells on the
  // first: a beaker, a petri dish and a pipette stand are the laboratory's, and a desk wants paper
  static var PICK_OFFICE:Array<Int> = [
    for (i in 0...FacilityStyle.CLUTTER_CELLS)
      if (FacilityStyle.CLUTTER_OFFICE_SKIP.indexOf(i) < 0) i
  ];

// every decal in the compound as ONE merged mesh. returns how many landed, for __facility() — a
// merged mesh has no instance count and this is the only handle on the family, the same reason
// FacilitySink.build returns its own
  public static function build(scene:Scene, m:Facility):Int
    {
      var b = MeshBufTools.make();
      var bOffice = MeshBufTools.make();
      var n = 0;
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            // a bench cell, and not one a basin is lying across
            if (!m.table[row][col] ||
                m.tableSink[row][col])
              continue;
            var office = (m.surf[row][col] == Surf.OFFICE);
            n += cell(office ? bOffice : b, m, col, row, office ? PICK_OFFICE : PICK, office);
          }
      n += slots(m, b, bOffice);
      add(scene, b, FacilityStyle.CLUTTER_TEX);
      add(scene, bOffice, FacilityStyle.CLUTTER_OFFICE_TEX);
      return n;
    }

// the CLUTTER SLOTS: every piece of standing furniture with a usable LID, dressed the same way a
// worktop is and out of the same two sheets.
//
// TWO KINDS AND NOT EVERY FITTING, and the test is whether the top is a surface somebody would put
// something down on. A bookcase's lid is flat and at hand height; the lounge table exists to have
// things on it and read as a moulded slab without them. A rack is louvred, a machine's lid carries a
// drawn gland (art/textures.json facility/deco-machine-top) and a cabinet is chest-high with a
// rounded top — none of the three is a shelf.
//
// THE RECT COMES OFF FacilityDeco.rectOf, which is the same pure function of the saved grid the
// electrical service asks for the same reason: the lid's real footprint is the fitting slid along its
// own wall and stood STAND_GAP off the slab face, and a second copy of that arithmetic here would be
// wrong in exactly the places that are hard to see
  static function slots(m:Facility, lab:MeshBuf, office:MeshBuf):Int
    {
      var n = 0;
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            var kind = m.deco[row][col] - 1;
            if (kind != _FittingKind.FIT_BOOKCASE &&
                kind != _FittingKind.FIT_TABLE_LOW)
              continue;
            var isOffice = (m.surf[row][col] == Surf.OFFICE);
            n += slot(isOffice ? office : lab, m, col, row, kind,
              isOffice ? PICK_OFFICE : PICK);
          }
      return n;
    }

// one lid's worth: 0..CLUTTER_SLOT_MAX items scattered over it, each inset by its own half size so
// nothing overhangs, and spaced off the ones already down. the same rejection sampler `cell` runs,
// against a rect that is the FITTING and not the grid
  static function slot(b:MeshBuf, m:Facility, col:Int, row:Int, kind:Int, pick:Array<Int>):Int
    {
      var q = FacilityDeco.rectOf(m, col, row, kind);
      var g = FacilityModel.mix((col * 1274126177) ^ (row * 1103515245));
      var want = g % (FacilityStyle.CLUTTER_SLOT_MAX + 1);
      // and the LOUNGE TABLE is floored at one, for the workstation desk's reason one function down:
      // a bookcase lid is a lid and may be bare, where a low table in front of a sofa exists to have
      // something on it and reads as an unused moulding without
      if (kind == _FittingKind.FIT_TABLE_LOW &&
          want == 0)
        want = 1;
      var cx = (q.x0 + q.x1) / 2, cz = (q.z0 + q.z1) / 2;
      var spots:Array<ClutterSlot> = [];
      var n = 0;
      for (i in 0...want)
        {
          var h = FacilityModel.mix(g ^ ((i + 1) * 668265263));
          var sz = FacilityStyle.CLUTTER_SZ +
            ((h % 1000) / 1000) * FacilityStyle.CLUTTER_SZ_VAR;
          var lid = Math.min(q.x1 - q.x0, q.z1 - q.z0) * FacilityStyle.CLUTTER_SLOT_FILL;
          if (sz > lid)
            sz = lid;
          var rx = (q.x1 - q.x0) / 2 - sz * 0.5 - FacilityStyle.CLUTTER_SLOT_INSET;
          var rz = (q.z1 - q.z0) / 2 - sz * 0.5 - FacilityStyle.CLUTTER_SLOT_INSET;
          if (rx <= 0 ||
              rz <= 0)
            continue;
          var yaw = ((h >>> 12) % 1000) / 1000 * 2 * Math.PI;
          var ok = false;
          var box = ClutterSlotTools.turned(cx, cz, sz, sz, yaw);
          for (t in 0...FacilityStyle.CLUTTER_TRIES)
            {
              var hh = FacilityModel.mix(h ^ ((t + 1) * 83492791));
              box.x = cx + (((hh % 1000) / 1000) * 2 - 1) * rx;
              box.z = cz + ((((hh >>> 10) % 1000) / 1000) * 2 - 1) * rz;
              ok = !ClutterSlotTools.hits(spots, box.x, box.z, box.hw, box.hd);
              if (ok)
                break;
            }
          if (!ok)
            continue;
          spots.push(box);
          emit(b, box.x, box.z, sz, yaw, pick[(h >>> 22) % pick.length],
            q.h + FacilityStyle.CLUTTER_Y);
          n++;
        }
      return n;
    }

// one bench cell's worth. returns how many actually landed, which is not the rolled count: an item
// that cannot find room in CLUTTER_TRIES attempts is simply dropped rather than pushed somewhere it
// does not fit.
//
// THE ROLLED COUNT REACHES ZERO ON PURPOSE. `h % (CLUTTER_MAX + 1)` gives 0..3 evenly, and the empty
// cells are what stop 139 worktops reading as a grid again — which is the whole complaint this family
// answers. Flooring it at 1 would put a thing on every cell and rebuild the rhythm.
//
// EXCEPT ON A WORKSTATION DESK, which is the one cell where the empty roll is the wrong answer: a
// researcher's desk is a SET — the desk, the chair, the machine and something of the occupant's lying
// beside the keyboard — and a screen and a tower with a bare worktop around them reads as stock
// rather than as somebody's place. So such a cell is offered the desk's own front SLOT on top of
// whatever it rolls (see the block below), and the rolled count keeps reaching zero. The lab's own
// rhythm is untouched either way, because a lab has no workstation on it: FacilityWork.at is
// Surf.OFFICE only
  static function cell(b:MeshBuf, m:Facility, col:Int, row:Int, pick:Array<Int>,
      office:Bool):Int
    {
      var g = FacilityModel.mix((col * 1103515245) ^ (row * 12345));
      // the office desk's workstation, which stands on the worktop and is not a decoration at all —
      // it is emitted by FacilityWork off the grid, so it is asked for rather than read out of a grid
      // this pass could have run before. Asked HERE because it floors the count as well as taking
      // room
      var pc = FacilityWork.at(m, col, row);
      var want = g % (FacilityStyle.CLUTTER_MAX + 1);
      if (want == 0 &&
          pc == null)
        return 0;
      var c = CityConfig.cellToWorld(col, row);
      // EVERYTHING ALREADY ON THIS WORKTOP, as boxes, in the order it took the surface: the standing
      // or lying decoration the generator left, the three machines of a workstation, and the trinkets
      // that landed on it. ASKED FOR rather than re-derived, which is why every one of those is a pure
      // function of the saved grid — and one list rather than this pass's own guesses at each, which
      // is what put a decal under the tower and a lamp on the paperwork. See ClutterSlot
      var spots = FacilityWork.claims(m, col, row);
      // WHERE THE WORKTOP ACTUALLY IS, which on an office desk is not the cell. A desk is a bench cut
      // to FacilityStyle.DESK_D on its OPEN side (FacilityTables.build, `var cut`), so a decal
      // wandering the whole cell lands up to (CELL - DESK_D) / 2 past the front edge and lies at
      // BENCH_H over bare floor — reported from the game as a table decoration floating in the air
      // beside the desk. The centre slides back toward the wall by exactly that cut and the span
      // shrinks by it, so the rect this rolls in IS the worktop; both numbers come off DESK_D and
      // FacilityTables' own hand search, so the geometry and the dressing cannot drift apart
      var hand = (office ? FacilityTables.wallHand(m, col, row) : -1);
      var dx = 0.0, dz = 0.0;
      var deep:Float = CityConfig.CELL;
      if (hand >= 0)
        {
          var cut = (CityConfig.CELL - FacilityStyle.DESK_D) / 2;
          deep = FacilityStyle.DESK_D;
          dx = DC[hand] * cut;
          dz = DR[hand] * cut;
        }
      var n = 0;
      // THE DESK'S OWN ITEM IS OFFERED A SLOT, NOT A POSITION, and that is the difference between this
      // and the version that was reported. Everything else in this family finds its spot by rejection
      // sampling, which works on a bench because a bench is 4 x 4 of free worktop; a workstation desk
      // is 4 x 2.6 with a screen, a stand, a keyboard and a tower on it, so MEASURED over ten desks
      // the sampler placed one on five of them — half the offices with a machine and a bare worktop.
      // So it is handed the front slot of the desk's free end outright (FacilityWork.spots, the same
      // two the trinkets are dealt from).
      //
      // AND THE SLOT MAY ALREADY BE THE MUG'S, which is the whole of the arbitration: the front one
      // takes a mug 70% of the time and the paperwork the rest, decided by nothing more than this box
      // failing the claim test. Placed outright at its own fixed offset instead, it landed 0.05 from
      // the trinket beside it on every desk in the compound
      var sp = FacilityWork.spots(m, col, row);
      if (sp.length > 0)
        {
          var sz = FacilityStyle.CLUTTER_DESK_SZ;
          var yaw = ((g >>> 12) % 1000) / 1000 * 2 * Math.PI;
          var box = ClutterSlotTools.turned(sp[1].x, sp[1].z, sz, sz, yaw);
          if (!ClutterSlotTools.hits(spots, box.x, box.z, box.hw, box.hd))
            {
              spots.push(box);
              emit(b, box.x, box.z, sz, yaw, pick[(g >>> 22) % pick.length],
                FacilityStyle.BENCH_H + FacilityStyle.CLUTTER_Y);
              n++;
            }
        }
      for (i in 0...want)
        {
          var h = FacilityModel.mix(g ^ ((i + 1) * 40503));
          var sz = FacilityStyle.CLUTTER_SZ +
            ((h % 1000) / 1000) * FacilityStyle.CLUTTER_SZ_VAR;
          // how far the CENTRE may wander: half the worktop, less the item's own half size, so the
          // quad never crosses into a neighbour and no cross-cell test is needed. PER AXIS, because
          // a desk is only `deep` on the hand its own wall is on
          var room = CityConfig.CELL / 2 - sz * 0.5;
          var roomD = deep / 2 - sz * 0.5;
          if (room <= 0 ||
              roomD <= 0)
            continue;
          var rx = (hand >= 2 ? roomD : room);
          var rz = (hand >= 0 && hand < 2 ? roomD : room);
          var yaw = ((h >>> 12) % 1000) / 1000 * 2 * Math.PI;
          var ok = false;
          var box = ClutterSlotTools.turned(c.x + dx, c.z + dz, sz, sz, yaw);
          for (t in 0...FacilityStyle.CLUTTER_TRIES)
            {
              var hh = FacilityModel.mix(h ^ ((t + 1) * 83492791));
              box.x = c.x + dx + (((hh % 1000) / 1000) * 2 - 1) * rx;
              box.z = c.z + dz + ((((hh >>> 10) % 1000) / 1000) * 2 - 1) * rz;
              ok = !ClutterSlotTools.hits(spots, box.x, box.z, box.hw, box.hd);
              if (ok)
                break;
            }
          if (!ok)
            continue;
          spots.push(box);
          emit(b, box.x, box.z, sz, yaw, pick[(h >>> 22) % pick.length],
            FacilityStyle.BENCH_H + FacilityStyle.CLUTTER_Y);
          n++;
        }
      return n;
    }

// one decal: a square quad lying flat on the worktop, TURNED about its own centre.
//
// it cannot go through FacilityGeom.cap, which takes an axis-aligned rect — and the turn is the point.
// A rank of square-on cut-outs reads as a layout; a free yaw reads as things someone put down. The
// corners walk FacilityDeco.crate's cyclic order, wound to FacilityGeom.cap's own winding so the face
// looks UP.
//
// THE UV IS THE SHEET'S CELL and v is flipped, the trap FacilitySink.emit records: three flips y, so
// the source's TOP row is the HIGH v. Reading order across the sheet is the same order the prompt
// listed its 64 subjects in
// `y` is a parameter for the CLUTTER SLOTS and nothing else: a bench decal lies at BENCH_H and a slot
// decal at its own fitting's lid, and that is the only difference between the two families
  static function emit(b:MeshBuf, x:Float, z:Float, sz:Float, yaw:Float, idx:Int, y:Float):Void
    {
      var hs = sz * 0.5;
      var cs = Math.cos(yaw), sn = Math.sin(yaw);
      // the same cyclic order `crate` uses, so the winding below is cap's and the quad faces up
      var lx = [ -hs, hs, hs, -hs ];
      var lz = [ hs, hs, -hs, -hs ];
      var wx = [], wz = [];
      for (i in 0...4)
        {
          wx.push(x + lx[i] * cs - lz[i] * sn);
          wz.push(z + lx[i] * sn + lz[i] * cs);
        }
      var t = FacilityStyle.CLUTTER_COLS;
      var cc = idx % t, cr = Std.int(idx / t);
      var u0 = cc / t, u1 = (cc + 1) / t;
      var v0 = 1 - (cr + 1) / t, v1 = 1 - cr / t;
      MeshBufTools.quad(b,
        [wx[0], y, wz[0]], [wx[1], y, wz[1]], [wx[2], y, wz[2]], [wx[3], y, wz[3]],
        [u0, v0, u1, v0, u1, v1, u0, v1]);
    }

// the whole family as one mesh. FacilitySink.add's material exactly, and for its three reasons: an
// opaque alphaTest draws DoubleSide in ONE pass, it still writes depth so nothing sorts against the
// worktop under it, and leaving `transparent` false keeps VisionMask on its darkening branch rather
// than the alpha-scaling one (the trap FacilityGeom.addPane records).
//
// NO CONTACT POOL, unlike everything that STANDS on a bench. A pool is the shadow of a thing meeting
// the surface it rests on; this IS the surface it rests on, with nothing between. The basin beside it
// gets none for the same reason
  static function add(scene:Scene, b:MeshBuf, tex:String):Void
    {
      if (b.idx.length == 0)
        return;
      var mesh = new Mesh(FacilityGeom.geom(b), VisionMask.patch(new MeshLambertMaterial({
        map: Textures.loadTexture(tex, 'wall', 1),
        alphaTest: FacilityStyle.CLUTTER_CUT,
        side: THREE.DoubleSide,
      })));
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
    }
}
