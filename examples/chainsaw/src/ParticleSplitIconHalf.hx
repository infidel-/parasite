// mod-side particle: one half of a sliced AI sprite. spawned in pairs on
// chainsaw kills — each half flies to a nearby tile rotating, holds briefly,
// then fades to transparent. atlas, source tile, and split geometry are
// snapshot at ctor so engine pixel positions stay stable across the ~900ms
// lifetime (matches ParticleBloodSpurt's camera-snapshot pattern).
package;

import particles.Particle;

class ParticleSplitIconHalf extends Particle
{
  // src/dst centroid pixel positions (camera-local, snapshot at ctor)
  var srcX: Float;
  var srcY: Float;
  var dstX: Float;
  var dstY: Float;
  // final rotation reached by the end of the fly phase (radians)
  var endAngle: Float;
  // atlas image element from scene.images (Dynamic — extern type)
  var img: Dynamic;
  // atlas subrect for this half
  var srcSubX: Float;
  var srcSubY: Float;
  var srcSubW: Float;
  var srcSubH: Float;
  // destination draw width/height (tile-scaled)
  var dstW: Float;
  var dstH: Float;

// constructs one half. `axis` 0 = vertical cut (left/right halves),
// 1 = horizontal cut (top/bottom). `splitFrac` in (0..1) is the small-half
// fraction. `half` 0 = small half (left/top), 1 = big half (right/bottom).
// `ent` is the live AIEntity ref grabbed before AreaGame.removeAI nulled it
  public function new(s: GameScene, target: _Point, ent: Dynamic,
      axis: Int, splitFrac: Float, half: Int)
    {
      super(s);

      var tile = Const.TILE_SIZE;
      var clean = Const.TILE_SIZE_CLEAN;

      // pull icon source data via untyped — imageName/ix/iy are package-private
      // on Entity so they're stripped from the SDK extern, but the JS fields
      // exist (engine builds with -dce no)
      var imageName: String = untyped ent.imageName;
      var ix: Int = untyped ent.ix;
      var iy: Int = untyped ent.iy;
      var isMale: Bool = ent.isMaleAtlas;
      img = s.images.getImage(imageName, isMale);

      // base atlas rect for the full tile (matches Entity.drawImage layout)
      var fullSx = ix * clean;
      var fullSy = iy * clean + 1;
      var fullSw = clean;
      var fullSh = clean - 1;

      // compute the half's atlas subrect + destination size + centroid offset
      // (offset = where this half's centroid sits relative to the full tile
      // center, in pixels at destination scale)
      var halfOffX = 0.0;
      var halfOffY = 0.0;
      if (axis == 0)
        {
          // vertical cut
          if (half == 0)
            {
              srcSubX = fullSx;
              srcSubW = fullSw * splitFrac;
              dstW = tile * splitFrac;
              halfOffX = - tile * (1 - splitFrac) / 2;
            }
          else
            {
              srcSubX = fullSx + fullSw * splitFrac;
              srcSubW = fullSw * (1 - splitFrac);
              dstW = tile * (1 - splitFrac);
              halfOffX = tile * splitFrac / 2;
            }
          srcSubY = fullSy;
          srcSubH = fullSh;
          dstH = tile;
        }
      else
        {
          // horizontal cut
          if (half == 0)
            {
              srcSubY = fullSy;
              srcSubH = fullSh * splitFrac;
              dstH = tile * splitFrac;
              halfOffY = - tile * (1 - splitFrac) / 2;
            }
          else
            {
              srcSubY = fullSy + fullSh * splitFrac;
              srcSubH = fullSh * (1 - splitFrac);
              dstH = tile * (1 - splitFrac);
              halfOffY = tile * splitFrac / 2;
            }
          srcSubX = fullSx;
          srcSubW = fullSw;
          dstW = tile;
        }

      // full-tile centroid in camera-local pixel space
      var fullCx = (target.x - s.cameraTileX1) * tile + tile / 2;
      var fullCy = (target.y - s.cameraTileY1) * tile + tile / 2;
      srcX = fullCx + halfOffX;
      srcY = fullCy + halfOffY;

      // destination: ~1.5 tiles outward in the half's outward direction,
      // with a small random angular jitter so paired halves don't fly along
      // a perfectly mirrored line
      var dirAngle = 0.0;
      if (axis == 0)
        dirAngle = (half == 0 ? Math.PI : 0) + (Math.random() - 0.5) * 0.7;
      else
        dirAngle = (half == 0 ? - Math.PI / 2 : Math.PI / 2) +
          (Math.random() - 0.5) * 0.7;
      var dist = tile * (1.2 + Math.random() * 0.8);
      dstX = fullCx + Math.cos(dirAngle) * dist;
      dstY = fullCy + Math.sin(dirAngle) * dist;

      // 1–3 turns of rotation, randomized direction
      endAngle = (Math.random() < 0.5 ? -1 : 1) *
        (Math.PI + Math.random() * Math.PI * 2);

      // 900ms total: ~270ms fly + ~315ms hold + ~315ms fade
      time = 900;
      s.area.addParticle(this);
    }

// engine-driven draw, dt ∈ [0..1] across the 900ms lifetime.
// phases: 0..0.30 fly + rotate (ease-out), 0.30..0.65 hold, 0.65..1 fade
  public override function draw(ctx: Dynamic, dt: Float)
    {
      if (img == null ||
          !img.complete ||
          img.naturalWidth <= 0)
        return;

      var flyEnd = 0.30;
      var holdEnd = 0.65;
      var curX: Float;
      var curY: Float;
      var curAngle: Float;
      var curAlpha: Float;
      if (dt < flyEnd)
        {
          var f = dt / flyEnd;
          // quadratic ease-out
          var k = 1 - (1 - f) * (1 - f);
          curX = srcX + (dstX - srcX) * k;
          curY = srcY + (dstY - srcY) * k;
          curAngle = endAngle * k;
          curAlpha = 1.0;
        }
      else if (dt < holdEnd)
        {
          curX = dstX;
          curY = dstY;
          curAngle = endAngle;
          curAlpha = 1.0;
        }
      else
        {
          curX = dstX;
          curY = dstY;
          curAngle = endAngle;
          curAlpha = 1 - (dt - holdEnd) / (1 - holdEnd);
        }

      ctx.save();
      ctx.globalAlpha = curAlpha;
      ctx.translate(curX, curY);
      ctx.rotate(curAngle);
      ctx.drawImage(img,
        srcSubX, srcSubY, srcSubW, srcSubH,
        - dstW / 2, - dstH / 2, dstW, dstH);
      ctx.restore();
    }
}
