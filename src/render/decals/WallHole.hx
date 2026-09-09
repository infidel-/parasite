package render.decals;

import three.Three;
import citygen.CityConfig;
import render.RenderConfig;
import render.particles.Sprites;
import render.world.WorldCtx;

// WALLHOLE bullet holes: stood upright on their struck wall face, nudged proud of it, radius-faded
// around the player. owns the lazy per-material hole-texture caches (masonry vs metal warehouse)
class WallHole {
  var d:Decals;                                          // coordinator back-ref (sprites, radiusOp)
  var holeTex:Array<Texture> = null;                     // masonry bullet-hole wall textures (lazy-loaded once)
  var holeTexMetal:Array<Texture> = null;                // metal-wall bullet-hole textures (lazy-loaded once)

  public function new(d:Decals)
    {
      this.d = d;
    }

// stand one bullet hole on its wall face; returns true if a quad was drawn
  public function draw(dec:tiles.Decoration, x:Int, y:Int, t:Float):Bool
    {
      if (dec.face == null)
        return false;
      var hts = holeTextures(dec.metal == true);
      if (hts.length == 0)
        return false;
      var fdir:Int = dec.face;
      var dv = render.world.Geom.DIRV[fdir];
      var w = CityConfig.cellToWorld(x + (dec.dx != null ? dec.dx : 0) / t,
        y + (dec.dy != null ? dec.dy : 0) / t);
      var op = d.radiusOp(w.x, w.z);
      if (op <= 0.001)
        return false;
      var roll = (dec.angle != null ? dec.angle : 0.0);
      // fold the stored roll into the variant so co-cell holes differ (reload-stable)
      var variant = ((x * 31 + y * 17 + Std.int(roll * 10)) % hts.length + hts.length) % hts.length;
      var sc = (dec.scale != null ? dec.scale : RenderConfig.WALLHOLE.scale);
      var wy = (dec.height != null ? dec.height : WorldCtx.floorY(x, y) + Sprites.SIZE * 0.4);
      // nudge proud of the wall face along the outward normal (clears the opaque face so the hole
      // isn't depth-culled; no z-fight since depthWrite is off)
      d.sprites.paintWall({
        x: w.x + dv[0] * 0.12,
        y: wy,
        z: w.z + dv[1] * 0.12,
        tex: hts[variant],
        op: op,
        scale: sc,
        faceRotY: render.world.Geom.faceRotY(fdir),
        roll: roll,
      });
      return true;
    }

// lazily load the bullet-hole wall textures once, per material (masonry vs metal-warehouse)
  function holeTextures(metal:Bool):Array<Texture>
    {
      if (metal)
        {
          if (holeTexMetal == null)
            holeTexMetal = loadHoleTex(RenderConfig.TEXTURES.bulletHolesMetal);
          return holeTexMetal;
        }
      if (holeTex == null)
        holeTex = loadHoleTex(RenderConfig.TEXTURES.bulletHoles);
      return holeTex;
    }

// load a set of clamp-wrapped alpha hole PNGs.
//
// these are the ONE family of textures bound to the sprite pool that render.particles.Sprites did
// not build: its own `mkTex` covers the six crop builders in that file and cannot reach a loader
// PNG. The pool uploads premultiplied and un-premultiplies per fragment, so a texture arriving
// without the flag gets divided by an alpha it was never multiplied by — measured on
// bullet-hole-1, whose edge band is 2.8% of the image at a mean RGB 79: an alpha-0.1 texel renders
// at 229 and anything under 0.05 clips to white and feeds the bloom pass.
//
// they want it on their OWN account as well, which is why this is set at the source rather than
// left to the guard in Sprites.slot: RGB under alpha 0 in these four files is 8 to 23, so they
// carry the same black bleed the atlas crops did
  function loadHoleTex(paths:Array<String>):Array<Texture>
    {
      return [for (p in paths)
        {
          var tx = render.Textures.loadTexture(p, 'wall');
          tx.wrapS = tx.wrapT = THREE.ClampToEdgeWrapping;
          tx.premultiplyAlpha = true;
          tx.colorSpace = THREE.NoColorSpace;
          tx;
        }];
    }
}
