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
// with its building. windowed/glass faces are skipped, so a decal never lands on a facade;
// decals overlapping a placed door's along-face span are skipped too (WorldCtx.doorSpans).
class WallDecals {
  static inline var CELL = CityConfig.CELL;
  static inline var EPS = 0.07;      // proud of the wall (avoid z-fight)
  static inline var MARGIN = 1.2;    // keep decals this far off the face edges/corners
  static inline var RES = 256;       // decal source edge (textures.json res) — the editor's wheel step is 1/res

  static inline function imax(a:Float, b:Float):Float return a > b ? a : b;

  public static function add(scene:Scene):Void {
    // ONE shared material per decal IMAGE, built on first use — not one per quad. Same art on every
    // wall that rolls it, and a material per image is also what gives each decal its own Poly class:
    // under a single shared 'walldecal' class the editor's wheel shifted every graffiti, poster and
    // crack in the city at once, and Poly.info could hold no texture path for the class at all
    var mats = new Map<String, MeshStandardMaterial>();
    function matFor(path:String, tint:Int):MeshStandardMaterial
      {
        var m = mats.get(path);
        if (m != null)
          return m;
        var t = Textures.loadTexture(path, 'wall');
        t.wrapS = t.wrapT = THREE.ClampToEdgeWrapping; // one image per decal, never tiled
        var lbl = label(path);
        m = cast tag(new MeshStandardMaterial({ map: t, color: tint, roughness: 1, metalness: 0,
          transparent: true, alphaTest: 0.35, depthWrite: false,
          polygonOffset: true, polygonOffsetFactor: -1, polygonOffsetUnits: -1 }),
          'walldecal-$lbl', '$lbl decal', path, RES);
        mats.set(path, m);
        return m;
      }
    // categories: image paths + world size band (lo..hi) + base height off the ground + albedo tint.
    // cracks are dark marks already sitting in the wall's value range, so they alone stay untinted
    var cats = [
      { tex: TEXTURES.cracks,   lo: 1.2, hi: 2.4, baseY: 0.6, tint: 0xffffff },                 // hairline cracks, low on the wall
      { tex: TEXTURES.graffiti, lo: 2.0, hi: 3.6, baseY: 1.0, tint: RenderConfig.WALLDECAL_TINT }, // mid-wall graffiti
      { tex: TEXTURES.posters,  lo: 1.6, hi: 2.6, baseY: 1.2, tint: RenderConfig.WALLDECAL_TINT }, // pasted posters, chest/eye height
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
        var path = cat.tex[(hh >> 7) % cat.tex.length];
        // size within the band, clamped to the clear span and the wall height
        var size = cat.lo + ((hh >> 11) % 1000) / 1000.0 * (cat.hi - cat.lo);
        if (size > span) size = span;
        if (size > b.h - 0.6) size = imax(1.0, b.h - 0.6);
        // along-face offset within the leftover clear span, and a small height jitter
        var off = (((hh >> 14) % 1000) / 1000.0 - 0.5) * (span - size);
        var y = cat.baseY + size / 2 + ((hh >> 18) % 100) / 100.0 * 1.2;
        if (y + size / 2 > b.h - 0.3) y = b.h - 0.3 - size / 2;
        if (y < size / 2) y = size / 2;
        // skip a decal that would clip a door on this same face (Entrances published the door's
        // along-face span; same center + off convention, so compare intervals directly)
        var dLo = off - size / 2, dHi = off + size / 2;
        var onDoor = false;
        for (ds in WorldCtx.doorSpans)
          if (ds.b == b &&
              ds.dir == f.dir &&
              dLo < ds.hi &&
              dHi > ds.lo)
            {
              onDoor = true;
              break;
            }
        if (onDoor) continue;
        var mesh = new Mesh(new PlaneGeometry(size, size), matFor(path, cat.tint));
        mesh.rotation.y = f.rotY;
        if (f.dir < 2) mesh.position.set(f.fx + off, y, f.fz);
        else mesh.position.set(f.fx, y, f.fz + off);
        // darken with the wall under it when a neighbour or a lamp shadows that face — same reason
        // Windows.add sets it on the pane quads. thin plane, nothing to cast
        mesh.receiveShadow = true;
        mesh.userData.b = b; // Occlusion fades the decal with its building
        scene.add(mesh);
      }
    }
  }

// Poly class label for a decal image: the file stem ('textures/decals/poster-2.png' -> 'poster-2')
  static function label(path:String):String
    {
      return path.split('/').pop().split('.')[0];
    }
}
