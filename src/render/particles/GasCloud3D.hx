package render.particles;

import js.Browser;
import three.Three;
import citygen.CityConfig;
import render.RenderConfig;

// one puff of the gas cloud: a lit alpha sprite that drifts up + outward, expands and spins slowly
typedef GasPuff = {
  mesh:Mesh,
  mat:Dynamic,
  x:Float, y:Float, z:Float,     // world position (integrated each tick)
  vx:Float, vy:Float, vz:Float,  // drift velocity (cells/sec * CELL)
  base:Float,                    // base world size (growth multiplies it)
  spin:Float,                    // in-plane roll speed (rad/sec)
  rot:Float,                     // current in-plane roll
  delay:Float,                   // ms before this puff appears (staggers the billow-in)
};

// lingering organ gas cloud: a cluster of soft, LIT, alpha-blended puff sprites over the emission
// cell. lit MeshStandardMaterial (like actor sprites) so the gas CATCHES the scene lights — the warm
// lamp spotlights, the moon, ambient — instead of self-glowing; alpha blend so it occludes + tints
// the ground behind it. a baked spherical normal map makes each puff self-shade like a round ball of
// smoke under the lamp. the cluster spawns fast (activation burst), drifts up + spreads low and wide
// (heavier-than-air creep, legible edge-on), then fades over its life. tint per kind (panic reddish /
// paralysis dodger-blue). cosmetic only — entering it re-applies nothing
class GasCloud3D extends Particle3D {
  static var quadGeo:PlaneGeometry = null;              // shared unit quad (scaled per puff)
  static var puffTex:Texture = null;                    // shared soft lumpy blob alpha
  static var puffNormal:Texture = null;                 // shared spherical normal (round shading)
  static var warmMats:Array<Dynamic> = null;            // pre-warm materials, kept alive so their compiled shader programs stay in three's (refcounted, cacheKey-shared) cache for every later burst
  var group:Group;
  var puffs:Array<GasPuff> = [];
  var durationMs:Float;
  var life:Float = 0;
  var walkable:(Float, Float) -> Bool;   // world (x,z) -> tile passable; keeps gas out of walls

  public function new(group:Group, cx:Float, cy:Float, cz:Float, color:Int, range:Int,
      durationMs:Float, ?atlasTex:Texture, ?walkable:(Float, Float) -> Bool)
    {
      super();
      var G = RenderConfig.GAS;
      this.group = group;
      this.durationMs = durationMs;
      this.walkable = walkable;
      ensureAssets();
      var baseR = range * CityConfig.CELL;
      var burstMs = G.burstMult * RenderConfig.BASE_MS;
      // puff count scales with footprint area (range²) so density stays constant across cloud sizes
      var count = Std.int(Math.min(G.puffCap,
        Math.max(G.puffMin, G.puffDensity * range * range)));
      // scatter the puffs across a low, wide disc over the footprint; each gets an outward + rising
      // drift and a staggered appear time so the cloud billows in rather than popping whole
      for (_ in 0...count)
        {
          var ang = Math.random() * Math.PI * 2;
          var rad = Math.random() * baseR * G.spread; // linear radius = denser toward the centre
          var ox = Math.cos(ang) * rad;
          var oz = Math.sin(ang) * rad;
          // tile containment: if the puff lands on a wall/building tile, pull it back toward the
          // emission cell (always walkable) so the cloud fills the open floor, not the walls
          var tries = 0;
          while (walkable != null
              && !walkable(cx + ox, cz + oz)
              && tries < 6)
            {
              rad *= 0.6;
              ox = Math.cos(ang) * rad;
              oz = Math.sin(ang) * rad;
              tries++;
            }
          var oy = Math.random() * baseR * 0.15;                 // hug the ground
          var out = G.drift * CityConfig.CELL;
          // some puffs use the game's own 2D gas sprite (blends the art in, kept pixel-crisp); the
          // rest are the baked soft blob rounded by the normal map + carrying the gas tint
          var useAtlas = (atlasTex != null && Math.random() < G.atlasFrac);
          var mat = new MeshStandardMaterial({
            transparent: true,
            depthWrite: false,
            side: THREE.DoubleSide,
            roughness: 1,
            metalness: 0,
            map: (useAtlas ? atlasTex : puffTex),
            opacity: 0.0,
          });
          if (useAtlas)
            // atlas art keeps its own per-kind colours (white base, just lit)
            untyped mat.color.setHex(0xffffff);
          else
            {
              untyped mat.normalMap = puffNormal;
              untyped mat.normalScale.set(G.normalScale, G.normalScale);
              untyped mat.color.setHex(color);
            }
          var mesh = new Mesh(quadGeo, mat);
          // actor render tier: the pool is all depthWrite:false, so order (not Y/depth) decides who
          // draws over whom. default 0 = ground-decal tier -> drew UNDER every actor. ORD_ACTOR lets
          // the puffs interleave with actors by distance so the cloud envelops them
          mesh.renderOrder = Sprites.ORD_ACTOR;
          mesh.position.set(cx + ox, cy + oy, cz + oz);
          group.add(mesh);
          puffs.push({
            mesh: mesh,
            mat: mat,
            x: cx + ox,
            y: cy + oy,
            z: cz + oz,
            vx: Math.cos(ang) * out * (0.5 + Math.random()),
            vy: G.rise * CityConfig.CELL * (0.6 + 0.5 * Math.random()),
            vz: Math.sin(ang) * out * (0.5 + Math.random()),
            base: Sprites.SIZE * (G.puffScaleMin + Math.random() * (G.puffScaleMax - G.puffScaleMin)),
            // atlas puffs all roll one consistent (negative) direction with magnitude variety; baked
            // blobs keep random +/- swirl
            spin: (useAtlas
              ? -(0.4 + Math.random() * 0.6) * G.atlasSpin
              : (Math.random() - 0.5) * G.spin),
            rot: Math.random() * Math.PI * 2,
            delay: Math.random() * burstMs,
          });
        }
    }

// advance the cloud: each puff drifts + expands + spins + ramps in over the burst window; the whole
// cloud holds then fades over the trailing fraction of life. dies at end of life
  override public function tick(dtMs:Float):Bool
    {
      var G = RenderConfig.GAS;
      // whole-cloud playback speed (faster burst + drift + fade)
      life += dtMs * G.speed;
      if (life >= durationMs)
        return false;
      var dt = dtMs / 1000 * G.speed;
      var t = life / durationMs;
      var appearMs = G.burstMult * RenderConfig.BASE_MS;
      var fadeStart = 1.0 - G.fadeFrac;
      var fade = (t < fadeStart ? 1.0 : 1.0 - (t - fadeStart) / G.fadeFrac);
      var master = G.alpha * fade;
      for (p in puffs)
        {
          var age = life - p.delay;
          if (age <= 0)
            {
              p.mat.opacity = 0;
              continue;
            }
          // integrate drift (raw-dt, like the flame embers), slow spin, expand. horizontal creep
          // stops at a wall tile (gas pools against the building) — vertical rise keeps going
          var nx = p.x + p.vx * dt;
          var nz = p.z + p.vz * dt;
          if (walkable == null || walkable(nx, nz))
            {
              p.x = nx;
              p.z = nz;
            }
          else
            {
              p.vx = 0;
              p.vz = 0;
            }
          p.y += p.vy * dt;
          p.rot += p.spin * dt;
          var sc = p.base * (G.startScale + G.growth * (age / durationMs));
          p.mesh.position.set(p.x, p.y, p.z);
          p.mesh.scale.set(sc, sc, sc);
          // frontal, fixed-yaw, leaned back toward the overhead camera like actor sprites; the roll
          // rides the z slot (world-anchored FX must not be a camera billboard)
          p.mesh.rotation.set(-Sprites.TILT, 0, p.rot);
          var appear = Math.min(1.0, age / appearMs);
          p.mat.opacity = master * appear;
        }
      return true;
    }

// drop every puff mesh + dispose its material (shared geometry + textures are kept)
  override public function onDeath():Void
    {
      for (p in puffs)
        {
          group.remove(p.mesh);
          untyped p.mat.dispose();
        }
      puffs = [];
    }

// pre-warm: build the shared assets and return throwaway puff meshes covering every program the first
// gas burst would otherwise compile mid-game (a visible frame hitch). the real puff material is
// transparent + DoubleSide, which three renders as TWO single-side passes (a front and a flipSided
// back), each its own program — so warm FOUR meshes: {baked-blob w/ normalMap, atlas-art w/o normalMap}
// x {FrontSide, BackSide}. giving explicit per-side materials lets compileAsync compile all four from
// their params alone (no in-frustum render needed). the caller adds these before compileAsync, renders
// once, then removes the MESHES (no per-frame draw cost) — but the MATERIALS are retained in warmMats
// and never disposed, so their programs stay in three's refcounted, cacheKey-shared cache and every
// later real puff (a different material instance, same key) reuses them instead of recompiling. (keys
// depend on FEATURE presence, not texture identity, so puffTex stands in for the not-yet-decoded atlas)
  public static function warmupMeshes():Array<Mesh>
    {
      ensureAssets();
      // idempotent: the program cache is per GL context, so one warm covers every later city build
      if (warmMats != null)
        return [];
      var G = RenderConfig.GAS;
      warmMats = [];
      var out = [];
      for (side in [THREE.FrontSide, THREE.BackSide])
        {
          // baked-blob variant: map + normalMap
          var blob = new MeshStandardMaterial({
            transparent: true,
            depthWrite: false,
            side: side,
            roughness: 1,
            metalness: 0,
            map: puffTex,
            opacity: 0.0,
          });
          untyped blob.normalMap = puffNormal;
          untyped blob.normalScale.set(G.normalScale, G.normalScale);
          warmMats.push(blob);
          out.push(new Mesh(quadGeo, blob));
          // atlas-art variant: map only, no normalMap
          var atlas = new MeshStandardMaterial({
            transparent: true,
            depthWrite: false,
            side: side,
            roughness: 1,
            metalness: 0,
            map: puffTex,
            opacity: 0.0,
          });
          warmMats.push(atlas);
          out.push(new Mesh(quadGeo, atlas));
        }
      return out;
    }

// build the shared quad + baked textures once (first cloud). puff alpha = a lumpy metaball blob
// (main lobe + a few offset lobes) so the silhouette is irregular, not a clean circle; normal map =
// a hemisphere so lighting rounds each flat quad into a ball of smoke
  static function ensureAssets():Void
    {
      if (quadGeo != null)
        return;
      quadGeo = new PlaneGeometry(1, 1);
      puffTex = makePuffTex();
      puffNormal = makePuffNormal();
    }

// soft lumpy blob alpha (white on transparent): one main radial lobe + a few smaller offset lobes.
// baked at low res + NearestFilter so it renders as chunky pixels, matching the game's pixel art
  static function makePuffTex():Texture
    {
      var s = RenderConfig.GAS.pixelSize;
      var cv:Dynamic = Browser.document.createElement('canvas');
      cv.width = s;
      cv.height = s;
      var g:Dynamic = cv.getContext('2d');
      // several overlapping soft radial lobes -> irregular fluffy edge
      var lobes = [
        { cx: 0.5, cy: 0.5, r: 0.42 },
        { cx: 0.38, cy: 0.44, r: 0.26 },
        { cx: 0.62, cy: 0.46, r: 0.28 },
        { cx: 0.5, cy: 0.62, r: 0.24 },
        { cx: 0.46, cy: 0.36, r: 0.22 },
      ];
      for (l in lobes)
        {
          var grd:Dynamic = g.createRadialGradient(
            l.cx * s, l.cy * s, 0,
            l.cx * s, l.cy * s, l.r * s);
          grd.addColorStop(0, 'rgba(255,255,255,0.85)');
          grd.addColorStop(0.5, 'rgba(255,255,255,0.35)');
          grd.addColorStop(1, 'rgba(255,255,255,0)');
          g.fillStyle = grd;
          g.fillRect(0, 0, s, s);
        }
      var t = new CanvasTexture(cv);
      t.colorSpace = THREE.SRGBColorSpace;
      // chunky pixels: nearest sampling, no mip smoothing
      untyped t.magFilter = THREE.NearestFilter;
      untyped t.minFilter = THREE.NearestFilter;
      untyped t.generateMipmaps = false;
      return t;
    }

// spherical normal map (tangent-space): center points at the viewer, edges tilt outward, so a lit
// flat quad shades like a rounded puff. data texture -> linear color space
  static function makePuffNormal():Texture
    {
      var s = 64;
      var cv:Dynamic = Browser.document.createElement('canvas');
      cv.width = s;
      cv.height = s;
      var g:Dynamic = cv.getContext('2d');
      var img:Dynamic = g.createImageData(s, s);
      var d = img.data;
      for (yy in 0...s)
        for (xx in 0...s)
          {
            var nx = (xx + 0.5) / s * 2 - 1;
            var ny = (yy + 0.5) / s * 2 - 1;
            var r2 = nx * nx + ny * ny;
            var vnx = 0.0;
            var vny = 0.0;
            var vnz = 1.0;
            if (r2 < 1)
              {
                vnx = nx;
                vny = -ny; // canvas y is down; flip so the bump lights correctly
                vnz = Math.sqrt(1 - r2);
              }
            var o = (yy * s + xx) * 4;
            d[o] = Std.int((vnx * 0.5 + 0.5) * 255);
            d[o + 1] = Std.int((vny * 0.5 + 0.5) * 255);
            d[o + 2] = Std.int((vnz * 0.5 + 0.5) * 255);
            d[o + 3] = 255;
          }
      g.putImageData(img, 0, 0);
      var t = new CanvasTexture(cv);
      return t;
    }
}
