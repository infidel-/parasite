package render.cave;

import three.Three;
import citygen.CityConfig;
import gen.cave.CaveField;
import render.Textures;
import render.Poly.tag;
import render.cave.CaveStyle.CavePatch;
import render.sewer.SewerModel;
import render.sewer.SewerModel.Sewer;
import render.world.CoverageMask;

// ragged ground patches over the cave floor — wet clay, bedrock showing through and loose gravel, one
// overlay layer each with its own coverage mask (asked for: "splotches of other dirt/stone like we
// have outside in the wilderness"). render.wild.WildPatches' idiom on render.world.CoverageMask's
// field: cells say where a layer may be drawn, the mask's smooth ramp says how far, and alphaTest
// turns that ramp into a ragged dissolve along the art's own islands. two differences that are the
// cave's: the floor is flat, so a layer is one mesh rather than one per chunk (the cave is 24x18), and
// the floor's baked value is darkened along the walls, so every vertex takes that value too
class CavePatches
{
  static inline var CELL = CityConfig.CELL;
  // the salt that separates the layers' hashes (render.wild.WildPatches.SALT's reasoning)
  static inline var SALT = 0x5BD1E995;

  // the baked masks, freed by the next build (render.wild.WildPatches.masks' reason)
  static var masks:Array<Texture> = [];

// emit every patch layer, bottom first
  public static function build(scene:Scene, m:Sewer):Void
    {
      for (t in masks)
        t.dispose();
      masks = [];
      var layers = CaveStyle.PATCHES;
      for (i in 0...layers.length)
        layer(scene, m, layers[i], i);
    }

// one layer: pick its floor cells, bake its mask, emit its quads
  static function layer(scene:Scene, m:Sewer, p:CavePatch, i:Int):Void
    {
      // a seed marks itself plus whichever of its four neighbours the spare bits of its hash pick, so
      // it grows into a 1-5 cell clump (render.wild.WildPatches' pass 1)
      var taken = [for (_ in 0...m.h) [for (_ in 0...m.w) false]];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            var h = SewerModel.mix(((col * 40503803) ^ (row * 12582917)) ^ (SALT * (i + 1)));
            if ((h % 1000) >= p.chance * 1000)
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
      if (p.mouths)
        for (l in m.lamps)
          for (dr in -CaveStyle.PATCH_MOUTH...CaveStyle.PATCH_MOUTH + 1)
            for (dc in -CaveStyle.PATCH_MOUTH...CaveStyle.PATCH_MOUTH + 1)
              mark(taken, m, l.col + dc, l.row + dr);
      var mask = CoverageMask.bake(taken, CaveStyle.PATCH_TILE, CaveStyle.PATCH_KERN,
        CaveStyle.PATCH_KERN_JIT);
      if (mask == null)
        return;
      masks.push(mask);
      // render.wild.WildPatches' material, for its reasons: blended, the alphaTest after the alphaMap
      // multiply, no depth write, and masked as alpha (transparent) by VisionMask.patch
      var mat = render.world.VisionMask.patch(tag(new MeshLambertMaterial({
        map: Textures.loadTexture(p.tex, 'wall', 1),
        alphaMap: mask,
        vertexColors: true,
        transparent: true,
        opacity: CaveStyle.PATCH_ALPHA,
        alphaTest: CaveStyle.PATCH_ALPHA * 0.5,
        depthWrite: false,
        side: THREE.FrontSide,
      }),
        'cave-patch', 'cave floor patch', p.tex));
      emit(scene, mat, m, taken, CaveStyle.PATCH_Y * (i + 1));
    }

// the layer's quads over every cell that is marked OR touches a marked one (the apron the blob rounds
// off into; the part of it under the rock is hidden by the rock), each cell split on the field lattice
// so the wall-foot darkening is sampled where the floor itself samples it
  static function emit(scene:Scene, mat:MeshLambertMaterial, m:Sewer, taken:Array<Array<Bool>>,
      y:Float):Void
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var s = CaveField.SAMPLES;
      var isFloor = function(col:Int, row:Int) return SewerModel.isFloor(m, col, row);
      var pos:Array<Float> = [];
      var nor:Array<Float> = [];
      var uv:Array<Float> = [];
      var colr:Array<Float> = [];
      var idx:Array<Int> = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (!near(taken, col, row))
              continue;
            for (sj in 0...s)
              for (si in 0...s)
                {
                  var base = Std.int(pos.length / 3);
                  for (k in [[0, 0], [1, 0], [1, 1], [0, 1]])
                    {
                      var u = col + (si + k[0]) / s;
                      var v = row + (sj + k[1]) / s;
                      var x = u * CELL - half;
                      var z = v * CELL - half;
                      pos.push(x);
                      pos.push(y);
                      pos.push(z);
                      nor.push(0);
                      nor.push(1);
                      nor.push(0);
                      // uv straight off world position, so abutting cells read as one patch
                      uv.push(x / CaveStyle.PATCH_TILE);
                      uv.push(z / CaveStyle.PATCH_TILE);
                      var c = CaveGeom.floorShade(u, v, CaveField.field(isFloor, u, v) - CaveField.ISO);
                      colr.push(c);
                      colr.push(c);
                      colr.push(c);
                    }
                  idx.push(base);
                  idx.push(base + 2);
                  idx.push(base + 1);
                  idx.push(base);
                  idx.push(base + 3);
                  idx.push(base + 2);
                }
          }
      var geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(pos, 3));
      geo.setAttribute('normal', new Float32BufferAttribute(nor, 3));
      geo.setAttribute('uv', new Float32BufferAttribute(uv, 2));
      geo.setAttribute('color', new Float32BufferAttribute(colr, 3));
      geo.setIndex(idx);
      var mesh = new Mesh(geo, mat);
      mesh.renderOrder = render.particles.Sprites.ORD_DECAL - 1; // ground, under the decals
      mesh.receiveShadow = true;
      scene.add(mesh);
    }

// mark a cell when it is walkable floor
  static inline function mark(taken:Array<Array<Bool>>, m:Sewer, col:Int, row:Int):Void
    {
      if (SewerModel.isFloor(m, col, row))
        taken[row][col] = true;
    }

// is (col, row) marked, or one of its eight neighbours?
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
