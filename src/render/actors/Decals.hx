package render.actors;

import three.Three;
import citygen.CityConfig;
import render.RenderConfig;
import render.particles.Sprites;
import render.world.WorldCtx;
import game.Game;

// the persisted + render-only ground/wall decal layer of the actor pass: seed-derived street
// debris, SPLAT blood ground quads, and WALLHOLE bullet holes stood on their wall face. revealed
// by a radius fade around the player's smoothed world pos (opaque near, fading to invisible at the
// edge), which replaced the old binary LOS gate. paints through the shared lit Sprites surface;
// owns only its lazy bullet-hole texture caches + the current debris scatter. driven once a frame
// by Actors.update via paint()
class Decals {
  var game:Game;
  var sprites:Sprites;                                    // lit ground/wall paint surface (shared)
  var holeTex:Array<Texture> = null;                     // masonry bullet-hole wall textures (lazy-loaded once)
  var holeTexMetal:Array<Texture> = null;                // metal-wall bullet-hole textures (lazy-loaded once)
  var debris:Array<render.world.Debris.DebrisSpot> = null; // seed-derived street debris (render-only, not persisted)
  var px:Float = 0.0;                                     // smoothed player world x for this frame's radius fade
  var pz:Float = 0.0;                                     // smoothed player world z for this frame's radius fade
  var clock:Float = 0.0;                                  // black-blood shimmer clock (BASE_MS units)
  var frameNo:Int = 0;                                    // paint-pass counter (star slot liveness stamp)
  var starOn:Map<Int,Int> = new Map();                    // active star slots: splat hash -> last frame drawn
  var starDenied:Map<Int,Int> = new Map();                // splat hash -> glint bucket refused a slot (stays dark)
  // last decal pass counts (leak/perf check), read by Actors.perfLog
  public var decalScan(default, null):Int = 0;
  public var decalDraw(default, null):Int = 0;

  public function new(game:Game, sprites:Sprites)
    {
      this.game = game;
      this.sprites = sprites;
    }

// set the seed-derived debris scatter for the current city (render-only, rebuilt per show)
  public function setDebris(list:Array<render.world.Debris.DebrisSpot>):Void
    {
      debris = list;
    }

// paint this frame's render-only debris, then the persisted tile decals (blood + bullet holes),
// in the order the actor pass expects them. px/pz is the player's smoothed world pos driving the
// radius fade that replaced the old LOS gate; dtMs advances the black-blood shimmer clock
  public function paint(px:Float, pz:Float, dtMs:Float):Void
    {
      this.px = px;
      this.pz = pz;
      clock += dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
      frameNo++;
      // free star slots whose splat vanished (not drawn last frame - removed decal, faded out)
      for (h in starOn.keys())
        if (starOn.get(h) < frameNo - 1)
          starOn.remove(h);
      drawDebris();
      drawDecals();
    }

// world-space reveal opacity: fully opaque inside the radius, linear fade to 0 across the edge band.
// replaces the old LOS gate. losEnabled off (debug reveal-all) => full opacity, radius ignored
  inline function radiusOp(wx:Float, wz:Float):Float
    {
      if (!game.player.vars.losEnabled)
        return 1.0;
      var r = RenderConfig.DECAL.radiusCells * CityConfig.CELL;
      var band = RenderConfig.DECAL.fadeCells * CityConfig.CELL;
      var dx = wx - px;
      var dz = wz - pz;
      var d = Math.sqrt(dx * dx + dz * dz);
      var op = (r - d) / band;
      return op < 0 ? 0.0 : (op > 1 ? 1.0 : op);
    }

// draw the seed-derived street debris as content-cropped flat ground quads, fog-gated per cell
// like the blood decals. render-only — these are not game-area decorations, so they never persist
  function drawDebris():Void
    {
      if (debris == null)
        return;
      for (s in debris)
        {
          var gs = sprites.texContent('entities', s.ix, s.iy, false, RenderConfig.DECAL.debrisMul);
          if (gs == null)
            continue;
          var w = CityConfig.cellToWorld(s.col + s.dx, s.row + s.dy);
          var op = radiusOp(w.x, w.z);
          if (op <= 0.001)
            continue;
          sprites.paintGround(w.x, WorldCtx.floorY(s.col, s.row) + 0.04, w.z, gs, op, s.scale, s.angle);
        }
    }

// draw persisted tile decorations: SPLAT blood as flat ground quads, WALLHOLE bullet holes as
// upright quads on their wall face. scans the tile grid (sparse + capped); non-3D floor
// decorations stay 2D-only
  function drawDecals():Void
    {
      var tiles = game.area.tiles;
      if (tiles == null)
        return;
      var t = Const.TILE_SIZE; // dx/dy are pixel offsets in +/-tile/2 (matches 2D splats)
      var scan = 0, draw = 0;
      for (x in 0...game.area.width)
        {
          if (tiles[x] == null)
            continue;
          for (y in 0...game.area.height)
            {
              scan++;
              var tile = tiles[x][y];
              if (tile == null ||
                  tile.decoration == null ||
                  tile.decoration.length == 0)
                continue;
              for (d in tile.decoration)
                if (drawDecal(d, x, y, t))
                  draw++;
            }
        }
      decalScan = scan; decalDraw = draw;
    }

// paint one tile decoration; returns true if a quad was drawn. SPLAT blood lays flat on the
// ground; WALLHOLE bullet holes stand upright on their wall face. both radius-fade around the player
  function drawDecal(d:tiles.Decoration, x:Int, y:Int, t:Float):Bool
    {
      // ground blood: radius-fade around the player, lay flat
      if (d.tag == 'SPLAT')
        {
          if (d.icon == null)
            return false;
          var dx = (d.dx != null ? d.dx : 0) / t;
          var dy = (d.dy != null ? d.dy : 0) / t;
          var w = CityConfig.cellToWorld(x + dx, y + dy);
          var op = radiusOp(w.x, w.z);
          if (op <= 0.001)
            return false;
          var tex = sprites.tex('entities', d.icon.col, d.icon.row, false, RenderConfig.DECAL.bloodMul);
          if (tex == null)
            return false;
          var sc = (d.scale != null ? d.scale : 1.0);
          // wall blood: a drop that flew into a wall stands its splat upright on the struck face
          // (like a bullet hole), nudged proud of the face; same wet sheen as the ground splats
          if (d.face != null)
            {
              var fdir:Int = d.face;
              var dv = render.world.Geom.DIRV[fdir];
              var wy = (d.height != null ? d.height : WorldCtx.floorY(x, y) + Sprites.SIZE * 0.4);
              sprites.paintWall(w.x + dv[0] * 0.12, wy, w.z + dv[1] * 0.12, tex, op, sc,
                render.world.Geom.faceRotY(fdir), (d.angle != null ? d.angle : 0.0),
                RenderConfig.BLOOD.wetRough, RenderConfig.BLOOD.wetMetal);
              return true;
            }
          // acid/slime goop glows faintly: emissive through the splat's own sprite (alpha-shaped),
          // bright enough for the hottest pixels to catch the bloom pass. keyed by the atlas row.
          // black blood instead shimmers: iridescent hue film + rare star glints (otherworldly)
          var em = 0;
          var emInt = 0.0;
          if (d.icon.row == Const.ROW_SPACESHIP1)
            {
              em = RenderConfig.BLOOD.acidGlow;
              emInt = RenderConfig.BLOOD.glowInt;
            }
          else if (d.icon.row == Const.ROW_SPACESHIP2)
            {
              em = RenderConfig.BLOOD.slimeGlow;
              emInt = RenderConfig.BLOOD.glowInt;
            }
          else if (d.icon.row == Const.ROW_BLOOD &&
                   d.icon.col >= Const.BLACK_BLOOD_LARGE)
            {
              // iridescent film; the star glint is its own tiny point quad below (lighting the
              // whole alpha-shaped stain read as a bug)
              var hash = x * 31 + y * 17 + (d.dx != null ? d.dx : 0);
              em = shimmerColor(hash);
              emInt = RenderConfig.BLOOD.blackShimmerInt;
              drawStar(hash, w.x, WorldCtx.floorY(x, y), w.z, sc, op);
            }
          // wet-blood sheen: BLOOD.wetRough (< 1) makes the flat splat catch a subtle specular
          // glint off the moon/lamp/flame lights
          sprites.paint({
            x: w.x,
            y: WorldCtx.floorY(x, y) + 0.04,
            z: w.z,
            tex: tex,
            op: op,
            scale: sc,
            flat: true,
            yaw: (d.angle != null ? d.angle : 0.0),
            order: Sprites.ORD_DECAL,
            emissive: em,
            emissiveInt: emInt,
            rough: RenderConfig.BLOOD.wetRough,
            metal: RenderConfig.BLOOD.wetMetal,
          });
          return true;
        }
      // bullet hole: stand it on its wall face, radius-fade around the player
      else if (d.tag == 'WALLHOLE' &&
               d.face != null)
        {
          var hts = holeTextures(d.metal == true);
          if (hts.length == 0)
            return false;
          var fdir:Int = d.face;
          var dv = render.world.Geom.DIRV[fdir];
          var w = CityConfig.cellToWorld(x + (d.dx != null ? d.dx : 0) / t,
            y + (d.dy != null ? d.dy : 0) / t);
          var op = radiusOp(w.x, w.z);
          if (op <= 0.001)
            return false;
          var roll = (d.angle != null ? d.angle : 0.0);
          // fold the stored roll into the variant so co-cell holes differ (reload-stable)
          var variant = ((x * 31 + y * 17 + Std.int(roll * 10)) % hts.length + hts.length) % hts.length;
          var sc = (d.scale != null ? d.scale : RenderConfig.WALLHOLE.scale);
          var wy = (d.height != null ? d.height : WorldCtx.floorY(x, y) + Sprites.SIZE * 0.4);
          // nudge proud of the wall face along the outward normal (clears the opaque
          // face so the hole isn't depth-culled; no z-fight since depthWrite is off)
          sprites.paintWall(w.x + dv[0] * 0.12, wy, w.z + dv[1] * 0.12,
            hts[variant], op, sc, render.world.Geom.faceRotY(fdir), roll);
          return true;
        }
      return false;
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

// load a set of clamp-wrapped alpha hole PNGs
  function loadHoleTex(paths:Array<String>):Array<Texture>
    {
      return [for (p in paths)
        {
          var tx = render.Textures.loadTexture(p, 'wall');
          tx.wrapS = tx.wrapT = THREE.ClampToEdgeWrapping;
          tx;
        }];
    }

// iridescent black-blood film color: hue ping-pongs over the teal->violet->magenta arc on the
// shimmer clock (fire/acid hues avoided), phase-offset per splat so puddles cycle out of sync
  function shimmerColor(hash:Int):Int
    {
      // scrambled phase: neighbouring splats have nearly equal hashes, a raw modulo would sync them
      var ph = ((hash * 48271) & 0x7fffffff) % 97;
      var t = clock / RenderConfig.BLOOD.blackCycleMult + ph / 97.0;
      t -= Math.floor(t);
      var tri = t < 0.5 ? t * 2 : 2 - t * 2;
      return hsl(0.5 + 0.45 * tri, 0.85, 0.6);
    }

// current glint time-bucket for a splat (same phase math as glintEnv, for slot denial keying)
  function glintBucket(hash:Int):Int
    {
      var ph0 = ((hash * 83492791) & 0x7fffffff) % 89;
      return Std.int(Math.floor(clock / RenderConfig.BLOOD.blackGlintMult + ph0 / 89.0));
    }

// star-glint envelope (0..1): time is bucketed per splat (phase-offset), a hash of (splat,
// bucket) turns a fraction of buckets on, and the lit window swells + fades on a sine bell so
// the glint breathes in and out instead of snapping
  function glintEnv(hash:Int):Float
    {
      var B = RenderConfig.BLOOD;
      // scrambled phase: neighbouring splats have nearly equal hashes, a raw modulo would sync
      // their buckets and their stars would all spawn at once
      var ph0 = ((hash * 83492791) & 0x7fffffff) % 89;
      var t = clock / B.blackGlintMult + ph0 / 89.0;
      var bucket = Math.floor(t);
      var r = ((hash * 73856093) ^ (Std.int(bucket) * 19349663)) % 100;
      if (r < 0)
        r = -r;
      if (r >= B.blackGlintPct)
        return 0.0;
      // frac is capped at 1: the bell must complete inside its bucket, or it snaps to zero at
      // the bucket roll instead of fading out (want a longer swell -> raise blackGlintMult)
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
      // hard concurrency cap: an active star keeps its slot to the end of its bell; a new one
      // spawns only into a free slot, and a refused bucket stays refused so the star cannot pop
      // in mid-bell when a slot frees later
      if (starOn.exists(hash))
        starOn.set(hash, frameNo);
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
          starOn.set(hash, frameNo);
        }
      var tex = sprites.svgTex('blackstar:32', STAR_SVG, 32);
      if (tex == null)
        return;
      var r = sc * Sprites.SIZE * 0.3;
      var ox = (((hash * 40503) & 0xffff) / 0xffff - 0.5) * 2 * r;
      var oz = (((hash * 20261) & 0xffff) / 0xffff - 0.5) * 2 * r;
      sprites.paint({
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
