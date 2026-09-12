package render.facility;

import three.Three;
import citygen.CityConfig;
import render.Textures;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// the laboratory sinks: one on the end cell of every bench block that has a free one.
//
// TWO QUADS AND NOT A PROP, and the silhouette-vs-surface triage answers it twice over. A basin seen
// from this camera's 51 degrees is not a silhouette at all — it is a SHAPE ON the worktop, a rim and
// a well and a drain hole, which is a surface and so a texture. And a tap read from the same pitch is
// a thin bent OUTLINE with air on both sides of it, which is an alpha cut: the one thing a quad does
// that a box cannot, and a thousand triangles of swept chrome to state any other way.
//
// ONE SHEET AND NOT TWO TEXTURES, which is render.facility.FacilityPlacard's argument and
// FacilityExit's before it: two images are two materials, two meshes and two draw calls to draw ONE
// fixture, where a u/v sub-rect is four numbers. docs/3d-textures.md warns that a packed sheet cannot
// serve an alpha cut, because `background:"transparent"` cuts the WHOLE image — and here BOTH cells
// want the cut, so that objection inverts into the argument FOR packing. It also bought the thing
// prose could not: drawn side by side the model harmonised the stainless, the way the cardboard and
// the steel finally agreed only once they shared a frame.
//
// AND THE SHEET HAS NO GRID. Nothing was split at a half or a third and nothing had to be: with the
// background genuinely empty each object's own ALPHA BBOX is its cell, so the rects in
// FacilityStyle are MEASURED off the drop rather than designed into it — including the one that
// matters most, the offset that puts the tap's column on the cell centre instead of hanging it by
// the middle of a bounding box its handle and its spout stick out of either side.
//
// NOT GATED ON `m.rooms`, which is the trap this pass had to be built around rather than into.
// FacilityModel.demo() leaves that list empty, so a rooms-gated family emits nothing in the warm
// scene and compiles its material on the frame the player first walks into a compound — the
// documented 91-to-101-programs failure. The demo model DOES stamp two bench blocks, so a pass that
// asks `m.table` and nothing else warms for free.
//
// AND IT PICKS A CELL RATHER THAN CLAIMING ONE. The generator decorates about 70% of bench cells and
// forces one on every room corner, so most of a run is already spoken for; a block whose edge cells
// are all taken simply gets no sink. That test is what FacilityModel.tableTaken exists for — the
// three decorations that LIE DOWN leave no trace in `tableDeco`, and a basin laid through a pair of
// gloves is exactly the failure a null check there would have shipped
class FacilitySink
{
  // the four cell-edge directions, in render.facility.FacilityGeom's own numbering:
  // 0 = -z, 1 = +z, 2 = -x, 3 = +x
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

// every sink in the compound as ONE merged mesh. returns how many stood, for __facility() — a merged
// mesh has no instance count and this is the only handle on the family
  public static function build(scene:Scene, m:Facility):Int
    {
      var b = MeshBufTools.make();
      var seen = new Map<Int, Bool>();
      var n = 0;
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            // an OFFICE desk takes none: a laboratory bench terminates in a sink, a writing desk does
            // not, and the washroom's own basins are its template's furniture
            if (!m.table[row][col] ||
                m.surf[row][col] == Surf.OFFICE ||
                seen.exists(key(m, col, row)))
              continue;
            var c = pick(m, block(m, col, row, seen));
            if (c == null)
              continue;
            emit(b, c.col, c.row);
            // and claim the cell, which is what render.facility.FacilityClutter reads: a basin is
            // 2.5 of a 4.0 cell, so nothing else may lie on this worktop
            m.tableSink[c.row][c.col] = true;
            n++;
          }
      add(scene, b);
      return n;
    }

// one bench BLOCK, as the cells of it — a flood fill claiming every cell on the way, so the outer
// scan above never restarts inside one. the discipline render.facility.FacilityTables.runs keeps for
// its casework, on four hands instead of one: a bench is a BLOCK and not a run, and the generator
// deals 1x1, 1x3, 3x1, 2x3 and 3x2 of them
  static function block(m:Facility, col:Int, row:Int, seen:Map<Int, Bool>):Array<{ col:Int, row:Int }>
    {
      var out = [{ col: col, row: row }];
      seen.set(key(m, col, row), true);
      var i = 0;
      while (i < out.length)
        {
          var c = out[i];
          i++;
          for (dir in 0...4)
            {
              var nc = c.col + DC[dir];
              var nr = c.row + DR[dir];
              if (!FacilityModel.isTable(m, nc, nr) ||
                  seen.exists(key(m, nc, nr)))
                continue;
              seen.set(key(m, nc, nr), true);
              out.push({
                col: nc,
                row: nr,
              });
            }
        }
      return out;
    }

// which cell of one block takes the sink, or null for a block with nowhere to put one.
//
// THE EDGE OF THE BLOCK, and "edge" has to be a neighbour count because nothing in this layer finds
// rects — FacilityModel keeps `table` as a grid precisely so every block shape falls out of one
// per-cell predicate. Two counts qualify and between them they cover everything the generator deals:
// ONE table neighbour is the END of a 1x3 or 3x1 run, and TWO ON PERPENDICULAR HANDS is the CORNER of
// a 3x2 island or of an L — the same "two hands that are not opposite" shape FacilityTables.hugs
// tests the walls with, asked of the bench grid instead. A cell with two OPPOSITE neighbours is the
// middle of a run and is not an edge at all, which is the case that count alone would get wrong.
//
// then the FREE one: a cell the generator already stood a flask on is a cell a tap draws through.
// The choice among what is left is rolled off the block's first cell so a compound does not put every
// sink on the same hand of every run, and off FacilityModel.mix rather than Math.random so a block
// comes back identical on every rebuild of the same area
  static function pick(m:Facility, cells:Array<{ col:Int, row:Int }>):{ col:Int, row:Int }
    {
      var edge = [];
      for (c in cells)
        {
          if (m.tableTaken[c.row][c.col])
            continue;
          var nz = FacilityModel.isTable(m, c.col, c.row - 1) ||
            FacilityModel.isTable(m, c.col, c.row + 1);
          var nx = FacilityModel.isTable(m, c.col - 1, c.row) ||
            FacilityModel.isTable(m, c.col + 1, c.row);
          var n = 0;
          for (dir in 0...4)
            if (FacilityModel.isTable(m, c.col + DC[dir], c.row + DR[dir]))
              n++;
          if (n == 1 ||
              (n == 2 && nz && nx))
            edge.push(c);
        }
      if (edge.length == 0)
        return null;
      var h = FacilityModel.mix((cells[0].col * 374761393) ^ (cells[0].row * 668265263));
      return edge[h % edge.length];
    }

// one sink on one bench cell: the basin lying on the worktop, and the tap standing at its back edge.
//
// BOTH MAP THEIR CROP 0..1, which is what locks each face's aspect to its rect in FacilityStyle — a
// clamp or a squeeze here is a stretch, and there is nothing to clamp AGAINST anyway: the basin is
// half a cell wide on a cell whose worktop is grown outward by BENCH_LIP on every open side.
//
// THE TAP GOES AT THE BACK and its base line is the basin's own far edge, so the spout reads as
// rising behind the bowl rather than out of the middle of it. Back is -z: this camera looks from +z,
// which is also why the quad faces +z and is never turned. FIXED YAW AND NOT CAMERA-FACING — the
// standing rule for anything glued to a world position, and the pose the bench sprites beside it
// already hold. It is left UNLEANED, unlike those sprites, which costs it cos 51 = 0.63 of its drawn
// height and is paid for in SINK_FAUCET_H rather than in a rotation the foot would then have to be
// corrected for
  static function emit(b:MeshBuf, col:Int, row:Int):Void
    {
      var c = CityConfig.cellToWorld(col, row);
      var hw = FacilityStyle.SINK_BASIN_W / 2;
      var hd = FacilityStyle.SINK_BASIN_D / 2;
      var x0 = c.x - hw, x1 = c.x + hw;
      var z0 = c.z - hd, z1 = c.z + hd;
      // the basin, wound to look UP — FacilityGeom.cap's winding, but off the sheet's own rect
      // instead of a world-aligned period. three flips y, so the source's TOP row is the HIGH v and
      // lands on the FAR edge of the cell: the art is a top-down view and its top is the back of it
      var y = FacilityStyle.BENCH_H + FacilityStyle.SINK_Y;
      MeshBufTools.quad(b, [x0, y, z1], [x1, y, z1], [x1, y, z0], [x0, y, z0], [
        FacilityStyle.SINK_BASIN_U0, FacilityStyle.SINK_BASIN_V0,
        FacilityStyle.SINK_BASIN_U1, FacilityStyle.SINK_BASIN_V0,
        FacilityStyle.SINK_BASIN_U1, FacilityStyle.SINK_BASIN_V1,
        FacilityStyle.SINK_BASIN_U0, FacilityStyle.SINK_BASIN_V1,
      ]);
      // and the tap, standing on the worktop itself and not on the basin quad: its foot is the
      // bench top, so a fraction of the column is hidden behind the rim exactly as a real one is.
      // the x slide is SINK_FAUCET_AXIS — the rect's centre is not the tap's centre, the handle and
      // the spout stick out either side of the column, and hanging the quad by its bounding box
      // would stand the tap off the middle of its own basin
      var fw = FacilityStyle.SINK_FAUCET_W;
      var fx = c.x + FacilityStyle.SINK_FAUCET_AXIS * fw;
      var fz = z0;
      var fy = FacilityStyle.BENCH_H;
      MeshBufTools.quad(b,
        [fx - fw / 2, fy, fz], [fx + fw / 2, fy, fz],
        [fx + fw / 2, fy + FacilityStyle.SINK_FAUCET_H, fz],
        [fx - fw / 2, fy + FacilityStyle.SINK_FAUCET_H, fz], [
        FacilityStyle.SINK_FAUCET_U0, FacilityStyle.SINK_FAUCET_V0,
        FacilityStyle.SINK_FAUCET_U1, FacilityStyle.SINK_FAUCET_V0,
        FacilityStyle.SINK_FAUCET_U1, FacilityStyle.SINK_FAUCET_V1,
        FacilityStyle.SINK_FAUCET_U0, FacilityStyle.SINK_FAUCET_V1,
      ]);
    }

// one cell's slot in the claimed-cell set. FacilityTables.key's layout WITHOUT its direction term: a
// cell belongs to exactly one bench block, where a corridor cell can stand a run against either of
// two walls
  static inline function key(m:Facility, col:Int, row:Int):Int
    {
      return row * m.w + col;
    }

// the whole family as one mesh. the CUT material render.facility.FacilityDeco.cut ships for its
// shelving frame, and here for the same three reasons: an opaque alphaTest draws DoubleSide in ONE
// pass, it still writes depth so nothing has to be sorted against the worktop under it, and leaving
// `transparent` false keeps VisionMask compiling its darkening branch rather than the alpha-scaling
// one (the trap FacilityGeom.addPane records). DoubleSide is free on an opaque material and is what
// keeps the basin whole when the player orbits the camera under the worktop's own plane.
//
// NO `alphaToCoverage` here, and that was measured rather than assumed — it makes this surface WORSE.
// See docs/3d-changes.md; the short version is that the basin runs at 2.32 texels per pixel at a
// normal viewing distance, so the alpha ramp is SUB-PIXEL, three's `fwidth(a)` swings between
// adjacent 2x2 derivative quads, and its smoothstep then hands the same fully-opaque texel a
// different coverage in each one. That dithers the edge instead of smoothing it: the basin's lower
// rim measured 0.149 px of edge wander with a plain cut and 0.296 px with the flag on
  static function add(scene:Scene, b:MeshBuf):Void
    {
      if (b.idx.length == 0)
        return;
      var mesh = new Mesh(FacilityGeom.geom(b), VisionMask.patch(new MeshLambertMaterial({
        map: Textures.loadTexture(FacilityStyle.SINK_TEX, 'wall', 1),
        alphaTest: FacilityStyle.SINK_CUT,
        side: THREE.DoubleSide,
      })));
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
    }
}
