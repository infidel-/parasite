package render.world;

import three.Three;
import citygen.CityConfig;
import citygen.CityConfig.cellToWorld;
import render.RenderConfig;
import render.RenderConfig.TEXTURES;
import render.Textures;
import render.Poly.tag;

// static wall decals (graffiti, posters, cracks) baked onto BARE (worn/windowless) building
// faces at city build. deterministic per building col/row/dir hash — no Math.random, so the
// same city looks identical across reloads and nothing is saved (re-derived from the seed).
// each decal is one alpha quad set proud of the wall, tagged userData.b so Occlusion fades it
// with its building. windowed/glass faces are skipped, so a decal never lands on a facade.
class WallDecals {
  static inline var CELL = CityConfig.CELL;
  static inline var EPS = 0.07;      // proud of the wall (avoid z-fight)
  static inline var MARGIN = 1.2;    // keep decals this far off the face edges/corners

  static inline function imax(a:Float, b:Float):Float return a > b ? a : b;

  public static function add(scene:Scene):Void {
    var graffiti = [for (p in TEXTURES.graffiti) load(p)];
    var posters  = [for (p in TEXTURES.posters) load(p)];
    var cracks   = [for (p in TEXTURES.cracks) load(p)];
    // categories: textures + world size band (lo..hi) + base height off the ground
    var cats = [
      { tex: cracks,   lo: 1.2, hi: 2.4, baseY: 0.6 }, // hairline cracks, low on the wall
      { tex: graffiti, lo: 2.0, hi: 3.6, baseY: 1.0 }, // mid-wall graffiti
      { tex: posters,  lo: 1.6, hi: 2.6, baseY: 1.2 }, // pasted posters, chest/eye height
    ];

    for (b in WorldCtx.buildings) {
      if (b.shop >= 0) continue; // single-story shops read as storefronts; skip for now
      var wWorld = b.w * CELL, dWorld = b.d * CELL;
      var center = cellToWorld(b.col + (b.w - 1) / 2, b.row + (b.d - 1) / 2);
      for (f in Geom.buildingFaces(center, wWorld, dWorld, EPS)) {
        if (!Geom.isWornFace(b, f.dir)) continue; // bare walls only — never on glass/windows
        // deterministic decision hash off col/row/dir (distinct multipliers per axis)
        var hh = (((b.col * 92821) ^ (b.row * 68917) ^ (f.dir * 40503)) & 0x7fffffff);
        if (hh % 100 >= RenderConfig.WALLDECAL_PCT) continue; // most faces stay clean
        var span = f.faceW - 2 * MARGIN;
        if (span < 1.0) continue; // face too narrow to place clear of the corners
        var cat = cats[(hh >> 3) % cats.length];
        if (cat.tex.length == 0) continue;
        var texv = cat.tex[(hh >> 7) % cat.tex.length];
        // size within the band, clamped to the clear span and the wall height
        var size = cat.lo + ((hh >> 11) % 1000) / 1000.0 * (cat.hi - cat.lo);
        if (size > span) size = span;
        if (size > b.h - 0.6) size = imax(1.0, b.h - 0.6);
        // along-face offset within the leftover clear span, and a small height jitter
        var off = (((hh >> 14) % 1000) / 1000.0 - 0.5) * (span - size);
        var y = cat.baseY + size / 2 + ((hh >> 18) % 100) / 100.0 * 1.2;
        if (y + size / 2 > b.h - 0.3) y = b.h - 0.3 - size / 2;
        if (y < size / 2) y = size / 2;
        // ponytail: no per-face door-run avoidance — a worn side door is occasionally overlapped;
        // upgrade to a Geom.doorRuns overlap test if posters visibly clip doors
        var mat = tag(new MeshStandardMaterial({ map: texv, roughness: 1, metalness: 0,
          transparent: true, alphaTest: 0.35, depthWrite: false,
          polygonOffset: true, polygonOffsetFactor: -1, polygonOffsetUnits: -1 }),
          'walldecal', 'wall decal', null);
        var mesh = new Mesh(new PlaneGeometry(size, size), mat);
        mesh.rotation.y = f.rotY;
        if (f.dir < 2) mesh.position.set(f.fx + off, y, f.fz);
        else mesh.position.set(f.fx, y, f.fz + off);
        mesh.userData.b = b; // Occlusion fades the decal with its building
        scene.add(mesh);
      }
    }
  }

  static function load(path:String):Texture {
    var t = Textures.loadTexture(path, 'wall');
    t.wrapS = t.wrapT = THREE.ClampToEdgeWrapping;
    return t;
  }
}
