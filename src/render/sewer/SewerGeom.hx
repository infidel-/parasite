package render.sewer;

import three.Three;
import citygen.CityConfig;
import render.Textures;
import render.sewer.SewerModel.Sewer;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;

// static tunnel SHELL from a SewerModel: walkway floor, inward-facing walls, the CAP_CHAMFER wedge
// that turns each wall's top arris into a bevel, and the flat wall tops the overhead camera looks
// down on. everything merges into ONE mesh per texture — six draw calls
// for a whole level (floor, ledge, and one per wall variation). nothing here fades (there is no sewer occlusion pass), which is
// exactly why it can all be welded like this; see docs/3d-render.md on the Occlusion constraint.
// the dressing that sits ON the shell (decals, grime, contact shadows) lives in SewerDetail
class SewerGeom
{
  static inline var CELL = CityConfig.CELL;

  // cell offsets of the neighbour each wall direction faces, matching side()'s four directions
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];
  // the PERPENDICULAR direction at each end of a face, in the order side() winds them (s then e):
  // a north/south face runs along x and ends on its west/east neighbours, an east/west face runs
  // along z and ends on its north/south ones. these are what the mitre and the corner darkening
  // are classified off
  static var PERP_S = [2, 3, 1, 0];
  static var PERP_E = [3, 2, 0, 1];

// build every tunnel surface into the scene
  public static function build(scene:Scene, m:Sewer):Void
    {
      var half = (CityConfig.GRID * CELL) / 2; // the shared cell->world origin (see CityConfig.cellToWorld)
      var floor = MeshBufTools.make();
      var ledge = MeshBufTools.make();
      // one buffer per wall variation: every face picks its own, so a run of wall is not one flat
      // repeat. merged per variation, so the whole level still costs one draw call each
      var walls = [for (_ in SewerStyle.WALLS) MeshBufTools.make()];

      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            var x0 = col * CELL - half, x1 = x0 + CELL;
            var z0 = row * CELL - half, z1 = z0 + CELL;
            // solid cell: cap it, so the camera looks down on a ledge and not on a paper-thin wall
            // edge. EVERY solid cell, not just the shell orthogonally touching floor — the caps
            // form one continuous plateau (which SAGS per lattice point, see capY), so an interior
            // or diagonal-only solid cell left uncapped is a hole straight through the plateau to
            // the background. 2 tris a cell into an already-merged mesh, so no extra draw call.
            // every edge that overlooks a FLOOR cell is pulled back by CAP_CHAMFER to make room for
            // the wedge side() raises there — the two are exactly paired (a cap edge is inset iff
            // its neighbour emits a wall against it), so the plateau never opens a gap
            if (!m.floor[row][col])
              {
                var c = SewerStyle.CAP_CHAMFER;
                cap(ledge,
                  SewerModel.isFloor(m, col - 1, row) ? x0 + c : x0,
                  SewerModel.isFloor(m, col + 1, row) ? x1 - c : x1,
                  SewerModel.isFloor(m, col, row - 1) ? z0 + c : z0,
                  SewerModel.isFloor(m, col, row + 1) ? z1 - c : z1,
                  SewerStyle.LEDGE_TILE);
                continue;
              }
            // floor: one continuous walkway. the corridor centreline used to run a sludge tile
            // instead of concrete — see SewerModel on why that grid is gone with it
            flat(floor, x0, x1, z0, z1, 0.0, SewerStyle.FLOOR_TILE);
            // walls on every edge facing a solid neighbour, wound to face into this cell. the
            // variation is picked PER FACE off its own (cell, dir) hash — mixed, or the area border
            // combs (see SewerModel.mix), and with multipliers of its own so a face's texture does
            // not correlate with the decal SewerDetail rolls for the same face
            inline function buf(dir:Int):MeshBuf
              return walls[SewerModel.mix((col * 30011) ^ (row * 50021) ^ (dir * 70001)) % walls.length];
            if (!SewerModel.isFloor(m, col, row - 1))
              side(buf(0), m, col, row, 0);
            if (!SewerModel.isFloor(m, col, row + 1))
              side(buf(1), m, col, row, 1);
            if (!SewerModel.isFloor(m, col - 1, row))
              side(buf(2), m, col, row, 2);
            if (!SewerModel.isFloor(m, col + 1, row))
              side(buf(3), m, col, row, 3);
          }

      add(scene, floor, SewerStyle.FLOOR, true, false);
      add(scene, ledge, SewerStyle.LEDGE, true, false);
      for (i in 0...walls.length)
        add(scene, walls[i], SewerStyle.WALLS[i], true, true);
      // dressing on top of the shell: SewerDetail owns the wall face, SewerGround the two horizontal
      // surfaces. called from HERE, not from SewerArea, so that View.warmup — which compiles a
      // throwaway SewerModel.demo() through this same function — warms the decal, grime, rim and
      // contact-shadow materials too, with no second wiring point to forget
      SewerDetail.build(scene, m);
      SewerGround.build(scene, m);
    }

// per-vertex tint at a point on the cell lattice: a hashed value either side of 1.0, so the shell
// varies in VALUE without any art and without a second texture.
//
// keyed off the LATTICE — the rounded cell index plus a coarse height band — and never off the
// quad or the face. MeshBuf gives every quad its own four vertices, so a per-face value would put a
// hard step on every cell boundary, which is exactly the seam that killed the two-wall-variant
// experiment (docs/3d-render.md). two quads meeting at a lattice point ask this the same question
// and get the same number, so the variation interpolates across a whole run and cannot seam.
// the same reason makes it safe on a ledge cap edge pulled back by CAP_CHAMFER: 0.15 of a 4-unit
// cell rounds to the lattice point it came from
  static function tint(x:Float, y:Float, z:Float):Float
    {
      var ci = Math.round(x / CELL);
      var ri = Math.round(z / CELL);
      var yi = Math.round(y / (SewerStyle.WALL_H / 2));
      // multipliers of its own, mixed: must not correlate with the wall-variant, decal, ledge,
      // floor-decal, wall-lamp, prop or litter rolls (see SewerModel.mix on why raw hashes comb)
      var h = SewerModel.mix((ci * 19349663) ^ (ri * 83492791) ^ (yi * 73856093));
      return 1.0 + ((h % 2001) / 1000.0 - 1.0) * SewerStyle.TINT_AMP;
    }

// cap height at a point on the cell lattice: WALL_H less a hashed sag, so the plateau — and the
// silhouette line its edge draws — is never dead level. see SewerStyle.CAP_SAG for why this is
// keyed off the LATTICE and not the cell (short version: a per-cell height steps, and a step
// between two solid cells is a hole through the plateau that needs a filler quad the chamfer then
// fights). two cells sharing an edge read the same two corner heights, so their caps meet exactly.
// the CAP_CHAMFER inset is 0.25 of a 4-unit cell, so an inset corner rounds back to the lattice
// point it came from and takes the height the wedge below it tops out at
  public static function capY(x:Float, z:Float):Float
    {
      var ci = Math.round(x / CELL);
      var ri = Math.round(z / CELL);
      // its own multipliers, mixed — must not correlate with the tint, wall-variant, decal, ledge,
      // floor-decal, wall-lamp, prop or litter rolls (SewerModel.mix on why raw hashes comb)
      var h = SewerModel.mix((ci * 24036583) ^ (ri * 32582657));
      return SewerStyle.WALL_H - (h % 1000) / 1000.0 * SewerStyle.CAP_SAG;
    }

// the cap surface at an arbitrary point, evaluated on the same two triangles cap() emits (quad
// winds p0..p3 and indexes 0-1-2 / 0-2-3, so the diagonal runs from the -x/+z corner to the +x/-z
// one, i.e. u + v = 1 in cell-local coordinates). anything laid FLAT on the plateau has to follow
// this or it sinks into a sagging cap at one end and floats off it at the other
  public static function capAt(x:Float, z:Float):Float
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var x0 = Math.floor((x + half) / CELL) * CELL - half;
      var z0 = Math.floor((z + half) / CELL) * CELL - half;
      var u = (x - x0) / CELL;
      var v = (z - z0) / CELL;
      if (u + v >= 1)
        {
          var h = capY(x0 + CELL, z0 + CELL);
          return h + (1 - u) * (capY(x0, z0 + CELL) - h) + (1 - v) * (capY(x0 + CELL, z0) - h);
        }
      var h = capY(x0, z0);
      return h + u * (capY(x0 + CELL, z0) - h) + v * (capY(x0, z0 + CELL) - h);
    }

// top of the FLAT part of a wall face on a cell edge: the LOWER of its two tilting corners, less
// the chamfer. dir matches side()'s four. anything laid on a face has to clamp to this — above it
// the wall recedes into the bevel, and the high end of a tilted top edge is not where the low one is
  public static function faceH(x0:Float, x1:Float, z0:Float, z1:Float, dir:Int):Float
    {
      var a = 0.0;
      var b = 0.0;
      if (dir < 2)
        {
          var z = dir == 0 ? z0 : z1;
          a = capY(x0, z);
          b = capY(x1, z);
        }
      else
        {
          var x = dir == 2 ? x0 : x1;
          a = capY(x, z0);
          b = capY(x, z1);
        }
      return (a < b ? a : b) - SewerStyle.CAP_CHAMFER;
    }

// one cell's ledge cap. the x/z bounds arrive already pulled in by CAP_CHAMFER on any edge
// overlooking a floor cell, so a corner is NOT necessarily on the lattice — hence capAt, not capY.
// an inset corner rounds back to the lattice point it came from, so capY there returns the height
// of a point CAP_CHAMFER away, while the neighbouring cell (un-inset on that edge, because ITS
// perpendicular neighbour is masonry) draws a straight line between the same two lattice heights
// over the full cell. the two then disagree by (CAP_CHAMFER / CELL) * CAP_SAG and the plateau
// cracks — measured 0.025 world units, one hairline down every inside corner. capAt IS that line
  static function cap(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, t:Float):Void
    {
      var h0 = capAt(x0, z1);
      var h1 = capAt(x1, z1);
      var h2 = capAt(x1, z0);
      var h3 = capAt(x0, z0);
      MeshBufTools.quadC(b, [x0, h0, z1], [x1, h1, z1], [x1, h2, z0], [x0, h3, z0],
        [x0 / t, z1 / t, x1 / t, z1 / t, x1 / t, z0 / t, x0 / t, z0 / t],
        [tint(x0, h0, z1), tint(x1, h1, z1), tint(x1, h2, z0), tint(x0, h3, z0)]);
    }

// one horizontal cell quad at height y, world-aligned UVs (never stretched)
  static function flat(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, y:Float, t:Float):Void
    {
      MeshBufTools.quadC(b, [x0, y, z1], [x1, y, z1], [x1, y, z0], [x0, y, z0],
        [x0 / t, z1 / t, x1 / t, z1 / t, x1 / t, z0 / t, x0 / t, z0 / t],
        [tint(x0, y, z1), tint(x1, y, z1), tint(x1, y, z0), tint(x0, y, z0)]);
    }

// one wall on a cell edge, facing INTO the cell: the flat face, then the CAP_CHAMFER wedge carrying
// it up to the ledge cap the neighbouring solid cell pulled back for it.
// dir: 0 = north edge (faces +z), 1 = south (-z), 2 = west (+x), 3 = east (-x).
//
// THE WEDGE IS A BEVEL ON THE MASONRY'S PLAN OUTLINE, SO IT HAS TO BE MITRED. run one along a whole
// cell edge and at an outside corner its last CAP_CHAMFER has nothing underneath it — two wedges
// cross in mid-air past the corner while the cap they should meet has been pulled back behind them.
// each end of the TOP edge is therefore classified off two neighbours, the cell along the run
// (perp) and the one diagonally behind it (diag):
//   diag floor             -> the masonry ENDS here: an outside corner, or two solids pinching at a
//                             point. pull the top edge IN by the chamfer, and the two wedges meet
//                             exactly along the 45 degree mitre — they already share the bottom
//                             corner, so closing the top closes the whole seam. costs no triangle,
//                             the quad just becomes a trapezoid
//   diag solid, perp floor -> a straight run of wall: the next cell emits a collinear wedge that
//                             abuts this one. leave it alone
//   diag solid, perp solid -> an INSIDE corner. leave the top edge (extending it would slide the
//                             wedge under the diagonal cell's un-inset cap and open a void beneath
//                             it) and close the end with a small vertical return triangle instead.
//                             that is a chamfer STOP, which is how a real chamfer dies into an
//                             inside corner, and the diagonal cap lands exactly on top of it
//
// one emitter covers all four directions off (p, n, s, e): the wall plane on the axis the face
// does NOT run along, the sign of its inward normal there, and the two run coordinates in winding
// order. the four hand-written cases this replaced could not have carried the mitre readably
  static function side(b:MeshBuf, m:Sewer, col:Int, row:Int, dir:Int):Void
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var x0 = col * CELL - half, x1 = x0 + CELL;
      var z0 = row * CELL - half, z1 = z0 + CELL;
      var k = SewerStyle.CAP_CHAMFER;
      var t = SewerStyle.WALL_TILE;
      var runX = dir < 2;                        // face on a z edge, running along x
      var p = 0.0;                               // wall plane on the other axis
      var n = 1.0;                               // sign of the inward normal on that axis
      var s = 0.0;                               // run coordinate of the first-wound end
      var e = 0.0;                               // ... and of the second
      switch (dir)
        {
          case 0:
            p = z0;
            s = x0;
            e = x1;
          case 1:
            p = z1;
            s = x1;
            e = x0;
            n = -1.0;
          case 2:
            p = x0;
            s = z1;
            e = z0;
          default:
            p = x1;
            s = z0;
            e = z1;
            n = -1.0;
        }
      var d = e > s ? 1.0 : -1.0;                // which way the run axis points from s to e
      var o = -n * k;                            // the wedge top recedes into the masonry
      inline function pt(run:Float, y:Float, off:Float):Array<Float>
        return runX ? [run, y, p + off] : [p + off, y, run];
      // this wall tops out at the CAP of the solid cell it faces, and that cap sags, so each END of
      // the face has its own height and the top edge tilts between them.
      // TWO samplers, and the difference between them is what keeps the plateau welded. the FACE
      // top sits on the cell lattice and takes capY — both faces of an inside corner then read the
      // same number for the vertical line they share. the WEDGE top sits CAP_CHAMFER further in,
      // off the lattice, where a neighbouring cap edge is already drawing a straight line between
      // two lattice heights, so it has to take THAT line (capAt). see cap() for what capY there costs
      inline function lat(run:Float):Float
        return runX ? capY(run, p) : capY(p, run);
      inline function surf(run:Float, off:Float):Float
        return runX ? capAt(run, p + off) : capAt(p + off, run);
      inline function tv(v:Array<Float>, mul:Float):Float
        return tint(v[0], v[1], v[2]) * mul;
      inline function perpSolid(pd:Int):Bool
        return !SewerModel.isFloor(m, col + DC[pd], row + DR[pd]);
      inline function diagSolid(pd:Int):Bool
        return !SewerModel.isFloor(m, col + DC[dir] + DC[pd], row + DR[dir] + DR[pd]);
      var pdS = PERP_S[dir];
      var pdE = PERP_E[dir];
      var s2 = s + (diagSolid(pdS) ? 0.0 : k) * d;   // top edge, mitred in at an outside corner
      var e2 = e - (diagSolid(pdE) ? 0.0 : k) * d;
      // an end that butts into another wall is an inside corner, and an inside corner wants
      // DARKNESS as well — a 90 degree crease reads as a corner when it is dark and as a paint edge
      // when it is not. both faces of a corner darken the shared vertical line by the same factor,
      // so they agree there
      var aoS = perpSolid(pdS) ? SewerStyle.TINT_CORNER : 1.0;
      var aoE = perpSolid(pdE) ? SewerStyle.TINT_CORNER : 1.0;
      var f = SewerStyle.TINT_FOOT;
      var lift = SewerStyle.TINT_CHAMFER;
      var f0 = lat(s) - k;                       // top of the flat face at each end...
      var f1 = lat(e) - k;
      var h0 = surf(s2, o);                      // ... and the wedge top above it, on the cap surface
      var h1 = surf(e2, o);
      var b0 = pt(s, 0, 0);
      var b1 = pt(e, 0, 0);
      var m0 = pt(s, f0, 0);
      var m1 = pt(e, f1, 0);
      var t0 = pt(s2, h0, o);
      var t1 = pt(e2, h1, o);
      MeshBufTools.quadC(b, b0, b1, m1, m0,
        [s / t, 0, e / t, 0, e / t, f1 / t, s / t, f0 / t],
        [tv(b0, f * aoS), tv(b1, f * aoE), tv(m1, aoE), tv(m0, aoS)]);
      MeshBufTools.quadC(b, m0, m1, t1, t0,
        [s / t, f0 / t, e / t, f1 / t, e2 / t, h1 / t, s2 / t, h0 / t],
        [tv(m0, aoS), tv(m1, aoE), tv(t1, lift * aoE), tv(t0, lift * aoS)]);
      // chamfer stops. u runs off the OTHER axis here — the return face is parallel to the
      // perpendicular wall it dies into, and that wall's u is world-derived on this same axis
      var ao = SewerStyle.TINT_CORNER;
      if (diagSolid(pdS) &&
          perpSolid(pdS))
        {
          // the apex is ON the lattice corner, which is where the diagonal cell's un-inset cap
          // reaches, so it takes the lattice height while the other top vertex takes the surface
          var a0 = lat(s);
          var c1 = pt(s, h0, o);
          var c2 = pt(s, a0, 0);
          MeshBufTools.triC(b, m0, c1, c2,
            [p / t, f0 / t, (p + o) / t, h0 / t, p / t, a0 / t],
            [tv(m0, ao), tv(c1, lift * ao), tv(c2, lift * ao)]);
        }
      if (diagSolid(pdE) &&
          perpSolid(pdE))
        {
          var a1 = lat(e);
          var c1 = pt(e, a1, 0);
          var c2 = pt(e, h1, o);
          MeshBufTools.triC(b, m1, c1, c2,
            [p / t, f1 / t, p / t, a1 / t, (p + o) / t, h1 / t],
            [tv(m1, ao), tv(c1, lift * ao), tv(c2, lift * ao)]);
        }
    }

// turn one buffer into a single lit mesh. Lambert, not Standard: measured -42% GPU on the city
// surfaces for no visual loss (docs/3d-render.md).
// everything here is FrontSide: walls are wound inward and the horizontals' normals come out at +Y
// with the camera always above them, so a back face is never seen and rasterizing one is pure waste.
// the floor and the ledge used to get DoubleSide as a side effect of not casting shadows — two
// unrelated decisions on one flag, which is also how it stayed unnoticed
  static function add(scene:Scene, b:MeshBuf, tex:String, recv:Bool, casts:Bool):Void
    {
      if (b.idx.length == 0)
        return;
      var geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(b.pos, 3));
      geo.setAttribute('uv', new Float32BufferAttribute(b.uv, 2));
      geo.setAttribute('color', new Float32BufferAttribute(b.col, 3));
      geo.setIndex(b.idx);
      geo.computeVertexNormals();
      // vertexColors carries the lattice tint and the baked creases (see tint). it multiplies the
      // map, costs no draw call and no attribute the merge did not already need — and the program
      // permutation it adds is warmed for free, because View.warmup runs this same builder over
      // SewerModel.demo()
      var mesh = new Mesh(geo, SewerMask.patch(new MeshLambertMaterial({
        map: Textures.loadTexture(tex, 'wall', 1),
        side: THREE.FrontSide,
        vertexColors: true,
      })));
      mesh.receiveShadow = recv;
      mesh.castShadow = casts;
      scene.add(mesh);
    }
}
