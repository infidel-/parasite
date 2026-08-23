package render.wild;

import three.Three;
import citygen.CityConfig;
import render.Textures;
import render.Poly.tag;
import render.wild.WildModel.Wild;
import render.world.CoverageMask;

// ragged ground patches over the wilderness turf — dead grass and bare earth, one overlay layer each
// with its own coverage mask. this is what gives the base ground real variability: the vertex mottle
// render.wild.WildGround carries only moves the VALUE of one texture, where a patch changes what the
// ground is made of, and it does that with no second base map, no splat shader and no blend weights.
//
// the idiom is render.world.Lawns' and the mask itself is shared with it (render.world.CoverageMask),
// with ONE deliberate difference: the geometry is emitted per render.Chunks.CELLS block rather than as
// a single mesh. Lawns can afford one mesh because a city lawn only ever covers a handful of alley
// cells; out here a layer spans the whole 400-unit area, which is past Chunks' own size guard, so a
// single mesh would sit at the scene root and submit the area's entire blended fill every frame
// however little of it is on screen.
class WildPatches
{
  static inline var CELL = CityConfig.CELL;
  // the salt that separates the two layers' hashes. any odd constant does — WildModel.mix avalanches,
  // so the layers decorrelate from each other and from the tuft and prop rolls over the same cells
  static inline var SALT = 0x9E3779B;

  // the baked masks, held so the next build can free them: View.disposeScene deliberately skips
  // textures, and these are per-area canvases rather than shared cached art (Lawns holds its own for
  // the same reason)
  static var masks:Array<Texture> = [];

// emit both patch layers
  public static function build(scene:Scene, m:Wild):Void
    {
      for (t in masks)
        t.dispose();
      masks = [];
      // earth first so it sits UNDER the dead grass: bare soil is what is left where nothing grew,
      // and dry grass lying over it reads the right way round
      layer(scene, m, WildStyle.PATCH_EARTH, WildStyle.PATCH_EARTH_CHANCE, 0);
      layer(scene, m, WildStyle.PATCH_DEAD, WildStyle.PATCH_DEAD_CHANCE, 1);
    }

// one overlay layer: pick its cells, bake its mask, then emit its geometry per chunk block.
// `i` is the layer index, which salts the hash and sets the height it sits at
  static function layer(scene:Scene, m:Wild, tex:String, chance:Float, i:Int):Void
    {
      // pass 1 — which cells this patch may cover. a seed marks itself plus whichever of its four
      // neighbours the spare bits of its hash pick, so it becomes a 1-5 cell clump rather than a lone
      // square and the blob the mask grows off it comes out lumpy instead of circular (Lawns' idiom)
      var taken = [for (_ in 0...m.h) [for (_ in 0...m.w) false]];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            var h = WildModel.mix(((col * 40503803) ^ (row * 12582917)) ^ (SALT * (i + 1)));
            if ((h % 1000) >= chance * 1000)
              continue;
            mark(taken, m, col, row);
            if (((h >> 10) & 1) != 0)
              mark(taken, m, col + 1, row);
            if (((h >> 11) & 1) != 0)
              mark(taken, m, col - 1, row);
            if (((h >> 12) & 1) != 0)
              mark(taken, m, col, row + 1);
            if (((h >> 13) & 1) != 0)
              mark(taken, m, col, row - 1);
          }
      var mask = CoverageMask.bake(taken, WildStyle.PATCH_TILE, WildStyle.PATCH_KERN,
        WildStyle.PATCH_KERN_JIT);
      if (mask == null)
        return;
      masks.push(mask);
      // blended, not a hard cutout: the patch is a half-transparent overlay so the turf shows through
      // it. alphaTest runs AFTER the alphaMap multiply, which is what turns the mask's smooth ramp
      // into a ragged dissolve along the art's own island shapes instead of a visible soft blob.
      // FrontSide, where Lawns takes DoubleSide — this only ever faces up
      var mat = tag(new MeshLambertMaterial({
        map: Textures.loadTexture(tex, 'wall', 1),
        alphaMap: mask,
        transparent: true,
        opacity: WildStyle.PATCH_ALPHA,
        alphaTest: WildStyle.PATCH_ALPHA * 0.5,
        depthWrite: false,
        side: THREE.FrontSide,
      }),
        'wild-patch', 'wilderness ground patch', tex);
      var y = WildStyle.PATCH_Y * (i + 1);
      var B = render.Chunks.CELLS;
      var row = 0;
      while (row < m.h)
        {
          var col = 0;
          while (col < m.w)
            {
              block(scene, mat, taken, y, col, row,
                (col + B <= m.w) ? B : m.w - col,
                (row + B <= m.h) ? B : m.h - row);
              col += B;
            }
          row += B;
        }
    }

// one chunk block of a layer: a flat quad per cell that is marked OR touches a marked one. the apron
// ring is what lets a blob round off past its own cell instead of being clipped square by it
  static function block(scene:Scene, mat:MeshLambertMaterial, taken:Array<Array<Bool>>, y:Float,
    col0:Int, row0:Int, cw:Int, ch:Int):Void
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var pos = [];
      var nor = [];
      var uv = [];
      var idx = [];
      for (dr in 0...ch)
        for (dc in 0...cw)
          {
            if (!near(taken, col0 + dc, row0 + dr))
              continue;
            var x0 = (col0 + dc) * CELL - half;
            var z0 = (row0 + dr) * CELL - half;
            var x1 = x0 + CELL;
            var z1 = z0 + CELL;
            var base = Std.int(pos.length / 3);
            // uv straight off world position, so abutting cells read as one continuous overgrown
            // field rather than a per-cell stamp — and nothing is stretched on either axis
            for (p in [[x0, z0], [x1, z0], [x1, z1], [x0, z1]])
              {
                pos.push(p[0]);
                pos.push(y);
                pos.push(p[1]);
                nor.push(0.0);
                nor.push(1.0);
                nor.push(0.0);
                uv.push(p[0] / WildStyle.PATCH_TILE);
                uv.push(p[1] / WildStyle.PATCH_TILE);
              }
            idx.push(base);
            idx.push(base + 2);
            idx.push(base + 1);
            idx.push(base);
            idx.push(base + 3);
            idx.push(base + 2);
          }
      if (idx.length == 0)
        return;
      var geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(pos, 3));
      // written flat, not computed: every quad here faces straight up and computeVertexNormals over
      // the whole layer for a known answer is build-time cost with no output
      geo.setAttribute('normal', new Float32BufferAttribute(nor, 3));
      geo.setAttribute('uv', new Float32BufferAttribute(uv, 2));
      geo.setIndex(idx);
      var mesh = new Mesh(geo, mat);
      mesh.renderOrder = render.particles.Sprites.ORD_DECAL - 1; // under blood and debris: this is ground, not a decal
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
    }

// mark a cell, if it is on the grid at all
  static inline function mark(taken:Array<Array<Bool>>, m:Wild, col:Int, row:Int):Void
    {
      if (WildModel.inside(m, col, row))
        taken[row][col] = true;
    }

// is (col,row) marked, or one of its eight neighbours?
  static function near(taken:Array<Array<Bool>>, col:Int, row:Int):Bool
    {
      for (dr in -1...2)
        for (dc in -1...2)
          {
            var c = col + dc;
            var r = row + dr;
            if (r >= 0 &&
                r < taken.length &&
                c >= 0 &&
                c < taken[r].length &&
                taken[r][c])
              return true;
          }
      return false;
    }
}
