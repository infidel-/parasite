package render.facility;

import three.Three;
import citygen.CityConfig;
import render.Textures;
import render.facility.FacilityModel.Facility;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// the laboratory benches: the casework runs the generator lays beside every window wall, and the
// island it puts in the middle of a room big enough to hold one.
//
// MERGED GEOMETRY and not a generated prop, which is the one decision worth recording here. A bench
// is a BOX — a worktop slab over a run of cabinet fronts — so the whole thing is six quads a cell
// against a glb's unwrap lottery, and it costs two draw calls for every bench in the area rather
// than one instanced batch per shape. What that buys is the part a prop cannot do: the generator
// deals 1x1, 1x3, 3x1, 2x3 and 3x2 blocks, and a run of instanced units would show a seam at every
// cell boundary, so a prop would have needed a shape per shape. Here the shapes are never named at
// all — a face is emitted toward a neighbour that is not a bench, exactly as the wall pass emits
// toward a neighbour that is not a wall, and every block the generator can lay falls out of it.
//
// what the 2D tile art shows is a plain slab with a thin front strip, so the silhouette is the whole
// job: the worktop overhangs the casework by FacilityStyle.BENCH_LIP and that shadow line is what
// stops a bench reading as a low wall. The overhang is taken out of the TOP, which is grown outward,
// and never out of the casework, which is pulled in — see BENCH_LIP for why that is a UV decision
class FacilityTables
{
  static inline var CELL = CityConfig.CELL;

  // the four cell-edge directions, in the order render.facility.FacilityGeom.face reads them:
  // 0 = -z, 1 = +z, 2 = -x, 3 = +x
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

// every bench in the area, in two merged meshes
  public static function build(scene:Scene, m:Facility):Void
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var top = MeshBufTools.make();
      var body = MeshBufTools.make();
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (!m.table[row][col])
              continue;
            var x0 = col * CELL - half, x1 = x0 + CELL;
            var z0 = row * CELL - half, z1 = z0 + CELL;
            // the worktop, GROWN outward by BENCH_LIP on every side that does not carry on into
            // another bench cell — that overhang is the bench's silhouette, and taking it out of the
            // top rather than out of the casework is what keeps the cabinet fronts whole (see
            // FacilityStyle.BENCH_LIP). a side that continues reaches the plain boundary, so
            // abutting cells of one run still share a world-aligned grid and a 3-cell bench is one
            // unbroken sheet of resin
            var ox0 = FacilityModel.isTable(m, col - 1, row) ? x0 : x0 - FacilityStyle.BENCH_LIP;
            var ox1 = FacilityModel.isTable(m, col + 1, row) ? x1 : x1 + FacilityStyle.BENCH_LIP;
            var oz0 = FacilityModel.isTable(m, col, row - 1) ? z0 : z0 - FacilityStyle.BENCH_LIP;
            var oz1 = FacilityModel.isTable(m, col, row + 1) ? z1 : z1 + FacilityStyle.BENCH_LIP;
            FacilityGeom.cap(top, ox0, ox1, oz0, oz1, FacilityStyle.BENCH_H,
              FacilityStyle.BENCH_TOP_TILE);
            for (dir in 0...4)
              {
                if (FacilityModel.isTable(m, col + DC[dir], row + DR[dir]))
                  continue;
                // the worktop's edge band, out on the grown rect with it
                FacilityGeom.face(top, ox0, ox1, oz0, oz1, dir,
                  FacilityStyle.BENCH_H - FacilityStyle.BENCH_EDGE, FacilityStyle.BENCH_H,
                  FacilityStyle.BENCH_TOP_TILE);
                // and the casework on the plain cell, so u spans exactly CELL and the door rhythm
                // lands whole
                panel(body, x0, x1, z0, z1, dir);
              }
          }
      // no soffit under the overhang and no floor under the casework. the ring left open at the top
      // of the body is BENCH_LIP wide and sits behind the edge band from anything above it: at the
      // camera's 51 degrees a ray entering at the bottom of the band drops 0.25 units over the 0.2
      // it travels inward and lands on the cabinet face, so there is nothing to see through.
      //
      // at a CONCAVE corner — where one run meets another and the block is not a rectangle — the two
      // grown rects overlap by BENCH_LIP squared. The caps are coplanar, same texture, same
      // world-aligned UVs, so that overlap resolves to the same pixel either way; the two edge bands
      // cross, each poking BENCH_LIP past the other, which is 0.2 world units and reads as nothing
      add(scene, top, FacilityStyle.BENCH_TOP);
      add(scene, body, FacilityStyle.BENCH_BODY);
    }

// one cabinet-front quad.
//
// the same winding FacilityGeom.face uses, through the same `ends`, but with a DIFFERENT PERIOD ON
// EACH AXIS — which is the whole reason this is not a call to `face`. `u` has to be world-aligned on
// FacilityStyle.BENCH_TILE so a door lands on the cell grid and a run never ends on half of one,
// while `v` has to run 0..1 over the body's own height so the art's bottom-up composition lands
// whole. One `t` cannot do both, and `face` has one `t`
  static function panel(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, dir:Int):Void
    {
      var e = FacilityGeom.ends(x0, x1, z0, z1, dir);
      var us = (dir < 2 ? e[0] : e[1]) / FacilityStyle.BENCH_TILE;
      var ue = (dir < 2 ? e[2] : e[3]) / FacilityStyle.BENCH_TILE;
      var y1 = FacilityStyle.BENCH_H - FacilityStyle.BENCH_EDGE;
      MeshBufTools.quad(b, [e[0], 0, e[1]], [e[2], 0, e[3]], [e[2], y1, e[3]], [e[0], y1, e[1]],
        [us, 0, ue, 0, ue, 1, us, 1]);
    }

// the height of whatever an actor or a decal rests on at a WORLD point, for render.world.WorldCtx
// .ground. two things stack here and neither is optional.
//
// the WORKTOP is what stands a table decoration ON its bench instead of inside it: the generator
// writes the decoration onto the SAME cell as the table tile it belongs to (FacilityAreaGenerator's
// chem-lab pass), so without this every flask and microscope in the area sits at y = 0 with a metre
// of casework in front of it.
//
// the SURFACE is the kerb step (FacilityStyle.KERB_DROP), and routing it through here is what makes
// the whole compound follow for free — actors, decals, the slime trail, the path line, the tactical
// grid and the cursor pick all read this one hook and nothing else had to be touched
  public static function groundY(m:Facility, x:Float, z:Float):Float
    {
      var c = CityConfig.worldToCell(x, z);
      if (FacilityModel.isTable(m, c.col, c.row))
        return FacilityStyle.BENCH_H;
      if (!FacilityModel.inside(m, c.col, c.row))
        return 0.0;
      return FacilityGround.surfY(m.surf[c.row][c.col]);
    }

// merge one buffer into a lit mesh. interior surfaces, so they receive the moon's shadow and cast
// none of their own — the same pair every indoor buffer in FacilityGeom takes
  static function add(scene:Scene, b:MeshBuf, tex:String):Void
    {
      if (b.idx.length == 0)
        return;
      var geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(b.pos, 3));
      geo.setAttribute('uv', new Float32BufferAttribute(b.uv, 2));
      geo.setIndex(b.idx);
      geo.computeVertexNormals();
      var mesh = new Mesh(geo, VisionMask.patch(new MeshLambertMaterial({
        map: Textures.loadTexture(tex, 'wall', 1),
        side: THREE.FrontSide,
      })));
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
    }
}
