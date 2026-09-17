package render.facility;

import three.Three;
import citygen.CityConfig;
import render.Models;
import render.RenderConfig;
import render.Textures;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// where the compound's gate furniture stands. every field falls out of the entry hole itself, so
// nothing new is persisted and a compound saved long before any of this existed gets its checkpoint
// the next time it is drawn — the same contract render.facility.FacilityGround.bins runs on
typedef Gate = {
  col:Int,       // the hole's low corner, and its size in cells
  row:Int,
  w:Int,
  h:Int,
  lotDR:Int,     // the row step from the hole toward the LOT; the road lies the other way
  mouthRow:Int,  // the first lot row past the hole — the line the booth and the mast stand on
  boothCol:Int,  // the parking bay the booth takes, on the hole's low-column flank
  lampCol:Int,   // and the bay on the far flank, which carries the gate's own mast
};

// the CHECKPOINT at the parking entry: the boom barrier across the drive, and the guard booth
// standing beside it on the bay it takes out of the lot.
//
// this file owns nothing but the arithmetic — three other passes read `find` and act on it, and they
// have to agree or the furniture ends up striped over, unlit or stood in:
//   render.facility.FacilityPaint strikes no bay on the booth's own cell;
//   render.facility.FacilityLamps stands the one mast the lit-line rules cannot deal, on the flank
//     opposite the booth, because the barrier is the thing out here that has to be seen;
//   game.AreaGame.initSpawnPoints puts a guard post in the mouth, mirroring this in the tile grid.
//
// THE BOOM'S OWN ROW IS UNWALKABLE AND THE REST OF THIS IS STILL RENDER-ONLY. The generator stamps
// the mouth row nearest the lot with Const.TILE_ALLEY_UNWALKABLE (gen.facility.FacilityTemp
// .TEMP_BARRIER) — the same asphalt with the walk taken off it, so `find` below still reads it as
// Surf.LOT and everything here is unchanged — because a bar across a drive that the player strolls
// through is decoration. The BOOTH is not stamped: it stands on open lot the way the park railing
// does, and an old compound gets its checkpoint drawn the moment it is entered either way. Only the
// boom's row needs the grid, and a compound saved before that tile existed simply has a boom that
// can be walked under.
//
// NEITHER WAS EVER A GOOD PROP. Both were generated first and both were rebuilt here, and the second rebuild is
// the one worth reading, because the first had a rule drawn round it that turned out to be wrong.
//
// The booth went first, and the argument was that it is a BOX — four clad faces, a glazing band and
// a flat slab over them, about thirty triangles — so the reasoning render.facility.FacilityTables
// wrote down for a bench applies to it exactly: put a box through the generator and you pay for an
// unwrap lottery you did not need. It lost on every number the acceptance gate reports
// (tools/propstat.py on the drop: 40 connected components with the largest holding 58.1%, a 3.14x
// split ratio no decimator can touch, an albedo baked at 91/97/104 against the prop family's 46-52).
//
// THE LINE DRAWN THEN was "a box is not a prop, but the barrier stays one — an arm, a counterweight
// and a cabinet is a shape worth generating". THAT LINE WAS IN THE WRONG PLACE. An arm and a cabinet
// are two boxes at right angles, and the generator scored them almost exactly as it scored the
// booth: 3 components with the largest holding 65.9%, a 2.07x split, and an albedo of 145/125/105.
// Worse, the part everything hinged on came back UNUSABLE — a boom barrier is its hazard bands, and
// the bake returned orange chevrons on tan where the reference had painted red on off-white. There
// was no fix on that path: `baseColor` is a per-channel MULTIPLY, so it can move the level and can
// never put back contrast the generator merged away, which is a note models.json ended up carrying
// as a justification for a fitted-by-hand value 30 points off the family.
//
// SO THE REAL TEST IS NOT "IS IT A BOX", IT IS WHETHER THE THING THAT CARRIES THE OBJECT IS ITS
// SILHOUETTE OR ITS SURFACE. A silhouette is what a mesh generator is for. A stripe pattern is what
// a TILING TEXTURE is for, and a tiling texture cannot lose contrast, cannot smear, holds its
// density at any length, and costs $0.01 to repaint. Built here the barrier is 22 triangles against
// 3,098, its arm is banded by textures/facility/barrier-arm.png at 85 texels per world unit, and its
// LENGTH is derived from the gate hole rather than fixed by a glb's aspect ratio — so a mouth of any
// width is spanned exactly. (THE THIRD ROUTE, behind FacilityStyle.ENTRY_BLENDER, is a mesh
// hand-modelled to these same constants: it cannot derive the span either, and survives only because
// gen.blocks.RoadBlock.ENTRY_W is 4 on every seed. See models-src/facility/entry_build.py.) The booth is exact in the same way, wears the compound's OWN cladding and
// roofing world-aligned at full density rather than a 2048 atlas smeared over a 4-unit box, and takes
// the same lit-ribbon art every window run in the area already does — so the whole tools/emissive.py
// step, and the hand-authored emissive map with it, simply stopped existing
class FacilityEntry
{
  static inline var CELL = CityConfig.CELL;

// where the gate furniture goes, or null for a compound whose entry cannot be read.
//
// the hole is the one game.FacilityAreaGenerator punches through the sidewalk band beside the road
// (4 cells wide by the band's own 2 deep), so FacilityPaint.isEntry already names its eight cells
// and nothing else in the lot: the band always lies between the lot and the road. its bounding box
// is therefore the hole, and which side the LOT is on is whichever side of that box is not pavement
  public static function find(m:Facility):Gate
    {
      var c0 = m.w;
      var c1 = -1;
      var r0 = m.h;
      var r1 = -1;
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (!FacilityPaint.isEntry(m, col, row))
              continue;
            if (col < c0)
              c0 = col;
            if (col > c1)
              c1 = col;
            if (row < r0)
              r0 = row;
            if (row > r1)
              r1 = row;
          }
      if (c1 < 0)
        return null;
      var dr = (isLot(m, c0, r0 - 1) ? -1 : 1);
      var mouth = (dr < 0 ? r0 - 1 : r1 + 1);
      var gate:Gate = {
        col: c0,
        row: r0,
        w: c1 - c0 + 1,
        h: r1 - r0 + 1,
        lotDR: dr,
        mouthRow: mouth,
        boothCol: c0 - 1,
        lampCol: c1 + 1,
      };
      // and both flanking bays have to BE bays. the generator always leaves them open, but this
      // reads a saved grid rather than the generator, and a booth on a wall is worse than no booth
      if (!isLot(m, gate.boothCol, mouth) ||
          !isLot(m, gate.lampCol, mouth))
        return null;
      return gate;
    }

  // which checkpoint the compound draws (FacilityStyle.ENTRY_BLENDER), resolved ONCE and read from
  // here by the three places that have to agree: this file's own batches, FacilityWarm's rows and
  // FacilityArea's EXTRA list. A batch is keyed by PATH, so a site left on the other branch would
  // cost a draw call for the same object — the same reason FacilityGround.BIN_PATH exists
  public static final BARRIER_PATH = RenderConfig.MODELS.facilityBarrier;
  public static final BOOTH_PATH = RenderConfig.MODELS.facilityBooth;

// the checkpoint. TWO BATCHES AND ONE MERGED MESH when ENTRY_BLENDER is on — the boom assembly, the
// kiosk shell, and the glazing band that is still quads either way — and three merged meshes when it
// is off.
//
// it hands back one InstancedProp per batch, ALWAYS and in this order, because FacilityArea's
// `green` has to stay index-aligned with its EXTRA list: an empty batch is a row with a count of 0,
// which is what an emitted checkpoint and a compound with no readable gate both return
  public static function build(scene:Scene, m:Facility):Array<Models.InstancedProp>
    {
      var gate = find(m);
      if (gate == null)
        return [empty(), empty()];
      // both stand on asphalt, which lies a kerb below the pavement (FacilityStyle.KERB_DROP)
      var y = FacilityGround.surfY(Surf.LOT);
      // the glazing is drawn either way and by the same pass: one glb carries ONE material
      // (render.Models.instanced keeps the first mesh and drops the rest), and a lit band wants its
      // own emissive intensity, so the panes stay quads and the mesh is built around their gap
      glazing(scene, gate, y);
      if (!FacilityStyle.ENTRY_BLENDER)
        {
          booth(scene, gate, y);
          barrier(scene, gate, y);
          return [empty(), empty()];
        }
      return [barrierProp(scene, gate, y), boothProp(scene, gate, y)];
    }

// a batch that drew nothing: the row FacilityArea's `green` still has to carry, because that list is
// index-aligned with its EXTRA one and an absent row shifts every batch after it
  static inline function empty():Models.InstancedProp
    {
      return {
        mesh: null,
        matrices: [],
        centres: [],
      };
    }

// the boom assembly as one instance. its own local x runs from the cabinet's low face to the tip, so
// the mouth's own axis is world X and the yaw is 0 — the same assumption `barrier` below makes and
// the prop era's fixed `Math.PI` did not.
//
// THE MESH IS BUILT TO THE MOUTH and cannot stretch: Models.instanced scales by HEIGHT alone, so
// BARRIER_CAB_H is passed as the target and the scale comes out 1. That is only sound because the
// hole is gen.blocks.RoadBlock.ENTRY_W cells on every seed — see models-src/facility/entry_build.py
  static function barrierProp(scene:Scene, gate:Gate, y:Float):Models.InstancedProp
    {
      var row = gate.row + (gate.lotDR < 0 ? 0 : gate.h - 1);
      var a = CityConfig.cellToWorld(gate.col, row);
      var x0 = a.x - CELL / 2 + FacilityStyle.BARRIER_INSET;
      var x1 = a.x - CELL / 2 + gate.w * CELL - FacilityStyle.BARRIER_TIP;
      var prop = Models.instanced(scene, BARRIER_PATH, [{
        x: (x0 + x1) / 2,
        z: a.z,
        yaw: 0.0,
        y: y,
      }], FacilityStyle.BARRIER_CAB_H, SOLID);
      Models.get(BARRIER_PATH, function(_) VisionMask.patchMesh(prop.mesh));
      return prop;
    }

// the kiosk shell as one instance, centred on the bay FacilityPaint leaves unstriped for it. UNTURNED
// like the emitted one, and for the same reason: what a yaw would aim is a door, and this mesh has
// none — what reads from 18-55 units up is the roof, the aerial over it and the lit band under it
  static function boothProp(scene:Scene, gate:Gate, y:Float):Models.InstancedProp
    {
      var c = CityConfig.cellToWorld(gate.boothCol, gate.mouthRow);
      var prop = Models.instanced(scene, BOOTH_PATH, [{
        x: c.x,
        z: c.z,
        yaw: 0.0,
        y: y,
      }], FacilityStyle.BOOTH_H + FacilityStyle.BOOTH_FASCIA + FacilityStyle.BOOTH_MAST, SOLID);
      Models.get(BOOTH_PATH, function(_) VisionMask.patchMesh(prop.mesh));
      return prop;
    }

// the checkpoint's SERVICE DROP: one cable from the gate's own mast to the collar on the booth's
// aerial. It is what the aerial was reshaped for — the square crossbar that stood up there was
// reported as reading like a cable connection point with nothing connected to it, so it is a round
// collar now and this is the cable.
//
// IT BORROWS FacilityCable's RIBBON, exactly as FacilityWork's desk leads and the hangar's machine
// runs do, so the run costs no draw call of its own — and like them it has to be filled BEFORE
// FacilityCable.build merges that buffer (render.facility.FacilityArea)
  public static function cable(m:Facility, b:MeshBuf):Void
    {
      var gate = find(m);
      if (gate == null)
        return;
      var y = FacilityGround.surfY(Surf.LOT);
      var c = CityConfig.cellToWorld(gate.boothCol, gate.mouthRow);
      var off = FacilityStyle.BOOTH_W / 2 - FacilityStyle.BOOTH_MAST_IN;
      var post = FacilityLamps.gateMast(m, gate);
      var a = [
        post.ax,
        post.y + FacilityStyle.LAMP_H * FacilityStyle.ENTRY_CABLE_Y,
        post.az,
      ];
      var t = [
        c.x + off,
        y + FacilityStyle.BOOTH_H + FacilityStyle.BOOTH_FASCIA +
          FacilityStyle.BOOTH_MAST * FacilityStyle.BOOTH_MAST_FRAC,
        c.z - off,
      ];
      FacilityCable.strip(b, {
        a: a,
        c: t,
        n: level(a, t),
        side: null,
        bow: FacilityStyle.ENTRY_CABLE_BOW,
        sag: FacilityStyle.ENTRY_CABLE_SAG,
        wave: FacilityStyle.ENTRY_CABLE_WAVE,
        seed: FacilityModel.mix((gate.col * 90001) ^ (gate.row * 10007)),
      });
    }

// the most nearly UPRIGHT unit normal a plane through both ends of a run can take: world up with the
// chord's own component taken out of it. it is the plane the ribbon is WIDENED in — level, so the
// band faces the camera rather than showing it an edge — and a run whose ends differ in height has
// no exactly horizontal one. it cannot degenerate here: the chord is cells of mouth across against a
// metre of height. the fall out of that plane is StripOpts.sag and is not this
  static function level(a:Array<Float>, c:Array<Float>):Array<Float>
    {
      var dx = c[0] - a[0], dy = c[1] - a[1], dz = c[2] - a[2];
      var l = Math.sqrt(dx * dx + dy * dy + dz * dz);
      var ty = dy / l;
      var nx = -ty * dx / l, ny = 1 - ty * ty, nz = -ty * dz / l;
      var nl = Math.sqrt(nx * nx + ny * ny + nz * nz);
      return [nx / nl, ny / nl, nz / nl];
    }

// the lit band itself, on the four faces of the booth's own footprint. split out of `booth` because
// BOTH checkpoints want it and neither wants the other's walls
  static function glazing(scene:Scene, gate:Gate, y:Float):Void
    {
      var c = CityConfig.cellToWorld(gate.boothCol, gate.mouthRow);
      var half = FacilityStyle.BOOTH_W / 2;
      var glass = MeshBufTools.make();
      for (dir in 0...4)
        FacilityGeom.pane(glass, c.x - half, c.x + half, c.z - half, c.z + half, dir,
          y + FacilityStyle.BOOTH_SILL, y + FacilityStyle.BOOTH_HEAD);
      addGlass(scene, glass);
    }

// the boom barrier: a cabinet standing on the booth's own flank, and an arm reaching from it across
// the mouth.
//
// THE ARM'S LENGTH IS DERIVED AND NOT NAMED, which is the whole of what the prop could not do. A glb
// scales UNIFORMLY through render.Models.instanced, so its height fixed its reach and the barrier
// spanned 14.7 units whatever the generator had cut; here the two ends are the hole's OWN outer cell
// boundaries, so the arm crosses exactly, stopping FacilityStyle.BARRIER_TIP short of the far kerb.
//
// the mouth runs along X — the hole is read as a span of COLUMNS with the lot a ROW step away — and
// that is not a new assumption: `find` only ever tests the row direction for the lot, `boothCol` and
// `lampCol` are column steps either side, and the prop this replaces stood on a hardcoded yaw of PI
  static function barrier(scene:Scene, gate:Gate, y:Float):Void
    {
      // the row of the hole that faces the LOT: a car meets the barrier on its way in, not out on
      // the kerb behind it
      var row = gate.row + (gate.lotDR < 0 ? 0 : gate.h - 1);
      var a = CityConfig.cellToWorld(gate.col, row);
      var b = CityConfig.cellToWorld(gate.col + gate.w - 1, row);
      var x0 = a.x - CELL / 2;
      var x1 = b.x + CELL / 2;
      var cab = MeshBufTools.make();
      var arm = MeshBufTools.make();
      // the cabinet, standing on the booth's flank (gate.boothCol is the low column, so this end)
      // and held BARRIER_INSET off the mouth's own boundary, because the kerb edging protrudes over
      // the asphalt there and flush with the boundary the box stood in it. four faces and a lid, and
      // NO floor: it is a closed vertical box on the ground, where the far faces span its whole
      // height and so carry the whole shadow — the case the booth's walls already prove, and the one
      // its roof slab does not (see `booth`)
      var cx0 = x0 + FacilityStyle.BARRIER_INSET;
      var cx1 = cx0 + FacilityStyle.BARRIER_CAB_W;
      var cz0 = a.z - FacilityStyle.BARRIER_CAB_W / 2;
      var cz1 = a.z + FacilityStyle.BARRIER_CAB_W / 2;
      var top = y + FacilityStyle.BARRIER_CAB_H;
      for (dir in 0...4)
        FacilityGeom.face(cab, cx0, cx1, cz0, cz1, dir, y, top, FacilityStyle.BARRIER_CAB_TILE);
      FacilityGeom.cap(cab, cx0, cx1, cz0, cz1, top, FacilityStyle.BARRIER_CAB_TILE);
      // and the boom, hinged off the cabinet's far face. it takes ONE period on every face it has,
      // and that works only because the art is uniform top to bottom: on the sides v is y / TILE over
      // a 0.3-unit bar and on the lid v is z / TILE over a 0.34-unit one, so both are thin horizontal
      // slices of the same image at unrelated offsets. u is world-aligned on both, so the bands line
      // up across the lid and the two sides for free — see the note on the texture in textures.json
      var az0 = a.z - FacilityStyle.BARRIER_ARM_W / 2;
      var az1 = a.z + FacilityStyle.BARRIER_ARM_W / 2;
      var ay0 = y + FacilityStyle.BARRIER_ARM_Y;
      var ay1 = ay0 + FacilityStyle.BARRIER_ARM_T;
      var tip = x1 - FacilityStyle.BARRIER_TIP;
      for (dir in 0...4)
        FacilityGeom.face(arm, cx1, tip, az0, az1, dir, ay0, ay1, FacilityStyle.BARRIER_ARM_TILE);
      FacilityGeom.cap(arm, cx1, tip, az0, az1, ay1, FacilityStyle.BARRIER_ARM_TILE);
      // and the UNDERSIDE, which is the booth roof's lesson repeated: a FrontSide material renders
      // BACK faces into the shadow map, so an open-bottomed box floating in the air has its lid
      // culled from the light's side and every ray through it exits into open asphalt. The cabinet
      // above needs none because it stands ON the ground, where those rays land under the box itself
      FacilityGeom.capDown(arm, cx1, tip, az0, az1, ay0, FacilityStyle.BARRIER_ARM_TILE);
      FacilityGeom.add(scene, cab, FacilityStyle.BARRIER_CAB_TEX, true, true);
      // and the bands are PHASED so the free end lands on a whole white one. world-aligned UVs put
      // the band grid on the world and the tip wherever the gate's arithmetic leaves it, which cut
      // the last band in half — reported from the game as the bar ending split red/white. the art is
      // laid out red-first and white-last, so a `u` that reaches a whole number at the tip ends on
      // the end of a white band, and shifting the map by the fraction it falls short is a pure phase
      // change: same period, same texel density, nothing stretched
      var u = tip / FacilityStyle.BARRIER_ARM_TILE;
      addArm(scene, arm, Math.ceil(u) - u);
    }

// the boom's own mesh, and the TWO reasons it is not a plain FacilityGeom.add. The hazard art is
// high-vis paint at 0.311 mean linear, and the level has to come down without the two bands moving
// relative to each other — `color` is a LINEAR multiply and does exactly that where textures.json's
// `lift`, a gamma, does not (see FacilityStyle.BARRIER_TINT). And the band grid needs phasing by
// `uPhase` so the tip ends on white; `Textures.loadTexture` builds a fresh Texture per call, so the
// offset is this mesh's own and nothing else samples it
  static function addArm(scene:Scene, b:MeshBuf, uPhase:Float):Void
    {
      var tex = Textures.loadTexture(FacilityStyle.BARRIER_ARM_TEX, 'wall', 1);
      tex.offset.x = uPhase;
      var mat = VisionMask.patch(new MeshLambertMaterial({
        map: tex,
        side: THREE.FrontSide,
      }));
      mat.color.multiplyScalar(FacilityStyle.BARRIER_TINT);
      var mesh = new Mesh(FacilityGeom.geom(b), mat);
      mesh.receiveShadow = true;
      mesh.castShadow = true;
      scene.add(mesh);
    }

// the guard booth, standing centred on the bay FacilityPaint leaves unstriped for it: four clad
// faces with a glazing band cut out of them, and a flat slab overhanging the lot.
//
// UNTURNED, and glazed on all four sides, because what a yaw would aim is the door and a door is a
// few texels from a camera 18-55 units up. What reads from up there is the ROOF and the lit band
// under it, and both are square
  static function booth(scene:Scene, gate:Gate, y:Float):Void
    {
      var c = CityConfig.cellToWorld(gate.boothCol, gate.mouthRow);
      var half = FacilityStyle.BOOTH_W / 2;
      var x0 = c.x - half, x1 = c.x + half;
      var z0 = c.z - half, z1 = c.z + half;
      var sill = y + FacilityStyle.BOOTH_SILL;
      var head = y + FacilityStyle.BOOTH_HEAD;
      var eave = y + FacilityStyle.BOOTH_H;
      var walls = MeshBufTools.make();
      var roof = MeshBufTools.make();
      // the spandrel under the glazing and the one over it, exactly as the wall pass leaves a window
      // run's opening — same cladding, same world-aligned period, so the booth courses with the
      // buildings behind it instead of reading as a differently-scaled object
      for (dir in 0...4)
        {
          FacilityGeom.face(walls, x0, x1, z0, z1, dir, y, sill, FacilityStyle.WALL_TILE);
          FacilityGeom.face(walls, x0, x1, z0, z1, dir, head, eave, FacilityStyle.WALL_TILE);
        }
      // the roof slab: a cap on the grown rect, a fascia band down its edge and a SOFFIT closing it
      // underneath, all in the booth's own decking rather than the buildings' ballasted bitumen
      // (FacilityStyle.BOOTH_ROOF) and all on ROOF_TILE, so the fascia is a slice of the same pan the
      // cap above it lands on.
      //
      // the soffit is not there to be LOOKED at — the camera pitches 51 degrees down and a ray
      // reaching under a BOOTH_EAVE overhang has already met the wall, which is the argument
      // FacilityTables makes for leaving its bench lip open. It is there to CLOSE THE SLAB, because
      // the shadow pass does not look from the camera: a FrontSide material renders BACK faces into
      // the shadow map, so an open-bottomed box has its lid culled from the light's side and casts
      // only from the inside of its own fascia. Left off, the roof punched a second set of holes in
      // the shadow after the glazing's were closed
      var e = FacilityStyle.BOOTH_EAVE;
      var top = eave + FacilityStyle.BOOTH_FASCIA;
      FacilityGeom.cap(roof, x0 - e, x1 + e, z0 - e, z1 + e, top, FacilityStyle.ROOF_TILE);
      FacilityGeom.capDown(roof, x0 - e, x1 + e, z0 - e, z1 + e, eave, FacilityStyle.ROOF_TILE);
      for (dir in 0...4)
        FacilityGeom.face(roof, x0 - e, x1 + e, z0 - e, z1 + e, dir, eave, top,
          FacilityStyle.ROOF_TILE);
      // ALL THREE CAST, and the booth is the one thing here where that is not the default answer.
      // The walls cast the way the compound's cladding does — a booth with no shadow on the asphalt
      // beside it floats. The ROOF casts, which FacilityGeom.addRoof refuses for a building's: that
      // rule is about a roof over a whole lot under a moon box that follows the player, and this is a
      // 4.3-unit cap. Not casting it, the shadow stopped at the WALL line and the overhang — the one
      // feature of the silhouette — threw none, so the booth read a size smaller than it is
      FacilityGeom.add(scene, walls, FacilityStyle.WALL_EXTERIOR, true, true);
      FacilityGeom.add(scene, roof, FacilityStyle.BOOTH_ROOF, true, true);
    }

// the booth's lit band: the same window art every run in the area takes, and OPAQUE.
//
// a run's panes are half see-through — tools/textures.py's `glass_alpha` key takes the bright half
// of that art to 128 — because a window is read from both sides of ONE wall. A booth is a BOX, and
// see-through glazing on a box means looking straight in the near face and out the far one, at an
// interior nobody is going to model. Opaque it is the brief exactly: a glowing band with nothing
// behind it. alphaTest survives the switch and is doing the same job it does there, killing the
// margin the art's own cut leaves; with `transparent` off it costs no sorted pass — and the glow
// takes FacilityStyle.BOOTH_EMISSIVE rather than a run's own, which the opaque switch is half the
// reason for
  static function addGlass(scene:Scene, b:MeshBuf):Void
    {
      var tex = Textures.loadAlphaCropped(FacilityStyle.WINDOW_LIT);
      var mesh = new Mesh(FacilityGeom.geom(b), VisionMask.patch(new MeshLambertMaterial({
        map: tex,
        emissiveMap: tex,
        emissive: new Color(0xffffff),
        emissiveIntensity: FacilityStyle.BOOTH_EMISSIVE,
        alphaTest: 0.02,
        side: THREE.FrontSide,
      })));
      mesh.receiveShadow = false;
      // and it CASTS, for the identical reason FacilityGeom.addPane's does: the glazing band is cut
      // OUT of the walls above, so with the glass not casting the opening is a real hole in the
      // caster and the moon shines straight through the box. Reported from the game as the booth's
      // shadow having holes in it — a bright band across the middle of it, one per face the light
      // reaches, which is exactly the parallelogram of moonlight a non-casting window run left inside
      // a building. Opaque here rather than alpha-keyed, so it casts solid with nothing to tune
      mesh.castShadow = true;
      scene.add(mesh);
    }

// is this cell open asphalt? false off the grid
  static inline function isLot(m:Facility, col:Int, row:Int):Bool
    return FacilityModel.inside(m, col, row) && m.surf[row][col] == Surf.LOT;
}
