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
// BOTH ARE RENDER-ONLY and stand on walkable asphalt, the way the park railing does. nothing is
// stamped on the tiles for them, which is what makes the whole feature retroactive — and a gate a
// car drives through is the wrong place to start blocking cells anyway.
//
// THE BARRIER IS A PROP AND THE BOOTH IS MERGED GEOMETRY, and that split is the one decision worth
// recording. The booth is a BOX — four clad faces, a glazing band and a flat slab over them, about
// thirty triangles — and the same reasoning render.facility.FacilityTables wrote down for a bench
// applies to it exactly: put a box through the generator and you pay for an unwrap lottery you did
// not need. It was tried, and it lost on every number the acceptance gate reports (tools/propstat.py
// on the drop: 40 connected components with the largest holding 58.1%, a 3.14x split ratio that no
// decimator can touch, an albedo baked at 91/97/104 against the prop family's 46-52). Built here it
// is instead exact, it wears the compound's OWN cladding and roofing tiled world-aligned at full
// texel density rather than a 2048 atlas smeared over a 4-unit box, and the glowing window band is
// the same lit-ribbon art every window run in the area already takes — so the whole
// tools/emissive.py step, and the hand-authored emissive map with it, simply stops existing.
//
// The barrier stays a prop because it is not a box: an arm, a counterweight and a cabinet, a shape
// worth generating, and it unwraps at 1.26x with 3 components
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

// the checkpoint: the booth's own meshes, and the barrier batch the caller appends to `green`
  public static function build(scene:Scene, m:Facility):Array<Models.InstancedProp>
    {
      var gate = find(m);
      var barrier:Array<Models.PropPlace> = [];
      if (gate != null)
        {
          // both stand on asphalt, which lies a kerb below the pavement (FacilityStyle.KERB_DROP)
          var y = FacilityGround.surfY(Surf.LOT);
          booth(scene, gate, y);
          // the arm lies ACROSS the mouth, so the prop is centred on the hole's own columns and
          // stands on whichever of its two rows faces the lot — a car meets the barrier on its way
          // in, not out on the kerb. the cabinet is at the glb's +x end (measured: the low half of
          // its long axis spans 0.035 in y against the high half's 0.147), so the whole thing is
          // turned PI to stand it on the booth's flank with the arm reaching away
          var v = CityConfig.cellToWorld(gate.col + (gate.w - 1) / 2.0,
            gate.row + (gate.lotDR < 0 ? 0 : gate.h - 1));
          barrier.push({
            x: v.x,
            z: v.z,
            yaw: Math.PI,
            y: y,
          });
        }
      return [add(scene, RenderConfig.MODELS.facilityBarrier, barrier, FacilityStyle.BARRIER_H)];
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
      var glass = MeshBufTools.make();
      // the spandrel under the glazing and the one over it, exactly as the wall pass leaves a window
      // run's opening — same cladding, same world-aligned period, so the booth courses with the
      // buildings behind it instead of reading as a differently-scaled object
      for (dir in 0...4)
        {
          FacilityGeom.face(walls, x0, x1, z0, z1, dir, y, sill, FacilityStyle.WALL_TILE);
          FacilityGeom.face(walls, x0, x1, z0, z1, dir, head, eave, FacilityStyle.WALL_TILE);
          FacilityGeom.pane(glass, x0, x1, z0, z1, dir, sill, head);
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
      addGlass(scene, glass);
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

// one gate batch, mask-patched behind the loader callback — the mesh does not exist until the glb
// resolves, and an empty batch must not have its material patched and warmed for nothing
  static function add(scene:Scene, path:String, places:Array<Models.PropPlace>,
      h:Float):Models.InstancedProp
    {
      var prop = Models.instanced(scene, path, places, h, SOLID);
      if (places.length > 0)
        Models.get(path, function(_) VisionMask.patchMesh(prop.mesh));
      return prop;
    }

// is this cell open asphalt? false off the grid
  static inline function isLot(m:Facility, col:Int, row:Int):Bool
    return FacilityModel.inside(m, col, row) && m.surf[row][col] == Surf.LOT;
}
