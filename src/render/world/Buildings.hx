package render.world;

import three.Three;
import citygen.CityConfig;
import citygen.CityConfig.cellToWorld;
import render.RenderConfig;
import render.RenderConfig.TEXTURES;
import render.Textures;
import render.Poly.tag;

// per-building box construction: the wall/roof box, storefront overlay, metal-warehouse
// door, near-ground grime band, and (Buildings.addGround) the ground-floor storefront
// band. Parapets and gable roofs are delegated to Roofs; face/worn/front classification
// to Geom. Sets window.__grime for live grime-opacity tuning.
class Buildings {
  static inline var CELL = CityConfig.CELL;
  static inline var GROUND_H = CityConfig.GROUND_H;
  // how far a flush wall overlay stands proud of its wall. Entrances tuned 0.06 → visible gap and
  // 0.01 → flush; this sits between: enough depth margin to survive a pass that drops polygonOffset
  static inline var OVERLAY_EPS = 0.02;

  static inline function imax(a:Float, b:Float):Float return a > b ? a : b;

  public static function build(scene:Scene):Void {
    var buildings = WorldCtx.buildings;

    var roofBases = [for (p in TEXTURES.roofBases) Textures.loadTexture(p, 'roof')];
    var wallTex = [for (p in TEXTURES.walls) Textures.loadTexture(p, 'wall')];
    var wornTex = [for (p in TEXTURES.wornWalls) Textures.loadTexture(p, 'wall')];
    var metalWallTex = [for (p in TEXTURES.metalWalls) Textures.loadTexture(p, 'wall')]; // per-building metal variants
    var metalWornTex = [for (p in TEXTURES.metalWorn) Textures.loadTexture(p, 'wall')];
    var copingTex = Textures.loadCroppedTexture(TEXTURES.coping, 1, 0.42);
    var shopWornTex = Textures.loadTexture(TEXTURES.shopWorn, 'wall');           // shop box wall
    var shopCopingTex = Textures.loadCroppedTexture(TEXTURES.shopCoping, 1, 0.42); // shop parapet cap
    // storefront images by type [diner,corner,garage,laundromat]; door + door-less, lit/unlit
    var shopFrontLit   = [for (p in TEXTURES.shopFrontLit) Textures.loadTexture(p, 'wall')];
    var shopFront      = [for (p in TEXTURES.shopFront) Textures.loadTexture(p, 'wall')];
    var shopFrontNdLit = [for (p in TEXTURES.shopFrontNdLit) Textures.loadTexture(p, 'wall')];
    var shopFrontNd    = [for (p in TEXTURES.shopFrontNd) Textures.loadTexture(p, 'wall')];
    var grimeTex = [for (p in TEXTURES.grime) Textures.loadTexture(p, 'wall')]; // near-ground street grime (alpha hand-painted into the source)
    // premultiplied alpha: the hand-painted grime sources carry saturated junk RGB under
    // near-transparent texels (paint-editor leftover); with straight alpha, bilinear/minified
    // filtering bleeds that colour in as vivid cyan/magenta specks on dark walls at distance.
    // premultiply zeroes a transparent texel's colour contribution, killing the bleed.
    for (g in grimeTex) { untyped g.premultiplyAlpha = true; g.wrapT = THREE.ClampToEdgeWrapping; g.needsUpdate = true; }
    // ONE shared material per grime variant (no per-face texture clone). Horizontal tiling is
    // baked into each quad's UVs instead of texture.repeat.
    var grimeMat = [for (gv in 0...grimeTex.length)
      tag(new MeshStandardMaterial({ map: grimeTex[gv], roughness: 1, metalness: 0, transparent: true, premultipliedAlpha: true, depthWrite: false,
        opacity: RenderConfig.GRIME_OPACITY,
        polygonOffset: true, polygonOffsetFactor: -1, polygonOffsetUnits: -1 }),
        'grime-${gv + 1}', 'street grime', TEXTURES.grime[gv])];
    untyped js.Browser.window.__grime = grimeMat; // tuning: __grime.forEach(m=>m.opacity=0.5) to set strength live. keep.
    var doorTex = Textures.loadTexture(TEXTURES.doorMetal, 'wall'); // closed warehouse door (metal facade)
    doorTex.wrapS = doorTex.wrapT = THREE.ClampToEdgeWrapping;       // single image per door, no tiling
    var roofMetalTex = Textures.loadTexture(TEXTURES.roofMetal, 'wall'); // gable-roof slopes (metal warehouse)

    // every building box baked into ONE position-only caster (built after the loop) — see the note
    // at the box below for why the boxes themselves stop casting
    var shadowPos:Array<Float> = [];
    var shadowIdx:Array<Int> = [];

    for (bi in 0...buildings.length) {
      var b = buildings[bi];
      var wWorld = b.w * CELL;
      var dWorld = b.d * CELL;
      var center = cellToWorld(b.col + (b.w - 1) / 2, b.row + (b.d - 1) / 2);

      var roof = roofBases[b.facade % roofBases.length].clone();
      roof.needsUpdate = true;
      // world-aligned roof tiling: a global ROOF_TILE grid with world-position phase,
      // so abutting same-height strips of a T/L building share one continuous grid
      // instead of each tiling from its own corner at its own rounded tile size
      roof.wrapS = roof.wrapT = THREE.RepeatWrapping;
      roof.repeat.set(wWorld / RenderConfig.ROOF_TILE, dWorld / RenderConfig.ROOF_TILE);
      roof.offset.set((center.x - wWorld / 2) / RenderConfig.ROOF_TILE, -(center.z + dWorld / 2) / RenderConfig.ROOF_TILE);

      var wallH = imax(1, Math.round(b.h / RenderConfig.WALL_TILE));
      var clean = wallTex[b.facade % wallTex.length];
      var worn = wornTex[b.facade % wornTex.length];
      var cleanPath = TEXTURES.walls[b.facade % TEXTURES.walls.length];
      var wornPath = TEXTURES.wornWalls[b.facade % TEXTURES.wornWalls.length];
      if (b.facade == 3) { // metal warehouse: pick a corrugated-steel variant per-building (deterministic by footprint)
        var mv = ((b.col * 31 + b.row * 17) % metalWallTex.length + metalWallTex.length) % metalWallTex.length;
        clean = metalWallTex[mv]; worn = metalWornTex[mv];
        cleanPath = TEXTURES.metalWalls[mv]; wornPath = TEXTURES.metalWorn[mv];
      }
      var masonry = b.facade == 1 || b.facade == 2; // brick + stone: wall-continuation parapet (concrete + metal get thin rim)
      var k = RenderConfig.FACADE_NAMES[b.facade];
      function faceMat(dir:Int, faceLen:Float):MeshStandardMaterial {
        var isWorn = Geom.isWornFace(b, dir);
        var base = isWorn ? worn : clean;
        var t = base.clone(); t.needsUpdate = true;
        t.repeat.set(imax(1, Math.round(faceLen / RenderConfig.WALL_TILE)), wallH);
        var mat = new MeshStandardMaterial({ map: t, roughness: 1, metalness: 0 });
        return tag(mat, 'wall-$k' + (isWorn ? '-worn' : ''), '$k wall' + (isWorn ? ' (worn)' : ''),
          isWorn ? wornPath : cleanPath);
      }
      // single-story shop: TEST PASS — box is plain worn wall on every face; a single
      // aspect-fitted 16:9 storefront image is overlaid on each street face below.
      // (per-cell nd tiling + per-cell door overlay are dormant for this test)
      var shop = b.shop >= 0;
      function shopFace(dir:Int, faceLen:Float):MeshStandardMaterial {
        var t = shopWornTex.clone(); t.needsUpdate = true;
        t.repeat.set(imax(1, Math.round(faceLen / RenderConfig.WALL_TILE)), wallH);
        return tag(new MeshStandardMaterial({ map: t, roughness: 1, metalness: 0 }),
          'shop-worn', 'shop wall (worn)', TEXTURES.shopWorn);
      }
      var px = shop ? shopFace(2, dWorld) : faceMat(2, dWorld), nx = shop ? shopFace(3, dWorld) : faceMat(3, dWorld);
      var pz = shop ? shopFace(0, wWorld) : faceMat(0, wWorld), nz = shop ? shopFace(1, wWorld) : faceMat(1, wWorld);
      var top = tag(new MeshStandardMaterial({ map: roof, roughness: 1, metalness: 0 }),
        'roof-$k', '$k roof', TEXTURES.roofBases[b.facade % TEXTURES.roofBases.length]);
      // collapse the 6-material box to one draw call per distinct image (walls clean/worn + roof
      // -> ~3, from 6) by baking each face's UV transform; walls stay pixel-identical
      var boxGeo = new BoxGeometry(wWorld, b.h, dWorld);
      var boxMats:Array<Dynamic> = [px, nx, top, px, pz, nz];
      var box = new Mesh(boxGeo, render.Poly.flattenBox(boxGeo, boxMats, 'wall-$k', '$k wall', cleanPath));
      box.position.set(center.x, b.h / 2, center.z);
      box.userData.b = b; box.userData.bidx = bi; // Inspector: alt+click → record
      // the building volume is the real shadow caster (moon + nearby lamps) and receiver (neighbour
      // shadows land on its walls). wall-overlay bands stay flush with the box faces, so they don't
      // need to cast — the box covers them.
      // the box does NOT cast directly: flattenBox leaves ~3 material groups on it, and the depth
      // pass draws one call PER GROUP even though every group resolves to the same depth material —
      // 160 shadow calls citywide. bake the box into the merged caster below instead (depth wants
      // position only, no uv/normal). measured: 175 -> 16 shadow calls, 462 -> 304 total
      box.castShadow = false;
      box.receiveShadow = true;
      scene.add(box);
      // world-bake: BoxGeometry is origin-centred and the box is never rotated, so the mesh
      // position IS the offset
      var bgeo:BufferGeometry = cast boxGeo;
      var bpos = bgeo.attributes.position;
      var vbase = Std.int(shadowPos.length / 3);
      for (i in 0...(bpos.count : Int)) {
        shadowPos.push(bpos.getX(i) + center.x);
        shadowPos.push(bpos.getY(i) + b.h / 2);
        shadowPos.push(bpos.getZ(i) + center.z);
      }
      for (k in 0...(bgeo.index.count : Int)) shadowIdx.push(vbase + bgeo.index.getX(k));

      // storefront overlay: tile 2-cell-wide 16:9 bays across each street face. One bay per
      // face carries the entrance door (chosen from shopDoor), the rest are the door-less
      // continuation; lit (open) vs unlit (closed) by shopOpen. b.h = SHOP_H makes each bay
      // exact 16:9 → no distortion, fills width AND height. MeshBasic = full-bright, so open
      // fronts read lit and closed fronts stay dark by the image's own values (bloom at night).
      if (shop) {
        var type = b.shop;
        var open = b.shopOpen;
        var doorTex = open ? shopFrontLit[type % shopFrontLit.length] : shopFront[type % shopFront.length];
        var ndTex   = open ? shopFrontNdLit[type % shopFrontNdLit.length] : shopFrontNd[type % shopFrontNd.length];
        var bayW:Float = CELL * 2;
        // collect all bays, then merge into two draw calls per shop (door image + plain image)
        var doorQ:Array<{ fw:Float, h:Float, fx:Float, fz:Float, rotY:Float, rx:Float }> = [];
        var ndQ:Array<{ fw:Float, h:Float, fx:Float, fz:Float, rotY:Float, rx:Float }> = [];
        // OVERLAY_EPS, not flush: polygonOffset alone keeps a flush bay off the wall in the beauty
        // pass, but an overrideMaterial pass replaces the material and drops the offset, so bay and
        // wall z-fight — GTAO's prepass does this and the shopfront flickers. a real gap survives
        // any pass. a shop bay covers its whole wall, which is why this reads worst here
        for (f in Geom.buildingFaces(center, wWorld, dWorld, OVERLAY_EPS)) {
          if (!Geom.faceIsStreet(b, f.dir)) continue;
          var n = Std.int(imax(1, Math.round(f.faceW / bayW)));
          var doorBay = (b.shopDoor + f.dir) % n; // which bay holds the door on this face
          for (i in 0...n) {
            var off = (i - (n - 1) / 2) * bayW; // bay centre offset along the face
            var fx = (f.dir < 2) ? f.fx + off : f.fx;
            var fz = (f.dir < 2) ? f.fz : f.fz + off;
            var q = { fw: bayW, h: b.h, fx: fx, fz: fz, rotY: f.rotY, rx: 1.0 };
            if (i == doorBay) doorQ.push(q);
            else ndQ.push(q);
          }
        }
        inline function bayMat(tx:Dynamic):MeshBasicMaterial
          return new MeshBasicMaterial({ map: tx,
            polygonOffset: true, polygonOffsetFactor: -1, polygonOffsetUnits: -1 });
        mergeBand(scene, doorQ, bayMat(doorTex), b, false);
        mergeBand(scene, ndQ, bayMat(ndTex), b, false);
      }

      var gable = !shop && b.facade == 3; // citygen guarantees all metal is a standalone rectangle

      // metal warehouse: one big closed roll-up door, centred and glued to the ground.
      // prefer a street-facing GABLE-END wall (door "under the angle"); but if neither gable
      // end faces a street, fall back to the street-facing long side so the warehouse always
      // has a door (better than a doorless box).
      if (gable) {
        var endDirs = wWorld >= dWorld ? [2, 3] : [0, 1]; // gable-end faces (perpendicular to ridge)
        var endStreet = false;
        for (f in Geom.buildingFaces(center, wWorld, dWorld, 0))
          if (endDirs.indexOf(f.dir) >= 0 && Geom.faceIsStreet(b, f.dir)) { endStreet = true; break; }
        for (f in Geom.buildingFaces(center, wWorld, dWorld, 0)) {
          if (!Geom.faceIsStreet(b, f.dir)) continue;
          if (endStreet && endDirs.indexOf(f.dir) < 0) continue; // gable end available → don't door the long sides
          var doorW = Math.min(f.faceW * 0.55, CELL * 3); // centred, leaves wall margins
          var doorH = Math.min(b.h * 0.7, CELL * 1.8);    // tall roll-up, wall left above
          var mat = tag(new MeshStandardMaterial({ map: doorTex, roughness: 1, metalness: 0,
            polygonOffset: true, polygonOffsetFactor: -1, polygonOffsetUnits: -1 }),
            'door-metal', 'metal door', TEXTURES.doorMetal);
          var mesh = new Mesh(new PlaneGeometry(doorW, doorH), mat);
          mesh.rotation.y = f.rotY;
          mesh.position.set(f.fx, doorH / 2, f.fz);
          scene.add(mesh);
        }
      }

      // ground grime band on the WORN wall faces (back/alley walls), glued to the ground,
      // world-tiled horizontally, fading up. Skipped where a storefront band already owns
      // the ground floor (street faces) so the storefront reads solo. non-metal, non-shop.
      // (per-face quad like shop-front/door overlays; if draws bite, merge into one
      // BufferGeometry per variant like Ground.build.)
      if (!shop && b.facade != 3) {
        var gv = ((b.col * 7 + b.row * 13) % grimeTex.length + grimeTex.length) % grimeTex.length;
        inline function hasStorefront(dir:Int):Bool
          return Geom.faceIsStreet(b, dir)
            && !(b.winForce != null && b.winForce.indexOf(dir) >= 0)
            && !(b.winBlock != null && b.winBlock.indexOf(dir) >= 0);
        var bandH = Math.min(RenderConfig.GRIME_H, b.h - 0.5);
        // one merged grime mesh per building (was one draw call per worn face)
        var gq:Array<{ fw:Float, h:Float, fx:Float, fz:Float, rotY:Float, rx:Float }> = [];
        for (f in Geom.buildingFaces(center, wWorld, dWorld, 0)) {
          if (hasStorefront(f.dir)) continue; // storefront owns the ground floor here — leave it solo
          var rx = imax(1, Math.round(f.faceW / RenderConfig.GRIME_TILE)); // horizontal repeats
          gq.push({ fw: f.faceW, h: bandH, fx: f.fx, fz: f.fz, rotY: f.rotY, rx: rx });
        }
        mergeBand(scene, gq, grimeMat[gv], b, true);
      }

      // roof: metal warehouses get a gable (no parapet); everyone else keeps their parapet
      if (gable) {
        Roofs.addGableRoof(scene, b, center, wWorld, dWorld, clean, worn, roofMetalTex);
      } else {
        Roofs.addParapet(scene, b, center, wWorld, dWorld, shop ? shopCopingTex : copingTex, clean, worn, shop ? false : masonry);
      }
    }
    addShadowCaster(scene, shadowPos, shadowIdx);
  }

// the whole city's building volumes as ONE caster: every box baked into a single position-only
// geometry (the depth material reads nothing else — walls are opaque, no alphaTest), so the moon's
// depth pass costs one call instead of one per material group per building. the city is only ~2.7k
// tris, so the geometry is free; this is pure draw-call overhead being removed.
// it must also sit in the beauty pass: three has no shadow-only object (WebGLShadowMap tests
// object.layers against the VIEW camera, so a layer the camera can't see hides it from the shadow
// map too), hence colorWrite off — one draw that writes nothing.
// Occlusion leaves it alone: world-baked verts put it at the origin, so pick()'s size guard rejects
// it into __occ.skipped() like the other city-wide meshes. it is invisible, so it must not fade
  static function addShadowCaster(scene:Scene, pos:Array<Float>, idx:Array<Int>):Void
    {
      var g = new BufferGeometry();
      g.setAttribute('position', new Float32BufferAttribute(pos, 3));
      g.setIndex(idx);
      var m = new Mesh(g, new MeshBasicMaterial({
        colorWrite: false,
        depthWrite: false,
        depthTest: false,
        // a scene.overrideMaterial pass REPLACES the material, which would throw away the three
        // flags above and let this volume write depth + normals coplanar with the real walls — GTAO
        // does exactly that for its prepass, and the whole facade z-fights. allowOverride keeps our
        // own material on this mesh, so it goes on writing nothing no matter who renders the scene.
        // the shadow map is unaffected either way (WebGLShadowMap swaps in its own depth material)
        allowOverride: false,
      }));
      m.castShadow = true;
      // spans the city, so its bounding sphere is always on screen — the test would never reject it
      untyped m.frustumCulled = false;
      scene.add(m);
    }

  // merge upright wall-band quads that all share ONE material into a single mesh (one draw
  // call): each quad is fw×h, centred at world (fx, h/2, fz), rotated rotY about Y, with
  // horizontal UV repeat rx. rotation+position baked into verts; a +z-rotated face normal is
  // written when the material is lit (MeshStandard). userData.b keeps Occlusion fading it
  static function mergeBand(scene:Scene,
      quads:Array<{ fw:Float, h:Float, fx:Float, fz:Float, rotY:Float, rx:Float }>,
      mat:Dynamic, b:Dynamic, lit:Bool):Void {
    if (quads.length == 0) return;
    var gpos:Array<Float> = [];
    var gnrm:Array<Float> = [];
    var guv:Array<Float> = [];
    var gidx:Array<Int> = [];
    for (q in quads) {
      var geo = new PlaneGeometry(q.fw, q.h);
      var pos:Dynamic = untyped geo.attributes.position;
      var uv:Dynamic = untyped geo.attributes.uv;
      var idx:Dynamic = untyped geo.index;
      var cosR = Math.cos(q.rotY), sinR = Math.sin(q.rotY);
      var vbase = Std.int(gpos.length / 3);
      for (i in 0...(pos.count:Int)) {
        var x:Float = pos.getX(i), y:Float = pos.getY(i), z:Float = pos.getZ(i);
        gpos.push(x * cosR + z * sinR + q.fx); // rotateY(rotY) then translate to the face
        gpos.push(y + q.h / 2);
        gpos.push(-x * sinR + z * cosR + q.fz);
        if (lit) {
          gnrm.push(sinR); // rotateY(rotY) of the plane's +z normal
          gnrm.push(0);
          gnrm.push(cosR);
        }
        guv.push(uv.getX(i) * q.rx);
        guv.push(uv.getY(i));
      }
      for (k in 0...(idx.count:Int)) gidx.push(vbase + idx.getX(k));
    }
    var g = new BufferGeometry();
    g.setAttribute('position', new Float32BufferAttribute(gpos, 3));
    if (lit) g.setAttribute('normal', new Float32BufferAttribute(gnrm, 3));
    g.setAttribute('uv', new Float32BufferAttribute(guv, 2));
    g.setIndex(gidx);
    var mesh = new Mesh(g, mat);
    mesh.userData.b = b;
    scene.add(mesh);
  }

  // ground-floor storefront band on street-facing walls
  public static function addGround(scene:Scene):Void {
    var buildings = WorldCtx.buildings;
    var texes = [for (p in TEXTURES.storefronts) Textures.loadTexture(p, 'wall')];
    // one shared band material per facade; horizontal tiling is baked into the merged quad UVs
    // (so no per-face texture clone), matching the old per-face texture.repeat
    var mats = [for (i in 0...texes.length)
      tag(new MeshStandardMaterial({ map: texes[i], roughness: 1, metalness: 0,
        polygonOffset: true, polygonOffsetFactor: -1, polygonOffsetUnits: -1 }),
        'storefront-' + RenderConfig.FACADE_NAMES[i % RenderConfig.FACADE_NAMES.length],
        'storefront band', TEXTURES.storefronts[i])];
    for (b in buildings) {
      if (b.shop >= 0 || b.facade == 3) continue; // shop face is its own storefront; metal warehouse has doors, no band
      var fi = Geom.frontInfo(b);
      if (fi.simple && !fi.store) continue; // plain/small building: no storefront band (entrance + maybe windows instead)
      var wWorld = b.w * CELL;
      var dWorld = b.d * CELL;
      var center = cellToWorld(b.col + (b.w - 1) / 2, b.row + (b.d - 1) / 2);
      // one merged band mesh per building (was one draw call per street face)
      var q:Array<{ fw:Float, h:Float, fx:Float, fz:Float, rotY:Float, rx:Float }> = [];
      for (f in Geom.buildingFaces(center, wWorld, dWorld, 0)) {
        if ((b.winForce != null && b.winForce.indexOf(f.dir) >= 0) || (b.winBlock != null && b.winBlock.indexOf(f.dir) >= 0)) continue;
        if (!Geom.faceIsStreet(b, f.dir)) continue;
        q.push({ fw: f.faceW, h: (GROUND_H : Float), fx: f.fx, fz: f.fz, rotY: f.rotY, rx: f.faceW / GROUND_H });
        WorldCtx.bandSeen.set(b, true); // checklist: this building rendered a storefront band
      }
      mergeBand(scene, q, mats[b.facade % texes.length], b, true);
    }
  }
}
