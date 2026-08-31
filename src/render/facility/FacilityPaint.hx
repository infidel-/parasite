package render.facility;

import three.Three;
import citygen.CityConfig;
import render.RenderConfig;
import render.Textures;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// everything struck on the compound's asphalt: the PARKING LOT — its bays against every pavement
// apron and the back-to-back rows that march on into the middle — and the main road's lane lines.
//
// ONE merged mesh in the city's own worn traffic paint, which is why the road's few lines share a
// file with the lot's many: they lie on the same surfaces and cost one draw call together. opaque
// and lit like the ground under them (render.world.Ground says why it is not a cutout), floating
// FacilityStyle.PAINT_Y over the surface each line belongs to and NOT over y = 0.
//
// the lot's geometry is never searched for as a rectangle. a lot cell against a pavement apron IS
// the edge cars park at, so the whole lattice falls out of the tile grid: a RUN is the stretch of
// asphalt holding its pavement on one side, and the run decides both phases — the rhythm along the
// kerb (`runStart`) and the depth marching away from it (`bayLine`)
class FacilityPaint
{
  static inline var CELL = CityConfig.CELL;
  // the four cell-edge directions, in render.facility.FacilityGeom's own numbering. `dir ^ 1` is the
  // opposite of a direction, which is how a bay line marches away from the kerb it hangs off
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

// every painted line in the compound, merged into one mesh
  public static function build(scene:Scene, m:Facility):Void
    {
      var b = MeshBufTools.make();
      lanes(b, m);
      bays(b, m);
      add(scene, b, FacilityStyle.GROUND_PAINT);
    }

// the main road's lane lines. the compound has exactly one road, and it is a straight band laid
// across the FULL WIDTH at one edge (game.FacilityAreaGenerator lines 66-69). so the band is its row
// extent, it never meets an intersection, and none of render.world.Ground's crossing machinery is
// needed here
  static function lanes(b:MeshBuf, m:Facility):Void
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var lw = RenderConfig.LINE_W;
      var r0 = -1;
      var r1 = -1;
      for (row in 0...m.h)
        if (m.surf[row][0] == Surf.ROAD)
          {
            if (r0 < 0)
              r0 = row;
            r1 = row;
          }
      if (r1 - r0 + 1 != 4)
        return;
      var y = FacilityGround.surfY(Surf.ROAD) + FacilityStyle.PAINT_Y;
      var x0 = -half;
      var x1 = m.w * CELL - half;
      for (k in 0...3)
        {
          var z = (r0 + k + 1) * CELL - half;
          // the middle boundary is the centre of the road and takes the double solid line; the two
          // either side are lane dividers and dash
          if (k != 1)
            {
              var p = x0;
              while (p < x1)
                {
                  mark(b, p, Math.min(p + RenderConfig.DASH_LEN, x1), z - lw / 2, z + lw / 2, y);
                  p += RenderConfig.DASH_LEN + RenderConfig.DASH_GAP;
                }
              continue;
            }
          var g = RenderConfig.DOUBLE_GAP / 2;
          mark(b, x0, x1, z - g - lw / 2, z - g + lw / 2, y);
          mark(b, x0, x1, z + g - lw / 2, z + g + lw / 2, y);
        }
    }

// the parking lot. one pass over the asphalt, striking the lines of whichever run each cell belongs
// to — the first pavement it finds, so a cell in a corner is claimed once and the two runs meeting
// there do not both stripe it
  static function bays(b:MeshBuf, m:Facility):Void
    {
      var dom = dominant(m);
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (m.surf[row][col] != Surf.LOT)
              continue;
            for (dir in 0...4)
              {
                if (!isSurf(m, col + DC[dir], row + DR[dir], Surf.WALKWAY))
                  continue;
                if (isEntry(m, col, row, dir))
                  break;
                // the run's rhythm, struck on the cell's OWN west (or north) edge and counted from
                // the CORNER the run starts at, not from the world grid — a run that begins on an
                // odd cell would otherwise open with a half-width spot. the lot test is what keeps
                // the first divider off the kerb it starts at: where a second pavement meets this
                // one the divider would lie ALONG that kerb, parallel to the pavement instead of
                // across it, and that bay is bounded by the kerb already
                var s = runStart(m, col, row, dir);
                if (((dir < 2 ? col : row) - s) % FacilityStyle.BAY_SPACING == 0 &&
                    isSurf(m, col + (dir < 2 ? -1 : 0), row + (dir < 2 ? 0 : -1), Surf.LOT))
                  bayLine(b, m, col, row, dir, dir == dom);
                // and one closing the run where the KERB ENDS. the next cell along is still lot but
                // has no pavement to park against, so nothing else strikes that edge and the last
                // bay bleeds into the open lot — which is exactly the inside corner of an L-shaped
                // pavement, where the two runs meet. only where the closing edge lands ON the
                // rhythm, though: struck anywhere else it fences off a half-width spot
                var tc = col + (dir < 2 ? 1 : 0);
                var tr = row + (dir < 2 ? 0 : 1);
                if (((dir < 2 ? tc : tr) - s) % FacilityStyle.BAY_SPACING == 0 &&
                    isSurf(m, tc, tr, Surf.LOT) &&
                    !isSurf(m, tc + DC[dir], tr + DR[dir], Surf.WALKWAY))
                  bayLine(b, m, tc, tr, dir, dir == dom);
                break;
              }
          }
    }

// one whole bay line, marching away from the kerb: the row of bays against the pavement, then an
// aisle, then the back-to-back rows that fill the middle. (col, row) is the cell whose leading edge
// the line is struck on — the run's own for its rhythm, the next one along for the line that closes
// it. `deep` is off for every kerb but the compound's busiest, whose rows are the only ones that
// march
  static function bayLine(b:MeshBuf, m:Facility, col:Int, row:Int, dir:Int, deep:Bool):Void
    {
      var half = (CityConfig.GRID * CELL) / 2;
      // inward is away from the pavement, so the line marches on the OPPOSITE direction's step
      var dc = DC[dir ^ 1];
      var dr = DR[dir ^ 1];
      // the line's own coordinate across the run, and the kerb edge it measures its depth from
      var e = (dir < 2 ? col : row) * CELL - half;
      var k = ((dir < 2 ? row : col) + (dir == 1 || dir == 3 ? 1 : 0)) * CELL - half;
      var step = (dir == 1 || dir == 3 ? -CELL : CELL);
      // a line that OPENS a bay carries the row divider too; the one that CLOSES a run has no bay
      // after it. the run's own cells have the pavement beside them, the closing cell is past the end
      var lead = isSurf(m, col + DC[dir], row + DR[dir], Surf.WALKWAY);
      var o = 0;
      var len = FacilityStyle.BAY_CELLS;
      while (FacilityModel.inside(m, col + dc * o, row + dr * o))
        {
          // a blocked band is SKIPPED and not stopped at — a building standing in the middle of the
          // lot must not take the asphalt behind it out of the lattice too
          if (open(m, col + dc * o, row + dr * o, dir, len, o > 0))
            {
              divider(b, dir >= 2, e, k + step * o, k + step * (o + len));
              // a marching band is TWO rows of bays laid back to back, so it takes the line down its
              // middle that tells one row from the other. one bay's worth per divider, which is what
              // makes the segments meet into a line the length of the row
              if (lead && len > FacilityStyle.BAY_CELLS)
                divider(b, dir < 2, k + step * (o + FacilityStyle.BAY_CELLS),
                  e, e + FacilityStyle.BAY_SPACING * CELL);
            }
          if (!deep)
            return;
          o += len + FacilityStyle.AISLE_CELLS;
          len = FacilityStyle.BAY_CELLS * 2;
        }
    }

// one bay divider: a stripe of paint at `e` on the axis ACROSS the run, spanning a0..a1 along it,
// floating over the lot's own surface and not over y = 0
  static function divider(b:MeshBuf, alongX:Bool, e:Float, a0:Float, a1:Float):Void
    {
      var lw = RenderConfig.LINE_W;
      var y = FacilityGround.surfY(Surf.LOT) + FacilityStyle.PAINT_Y;
      if (alongX)
        mark(b, Math.min(a0, a1), Math.max(a0, a1), e - lw / 2, e + lw / 2, y);
      else
        mark(b, e - lw / 2, e + lw / 2, Math.min(a0, a1), Math.max(a0, a1), y);
    }

// is the lot open for this stretch of a bay line — `len` cells of asphalt from here inward? an
// INNER stretch has to clear every other pavement's row of bays AND the aisle behind it: laid any
// closer, the marching rows meet a row struck at right angles nose to nose, with nothing between
// them for a car to turn in. the row against the kerb does not clear anything: that row IS one of
// those, and in a corner it shares its cells with the other one by design
  static function open(m:Facility, col:Int, row:Int, dir:Int, len:Int, inner:Bool):Bool
    {
      var dc = DC[dir ^ 1];
      var dr = DR[dir ^ 1];
      var keep = FacilityStyle.BAY_CELLS + FacilityStyle.AISLE_CELLS;
      for (i in 0...len)
        {
          var c = col + dc * i;
          var r = row + dr * i;
          if (!isSurf(m, c, r, Surf.LOT))
            return false;
          if (!inner)
            continue;
          for (d in 0...4)
            {
              if (d == dir)
                continue;
              for (j in 1...keep + 1)
                if (isSurf(m, c + DC[d] * j, r + DR[d] * j, Surf.WALKWAY))
                  return false;
            }
        }
      return true;
    }

// which of the four kerb directions the compound parks against most. only that one's lines march
// into the middle, so the open asphalt is filled by ONE lattice instead of by two crossing ones
  static function dominant(m:Facility):Int
    {
      var n = [0, 0, 0, 0];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (m.surf[row][col] != Surf.LOT)
              continue;
            for (dir in 0...4)
              if (isSurf(m, col + DC[dir], row + DR[dir], Surf.WALKWAY))
                n[dir]++;
          }
      var best = 0;
      for (dir in 1...4)
        if (n[dir] > n[best])
          best = dir;
      return best;
    }

// is this lot cell part of the sidewalk's parking ENTRY — a run of asphalt that begins off the ROAD
// rather than against a pavement? it is the gateway the cars drive through, so nothing is struck on
// it and, as render.facility.FacilityLamps asks the same question, nothing stands in it either
  public static function isEntry(m:Facility, col:Int, row:Int, dir:Int):Bool
    {
      var s = runStart(m, col, row, dir);
      return isSurf(m, (dir < 2 ? s - 1 : col), (dir < 2 ? row : s - 1), Surf.ROAD);
    }

// the coordinate along the kerb where this cell's bay run BEGINS — walk back while the cells keep
// their pavement on the same side. the rhythm counts from here so that every run opens on a whole
// bay, and the two runs meeting at a corner square it off between them. public because
// render.facility.FacilityLamps reads the same phase to keep a mast out of the paint
  public static function runStart(m:Facility, col:Int, row:Int, dir:Int):Int
    {
      var dc = (dir < 2 ? -1 : 0);
      var dr = (dir < 2 ? 0 : -1);
      while (isSurf(m, col + dc, row + dr, Surf.LOT) &&
             isSurf(m, col + dc + DC[dir], row + dr + DR[dir], Surf.WALKWAY))
        {
          col += dc;
          row += dr;
        }
      return (dir < 2 ? col : row);
    }

// does this cell hold that ground surface? false off the grid
  static inline function isSurf(m:Facility, col:Int, row:Int, s:Surf):Bool
    return FacilityModel.inside(m, col, row) && m.surf[row][col] == s;

// one painted rect, its uv world-aligned on both axes so the wear samples at one scale everywhere
  static inline function mark(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, y:Float):Void
    {
      var t = RenderConfig.PAINT_TILE;
      MeshBufTools.quad(b, [x0, y, z1], [x1, y, z1], [x1, y, z0], [x0, y, z0],
        [x0 / t, z1 / t, x1 / t, z1 / t, x1 / t, z0 / t, x0 / t, z0 / t]);
    }

// merge the paint buffer into a lit mesh, the same pair of shadow flags every outdoor surface takes
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
        map: Textures.loadTexture(tex, 'ground', 1),
        side: THREE.FrontSide,
      })));
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
    }
}
