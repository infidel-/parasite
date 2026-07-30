// mod-side particle: one half of a sliced AI sprite produced by a
// random-angle chainsaw cut. spawned in pairs sharing the same cut line and
// pivot point — each half flies outward perpendicular to the cut, rotating,
// holds briefly, then fades to transparent. atlas, source tile, and polygon
// geometry are snapshot at ctor so engine pixel positions stay stable across
// the ~900ms lifetime (matches ParticleBloodSpurt's camera-snapshot pattern).
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
  // atlas subrect for the full tile
  var srcSubX: Float;
  var srcSubY: Float;
  var srcSubW: Float;
  var srcSubH: Float;
  // destination tile draw size
  var dstSize: Float;
  // offset of full tile's top-left in centroid-local pixel space
  // (= -centroid; placing tile here aligns its centroid with rotation origin)
  var tileOffX: Float;
  var tileOffY: Float;
  // clip polygon for this half in centroid-local pixel space
  var polyLocal: Array<{ x: Float, y: Float }>;

// constructs one half. `cutAngleRad` is the cut line angle (radians).
// `cutTileX`, `cutTileY` is the point through which the cut line passes,
// in tile-local pixel space (0..tile). `half` 0 = negative side of the
// half-plane normal, 1 = positive side. `ent` is the live AIEntity ref
// grabbed before AreaGame.removeAI nulled it
  public function new(s: GameScene, target: _Point, ent: entities.AIEntity,
      cutAngleRad: Float, cutTileX: Float, cutTileY: Float, half: Int)
    {
      super(s);

      var tile = Const.TILE_SIZE;
      var clean = Const.TILE_SIZE_CLEAN;

      // icon source data — imageName/ix/iy/isMaleAtlas are all public on Entity
      // and present in the SDK extern, so no untyped access is needed
      var imageName: String = ent.imageName;
      var ix: Int = ent.ix;
      var iy: Int = ent.iy;
      var isMale: Bool = ent.isMaleAtlas;
      img = s.images.getImage(imageName, isMale);

      // full atlas rect (matches Entity.drawImage layout)
      srcSubX = ix * clean;
      srcSubY = iy * clean + 1;
      srcSubW = clean;
      srcSubH = clean - 1;
      dstSize = tile;

      // half-plane normal: perpendicular to the cut direction
      var nx = - Math.sin(cutAngleRad);
      var ny = Math.cos(cutAngleRad);
      var sideSign = (half == 0 ? -1.0 : 1.0);

      // clip the tile rect by the half-plane to get this half's polygon
      // (vertices in tile-local pixel coords, 0..tile)
      var poly = clipRectHalfPlane(tile,
        cutTileX, cutTileY, nx, ny, sideSign);

      // centroid of the polygon — used as rotation pivot and fly origin
      var c = polyCentroid(poly);

      // store polygon in centroid-local space so clip path is ready to use
      // directly after the rotate transform at draw time
      polyLocal = [];
      for (p in poly)
        polyLocal.push({ x: p.x - c.x, y: p.y - c.y });
      tileOffX = - c.x;
      tileOffY = - c.y;

      // tile top-left in camera-local pixel space, plus centroid offset
      var tileTLx = (target.x - s.cameraTileX1) * tile;
      var tileTLy = (target.y - s.cameraTileY1) * tile;
      srcX = tileTLx + c.x;
      srcY = tileTLy + c.y;

      // fly direction: outward along the half-plane normal, with small
      // jitter so paired halves don't fly along a perfectly mirrored line
      var outAngle = Math.atan2(ny * sideSign, nx * sideSign) +
        (Math.random() - 0.5) * 0.7;
      var dist = tile * (1.2 + Math.random() * 0.8);
      dstX = srcX + Math.cos(outAngle) * dist;
      dstY = srcY + Math.sin(outAngle) * dist;

      // 1–3 turns of rotation, randomized direction
      endAngle = (Math.random() < 0.5 ? -1 : 1) *
        (Math.PI + Math.random() * Math.PI * 2);

      // 900ms total: ~270ms fly + ~315ms hold + ~315ms fade
      time = 900;
      s.area.addParticle(this);
    }

// clips the tile rect by a half-plane { p : ((p - P) · n) * sideSign >= 0 }
// returns polygon vertices (tile-local) in CCW/CW order following the rect
  static function clipRectHalfPlane(tile: Float,
      px: Float, py: Float, nx: Float, ny: Float,
      sideSign: Float): Array<{ x: Float, y: Float }>
    {
      var corners = [
        { x: 0.0, y: 0.0 },
        { x: tile, y: 0.0 },
        { x: tile, y: tile },
        { x: 0.0, y: tile },
      ];
      var out: Array<{ x: Float, y: Float }> = [];
      for (i in 0...4)
        {
          var a = corners[i];
          var b = corners[(i + 1) % 4];
          var da = ((a.x - px) * nx + (a.y - py) * ny) * sideSign;
          var db = ((b.x - px) * nx + (b.y - py) * ny) * sideSign;
          var aIn = da >= 0;
          var bIn = db >= 0;
          if (aIn)
            out.push(a);
          // edge crosses the line — emit intersection
          if (aIn != bIn)
            {
              var t = da / (da - db);
              out.push({
                x: a.x + t * (b.x - a.x),
                y: a.y + t * (b.y - a.y),
              });
            }
        }
      return out;
    }

// polygon centroid via the shoelace formula; falls back to vertex average
// for degenerate (zero-area) polygons
  static function polyCentroid(poly: Array<{ x: Float, y: Float }>):
      { x: Float, y: Float }
    {
      if (poly.length == 0)
        return { x: 0.0, y: 0.0 };
      var a = 0.0, cx = 0.0, cy = 0.0;
      for (i in 0...poly.length)
        {
          var p0 = poly[i];
          var p1 = poly[(i + 1) % poly.length];
          var cross = p0.x * p1.y - p1.x * p0.y;
          a += cross;
          cx += (p0.x + p1.x) * cross;
          cy += (p0.y + p1.y) * cross;
        }
      a *= 0.5;
      if (Math.abs(a) < 0.001)
        {
          var sx = 0.0, sy = 0.0;
          for (p in poly)
            {
              sx += p.x;
              sy += p.y;
            }
          return { x: sx / poly.length, y: sy / poly.length };
        }
      return { x: cx / (6 * a), y: cy / (6 * a) };
    }

// engine-driven draw, dt ∈ [0..1] across the 900ms lifetime.
// phases: 0..0.30 fly + rotate (ease-out), 0.30..0.65 hold, 0.65..1 fade
  public override function draw(ctx: Dynamic, dt: Float)
    {
      if (img == null ||
          !img.complete ||
          img.naturalWidth <= 0)
        return;
      if (polyLocal.length < 3)
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

      // clip subsequent draw to this half's polygon (centroid-local)
      ctx.beginPath();
      ctx.moveTo(polyLocal[0].x, polyLocal[0].y);
      for (i in 1...polyLocal.length)
        ctx.lineTo(polyLocal[i].x, polyLocal[i].y);
      ctx.closePath();
      ctx.clip();

      // draw the full atlas tile, offset so its centroid lands on origin
      ctx.drawImage(img,
        srcSubX, srcSubY, srcSubW, srcSubH,
        tileOffX, tileOffY, dstSize, dstSize);
      ctx.restore();
    }
}
