package render.world;

import three.Three;
import citygen.CityConfig;

// the coverage field behind a ragged ground-patch layer: one soft radial kernel per marked cell,
// unioned onto an area-wide canvas and handed to a material as its alphaMap.
//
// the SHAPE a caller gets does not come from the cells it marked. cells only say WHERE the art may be
// drawn; the visible boundary is this field, so it is a smooth round contour that owes nothing to the
// tile axes and never shows the grid as a straight 4-unit edge. alphaTest then runs AFTER the alphaMap
// multiply, which is what turns this smooth ramp into a ragged dissolve along the ART's own shapes
// instead of a visible soft blob.
//
// lifted out of render.world.Lawns when render.wild.WildPatches became the second caller. it is shared
// rather than copied because every one of its four decisions is a trap that would be stepped in again:
//  - 'lighten' is a per-channel MAX, not an additive composite. a kernel's reach is then exactly its
//    own radius however many neighbours pile up; added, the visible contour creeps outward in dense
//    clusters until it spills past the geometry underneath it.
//  - flipY = false. canvas row 0 is z = -half, and a bare CanvasTexture defaults to true and mirrors it.
//  - the mask rides on the SAME uv as the art (alphaMap carries its own texture transform), so the uv
//    that tiles the art every `tile` world units is rescaled here to span the area rect exactly once.
//  - the kernel radius must stay comfortably above CELL * 0.5, or neighbouring kernels pinch at their
//    waist and a run of marked cells beads into a string of pearls instead of one lumpy band.
class CoverageMask
{
  static inline var GRID = CityConfig.GRID;
  static inline var CELL = CityConfig.CELL;
  // canvas edge. it covers the WHOLE area rect, so this is ~0.4 world units per texel. the field it
  // holds is a smooth ramp, so bilinear reconstruction is near-exact and the contour stays curved
  // even at this resolution
  static inline var MASK_PX = 1024;

// bake the coverage field for a marked-cell grid. `tile` is the world size of one repeat of the art
// this mask will ride on; `kern` is the kernel radius in world units and `kernJit` the per-cell
// jitter of that radius and of the kernel centre, as a fraction. returns null when nothing is marked,
// so a caller can skip its whole layer rather than build an empty one
  public static function bake(taken:Array<Array<Bool>>, tile:Float, kern:Float, kernJit:Float):Texture
    {
      var px = MASK_PX / (GRID * CELL); // canvas pixels per world unit
      var cv = js.Browser.document.createCanvasElement();
      cv.width = MASK_PX;
      cv.height = MASK_PX;
      var ctx = cv.getContext2d();
      ctx.fillStyle = '#000000';
      ctx.fillRect(0, 0, MASK_PX, MASK_PX);
      ctx.globalCompositeOperation = 'lighten';
      var any = false;
      for (row in 0...taken.length)
        for (col in 0...taken[row].length)
          {
            if (!taken[row][col])
              continue;
            any = true;
            var h = ((col * 83492791) ^ (row * 51992411)) & 0x7fffffff;
            // three independent jitters off one hash: kernel centre in x and z, and its radius.
            // without them every blob is the same circle on the same lattice, which reads as a pattern
            var jx = ((h & 63) / 63 - 0.5) * CELL * kernJit;
            var jz = (((h >> 6) & 63) / 63 - 0.5) * CELL * kernJit;
            var r = kern * (1 + (((h >> 12) & 63) / 63 - 0.5) * 2 * kernJit) * px;
            var cx = (col * CELL + CELL / 2 + jx) * px;
            var cy = (row * CELL + CELL / 2 + jz) * px;
            var g = ctx.createRadialGradient(cx, cy, 0, cx, cy, r);
            g.addColorStop(0, '#ffffff');
            g.addColorStop(1, '#000000');
            ctx.fillStyle = g;
            ctx.fillRect(cx - r, cy - r, r * 2, r * 2);
          }
      if (!any)
        return null;
      var tex = new CanvasTexture(cv);
      tex.flipY = false;
      tex.repeat.set(tile / (GRID * CELL), tile / (GRID * CELL));
      tex.offset.set(0.5, 0.5);
      tex.needsUpdate = true;
      return tex;
    }
}
