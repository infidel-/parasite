package render.decals;

import three.Three;
import citygen.CityConfig;
import render.RenderConfig;
import render.particles.Sprites;
import render.world.WorldCtx;

// SPLAT blood decals: flat ground splats + wall blood on a struck face, plus the acid/slime emissive
// glow and the black-blood iridescent shimmer film + rare star glints. owns the shimmer/glint math
// and the hard star-slot concurrency cap. driven by the coordinator's grid scan via draw()
class Blood {
  var d:Decals;                                          // coordinator back-ref (batch, sprites, radiusOp, clock, frameNo)
  var starOn:Map<Int,Int> = new Map();                    // active star slots: splat hash -> last frame drawn
  var starDenied:Map<Int,Int> = new Map();                // splat hash -> glint bucket refused a slot (stays dark)

  public function new(d:Decals)
    {
      this.d = d;
    }

// free star slots whose splat vanished (not drawn last frame - removed decal, faded out). called
// once per frame by the coordinator before the grid scan
  public function beginFrame():Void
    {
      for (h in starOn.keys())
        if (starOn.get(h) < d.frameNo - 1)
          starOn.remove(h);
    }

// paint one SPLAT decoration; returns true if a quad was drawn. ground blood lays flat; a drop that
// flew into a wall stands upright on the struck face. both radius-fade around the player
  public function draw(dec:tiles.Decoration, x:Int, y:Int, t:Float):Bool
    {
      if (dec.icon == null)
        return false;
      var dx = (dec.dx != null ? dec.dx : 0) / t;
      var dy = (dec.dy != null ? dec.dy : 0) / t;
      var w = CityConfig.cellToWorld(x + dx, y + dy);
      var op = d.radiusOp(w.x, w.z);
      if (op <= 0.001)
        return false;
      var tex = d.sprites.tex('entities', dec.icon.col, dec.icon.row, false, RenderConfig.DECAL.bloodMul);
      if (tex == null)
        return false;
      var sc = (dec.scale != null ? dec.scale : 1.0);
      // wall blood: a drop that flew into a wall stands its splat upright on the struck face (like a
      // bullet hole), nudged proud of the face; same wet sheen as the ground splats
      if (dec.face != null)
        {
          var fdir:Int = dec.face;
          var dv = render.world.Geom.DIRV[fdir];
          var wy = (dec.height != null ? dec.height : WorldCtx.floorY(x, y) + Sprites.SIZE * 0.4);
          d.sprites.paintWall({
            x: w.x + dv[0] * 0.12,
            y: wy,
            z: w.z + dv[1] * 0.12,
            tex: tex,
            op: op,
            scale: sc,
            faceRotY: render.world.Geom.faceRotY(fdir),
            roll: (dec.angle != null ? dec.angle : 0.0),
            rough: RenderConfig.BLOOD.wetRough,
            metal: RenderConfig.BLOOD.wetMetal,
          });
          return true;
        }
      // acid/slime goop glows faintly: emissive through the splat's own sprite (alpha-shaped),
      // bright enough for the hottest pixels to catch the bloom pass. keyed by the atlas row.
      // black blood instead shimmers: iridescent hue film + rare star glints (otherworldly)
      var em = 0;
      var emInt = 0.0;
      if (dec.icon.row == Const.ROW_SPACESHIP1)
        {
          em = RenderConfig.BLOOD.acidGlow;
          emInt = RenderConfig.BLOOD.glowInt;
        }
      else if (dec.icon.row == Const.ROW_SPACESHIP2)
        {
          em = RenderConfig.BLOOD.slimeGlow;
          emInt = RenderConfig.BLOOD.glowInt;
        }
      else if (dec.icon.row == Const.ROW_BLOOD &&
               dec.icon.col >= Const.BLACK_BLOOD_LARGE)
        {
          // iridescent film; the star glint is its own tiny point quad below (lighting the
          // whole alpha-shaped stain read as a bug)
          var hash = x * 31 + y * 17 + (dec.dx != null ? dec.dx : 0);
          em = shimmerColor(hash);
          emInt = RenderConfig.BLOOD.blackShimmerInt;
          drawStar(hash, w.x, WorldCtx.floorY(x, y), w.z, sc, op);
        }
      // wet-blood sheen: BLOOD.wetRough (< 1) makes the flat splat catch a subtle specular glint off
      // the moon/lamp/flame lights. acid/slime/black glow (emInt > 0) keeps the per-quad path
      // (per-instance emissive isn't batched); plain blood goes instanced
      if (emInt > 0.0)
        d.sprites.paint({
          x: w.x,
          y: WorldCtx.floorY(x, y) + 0.04,
          z: w.z,
          tex: tex,
          op: op,
          scale: sc,
          flat: true,
          yaw: (dec.angle != null ? dec.angle : 0.0),
          order: Sprites.ORD_DECAL,
          emissive: em,
          emissiveInt: emInt,
          rough: RenderConfig.BLOOD.wetRough,
          metal: RenderConfig.BLOOD.wetMetal,
        });
      else
        d.batch.add(tex, w.x, WorldCtx.floorY(x, y) + 0.04, w.z,
          Sprites.SIZE * sc, Sprites.SIZE * sc, (dec.angle != null ? dec.angle : 0.0),
          op, RenderConfig.BLOOD.wetRough, RenderConfig.BLOOD.wetMetal);
      return true;
    }

// iridescent black-blood film color: hue ping-pongs over the teal->violet->magenta arc on the
// shimmer clock (fire/acid hues avoided), phase-offset per splat so puddles cycle out of sync
  function shimmerColor(hash:Int):Int
    {
      // scrambled phase: neighbouring splats have nearly equal hashes, a raw modulo would sync them
      var ph = ((hash * 48271) & 0x7fffffff) % 97;
      var t = d.clock / RenderConfig.BLOOD.blackCycleMult + ph / 97.0;
      t -= Math.floor(t);
      var tri = t < 0.5 ? t * 2 : 2 - t * 2;
      return hsl(0.5 + 0.45 * tri, 0.85, 0.6);
    }

// current glint time-bucket for a splat (same phase math as glintEnv, for slot denial keying)
  function glintBucket(hash:Int):Int
    {
      var ph0 = ((hash * 83492791) & 0x7fffffff) % 89;
      return Std.int(Math.floor(d.clock / RenderConfig.BLOOD.blackGlintMult + ph0 / 89.0));
    }

// star-glint envelope (0..1): time is bucketed per splat (phase-offset), a hash of (splat, bucket)
// turns a fraction of buckets on, and the lit window swells + fades on a sine bell so the glint
// breathes in and out instead of snapping
  function glintEnv(hash:Int):Float
    {
      var B = RenderConfig.BLOOD;
      // scrambled phase: neighbouring splats have nearly equal hashes, a raw modulo would sync
      // their buckets and their stars would all spawn at once
      var ph0 = ((hash * 83492791) & 0x7fffffff) % 89;
      var t = d.clock / B.blackGlintMult + ph0 / 89.0;
      var bucket = Math.floor(t);
      var r = ((hash * 73856093) ^ (Std.int(bucket) * 19349663)) % 100;
      if (r < 0)
        r = -r;
      if (r >= B.blackGlintPct)
        return 0.0;
      // frac is capped at 1: the bell must complete inside its bucket, or it snaps to zero at the
      // bucket roll instead of fading out (want a longer swell -> raise blackGlintMult)
      var f = B.blackGlintFrac > 1 ? 1.0 : B.blackGlintFrac;
      var ph = (t - bucket) / f;
      if (ph >= 1)
        return 0.0;
      return Math.sin(Math.PI * ph);
    }

// point star glint: a tiny 4-ray star quad at a fixed hash-picked point inside the stain; alpha,
// scale AND emissive all ride the sine envelope, so it scales in from nothing while fading in and
// never pops (a constant emissive still bloomed hard at low alpha and read as a blink). own quad,
// so only the point lights up — never the whole alpha-shaped splat
  function drawStar(hash:Int, wx:Float, floorY:Float, wz:Float, sc:Float, op:Float):Void
    {
      var e = glintEnv(hash);
      if (e <= 0.001)
        {
          starOn.remove(hash);
          return;
        }
      // hard concurrency cap: an active star keeps its slot to the end of its bell; a new one spawns
      // only into a free slot, and a refused bucket stays refused so the star cannot pop in mid-bell
      // when a slot frees later
      if (starOn.exists(hash))
        starOn.set(hash, d.frameNo);
      else
        {
          var bucket = glintBucket(hash);
          if (starDenied.get(hash) == bucket)
            return;
          var n = 0;
          for (_ in starOn)
            n++;
          if (n >= RenderConfig.BLOOD.blackStarMax)
            {
              starDenied.set(hash, bucket);
              return;
            }
          starOn.set(hash, d.frameNo);
        }
      var tex = d.sprites.svgTex('blackstar:32', STAR_SVG, 32);
      if (tex == null)
        return;
      var r = sc * Sprites.SIZE * 0.3;
      var ox = (((hash * 40503) & 0xffff) / 0xffff - 0.5) * 2 * r;
      var oz = (((hash * 20261) & 0xffff) / 0xffff - 0.5) * 2 * r;
      d.sprites.paint({
        x: wx + ox,
        y: floorY + 0.06,
        z: wz + oz,
        tex: tex,
        op: op * e * RenderConfig.BLOOD.blackStarAlpha,
        scale: RenderConfig.BLOOD.blackStarScale * e,
        flat: true,
        order: Sprites.ORD_DECAL + 1,
        emissive: 0xeeddff,
        emissiveInt: RenderConfig.BLOOD.blackGlintInt * e,
      });
    }

  // white (tintable) 4-ray star shape for the point glint
  static inline var STAR_SVG = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><path d="M50 5 L58 42 L95 50 L58 58 L50 95 L42 58 L5 50 L42 42 Z" fill="#fff"/></svg>';

// hsl (all 0..1) -> 0xRRGGBB
  static function hsl(h:Float, s:Float, l:Float):Int
    {
      var q = l < 0.5 ? l * (1 + s) : l + s - l * s;
      var p = 2 * l - q;
      inline function chan(t:Float):Int
        {
          t -= Math.floor(t);
          var v = p;
          if (t < 1 / 6)
            v = p + (q - p) * 6 * t;
          else if (t < 0.5)
            v = q;
          else if (t < 2 / 3)
            v = p + (q - p) * (2 / 3 - t) * 6;
          return Std.int(v * 255);
        }
      return (chan(h + 1 / 3) << 16) | (chan(h) << 8) | chan(h - 1 / 3);
    }
}
