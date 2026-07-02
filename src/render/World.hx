package render;

import three.Three;
import citygen.CityConfig;
import citygen.CityConfig.cellToWorld;
import citygen.CityModel.Tile;
import citygen.CityModel.Building;
import citygen.CityModel.City;
import render.RenderConfig.TEXTURES;
import render.RenderConfig.DETAIL_TYPES;
import render.Poly.tag;

using StringTools;

typedef Role = { post:Bool, outDir:Int, cx:Float, cz:Float };
typedef GroundBuf = { pos:Array<Float>, uv:Array<Float>, idx:Array<Int> };

// builds the whole static city geometry into a scene from a City model. Faithful
// port of world.js. Reads the city via statics set in build() so the helper
// methods read like the original module-level functions
class World {
  static inline var GRID = CityConfig.GRID;
  static inline var CELL = CityConfig.CELL;
  static inline var GROUND_H = CityConfig.GROUND_H;
  static inline var FLOOR_H = CityConfig.FLOOR_H;

  static var buildings:Array<Building>;
  static var tiles:Array<Array<Tile>>;

  // post-gen checklist: presence of each feature per building, recorded AT the render
  // chokepoints (so the check verifies what actually rendered, not a re-derivation)
  static var winSeen:haxe.ds.ObjectMap<Building, Bool>;
  static var doorSeen:haxe.ds.ObjectMap<Building, Bool>;
  static var bandSeen:haxe.ds.ObjectMap<Building, Bool>;
  static var noBackDoor:Array<Building>; // had an open back wall but no side door fit (clearance)

  static inline function imax(a:Float, b:Float):Float return a > b ? a : b;

  public static function build(scene:Scene, city:City):Void {
    buildings = city.buildings;
    tiles = city.tiles;
    winSeen = new haxe.ds.ObjectMap();
    doorSeen = new haxe.ds.ObjectMap();
    bandSeen = new haxe.ds.ObjectMap();
    noBackDoor = [];

    buildGroundTiles(scene);

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
        var isWorn = isWornFace(b, dir);
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
      var box = new Mesh(new BoxGeometry(wWorld, b.h, dWorld), [px, nx, top, px, pz, nz]);
      box.position.set(center.x, b.h / 2, center.z);
      box.userData.b = b; box.userData.bidx = bi; // Inspector: alt+click → record
      scene.add(box);

      // storefront overlay: tile 2-cell-wide 16:9 bays across each street face. One bay per
      // face carries the entrance door (chosen from shopDoor), the rest are the door-less
      // continuation; lit (open) vs unlit (closed) by shopOpen. b.h = SHOP_H makes each bay
      // exact 16:9 → no distortion, fills width AND height. MeshBasic = full-bright, so open
      // fronts read lit and closed fronts stay dark by the image's own values (bloom at night).
      if (shop) {
        var type = b.shop;
        var lit = b.shopOpen;
        var doorTex = lit ? shopFrontLit[type % shopFrontLit.length] : shopFront[type % shopFront.length];
        var ndTex   = lit ? shopFrontNdLit[type % shopFrontNdLit.length] : shopFrontNd[type % shopFrontNd.length];
        var bayW = CELL * 2;
        for (f in buildingFaces(center, wWorld, dWorld, 0)) {
          if (!faceIsStreet(b, f.dir)) continue;
          var n = Std.int(imax(1, Math.round(f.faceW / bayW)));
          var doorBay = (b.shopDoor + f.dir) % n; // which bay holds the door on this face
          for (i in 0...n) {
            var mat = new MeshBasicMaterial({ map: (i == doorBay) ? doorTex : ndTex,
              polygonOffset: true, polygonOffsetFactor: -1, polygonOffsetUnits: -1 });
            var mesh = new Mesh(new PlaneGeometry(bayW, b.h), mat);
            mesh.rotation.y = f.rotY;
            var off = (i - (n - 1) / 2) * bayW; // bay centre offset along the face
            if (f.dir < 2) mesh.position.set(f.fx + off, b.h / 2, f.fz);
            else mesh.position.set(f.fx, b.h / 2, f.fz + off);
            scene.add(mesh);
          }
        }
      }

      var gable = !shop && b.facade == 3; // citygen guarantees all metal is a standalone rectangle

      // metal warehouse: one big closed roll-up door, centred and glued to the ground.
      // prefer a street-facing GABLE-END wall (door "under the angle"); but if neither gable
      // end faces a street, fall back to the street-facing long side so the warehouse always
      // has a door (better than a doorless box).
      if (gable) {
        var endDirs = wWorld >= dWorld ? [2, 3] : [0, 1]; // gable-end faces (perpendicular to ridge)
        var endStreet = false;
        for (f in buildingFaces(center, wWorld, dWorld, 0))
          if (endDirs.indexOf(f.dir) >= 0 && faceIsStreet(b, f.dir)) { endStreet = true; break; }
        for (f in buildingFaces(center, wWorld, dWorld, 0)) {
          if (!faceIsStreet(b, f.dir)) continue;
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
      // BufferGeometry per variant like buildGroundTiles.)
      if (!shop && b.facade != 3) {
        var gv = ((b.col * 7 + b.row * 13) % grimeTex.length + grimeTex.length) % grimeTex.length;
        inline function hasStorefront(dir:Int):Bool
          return faceIsStreet(b, dir)
            && !(b.winForce != null && b.winForce.indexOf(dir) >= 0)
            && !(b.winBlock != null && b.winBlock.indexOf(dir) >= 0);
        var bandH = Math.min(RenderConfig.GRIME_H, b.h - 0.5);
        for (f in buildingFaces(center, wWorld, dWorld, 0)) {
          if (hasStorefront(f.dir)) continue; // storefront owns the ground floor here — leave it solo
          var rx = imax(1, Math.round(f.faceW / RenderConfig.GRIME_TILE)); // horizontal repeats
          var geo = new PlaneGeometry(f.faceW, bandH);
          var uv:Dynamic = untyped geo.attributes.uv; // bake horizontal tiling into U (shared texture, no clone)
          var n:Int = uv.count;
          for (i in 0...n) uv.setX(i, uv.getX(i) * rx);
          uv.needsUpdate = true;
          var mesh = new Mesh(geo, grimeMat[gv]);
          mesh.rotation.y = f.rotY;
          mesh.position.set(f.fx, bandH / 2, f.fz);
          scene.add(mesh);
        }
      }

      // roof: metal warehouses get a gable (no parapet); everyone else keeps their parapet
      if (gable) {
        addGableRoof(scene, b, center, wWorld, dWorld, clean, worn, roofMetalTex);
      } else {
        addParapet(scene, b, center, wWorld, dWorld, shop ? shopCopingTex : copingTex, clean, worn, shop ? false : masonry);
      }
    }

    addWindows(scene);
    addGround(scene);
    addEntrances(scene);
    addRoofShadows(scene);
    addRoofDetails(scene);

    runChecklist();
  }

  // should this building show upper-floor windows? shops (storefront, no upper windows) and
  // metal warehouses (closed) never do; composites force them; simple buildings use frontInfo.
  static function expectWindows(b:Building):Bool {
    if (b.shop >= 0 || b.facade == 3) return false;
    var fi = frontInfo(b);
    return fi.simple ? fi.windows : true; // composite (winForce/winBlock) forces windows
  }

  // --- post-generation checklist ------------------------------------------
  // runs after every build(): compares each building's intended front-role against what the
  // render passes ACTUALLY emitted (winSeen/doorSeen/bandSeen), so a silent blank (e.g. a tall
  // plain tower that rendered no windows) or a doorless building surfaces immediately instead of
  // the user flying out to find it. FAIL = a guarantee broke; INFO = intended (blank-by-design).
  // Loud HUD badge + console + window.__check (drill-down + goto, wired in Main).
  static function runChecklist():Void {
    var fails:Array<{ id:Int, reason:String, line:String }> = [];
    var windowless:Array<Int> = [], doorless:Array<Int> = [], blank:Array<Int> = [];
    var nSimple = 0, nStore = 0, nSmall = 0, nPlain = 0;
    for (i in 0...buildings.length) {
      var b = buildings[i];
      var fi = frontInfo(b);
      if (fi.simple) { nSimple++; if (fi.small) nSmall++; else if (fi.store) nStore++; else nPlain++; }
      var exemptArt = b.shop >= 0 || b.facade == 3; // shop/metal: doors+closures baked into the art
      // FAIL: doorless. Only SIMPLE buildings carry the hard guarantee (a front door, street face or
      // anyFront fallback). Composite (+/T/L) pieces door only their own street faces — a buried inner
      // piece legitimately has none while the overall footprint still has doors, so they're exempt.
      if (fi.simple && !doorSeen.exists(b)) { doorless.push(i); fails.push({ id: i, reason: 'doorless', line: BDump.bline(i, b) }); }
      // FAIL: windows expected but none emitted (landlocked — every face buried / store with no street face)
      if (expectWindows(b) && !winSeen.exists(b)) { windowless.push(i); fails.push({ id: i, reason: 'windows expected, none emitted (landlocked?)', line: BDump.bline(i, b) }); }
      // INFO: intended blank box — simple bldg, windows not expected, no storefront band (just a door)
      if (!exemptArt && fi.simple && !expectWindows(b) && !winSeen.exists(b) && !bandSeen.exists(b)) blank.push(i);
    }
    var share = nSimple > 0 ? Math.round(100.0 * nStore / nSimple) : 0;
    var noBack = [for (b in noBackDoor) buildings.indexOf(b)];
    var pass = fails.length == 0;

    var summary = '[check] ${pass ? "PASS" : "FAIL"} — ${buildings.length} bldgs · doorless ${doorless.length} · winless ${windowless.length} · blank-by-design ${blank.length} · noBackDoor ${noBack.length} · store $share%';
    if (pass) js.Browser.console.log(summary);
    else {
      js.Browser.console.error(summary);
      for (f in fails) js.Browser.console.warn('#${f.id} ${f.reason}\n${f.line}');
    }
    if (nSimple >= 20 && (share < 15 || share > 45))
      js.Browser.console.warn('[check] store share $share% off target ${RenderConfig.STORE_PCT}% — check frontInfo hash/gating');

    var el = js.Browser.document.getElementById('check');
    if (el != null) {
      el.textContent = pass ? 'CHECK ✓' : 'CHECK: ${fails.length} ISSUE${fails.length == 1 ? "" : "S"}';
      el.classList.toggle('bad', !pass);
      el.classList.toggle('ok', pass);
    }
    untyped js.Browser.window.__check = {
      pass: pass, fails: fails, windowless: windowless, doorless: doorless, noBackDoor: noBack, blank: blank,
      counts: { bldgs: buildings.length, simple: nSimple, store: nStore, plain: nPlain, small: nSmall, storePct: share },
    };
  }

  // --- ground tiles: one merged mesh per surface type ---------------------
  // each cell = one quad; walkway is raised CURB_H with curb side-faces where it
  // meets a lower (road/alley) cell. A walkway cell with exactly one convex corner
  // (both edge-neighbours lower) is chamfered: the jutting corner is sliced off on
  // the diagonal, the road/alley underneath fills the cut, and the curb follows it
  static function buildGroundTiles(scene:Scene):Void {
    var half = (GRID * CELL) / 2;
    var types = [
      { tile: Tile.Road, tex: TEXTURES.asphalt, kind: 'asphalt', tileW: RenderConfig.ROAD_TILE, y: 0.0 },
      { tile: Tile.Alley, tex: TEXTURES.alley, kind: 'asphalt', tileW: RenderConfig.ALLEY_TILE, y: 0.0 },
      { tile: Tile.Walkway, tex: TEXTURES.walkway, kind: 'wall', tileW: RenderConfig.WALKWAY_TILE, y: RenderConfig.CURB_H },
    ];
    var bufs = [for (_ in types) { pos: ([] : Array<Float>), uv: ([] : Array<Float>), idx: ([] : Array<Int>) }];
    var borderBuf:GroundBuf = { pos: [], uv: [], idx: [] }; // kerb-edging stripe on walkway tops (own mesh/tex)
    var markBuf:GroundBuf = { pos: [], uv: [], idx: [] };   // road markings overlay (lane lines, crosswalks; own mesh/tex)
    function bidx(tile:Tile):Int { for (i in 0...types.length) if (types[i].tile == tile) return i; return -1; }

    function vtx(b:GroundBuf, x:Float, y:Float, z:Float, u:Float, v:Float):Void {
      b.pos.push(x); b.pos.push(y); b.pos.push(z); b.uv.push(u); b.uv.push(v);
    }
    function tri(b:GroundBuf, p0:Array<Float>, p1:Array<Float>, p2:Array<Float>, uv:Array<Float>):Void {
      var base = Std.int(b.pos.length / 3);
      vtx(b, p0[0], p0[1], p0[2], uv[0], uv[1]);
      vtx(b, p1[0], p1[1], p1[2], uv[2], uv[3]);
      vtx(b, p2[0], p2[1], p2[2], uv[4], uv[5]);
      b.idx.push(base); b.idx.push(base + 1); b.idx.push(base + 2);
    }
    function quad(b:GroundBuf, p0:Array<Float>, p1:Array<Float>, p2:Array<Float>, p3:Array<Float>, uv:Array<Float>):Void {
      var base = Std.int(b.pos.length / 3);
      vtx(b, p0[0], p0[1], p0[2], uv[0], uv[1]);
      vtx(b, p1[0], p1[1], p1[2], uv[2], uv[3]);
      vtx(b, p2[0], p2[1], p2[2], uv[4], uv[5]);
      vtx(b, p3[0], p3[1], p3[2], uv[6], uv[7]);
      b.idx.push(base); b.idx.push(base + 1); b.idx.push(base + 2);
      b.idx.push(base); b.idx.push(base + 2); b.idx.push(base + 3);
    }
    function isLower(rr:Int, cc:Int):Bool {
      if (rr < 0 || cc < 0 || rr >= GRID || cc >= GRID) return true;
      var t = tiles[rr][cc];
      return t == Tile.Road || t == Tile.Alley;
    }
    // buffer of the surface under a chamfer cut: prefer the diagonal cell, else an edge
    function underBuf(r:Int, c:Int, dc:Int, dr:Int):Int {
      inline function pick(rr:Int, cc:Int):Int {
        if (rr < 0 || cc < 0 || rr >= GRID || cc >= GRID) return bidx(Tile.Road);
        var t = tiles[rr][cc];
        return (t == Tile.Road || t == Tile.Alley) ? bidx(t) : -1;
      }
      var d = pick(r + dr, c + dc); if (d >= 0) return d;
      var e = pick(r, c + dc); if (e >= 0) return e;
      var s = pick(r + dr, c); if (s >= 0) return s;
      return bidx(Tile.Road);
    }

    var H = RenderConfig.CURB_H;
    var BW = RenderConfig.WALKWAY_BORDER_W, BT = RenderConfig.WALKWAY_BORDER_TILE;
    // unit outward normal of segment a→b, flipped to point toward (tx,tz) (road side)
    function outN(ax:Float, az:Float, bx:Float, bz:Float, tx:Float, tz:Float):{x:Float, z:Float} {
      var nx = bz - az, nz = -(bx - ax);                       // perpendicular to a→b
      if (nx * (tx - ax) + nz * (tz - az) < 0) { nx = -nx; nz = -nz; }
      var nl = Math.sqrt(nx * nx + nz * nz);
      return nl < 1e-6 ? { x: 0.0, z: 0.0 } : { x: nx / nl, z: nz / nl };
    }
    // collect every curb segment (inner edge a→b + unit outward normal) here; the
    // kerb-edging strip is emitted in one mitered post-pass so adjacent segments meet
    // exactly at shared vertices — no gaps at convex corners, no overlap at concave ones
    var curbs:Array<{ax:Float, az:Float, bx:Float, bz:Float, nx:Float, nz:Float}> = [];
    inline function lipN(ax:Float, az:Float, bx:Float, bz:Float, nx:Float, nz:Float):Void {
      if ((bx - ax) * (bx - ax) + (bz - az) * (bz - az) > 1e-9) curbs.push({ax: ax, az: az, bx: bx, bz: bz, nx: nx, nz: nz});
    }
    function lipSeg(ax:Float, az:Float, bx:Float, bz:Float, tx:Float, tz:Float):Void {
      var n = outN(ax, az, bx, bz, tx, tz); lipN(ax, az, bx, bz, n.x, n.z);
    }
    // a road cell with exactly one convex walkway corner is beveled: a diagonal half-
    // tile of walkway is dropped into corner O, so its two O-adjacent edges become
    // raised walkway (continuous with the neighbours that triggered the bevel). returns
    // the corner 0 SW · 1 SE · 2 NE · 3 NW, or -1
    inline function isWk(rr:Int, cc:Int):Bool return rr >= 0 && cc >= 0 && rr < GRID && cc < GRID && tiles[rr][cc] == Tile.Walkway;
    function bevelAt(r:Int, c:Int):Int {
      if (r < 0 || c < 0 || r >= GRID || c >= GRID) return -1; // off-grid (lowerSide probes the border): no corner to bevel
      if (tiles[r][c] != Tile.Road) return -1;
      var Nw = isWk(r - 1, c), Sw = isWk(r + 1, c), Ew = isWk(r, c + 1), Ww = isWk(r, c - 1);
      var O = -1, nC = 0;
      if (Ew && Sw) { O = 1; nC++; } if (Ww && Sw) { O = 0; nC++; }
      if (Ew && Nw) { O = 2; nC++; } if (Ww && Nw) { O = 3; nC++; }
      return nC == 1 ? O : -1;
    }
    // is the road/alley cell (r,c) lower (curbed) as seen across the edge facing it from
    // direction `from` (0=N 1=E 2=S 3=W neighbour of it)? a bevel leg is walkway → not lower
    function lowerSide(r:Int, c:Int, from:Int):Bool {
      if (!isLower(r, c)) return false;
      var O = bevelAt(r, c);
      if (O < 0) return true;
      // legs adjacent to O: O 0→S,W · 1→S,E · 2→N,E · 3→N,W. `from` edge is a leg → not lower
      var legA = (O == 2 || O == 3) ? 0 : 2;          // N for NE/NW else S
      var legB = (O == 1 || O == 2) ? 1 : 3;          // E for SE/NE else W
      return from != legA && from != legB;
    }
    for (r in 0...GRID) for (c in 0...GRID) {
      var ti = bidx(tiles[r][c]);
      if (ti < 0) continue; // building
      var T = types[ti].tileW;
      var b = bufs[ti];
      var x0 = c * CELL - half, x1 = x0 + CELL;
      var z0 = r * CELL - half, z1 = z0 + CELL;

      if (tiles[r][c] != Tile.Walkway) {
        var y = types[ti].y;
        // outer road-turn corner (a road cell with two adjacent walkway neighbours):
        // bevel it with a diagonal HALF-tile of walkway dropped into the road
        var O = bevelAt(r, c);
        if (O >= 0) {
          var wb = bidx(Tile.Walkway), wT = types[wb].tileW;
          var CXr = [x0, x1, x1, x0], CZr = [z1, z1, z0, z0];
          var pp = (O + 3) % 4, su = (O + 1) % 4, P = (O + 2) % 4;
          // road keeps the inner half (away from the corner), at road level
          tri(b, [CXr[su], y, CZr[su]], [CXr[P], y, CZr[P]], [CXr[pp], y, CZr[pp]],
            [CXr[su] / T, CZr[su] / T, CXr[P] / T, CZr[P] / T, CXr[pp] / T, CZr[pp] / T]);
          // walkway fills the corner half, raised
          tri(bufs[wb], [CXr[pp], H, CZr[pp]], [CXr[O], H, CZr[O]], [CXr[su], H, CZr[su]],
            [CXr[pp] / wT, CZr[pp] / wT, CXr[O] / wT, CZr[O] / wT, CXr[su] / wT, CZr[su] / wT]);
          // kerb lip along the diagonal cut, toward the road side (corner P). full length:
          // the mitered post-pass trims it where it meets the neighbours' straight lips
          // (and the opposite bevel's diagonal at an arrow tip)
          lipSeg(CXr[pp], CZr[pp], CXr[su], CZr[su], CXr[P], CZr[P]);
        } else {
          quad(b, [x0, y, z1], [x1, y, z1], [x1, y, z0], [x0, y, z0],
            [x0 / T, z1 / T, x1 / T, z1 / T, x1 / T, z0 / T, x0 / T, z0 / T]);
        }
        continue;
      }

      // open (curbed) edge: neighbour is road/alley AND not a bevel leg (raised walkway).
      // `from` = this cell's direction relative to that neighbour (opposite of the probe)
      var E = lowerSide(r, c + 1, 3), W = lowerSide(r, c - 1, 1), S = lowerSide(r + 1, c, 0), N = lowerSide(r - 1, c, 2);
      var se = E && S, sw = W && S, ne = E && N, nw = W && N;
      var nConvex = (se ? 1 : 0) + (sw ? 1 : 0) + (ne ? 1 : 0) + (nw ? 1 : 0);
      // corners 0=SW 1=SE 2=NE 3=NW (cyclic, CCW from above → +y normals)
      var CX = [x0, x1, x1, x0], CZ = [z1, z1, z0, z0];

      if (nConvex == 1) {
        var O = se ? 1 : sw ? 0 : ne ? 2 : 3;            // convex corner: clip a small bit off it
        var dc = (O == 1 || O == 2) ? 1 : -1, dr = (O == 0 || O == 1) ? 1 : -1;
        var pp = (O + 3) % 4, su = (O + 1) % 4;           // the two edges meeting at O
        var ub = underBuf(r, c, dc, dr);
        var ut = types[ub].tileW;
        var f = 1 / 3;                                    // clip one of the (imagined) 3x3 sub-tiles
        var inx = CX[O] + f * (CX[pp] - CX[O]), inz = CZ[O] + f * (CZ[pp] - CZ[O]); // clip point on pp-edge
        var oux = CX[O] + f * (CX[su] - CX[O]), ouz = CZ[O] + f * (CZ[su] - CZ[O]); // clip point on su-edge
        // walkway top = the cell pentagon (corner O replaced by the two clip points), triangle fan
        var px:Array<Float> = [], pz:Array<Float> = [];
        for (i in 0...4) if (i == O) { px.push(inx); pz.push(inz); px.push(oux); pz.push(ouz); }
          else { px.push(CX[i]); pz.push(CZ[i]); }
        for (t in 1...px.length - 1) tri(b,
          [px[0], H, pz[0]], [px[t], H, pz[t]], [px[t + 1], H, pz[t + 1]],
          [px[0] / T, pz[0] / T, px[t] / T, pz[t] / T, px[t + 1] / T, pz[t + 1] / T]);
        // road/alley fills the clipped corner triangle, at road level
        tri(bufs[ub], [inx, 0, inz], [CX[O], 0, CZ[O]], [oux, 0, ouz],
          [inx / ut, inz / ut, CX[O] / ut, CZ[O] / ut, oux / ut, ouz / ut]);
        // kerb lips along each curbed edge (both straight parts + the diagonal cut).
        // outward = away from the cell centre (2·mid − centre): correct for the two
        // straight edges too, where corner O is collinear with the edge (toward=O fails).
        // the mitered post-pass joins the diagonal to each straight lip cleanly
        var mx = (x0 + x1) / 2, mz = (z0 + z1) / 2;
        lipSeg(CX[pp], CZ[pp], inx, inz, CX[pp] + inx - mx, CZ[pp] + inz - mz);
        lipSeg(inx, inz, oux, ouz, inx + oux - mx, inz + ouz - mz);
        lipSeg(oux, ouz, CX[su], CZ[su], oux + CX[su] - mx, ouz + CZ[su] - mz);
      } else {
        // full walkway paving top at curb height
        quad(b, [x0, H, z1], [x1, H, z1], [x1, H, z0], [x0, H, z0],
          [x0 / T, z1 / T, x1 / T, z1 / T, x1 / T, z0 / T, x0 / T, z0 / T]);
        // kerb lip along each open edge (in nConvex==0 open edges are never
        // perpendicular, so lips never meet at a corner)
        var mx = (x0 + x1) / 2, mz = (z0 + z1) / 2;
        if (N) lipSeg(x0, z0, x1, z0, mx, z0 - 1);
        if (S) lipSeg(x0, z1, x1, z1, mx, z1 + 1);
        if (E) lipSeg(x1, z0, x1, z1, x1 + 1, mz);
        if (W) lipSeg(x0, z0, x0, z1, x0 - 1, mz);
      }
    }

    // --- road markings: lane lines + crosswalks (painted overlay) -----------
    // pattern is geometry (dashes/bars/double); fill is one worn-paint texture.
    // roads carry no width/orientation metadata, so classify each road cell by run
    // length: the perpendicular run is the band thickness (≤ MAIN_ROAD_W), the
    // along run is the corridor (longer). both runs long ⇒ a crossing box (skip)
    {
      var PY = RenderConfig.PAINT_Y, PT = RenderConfig.PAINT_TILE, LW = RenderConfig.LINE_W;
      var MW = CityConfig.MAIN_ROAD_W;
      inline function isR(rr:Int, cc:Int):Bool return rr >= 0 && cc >= 0 && rr < GRID && cc < GRID && tiles[rr][cc] == Tile.Road;
      function hrun(rr:Int, cc:Int):Int { if (!isR(rr, cc)) return 0; var a = cc; while (isR(rr, a - 1)) a--; var b = cc; while (isR(rr, b + 1)) b++; return b - a + 1; }
      function vrun(rr:Int, cc:Int):Int { if (!isR(rr, cc)) return 0; var a = rr; while (isR(a - 1, cc)) a--; var b = rr; while (isR(b + 1, cc)) b++; return b - a + 1; }
      inline function inter(rr:Int, cc:Int):Bool return isR(rr, cc) && hrun(rr, cc) > MW && vrun(rr, cc) > MW;
      // axis-aligned painted rect at PY; UV is WORLD-aligned on both axes (worldPos/PT) so the
      // worn-paint field samples at one consistent scale everywhere — no per-strip stretch.
      // alongX kept for call-site symmetry but no longer affects UV
      function mark(mx0:Float, mx1:Float, mz0:Float, mz1:Float, alongX:Bool):Void {
        quad(markBuf, [mx0, PY, mz1], [mx1, PY, mz1], [mx1, PY, mz0], [mx0, PY, mz0],
          [mx0 / PT, mz1 / PT, mx1 / PT, mz1 / PT, mx1 / PT, mz0 / PT, mx0 / PT, mz0 / PT]);
      }
      // dashed line of thickness LW centred on `fixed`, running a→b. alongX: a,b are x (fixed=z); else a,b are z (fixed=x)
      function dashed(a:Float, b:Float, fixed:Float, alongX:Bool):Void {
        var step = RenderConfig.DASH_LEN + RenderConfig.DASH_GAP;
        var p = a;
        while (p < b - 1e-4) {
          var q = Math.min(p + RenderConfig.DASH_LEN, b);
          if (alongX) mark(p, q, fixed - LW / 2, fixed + LW / 2, true);
          else mark(fixed - LW / 2, fixed + LW / 2, p, q, false);
          p += step;
        }
      }
      // centre/lane line at boundary `fixed` for a band of width W at lane index k
      inline function laneLine(a:Float, b:Float, fixed:Float, W:Int, k:Int, alongX:Bool):Void {
        if (W == 2) { if (k == 0) dashed(a, b, fixed, alongX); }
        else if (W == 4) {
          if (k == 0 || k == 2) dashed(a, b, fixed, alongX);
          else if (k == 1) { // double solid centre line
            var g = RenderConfig.DOUBLE_GAP / 2;
            if (alongX) { mark(a, b, fixed - g - LW / 2, fixed - g + LW / 2, true); mark(a, b, fixed + g - LW / 2, fixed + g + LW / 2, true); }
            else { mark(fixed - g - LW / 2, fixed - g + LW / 2, a, b, false); mark(fixed + g - LW / 2, fixed + g + LW / 2, a, b, false); }
          }
        }
      }
      // zebra band + stop line across a road of width [lo,hi], at the mouth facing the
      // intersection. dir +1 = intersection on the high side of `edge`, -1 = low side.
      // `edge` is the corridor/box boundary; bars run across the road (perpendicular to travel)
      function crossing(lo:Float, hi:Float, edge:Float, dir:Int, alongTravelX:Bool):Void {
        var ZD = RenderConfig.ZEBRA_DEPTH, ZB = RenderConfig.ZEBRA_BAR, SW = RenderConfig.STOP_W, SG = RenderConfig.STOP_GAP;
        var zb0 = dir > 0 ? edge - ZD : edge;          // zebra band extent along the travel axis
        var zb1 = dir > 0 ? edge : edge + ZD;
        // bars run PARALLEL to the road (long along travel), repeating across the width.
        // fit n equal paint strips with n+1 equal gaps (gap on each road edge ⇒ paint never
        // touches the curb): width = (2n+1)·s, pick n so s ≈ ZEBRA_BAR
        var W = hi - lo;
        var n = Math.round((W / ZB - 1) / 2); if (n < 1) n = 1;
        var s = W / (2 * n + 1);
        for (i in 0...n) {
          var p = lo + (2 * i + 1) * s, q = p + s;
          if (alongTravelX) mark(zb0, zb1, p, q, true); else mark(p, q, zb0, zb1, false);
        }
        var s0 = dir > 0 ? zb0 - SG - SW : zb1 + SG;   // stop bar set back from the zebra by SG
        if (alongTravelX) mark(s0, s0 + SW, lo, hi, false); else mark(lo, hi, s0, s0 + SW, true);
      }
      for (r in 0...GRID) for (c in 0...GRID) {
        if (!isR(r, c)) continue;
        var Lh = hrun(r, c), Lv = vrun(r, c);
        var hCorr = Lh > MW, vCorr = Lv > MW;
        if (hCorr == vCorr) continue;                  // crossing box, or tiny stub: no centre markings
        var x0 = c * CELL - half, x1 = x0 + CELL;
        var z0 = r * CELL - half, z1 = z0 + CELL;
        if (hCorr) {                                   // E-W corridor: band runs in z, lines along x
          var W = Lv; if (W != 2 && W != 4) continue;
          var r0 = r; while (isR(r0 - 1, c)) r0--;
          var k = r - r0;
          var mouth = inter(r, c + 1) || inter(r, c - 1);
          if (!mouth) laneLine(x0, x1, z1, W, k, true); // line at this cell's south edge (skip in the crosswalk cell)
          if (k == 0) {                                // crosswalk spans the full band once
            var zTop = r0 * CELL - half, zBot = (r0 + W) * CELL - half;
            if (inter(r, c + 1)) crossing(zTop, zBot, x1, 1, true);
            if (inter(r, c - 1)) crossing(zTop, zBot, x0, -1, true);
          }
        } else {                                       // N-S corridor: band runs in x, lines along z
          var W = Lh; if (W != 2 && W != 4) continue;
          var c0 = c; while (isR(r, c0 - 1)) c0--;
          var k = c - c0;
          var mouth = inter(r + 1, c) || inter(r - 1, c);
          if (!mouth) laneLine(z0, z1, x1, W, k, false); // line at this cell's east edge (skip in the crosswalk cell)
          if (k == 0) {
            var xL = c0 * CELL - half, xR = (c0 + W) * CELL - half;
            if (inter(r + 1, c)) crossing(xL, xR, z1, 1, false);
            if (inter(r - 1, c)) crossing(xL, xR, z0, -1, false);
          }
        }
      }
    }

    // --- emit the kerb-edging strip with mitered joins ----------------------
    // each curb segment's inner edge stays on the walkway boundary; its outer edge is
    // offset BW onto the road. at a shared boundary vertex the two segments' outer
    // edges meet at the miter point V + BW·(n1+n2)/(1+n1·n2) — the intersection of
    // their offset lines — so they abut exactly: no gap (convex) and no overlap (concave)
    inline function vkey(x:Float, z:Float):String return Std.string(Math.round(x * 16)) + '_' + Std.string(Math.round(z * 16));
    var vmap = new Map<String, Array<{s:Int, e:Int}>>();
    inline function addV(k:String, s:Int, e:Int):Void {
      var a = vmap.get(k); if (a == null) { a = []; vmap.set(k, a); } a.push({s: s, e: e});
    }
    for (i in 0...curbs.length) { var c = curbs[i]; addV(vkey(c.ax, c.az), i, 0); addV(vkey(c.bx, c.bz), i, 1); }
    function outer(i:Int, e:Int):{x:Float, z:Float} {
      var c = curbs[i];
      var vx = e == 0 ? c.ax : c.bx, vz = e == 0 ? c.az : c.bz;
      var list = vmap.get(vkey(vx, vz));
      var oj = -1, cnt = 0;
      if (list != null) for (it in list) if (!(it.s == i && it.e == e)) { oj = it.s; cnt++; }
      if (cnt == 1 && oj >= 0) {
        var nj = curbs[oj];
        var denom = 1 + c.nx * nj.nx + c.nz * nj.nz;
        if (denom > 0.25) return { x: vx + (c.nx + nj.nx) / denom * BW, z: vz + (c.nz + nj.nz) / denom * BW };
      }
      return { x: vx + c.nx * BW, z: vz + c.nz * BW }; // square end (dangling or >2-way junction)
    }
    for (i in 0...curbs.length) {
      var c = curbs[i];
      var oA = outer(i, 0), oB = outer(i, 1);
      var ul = Math.sqrt((c.bx - c.ax) * (c.bx - c.ax) + (c.bz - c.az) * (c.bz - c.az)) / BT;
      quad(borderBuf, [c.ax, H, c.az], [oA.x, H, oA.z], [oB.x, H, oB.z], [c.bx, H, c.bz], [0, 1, 0, 0, ul, 0, ul, 1]);
      quad(borderBuf, [oA.x, 0, oA.z], [oB.x, 0, oB.z], [oB.x, H, oB.z], [oA.x, H, oA.z], [0, 0, ul, 0, ul, 1, 0, 1]);
    }

    for (i in 0...types.length) {
      var b = bufs[i];
      if (b.idx.length == 0) continue;
      var geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(b.pos, 3));
      geo.setAttribute('uv', new Float32BufferAttribute(b.uv, 2));
      geo.setIndex(b.idx);
      geo.computeVertexNormals();
      var map = Textures.loadTexture(types[i].tex, types[i].kind, 1);
      scene.add(new Mesh(geo, new MeshStandardMaterial({ map: map, roughness: 1, metalness: 0, side: THREE.DoubleSide })));
    }

    if (borderBuf.idx.length > 0) {
      var geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(borderBuf.pos, 3));
      geo.setAttribute('uv', new Float32BufferAttribute(borderBuf.uv, 2));
      geo.setIndex(borderBuf.idx);
      geo.computeVertexNormals();
      var map = Textures.loadTexture(TEXTURES.walkwayBorder, 'wall', 1);
      scene.add(new Mesh(geo, new MeshStandardMaterial({ map: map, roughness: 1, metalness: 0, side: THREE.DoubleSide })));
    }

    if (markBuf.idx.length > 0) {
      var geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(markBuf.pos, 3));
      geo.setAttribute('uv', new Float32BufferAttribute(markBuf.uv, 2));
      geo.setIndex(markBuf.idx);
      geo.computeVertexNormals();
      var map = Textures.loadTexture(TEXTURES.roadPaint, 'asphalt', 1);
      // opaque + non-emissive: lit like the road, so it darkens at night / brightens by day with
      // the lighting. the texture's keyed scuff pixels render as opaque grey wear (no cutout jaggies)
      scene.add(new Mesh(geo, new MeshStandardMaterial({ map: map, roughness: 1, metalness: 0, side: THREE.DoubleSide })));
    }
  }

  // dir: 0=+z,1=-z,2=+x,3=-x. Street = the cells directly outside are road/walkway
  static var DIRV = [[0, 1], [0, -1], [1, 0], [-1, 0]];
  static function faceIsStreet(b:Building, dir:Int):Bool {
    var dc = DIRV[dir][0], dr = DIRV[dir][1];
    if (dc != 0) {
      var col = (dc > 0 ? b.col + b.w - 1 : b.col) + dc;
      if (col < 0 || col >= GRID) return true;
      for (r in b.row...b.row + b.d) {
        var t = tiles[r][col];
        if (t != Tile.Road && t != Tile.Walkway) return false;
      }
      return true;
    }
    var row = (dr > 0 ? b.row + b.d - 1 : b.row) + dr;
    if (row < 0 || row >= GRID) return true;
    for (c in b.col...b.col + b.w) {
      var t = tiles[row][c];
      if (t != Tile.Road && t != Tile.Walkway) return false;
    }
    return true;
  }

  // does the wall `dir` have a clear straight path to a road? step out perpendicular across the
  // FULL face width: any Building tile in the corridor blocks it; a step where the whole width is
  // Road means the road is reached. unlike faceIsStreet (road/walkway ONE tile out), this tunnels
  // through alley + walkway up to DOOR_PATH_MAX_DEPTH tiles, so a wall facing a road across an
  // alley still earns a door. running off-grid before a road = no path (city boundary, not a road).
  static function faceHasPathToRoad(b:Building, dir:Int):Bool {
    var dc = DIRV[dir][0], dr = DIRV[dir][1];
    for (step in 0...RenderConfig.DOOR_PATH_MAX_DEPTH) {
      var sawRoad = true;
      if (dc != 0) {
        var col = (dc > 0 ? b.col + b.w : b.col - 1) + dc * step;
        if (col < 0 || col >= GRID) return false;
        for (r in b.row...b.row + b.d) {
          var t = tiles[r][col];
          if (t == Tile.Building) return false;
          if (t != Tile.Road) sawRoad = false;
        }
      } else {
        var row = (dr > 0 ? b.row + b.d : b.row - 1) + dr * step;
        if (row < 0 || row >= GRID) return false;
        for (c in b.col...b.col + b.w) {
          var t = tiles[row][c];
          if (t == Tile.Building) return false;
          if (t != Tile.Road) sawRoad = false;
        }
      }
      if (sawRoad) return true;
    }
    return false;
  }

  // does wall `dir` carry a ground-floor storefront band (addGround)? that band IS the entrance —
  // never place a pedestrian door + cover over it. mirrors addGround's per-building + per-face gate
  // EXACTLY (incl. composite T/L/+ pieces, which also draw bands — the old `fi.simple` test missed
  // them, so composites got a door slapped on top of their storefront).
  static function storefrontFace(b:Building, dir:Int):Bool {
    if (b.shop >= 0 || b.facade == 3) return false;
    var fi = frontInfo(b);
    if (fi.simple && !fi.store) return false; // plain/small simple building: no band
    return faceIsStreet(b, dir)
      && !(b.winForce != null && b.winForce.indexOf(dir) >= 0)
      && !(b.winBlock != null && b.winBlock.indexOf(dir) >= 0);
  }

  // tile-index runs of face `dir` that look onto open space (road / walkway / alley)
  // and so earn windows: each maximal run of columns (dir 0/1) or rows (dir 2/3)
  // with no building within OPEN_WIN_DEPTH tiles straight out. windows the OPEN part
  // of a partial face — e.g. both orthogonal inner walls of an L notch, where each
  // wall is half buried by the other wing and half open onto the notch. runs shorter
  // than MIN_OPEN_WIN_RUN are single-column slivers poking past a near neighbour →
  // dropped (full side or none). full-street faces never reach here. runs are
  // inclusive {lo,hi} along x for dir 0/1, along z for dir 2/3
  static inline var OPEN_WIN_DEPTH = 3;
  static inline var MIN_OPEN_WIN_RUN = 2; // min exposed tiles to window (no single-column slivers)
  static function openWinRuns(b:Building, dir:Int, allowPartial:Bool):Array<{lo:Int, hi:Int}> {
    if (faceIsStreet(b, dir)) return [];
    var dc = DIRV[dir][0], dr = DIRV[dir][1];
    // is the column/row at face index `idx` open (no building within 3 tiles out)?
    function exposed(idx:Int):Bool {
      for (step in 0...OPEN_WIN_DEPTH) {
        if (dc != 0) { // face runs along rows; step out along columns
          var col = (dc > 0 ? b.col + b.w : b.col - 1) + dc * step;
          if (col < 0 || col >= GRID) continue;
          if (tiles[idx][col] == Tile.Building) return false;
        } else { // face runs along columns; step out along rows
          var row = (dr > 0 ? b.row + b.d : b.row - 1) + dr * step;
          if (row < 0 || row >= GRID) continue;
          if (tiles[row][idx] == Tile.Building) return false;
        }
      }
      return true;
    }
    var runs:Array<{lo:Int, hi:Int}> = [];
    var lo = dc != 0 ? b.row : b.col;
    var hi = dc != 0 ? b.row + b.d : b.col + b.w; // exclusive
    inline function pushRun(from:Int, to:Int) if (to - from + 1 >= MIN_OPEN_WIN_RUN) runs.push({ lo: from, hi: to });
    var runStart = -1, buried = false;
    for (idx in lo...hi) {
      if (exposed(idx)) { if (runStart < 0) runStart = idx; }
      else { buried = true; if (runStart >= 0) { pushRun(runStart, idx - 1); runStart = -1; } }
    }
    if (runStart >= 0) pushRun(runStart, hi - 1);
    // whole face open (alley back wall, or an L/T/+ notch arm) → always window. a
    // PARTIAL face (part abutting a neighbour) is windowed only when it's a notch
    // inner wall citygen flagged via winBlock (allowPartial). otherwise it's just
    // an incidental wall half-buried by an unrelated neighbour → no half-window
    if (!buried) return runs;
    return allowPartial ? runs : [];
  }

  // tile-index runs of face `dir` whose cell ONE step straight out is open (not a Building) —
  // i.e. the wall fronts onto alley/road/walkway/edge, so a door there has space. Run ends mark
  // the corners: the building's own end, or where a sibling/neighbour wall abuts (T/L junction).
  // (depth-1, unlike openWinRuns' depth-3 window rule — a door is fine facing a near building
  // across an alley.) inclusive {lo,hi} along x for dir 0/1, along z for dir 2/3.
  static function doorRuns(b:Building, dir:Int):Array<{lo:Int, hi:Int}> {
    var dc = DIRV[dir][0], dr = DIRV[dir][1];
    inline function clear(idx:Int):Bool {
      if (dc != 0) { var col = dc > 0 ? b.col + b.w : b.col - 1; return col < 0 || col >= GRID || tiles[idx][col] != Tile.Building; }
      var row = dr > 0 ? b.row + b.d : b.row - 1; return row < 0 || row >= GRID || tiles[row][idx] != Tile.Building;
    }
    var lo = dc != 0 ? b.row : b.col;
    var hi = dc != 0 ? b.row + b.d : b.col + b.w; // exclusive
    var runs:Array<{lo:Int, hi:Int}> = [];
    var runStart = -1;
    for (idx in lo...hi) {
      if (clear(idx)) { if (runStart < 0) runStart = idx; }
      else if (runStart >= 0) { runs.push({ lo: runStart, hi: idx - 1 }); runStart = -1; }
    }
    if (runStart >= 0) runs.push({ lo: runStart, hi: hi - 1 });
    return runs;
  }

  // extend a windowed face-tile run [lo,hi] to the full contiguous wall it belongs
  // to — including flush co-planar wall cells of NEIGHBOURING pieces (an L/T/+ seam)
  // — so windows can be centred on the WHOLE wall and line up across the join. a
  // neighbour cell joins when it sits on this face's wall plane and its outward cell
  // is open (a real exposed wall there). returns inclusive tile indices along the
  // face axis (x for dir 0/1, z for dir 2/3)
  static function wallExtent(b:Building, dir:Int, lo:Int, hi:Int):{lo:Int, hi:Int} {
    if (dir < 2) { // face along columns; plane is a row, outward is a row
      var pr = dir == 0 ? b.row + b.d - 1 : b.row;
      var orr = dir == 0 ? b.row + b.d : b.row - 1;
      inline function wall(c:Int):Bool return c >= 0 && c < GRID && tiles[pr][c] == Tile.Building
        && (orr < 0 || orr >= GRID || tiles[orr][c] != Tile.Building);
      while (wall(lo - 1)) lo--;
      while (wall(hi + 1)) hi++;
    } else { // face along rows; plane is a column, outward is a column
      var pc = dir == 2 ? b.col + b.w - 1 : b.col;
      var oc = dir == 2 ? b.col + b.w : b.col - 1;
      inline function wall(r:Int):Bool return r >= 0 && r < GRID && tiles[r][pc] == Tile.Building
        && (oc < 0 || oc >= GRID || tiles[r][oc] != Tile.Building);
      while (wall(lo - 1)) lo--;
      while (wall(hi + 1)) hi++;
    }
    return { lo: lo, hi: hi };
  }

  // centred window-column world positions across [a,b] (margin at each end). same
  // count/centring as a single face, so a standalone wall is symmetric; fed the full
  // wall extent it stays continuous across seams (each piece emits its own slice)
  static function centeredCols(a:Float, b:Float):Array<Float> {
    var pitch = RenderConfig.WIN_PITCH_X;
    var inner = (b - a) - 2 * RenderConfig.WIN_MARGIN;
    if (inner < 0) return [(a + b) / 2];
    var n = Std.int(imax(1, Math.round(inner / pitch)));
    while (n > 1 && (n - 1) * pitch + RenderConfig.WIN_W > inner) n--;
    var mid = (a + b) / 2;
    return [for (k in 0...n) mid + (k - (n - 1) / 2) * pitch];
  }

  // wall texture: clean wherever the face shows windows, worn otherwise. mirrors
  // the window rule in addWindows — forced courtyard faces, street frontages (not
  // blocked), and inner walls opening onto a notch/alley are clean; everything
  // else (blocked frontages, cramped/buried back walls) is worn
  static function isWornFace(b:Building, dir:Int):Bool {
    var forceWin = b.winForce != null && b.winForce.indexOf(dir) >= 0;
    var blockWin = b.winBlock != null && b.winBlock.indexOf(dir) >= 0;
    var hasWin = forceWin || (faceIsStreet(b, dir) && !blockWin) || openWinRuns(b, dir, blockWin).length > 0;
    return !hasWin;
  }

  // deterministic per-building front role (render-only; no rng → citygen stays byte-identical).
  // only "simple rectangle" non-shop non-metal buildings are reclassified; everyone else keeps
  // the prior path (store+windows). store ~STORE_PCT%; the rest are plain (maybe windows, maybe
  // an entrance door). a building with a tiny footprint (≤2 tiles BOTH axes) is "small": entrance
  // only — no store band, no windows. (NOT narrow-front: a 4-deep building with a 2-wide street
  // face is a real building and keeps windows.) hashed off col/row like the metal/grime picks.
  static function frontInfo(b:Building):{ simple:Bool, small:Bool, store:Bool, windows:Bool } {
    if (b.shop >= 0 || b.facade == 3 || b.winForce != null || b.winBlock != null)
      return { simple: false, small: false, store: true, windows: true };
    var small = b.w <= 2 && b.d <= 2;
    var h = ((b.col * 73856093) ^ (b.row * 19349663)) & 0x7fffffff;
    var store = !small && (h % 100) < RenderConfig.STORE_PCT;
    // every concrete/brick/stone building gets windows — no blank plain boxes. only a buried
    // face (every wall against a neighbor) yields 0, which the checklist FAILs as a real anomaly.
    return { simple: true, small: small, store: store, windows: true };
  }

  // face placement: [faceWidth, rotationY, dir, faceCenterX, faceCenterZ]
  static function buildingFaces(center:{x:Float, z:Float}, wWorld:Float, dWorld:Float, eps:Float):Array<{faceW:Float, rotY:Float, dir:Int, fx:Float, fz:Float}> {
    return [
      { faceW: wWorld, rotY: 0, dir: 0, fx: center.x, fz: center.z + dWorld / 2 + eps },
      { faceW: wWorld, rotY: Math.PI, dir: 1, fx: center.x, fz: center.z - dWorld / 2 - eps },
      { faceW: dWorld, rotY: Math.PI / 2, dir: 2, fx: center.x + wWorld / 2 + eps, fz: center.z },
      { faceW: dWorld, rotY: -Math.PI / 2, dir: 3, fx: center.x - wWorld / 2 - eps, fz: center.z },
    ];
  }

  // ground-floor storefront band on street-facing walls
  static function addGround(scene:Scene):Void {
    var texes = [for (p in TEXTURES.storefronts) Textures.loadTexture(p, 'wall')];
    for (b in buildings) {
      if (b.shop >= 0 || b.facade == 3) continue; // shop face is its own storefront; metal warehouse has doors, no band
      var fi = frontInfo(b);
      if (fi.simple && !fi.store) continue; // plain/small building: no storefront band (entrance + maybe windows instead)
      var wWorld = b.w * CELL;
      var dWorld = b.d * CELL;
      var center = cellToWorld(b.col + (b.w - 1) / 2, b.row + (b.d - 1) / 2);
      var base = texes[b.facade % texes.length];
      var k = RenderConfig.FACADE_NAMES[b.facade];
      for (f in buildingFaces(center, wWorld, dWorld, 0)) {
        if ((b.winForce != null && b.winForce.indexOf(f.dir) >= 0) || (b.winBlock != null && b.winBlock.indexOf(f.dir) >= 0)) continue;
        if (!faceIsStreet(b, f.dir)) continue;
        var t = base.clone();
        t.needsUpdate = true;
        t.repeat.set(f.faceW / GROUND_H, 1);
        var mesh = new Mesh(
          new PlaneGeometry(f.faceW, GROUND_H),
          tag(new MeshStandardMaterial({
            map: t, roughness: 1, metalness: 0,
            polygonOffset: true, polygonOffsetFactor: -1, polygonOffsetUnits: -1,
          }), 'storefront-$k', '$k storefront', TEXTURES.storefronts[b.facade % TEXTURES.storefronts.length]));
        mesh.position.set(f.fx, GROUND_H / 2, f.fz);
        mesh.rotation.y = f.rotY;
        scene.add(mesh);
        bandSeen.set(b, true); // checklist: this building rendered a storefront band
      }
    }
  }

  // pedestrian entrance / maintenance doors on simple buildings.
  // front: one centred door on the widest STREET face, GUARANTEED for every building (stores are
  //   covered by their storefront band instead, except when landlocked). no building is doorless.
  // side: one per NON-street wall, independent coin-flip — worn walls at BACK_ENTRANCE_WORN_PCT
  //   (a drab steel maintenance door), clean back walls rarely (BACK_ENTRANCE_CLEAN_PCT); side
  //   doors sit OFF-CENTRE along the face. the door texture matches the wall it's on (clean door
  //   on a clean face, worn door on a worn face). all deterministic — no rng, no citygen desync.
  static function addEntrances(scene:Scene):Void {
    var doorTex = [for (p in TEXTURES.doors) Textures.loadTexture(p, 'wall')];
    var doorWornTex = [for (p in TEXTURES.doorsWorn) Textures.loadTexture(p, 'wall')];
    for (t in doorTex) { t.wrapS = t.wrapT = THREE.ClampToEdgeWrapping; t.needsUpdate = true; }
    for (t in doorWornTex) { t.wrapS = t.wrapT = THREE.ClampToEdgeWrapping; t.needsUpdate = true; }

    // per-facade entrance-cover lintel texture [concrete, brick, stone], world-tiled per cover.
    // NEVER a flat colour. cropped to the centre band (like coping) then cloned + repeat-set per slab.
    var coverTex = [for (p in TEXTURES.doorCovers) Textures.loadTexture(p, 'wall')]; // full material swatch (not a band)

    inline function doorSide(b:Building, faceW:Float):Float
      return Math.min(RenderConfig.DOOR_SIZE, Math.min(b.h * 0.9, faceW * 0.9));

    inline function place(b:Building, f:{faceW:Float, rotY:Float, dir:Int, fx:Float, fz:Float}, off:Float, s:Float):Void {
      var worn = isWornFace(b, f.dir);
      var tx = worn ? doorWornTex[b.facade] : doorTex[b.facade];
      var k = RenderConfig.FACADE_NAMES[b.facade];
      // s = SQUARE quad side (square texture → no stretch); passed in (full face for front/composite, open-run-capped for side)
      var mat = tag(new MeshStandardMaterial({ map: tx, roughness: 1, metalness: 0,
        transparent: false, alphaTest: 0.5, // hand-painted alpha = cutout: discard the transparent wall surround (wall behind shows). matches windows
        // depth-bias BELOW the grime (-1) so the door wins the depth test flush against the wall — no
        // physical gap needed. grime is transparent+depthWrite:false, so a nearer door bias keeps grime off it.
        polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2 }),
        'door-$k' + (worn ? '-worn' : ''), '$k door' + (worn ? ' (service)' : ''),
        worn ? TEXTURES.doorsWorn[b.facade] : TEXTURES.doors[b.facade]);
      doorSeen.set(b, true); // checklist: this building rendered at least one door
      var mesh = new Mesh(new PlaneGeometry(s, s), mat);
      mesh.rotation.y = f.rotY;
      var eps = 0.01; // effectively flush (was 0.06 → visible gap); polygonOffset -2 does the z-fight work, this hair just guards grazing angles
      if (f.dir < 2) mesh.position.set(f.fx + off, s / 2, f.fz + (f.dir == 0 ? eps : -eps));
      else mesh.position.set(f.fx + (f.dir == 2 ? eps : -eps), s / 2, f.fz + off);
      scene.add(mesh);
    }

    // thin tinted slab (lintel/canopy) just above a FRONT door, slightly wider, jutting out.
    // mirrors place()'s lateral (off) + normal (dir) math so it lines up with the door at (off,s).
    inline function placeCover(b:Building, f:{faceW:Float, rotY:Float, dir:Int, fx:Float, fz:Float}, off:Float, s:Float):Void {
      var cw = s * RenderConfig.COVER_WIDTH_FRAC;                            // ~ door-panel width (not wall-wide)
      var cd = RenderConfig.COVER_DEPTH;
      var mt = RenderConfig.COVER_MAT_TILE;
      var k = RenderConfig.FACADE_NAMES[b.facade];
      var ct = coverTex[b.facade].clone();
      ct.wrapS = ct.wrapT = THREE.RepeatWrapping;
      ct.needsUpdate = true;
      var cmat = tag(new MeshStandardMaterial({ map: ct, roughness: 1, metalness: 0, side: THREE.DoubleSide }), 'door-cover-$k', '$k door cover', TEXTURES.doorCovers[b.facade]);
      // world pos of the local origin (door-top-center on the wall), shifted `off` along the face,
      // `outN` along the outward normal. rotation.y = f.rotY makes local +z = outward for every dir.
      inline function setPos(cover:Mesh, y:Float, outN:Float):Void {
        cover.rotation.y = f.rotY;
        if (f.dir < 2) cover.position.set(f.fx + off, y, f.fz + (f.dir == 0 ? outN : -outN));
        else cover.position.set(f.fx + (f.dir == 2 ? outN : -outN), y, f.fz + off);
      }
      var anchor = s * RenderConfig.COVER_Y_FRAC; // cover BOTTOM sits here — just above the visible door, small gap
      var cover:Mesh;
      switch (b.facade) {
        case 0: // concrete: HALF-BARREL — half-cylinder, axis along door width, flat back on wall, curve bulges out
          ct.repeat.set(cw / mt, 1);
          var R = RenderConfig.COVER_BARREL_R;
          var geo = new CylinderGeometry(R, R, cw, RenderConfig.COVER_ARC_SEG, 1, false, -Math.PI / 2, Math.PI);
          geo.rotateZ(Math.PI / 2);                                        // cylinder axis Y → X (along door width); retained half faces +z (outward)
          cover = new Mesh(geo, cmat);
          setPos(cover, Math.min(anchor + R, b.h - R), -RenderConfig.COVER_EMBED); // flat diameter vertical on wall; bottom at anchor
        case 2: // stone: sloped slate cap INSET into the wall — ridge buried, only the front slope shows (grows from the wall)
          ct.repeat.set(1, 1);                                             // UVs already world-tiled inside coverGableGeo
          var geo = coverGableGeo(cw, cd, RenderConfig.COVER_SLOPE_RISE, mt);
          cover = new Mesh(geo, cmat);
          setPos(cover, Math.min(anchor + 0.2, b.h - RenderConfig.COVER_SLOPE_RISE), -RenderConfig.COVER_EMBED); // ridge (local z=0) ~at wall → back half embedded; lifted a touch (inset slope reads higher than flat covers)
        default: // brick: THIN flat painted-metal awning slab (metal = thin)
          var ch = RenderConfig.COVER_METAL_H;
          ct.repeat.set(cw / mt, cd / mt);
          cover = new Mesh(new BoxGeometry(cw, ch, cd), cmat);
          var by = s * 0.85; // sit at the door top: a thin sheet can't hide door poking above it, so ride higher than the thick covers' anchor
          setPos(cover, Math.min(by + ch / 2, b.h - ch / 2), cd / 2 - RenderConfig.COVER_EMBED);
      }
      scene.add(cover);
    }

    // main entrance on a frontage: a thick wall (> 5 window columns wide) gets TWO doors at the
    // quarter points instead of one centred, so a wide facade doesn't read as a single lonely door.
    // each FRONT door also gets a tinted cover (service doors via sideDoor are left coverless).
    inline function placeFront(b:Building, f:{faceW:Float, rotY:Float, dir:Int, fx:Float, fz:Float}, s:Float):Void {
      if (centeredCols(-f.faceW / 2, f.faceW / 2).length > 5) {
        var o = f.faceW / 4; place(b, f, -o, s); placeCover(b, f, -o, s); place(b, f, o, s); placeCover(b, f, o, s);
      } else { place(b, f, 0, s); placeCover(b, f, 0, s); }
    }

    for (b in buildings) {
      var fi = frontInfo(b);
      var composite = b.shop < 0 && b.facade != 3 && !fi.simple; // T/L/+/courtyard pieces (winForce/winBlock set)
      if (!fi.simple && !composite) continue; // shops + metal keep their own entrances
      var wWorld = b.w * CELL;
      var dWorld = b.d * CELL;
      var center = cellToWorld(b.col + (b.w - 1) / 2, b.row + (b.d - 1) / 2);
      var faces = buildingFaces(center, wWorld, dWorld, 0);
      var doored = new haxe.ds.IntMap<Bool>(); // dirs that already carry a door (no duplicates)

      // composite (T/L/+) piece: a CENTERED door on every wall facing a street. faceIsStreet
      // already requires the cells straight out to be road/walkway, so a wall buried behind a
      // sibling piece or another building is excluded (nothing covers the path to the street).
      if (composite) {
        for (f in faces) if (faceIsStreet(b, f.dir) && !storefrontFace(b, f.dir)) { placeFront(b, f, doorSide(b, f.faceW)); doored.set(f.dir, true); }
      } else {
        // front door — GUARANTEED: every building must have one. stores already show a storefront
        // band (its own entrance) on a street face, so they only need an explicit door if they are
        // landlocked (no street face → no band). everyone else always gets a pedestrian/glass door
        // on the widest street face, falling back to the widest face so nothing is ever doorless.
        var streetFront:{faceW:Float, rotY:Float, dir:Int, fx:Float, fz:Float} = null;
        var anyFront:{faceW:Float, rotY:Float, dir:Int, fx:Float, fz:Float} = null;
        for (f in faces) {
          if (anyFront == null || f.faceW > anyFront.faceW) anyFront = f;
          if (faceIsStreet(b, f.dir) && (streetFront == null || f.faceW > streetFront.faceW)) streetFront = f;
        }
        if (!fi.store || streetFront == null) { // store with a street face is covered by its band
          var front = streetFront != null ? streetFront : anyFront;
          if (front != null) { placeFront(b, front, doorSide(b, front.faceW)); doored.set(front.dir, true); }
        }

        // side / maintenance doors: each non-street wall independent, off-centre. The door must sit
        // in an OPEN run of the wall (openWinRuns = the part not buried behind a neighbour) and keep
        // DOOR_EDGE_CLEAR clear of the run's ends — which are the corners, including a T/L-junction
        // where a sibling piece abuts. too narrow a run → no room → no door. Returns true if placed.
        function sideDoor(f:{faceW:Float, rotY:Float, dir:Int, fx:Float, fz:Float}):Bool {
          var runs = doorRuns(b, f.dir);
          if (runs.length == 0) return false;
          var best = runs[0];
          for (rr in runs) if ((rr.hi - rr.lo) > (best.hi - best.lo)) best = rr;
          var runW = (best.hi - best.lo + 1) * CELL;
          var mid = (f.dir < 2)
            ? (cellToWorld(best.lo, b.row).x + cellToWorld(best.hi, b.row).x) / 2 - center.x
            : (cellToWorld(b.col, best.lo).z + cellToWorld(b.col, best.hi).z) / 2 - center.z;
          var s = Math.min(RenderConfig.DOOR_SIZE, Math.min(b.h * 0.9, runW - 2 * RenderConfig.DOOR_EDGE_CLEAR));
          if (s < RenderConfig.DOOR_MIN) return false; // run too narrow to fit a door clear of the corners
          var r = ((b.col * 92837111) ^ (b.row * 689287499) ^ (f.dir * 283923481)) & 0x7fffffff;
          var maxJit = Math.max(0, runW / 2 - s / 2 - RenderConfig.DOOR_EDGE_CLEAR);
          place(b, f, mid + ((r >> 8) % 1001 / 1000 * 2 - 1) * maxJit, s);
          return true;
        }
        var nonStreet = [for (f in faces) if (!faceIsStreet(b, f.dir)) f];
        var placedSide = false;
        for (f in nonStreet) {
          var r = ((b.col * 92837111) ^ (b.row * 689287499) ^ (f.dir * 283923481)) & 0x7fffffff;
          var pct = isWornFace(b, f.dir) ? RenderConfig.BACK_ENTRANCE_WORN_PCT : RenderConfig.BACK_ENTRANCE_CLEAN_PCT;
          if (r % 100 < pct && sideDoor(f)) { placedSide = true; doored.set(f.dir, true); }
        }
        if (!placedSide) for (f in nonStreet) if (sideDoor(f)) { placedSide = true; doored.set(f.dir, true); break; } // guarantee: first back wall with room
        // checklist: flag a building that has an open back wall yet got no side door (all runs
        // too narrow for corner clearance) — informational, not a hard failure
        if (!placedSide) for (f in nonStreet) if (doorRuns(b, f.dir).length > 0) { noBackDoor.push(b); break; }
      }

      // extra entrance: a windowed wall with a clear straight path to a road gets its OWN door —
      // even off the street, even if the building already has a front door. a corner/island
      // building facing a road across an alley or walkway shouldn't present a doorless wall to it.
      // a store's street wall already shows a storefront (its entrance) — never door over that.
      if (expectWindows(b)) for (f in faces)
        if (!doored.exists(f.dir) && !storefrontFace(b, f.dir) && faceHasPathToRoad(b, f.dir)) { placeFront(b, f, doorSide(b, f.faceW)); doored.set(f.dir, true); }
    }
  }

  // parapet ring: 4 corner posts + 4 inset rim segments (clean butt joints).
  // `covered` (per dir 0..3) lists world-axis intervals along each edge that are
  // shared with a same-height neighbour — those parts of the rim are dropped so
  // two attached buildings butt instead of overlapping (T/L junctions). A fully
  // covered edge yields no rim; a partially covered edge is split into the
  // exposed sub-spans, each adjusted at its junction end by `extend`: the brick
  // rim grows +T to fill the concave-corner square (overlap hidden under the cap),
  // while the cap retracts -E to butt against the perpendicular cap's outer edge
  // instead of overrunning the neighbour wall and z-fighting that cap's overhang
  static function parapetRing(scene:Scene, cx:Float, cz:Float, halfX:Float, halfZ:Float, yMid:Float, rimH:Float,
      matsFor:(Float, Float, Float, Role) -> Array<MeshStandardMaterial>, ?T:Float, ?covered:Array<Array<{a:Float, b:Float}>>, ?extend:Float):Void {
    if (T == null) T = RenderConfig.PARAPET_T;
    var EX = extend == null ? RenderConfig.PARAPET_T : extend;
    var ix = halfX - T / 2, iz = halfZ - T / 2;
    inline function add(w:Float, d:Float, x:Float, z:Float, post:Bool, outDir:Int) {
      var role:Role = { post: post, outDir: outDir, cx: x, cz: z };
      var m = new Mesh(new BoxGeometry(w, rimH, d), matsFor(w, rimH, d, role));
      m.position.set(x, yMid, z);
      scene.add(m);
    }
    // corner posts: always emitted with a cap. butting buildings only share edge
    // lines (never overlap area), so adjacent corner caps never z-fight
    for (sx in [-1, 1]) for (sz in [-1, 1]) add(T, T, cx + sx * ix, cz + sz * iz, true, -1);
    // rim segments along x (dir 0 +z / dir 1 -z), split around covered intervals
    var spanXLo = cx - (halfX - T), spanXHi = cx + (halfX - T);
    for (sz in [-1, 1]) {
      var dir = sz > 0 ? 0 : 1;
      var z = cz + sz * iz;
      for (seg in exposedSpans(covered, dir, spanXLo, spanXHi, EX)) {
        var w = seg.b - seg.a;
        if (w > 1e-6) add(w, T, (seg.a + seg.b) / 2, z, false, dir);
      }
    }
    // rim segments along z (dir 2 +x / dir 3 -x)
    var spanZLo = cz - (halfZ - T), spanZHi = cz + (halfZ - T);
    for (sx in [-1, 1]) {
      var dir = sx > 0 ? 2 : 3;
      var x = cx + sx * ix;
      for (seg in exposedSpans(covered, dir, spanZLo, spanZHi, EX)) {
        var d = seg.b - seg.a;
        if (d > 1e-6) add(T, d, x, (seg.a + seg.b) / 2, false, dir);
      }
    }
  }

  // is the corner at (cornerX,cornerZ), nudged outward along (sx,sz), strictly
  // inside a same-height neighbour? such corners are buried in the merged roof —
  // their coping cap is hidden and the corner contact-shadow is skipped. a corner
  // merely on a covered seam's open end is exposed and keeps cap + shadow
  static function cornerBuried(b:Building, cornerX:Float, cornerZ:Float, sx:Float, sz:Float):Bool {
    var px = cornerX + sx * 0.05, pz = cornerZ + sz * 0.05;
    for (o in buildings) if (o != b && Math.abs(o.h - b.h) < 0.001) {
      var oc = cellToWorld(o.col + (o.w - 1) / 2, o.row + (o.d - 1) / 2);
      var xmin = oc.x - o.w * CELL / 2, xmax = oc.x + o.w * CELL / 2;
      var zmin = oc.z - o.d * CELL / 2, zmax = oc.z + o.d * CELL / 2;
      if (xmin - 1e-6 < px && px < xmax + 1e-6 && zmin - 1e-6 < pz && pz < zmax + 1e-6) return true;
    }
    return false;
  }

  // exposed sub-spans of [lo,hi] after subtracting edge `dir`'s covered intervals.
  // each sub-span end that came from a covered cut (a junction with a neighbour,
  // not the edge's own end) is grown outward by `extend` so a wall/shadow placed
  // there reaches into the concave corner instead of stopping at the neighbour line
  static function exposedSpans(covered:Array<Array<{a:Float, b:Float}>>, dir:Int, lo:Float, hi:Float, extend:Float):Array<{a:Float, b:Float}> {
    var cuts:Array<{a:Float, b:Float}> = [];
    if (covered != null && covered[dir] != null) for (iv in covered[dir]) {
      var a = lo > iv.a ? lo : iv.a, b = hi < iv.b ? hi : iv.b;
      if (b > a) cuts.push({ a: a, b: b });
    }
    cuts.sort((p, q) -> p.a < q.a ? -1 : (p.a > q.a ? 1 : 0));
    var out:Array<{a:Float, b:Float}> = [];
    var cur = lo;
    for (c in cuts) { if (c.a > cur) out.push({ a: cur, b: c.a }); if (c.b > cur) cur = c.b; }
    if (cur < hi) out.push({ a: cur, b: hi });
    if (extend > 0) for (s in out) {
      if (s.a > lo + 1e-6) s.a -= extend;
      if (s.b < hi - 1e-6) s.b += extend;
    }
    return out;
  }

  // per edge (dir 0..3) the world-axis intervals shared with a same-height
  // neighbour: where another building's footprint covers this edge line. dir 0/1
  // intervals are along x; dir 2/3 along z. These are the parts of the parapet
  // rim that would go onto another building and must be cut so the two attach
  public static function coveredEdges(b:Building):Array<Array<{a:Float, b:Float}>> {
    var bc = cellToWorld(b.col + (b.w - 1) / 2, b.row + (b.d - 1) / 2);
    var bxMin = bc.x - b.w * CELL / 2, bxMax = bc.x + b.w * CELL / 2;
    var bzMin = bc.z - b.d * CELL / 2, bzMax = bc.z + b.d * CELL / 2;
    var nb:Array<{xmin:Float, xmax:Float, zmin:Float, zmax:Float}> = [];
    for (o in buildings) if (o != b && Math.abs(o.h - b.h) < 0.001) {
      var oc = cellToWorld(o.col + (o.w - 1) / 2, o.row + (o.d - 1) / 2);
      nb.push({ xmin: oc.x - o.w * CELL / 2, xmax: oc.x + o.w * CELL / 2,
                zmin: oc.z - o.d * CELL / 2, zmax: oc.z + o.d * CELL / 2 });
    }
    inline function inters(axisMin:Float, axisMax:Float, alongX:Bool, edgeZ:Float, edgeX:Float):Array<{a:Float, b:Float}> {
      var out:Array<{a:Float, b:Float}> = [];
      for (o in nb) {
        var coversPerp = alongX ? (o.zmin <= edgeZ + 1e-6 && edgeZ - 1e-6 <= o.zmax)
                                : (o.xmin <= edgeX + 1e-6 && edgeX - 1e-6 <= o.xmax);
        if (!coversPerp) continue;
        var a = alongX ? o.xmin : o.zmin, b = alongX ? o.xmax : o.zmax;
        var lo = axisMin > a ? axisMin : a, hi = axisMax < b ? axisMax : b;
        if (hi > lo) out.push({ a: lo, b: hi });
      }
      return out;
    }
    return [
      inters(bxMin, bxMax, true,  bzMax, 0),   // dir 0 (+z)
      inters(bxMin, bxMax, true,  bzMin, 0),   // dir 1 (-z)
      inters(bzMin, bzMax, false, 0, bxMax),   // dir 2 (+x)
      inters(bzMin, bzMax, false, 0, bxMin),   // dir 3 (-x)
    ];
  }

  // coping face materials: world-tiled side lips (joints on a global grid) + a
  // matching world-tiled flat cap, so joints line up corner↔corner and top↔side
  static function copingMats(tex:Texture, tileW:Float, vOffset:Float = 0, prefix:String = 'coping', label:String = 'parapet coping')
      :(Float, Float, Float, Role) -> Array<MeshStandardMaterial> {
    return function(w:Float, rimH:Float, d:Float, role:Role):Array<MeshStandardMaterial> {
      var slice = (w < d ? w : d) / tileW;
      var VTILE = 1.5;
      inline function mat(ru:Float, rv:Float, rot:Float = 0, offX:Float = 0, offY:Float = 0, cy:Float = 0.5):MeshStandardMaterial {
        var t = tex.clone();
        t.needsUpdate = true;
        t.center.set(0.5, cy);
        t.repeat.set(ru, rv);
        t.rotation = rot;
        t.offset.set(offX, offY);
        return new MeshStandardMaterial({ map: t, roughness: 1, metalness: 0 });
      }
      var VR = rimH / VTILE;
      var CT = 'textures/coping.png';
      inline function sideMat(worldStart:Float, len:Float, uDir:Int, cls:String, name:String):MeshStandardMaterial {
        var t = tex.clone();
        t.needsUpdate = true;
        t.wrapS = t.wrapT = THREE.RepeatWrapping;
        t.center.set(0, 1);
        if (uDir > 0) { t.repeat.set(len / tileW, VR); t.offset.set(worldStart / tileW, vOffset); }
        else { t.repeat.set(-len / tileW, VR); t.offset.set((worldStart + len) / tileW, vOffset); }
        return tag(new MeshStandardMaterial({ map: t, roughness: 1, metalness: 0 }), cls, name, CT);
      }
      if (role != null && role.post) {
        var x0 = role.cx - w / 2, z0 = role.cz - d / 2;
        var P = '$prefix-side-post', N = '$label side (corner)';
        var px = sideMat(z0, d, -1, P, N), nx = sideMat(z0, d, 1, P, N);
        var pz = sideMat(x0, w, 1, P, N), nz = sideMat(x0, w, -1, P, N);
        var top = tag(mat(slice, slice), '$prefix-top', '$label top', CT);
        return [px, nx, top, top, pz, nz];
      }
      var isX = w >= d;
      var end = tag(mat(slice, 1), '$prefix-end', '$label end', CT);
      var flatT = tex.clone();
      flatT.needsUpdate = true;
      flatT.wrapS = flatT.wrapT = THREE.RepeatWrapping;
      if (isX) {
        var x0 = role.cx - w / 2;
        flatT.center.set(0, 0.5); flatT.rotation = 0;
        flatT.repeat.set(w / tileW, slice); flatT.offset.set(x0 / tileW, 0);
      } else {
        // py face V runs along -z, so the rotated joint axis is reversed: negative
        // repeat + start at z0+d makes U = worldZ/tileW (matches the x-side lip grid)
        var z0 = role.cz - d / 2;
        flatT.center.set(0, 0); flatT.rotation = Math.PI / 2;
        flatT.repeat.set(-d / tileW, slice); flatT.offset.set((z0 + d) / tileW, 0.5 + slice / 2);
      }
      var flat = tag(new MeshStandardMaterial({ map: flatT, roughness: 1, metalness: 0 }), '$prefix-top', '$label top', CT);
      if (isX) {
        var x0 = role.cx - w / 2;
        var io0 = role.outDir == 0 ? 'out' : 'in', io1 = role.outDir == 1 ? 'out' : 'in';
        var pz = sideMat(x0, w, 1, '$prefix-side-z-$io0', '$label side z $io0');
        var nz = sideMat(x0, w, -1, '$prefix-side-z-$io1', '$label side z $io1');
        return [end, end, flat, flat, pz, nz];
      }
      var z0 = role.cz - d / 2;
      var io2 = role.outDir == 2 ? 'out' : 'in', io3 = role.outDir == 3 ? 'out' : 'in';
      var px = sideMat(z0, d, -1, '$prefix-side-x-$io2', '$label side x $io2');
      var nx = sideMat(z0, d, 1, '$prefix-side-x-$io3', '$label side x $io3');
      return [px, nx, flat, flat, end, end];
    };
  }

  // brick parapet: the wall texture continuing up at a uniform world scale. each
  // face picks worn vs clean to match the wall under it, so a corner post can be
  // worn on its alley side and clean on its street side
  static function brickMats(b:Building, clean:Texture, worn:Texture):(Float, Float, Float, Role) -> Array<MeshStandardMaterial> {
    var c = cellToWorld(b.col + (b.w - 1) / 2, b.row + (b.d - 1) / 2);
    return function(w:Float, h:Float, d:Float, role:Role):Array<MeshStandardMaterial> {
      inline function rep(m:Float):Float { var r = m / RenderConfig.WALL_TILE; return r >= 1 ? Math.round(r) : r; }
      inline function faceMat(dir:Int, ru:Float, rv:Float):MeshStandardMaterial {
        var wn = dir >= 0 && isWornFace(b, dir);
        var t = (wn ? worn : clean).clone();
        t.needsUpdate = true;
        t.repeat.set(ru, rv);
        var nm = RenderConfig.FACADE_NAMES[b.facade];
        return tag(new MeshStandardMaterial({ map: t, roughness: 1, metalness: 0 }),
          wn ? 'parapet-$nm-worn' : 'parapet-$nm', wn ? '$nm parapet (worn)' : '$nm parapet',
          (wn ? RenderConfig.TEXTURES.wornWalls : RenderConfig.TEXTURES.walls)[b.facade]);
      }
      // x-faces span z×h, z-faces span w×h; posts use each face's own direction,
      // rims share one outward direction across all faces
      var dirX = role == null ? -1 : (role.post ? (role.cx > c.x ? 2 : 3) : role.outDir);
      var dirZ = role == null ? -1 : (role.post ? (role.cz > c.z ? 0 : 1) : role.outDir);
      var xf = faceMat(dirX, rep(d), rep(h));
      var yf = faceMat(role != null && role.post ? -1 : (role == null ? -1 : role.outDir), rep(w), rep(d));
      var zf = faceMat(dirZ, rep(w), rep(h));
      return [xf, xf, yf, yf, zf, zf];
    };
  }

  // drop a coping block over each concave (T/L) junction corner so the two strips'
  // staggered edge caps read as one clean tile. `along`/`across` are the block size
  // along vs across the resuming edge; `inset` shifts its centre inward from the
  // corner point. raised a hair to win the depth test. shared by brick + concrete
  static function copingCorners(scene:Scene, tex:Texture, covered:Array<Array<{a:Float, b:Float}>>,
      bxMin:Float, bxMax:Float, bzMin:Float, bzMax:Float, capY:Float, capBoxH:Float,
      along:Float, across:Float, inset:Float):Void {
    inline function block(bx:Float, bz:Float, bw:Float, bd:Float) {
      var role:Role = { post: true, outDir: -1, cx: bx, cz: bz };
      var m = new Mesh(new BoxGeometry(bw, capBoxH, bd),
        copingMats(tex, 8, 0, 'coping-cap', 'cap coping')(bw, capBoxH, bd, role));
      m.position.set(bx, capY + 0.004, bz);
      scene.add(m);
    }
    // covered[0]/[1] run along x (block centred on the z edge line); [2]/[3] along z
    for (iv in covered[0]) {
      if (iv.a > bxMin + 1e-4) block(iv.a + inset, bzMax, along, across);
      if (iv.b < bxMax - 1e-4) block(iv.b - inset, bzMax, along, across);
    }
    for (iv in covered[1]) {
      if (iv.a > bxMin + 1e-4) block(iv.a + inset, bzMin, along, across);
      if (iv.b < bxMax - 1e-4) block(iv.b - inset, bzMin, along, across);
    }
    for (iv in covered[2]) {
      if (iv.a > bzMin + 1e-4) block(bxMax, iv.a + inset, across, along);
      if (iv.b < bzMax - 1e-4) block(bxMax, iv.b - inset, across, along);
    }
    for (iv in covered[3]) {
      if (iv.a > bzMin + 1e-4) block(bxMin, iv.a + inset, across, along);
      if (iv.b < bzMax - 1e-4) block(bxMin, iv.b - inset, across, along);
    }
  }

  static function addParapet(scene:Scene, b:Building, center:{x:Float, z:Float}, wWorld:Float, dWorld:Float, copingTex:Texture, clean:Texture, worn:Texture, masonry:Bool):Void {
    var T = RenderConfig.PARAPET_T;
    var covered = coveredEdges(b);
    var bxMin = center.x - wWorld / 2, bxMax = center.x + wWorld / 2;
    var bzMin = center.z - dWorld / 2, bzMax = center.z + dWorld / 2;
    if (!masonry) {
      var h = RenderConfig.PARAPET_H, embed = RenderConfig.PARAPET_EMBED, E = 0.12;
      var capY = b.h + h / 2 - embed / 2, capBoxH = h + embed;
      // single coping ring, width T+2E centred on the wall line, with corner posts
      // landing exactly on the wall corners. drop the rim where a same-height
      // neighbour abuts (T/L junction); extend=0 so the rim stops at the cut (no
      // overshoot). the terminating building's own corner post already fills the
      // concave corner — no patch block needed (unlike brick, whose cap posts inset)
      parapetRing(scene, center.x, center.z, wWorld / 2 + T / 2 + E, dWorld / 2 + T / 2 + E,
        capY, capBoxH, copingMats(copingTex, 8, 0.0), T + 2 * E, covered, 0);
      return;
    }
    var H = RenderConfig.PARAPET_H_BRICK;
    parapetRing(scene, center.x, center.z, wWorld / 2, dWorld / 2, b.h + H / 2, H, brickMats(b, clean, worn), null, covered);
    var capH = 0.3, capEmbed = 0.18, E = 0.08;
    parapetRing(scene, center.x, center.z, wWorld / 2 + E, dWorld / 2 + E,
      b.h + H + capH / 2 - capEmbed / 2, capH + capEmbed,
      copingMats(copingTex, 8, 0, 'coping-cap', 'brick cap coping'), T + 2 * E, covered);

    // concave-corner coping: at a T/L junction the two strips' edge caps are inset
    // toward opposite centres, so they sit on opposite sides of the shared edge
    // line and only touch at the corner (a stagger). one block over each such
    // corner — spanning both caps' footprints — reads as a single clean tile
    var capY = b.h + H + capH / 2 - capEmbed / 2, capBoxH = capH + capEmbed;
    var ACROSS = 2 * (T + E), ALONG = T + 2 * E; // across edge / along edge
    copingCorners(scene, copingTex, covered, bxMin, bxMax, bzMin, bzMax, capY, capBoxH, ALONG, ACROSS, T / 2);
  }

  // small pitched gable cap for a stone FRONT-door cover: 2 sloped quads (ridge parallel to the
  // wall, along local x) + 2 triangular gable ends. local frame: x = door width, y up from 0,
  // z out from wall; eaves at z=±cd/2,y=0; ridge at z=0,y=rise. UV world-tiled by `tile`.
  static function coverGableGeo(cw:Float, cd:Float, rise:Float, tile:Float):BufferGeometry {
    var hw = cw / 2, hd = cd / 2;
    var L = Math.sqrt(hd * hd + rise * rise) / tile; // eave→ridge tile span
    var p = new Array<Float>(), u = new Array<Float>();
    inline function v(x:Float, y:Float, z:Float, tu:Float, tv:Float):Void {
      p.push(x); p.push(y); p.push(z); u.push(tu); u.push(tv);
    }
    // front slope (+z)
    v(-hw, 0, hd, -hw / tile, 0); v(hw, 0, hd, hw / tile, 0); v(hw, rise, 0, hw / tile, L);
    v(-hw, 0, hd, -hw / tile, 0); v(hw, rise, 0, hw / tile, L); v(-hw, rise, 0, -hw / tile, L);
    // back slope (-z)
    v(hw, 0, -hd, hw / tile, 0); v(-hw, 0, -hd, -hw / tile, 0); v(-hw, rise, 0, -hw / tile, L);
    v(hw, 0, -hd, hw / tile, 0); v(-hw, rise, 0, -hw / tile, L); v(hw, rise, 0, hw / tile, L);
    // gable end +x
    v(hw, 0, hd, hd / tile, 0); v(hw, 0, -hd, -hd / tile, 0); v(hw, rise, 0, 0, rise / tile);
    // gable end -x
    v(-hw, 0, -hd, -hd / tile, 0); v(-hw, 0, hd, hd / tile, 0); v(-hw, rise, 0, 0, rise / tile);
    var geo = new BufferGeometry();
    geo.setAttribute('position', new Float32BufferAttribute(p, 3));
    geo.setAttribute('uv', new Float32BufferAttribute(u, 2));
    geo.computeVertexNormals();
    return geo;
  }

  // metal warehouse gable ("double slope") roof: a prism of 2 sloped quads + 2 triangular
  // gable ends, capping the box. ridge runs along the LONGER footprint axis. the SLOPES use a
  // dedicated metal-roof texture; the vertical gable-END triangles are wall (clean or worn to
  // match the wall below — a worn back wall gets a worn gable end). world-tiled (no stretch),
  // ridges run down-slope. only for simple-rectangle metal buildings. DoubleSide so winding
  // never hides a face. the box's own flat top stays, hidden beneath the slopes.
  static function addGableRoof(scene:Scene, b:Building, center:{x:Float, z:Float}, wWorld:Float, dWorld:Float, cleanWall:Texture, wornWall:Texture, roofTex:Texture):Void {
    var TILE = RenderConfig.WALL_TILE;
    var gV = RenderConfig.GABLE_V; // gable ends sample a CLEAN mid-texture V band (worn metal has a dirty base strip; eaves up high shouldn't show ground grime). ribs are vertical so V-shift keeps corrugation aligned.
    var eaveY = b.h;
    var bxMin = center.x - wWorld / 2, bxMax = center.x + wWorld / 2;
    var bzMin = center.z - dWorld / 2, bzMax = center.z + dWorld / 2;
    var sP = new Array<Float>(), sU = new Array<Float>();   // slopes (roof texture)
    var aP = new Array<Float>(), aU = new Array<Float>();   // gable end A
    var bP = new Array<Float>(), bU = new Array<Float>();   // gable end B
    inline function v(p:Array<Float>, u:Array<Float>, x:Float, y:Float, z:Float, tu:Float, tv:Float):Void {
      p.push(x); p.push(y); p.push(z); u.push(tu); u.push(tv);
    }
    var aDir = 0, bDir = 0;

    if (wWorld >= dWorld) {
      // ridge along X (z = center.z); slopes face ±z, gable ends at ±x
      var cz = center.z;
      var pitchH = Math.min(dWorld * 0.22, 2.6); // shallow gable (~18-20°)
      var ridgeY = eaveY + pitchH;
      var sV = Math.sqrt((dWorld / 2) * (dWorld / 2) + pitchH * pitchH) / TILE; // down-slope tile span
      v(sP, sU, bxMin, eaveY, bzMax, bxMin / TILE, 0); v(sP, sU, bxMax, eaveY, bzMax, bxMax / TILE, 0); v(sP, sU, bxMax, ridgeY, cz, bxMax / TILE, sV);
      v(sP, sU, bxMin, eaveY, bzMax, bxMin / TILE, 0); v(sP, sU, bxMax, ridgeY, cz, bxMax / TILE, sV); v(sP, sU, bxMin, ridgeY, cz, bxMin / TILE, sV);
      v(sP, sU, bxMax, eaveY, bzMin, bxMax / TILE, 0); v(sP, sU, bxMin, eaveY, bzMin, bxMin / TILE, 0); v(sP, sU, bxMin, ridgeY, cz, bxMin / TILE, sV);
      v(sP, sU, bxMax, eaveY, bzMin, bxMax / TILE, 0); v(sP, sU, bxMin, ridgeY, cz, bxMin / TILE, sV); v(sP, sU, bxMax, ridgeY, cz, bxMax / TILE, sV);
      // gable ends (vertical triangles), uv by world z (along) × height
      aDir = 2; v(aP, aU, bxMax, eaveY, bzMax, bzMax / TILE, gV); v(aP, aU, bxMax, eaveY, bzMin, bzMin / TILE, gV); v(aP, aU, bxMax, ridgeY, cz, cz / TILE, gV + pitchH / TILE);
      bDir = 3; v(bP, bU, bxMin, eaveY, bzMin, bzMin / TILE, gV); v(bP, bU, bxMin, eaveY, bzMax, bzMax / TILE, gV); v(bP, bU, bxMin, ridgeY, cz, cz / TILE, gV + pitchH / TILE);
    } else {
      // ridge along Z (x = center.x); slopes face ±x, gable ends at ±z
      var cx = center.x;
      var pitchH = Math.min(wWorld * 0.22, 2.6); // shallow gable (~18-20°)
      var ridgeY = eaveY + pitchH;
      var sV = Math.sqrt((wWorld / 2) * (wWorld / 2) + pitchH * pitchH) / TILE;
      v(sP, sU, bxMax, eaveY, bzMin, bzMin / TILE, 0); v(sP, sU, bxMax, eaveY, bzMax, bzMax / TILE, 0); v(sP, sU, cx, ridgeY, bzMax, bzMax / TILE, sV);
      v(sP, sU, bxMax, eaveY, bzMin, bzMin / TILE, 0); v(sP, sU, cx, ridgeY, bzMax, bzMax / TILE, sV); v(sP, sU, cx, ridgeY, bzMin, bzMin / TILE, sV);
      v(sP, sU, bxMin, eaveY, bzMax, bzMax / TILE, 0); v(sP, sU, bxMin, eaveY, bzMin, bzMin / TILE, 0); v(sP, sU, cx, ridgeY, bzMin, bzMin / TILE, sV);
      v(sP, sU, bxMin, eaveY, bzMax, bzMax / TILE, 0); v(sP, sU, cx, ridgeY, bzMin, bzMin / TILE, sV); v(sP, sU, cx, ridgeY, bzMax, bzMax / TILE, sV);
      // gable ends, uv by world x (along) × height
      aDir = 0; v(aP, aU, bxMax, eaveY, bzMax, bxMax / TILE, gV); v(aP, aU, bxMin, eaveY, bzMax, bxMin / TILE, gV); v(aP, aU, cx, ridgeY, bzMax, cx / TILE, gV + pitchH / TILE);
      bDir = 1; v(bP, bU, bxMin, eaveY, bzMin, bxMin / TILE, gV); v(bP, bU, bxMax, eaveY, bzMin, bxMax / TILE, gV); v(bP, bU, cx, ridgeY, bzMin, cx / TILE, gV + pitchH / TILE);
    }

    inline function mesh(p:Array<Float>, u:Array<Float>, tex:Texture, nm:String, desc:String, path:String):Void {
      var geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(p, 3));
      geo.setAttribute('uv', new Float32BufferAttribute(u, 2));
      geo.computeVertexNormals();
      var t = tex.clone(); t.needsUpdate = true; t.wrapS = t.wrapT = THREE.RepeatWrapping;
      var m = tag(new MeshStandardMaterial({ map: t, roughness: 1, metalness: 0, side: THREE.DoubleSide }), nm, desc, path);
      scene.add(new Mesh(geo, m));
    }
    mesh(sP, sU, roofTex, 'roof-gable-metal', 'metal gable roof', RenderConfig.TEXTURES.roofMetal);
    var aWorn = isWornFace(b, aDir), bWorn = isWornFace(b, bDir);
    mesh(aP, aU, aWorn ? wornWall : cleanWall, 'gable-end-metal' + (aWorn ? '-worn' : ''), 'metal gable end' + (aWorn ? ' (worn)' : ''), RenderConfig.TEXTURES.walls[3]);
    mesh(bP, bU, bWorn ? wornWall : cleanWall, 'gable-end-metal' + (bWorn ? '-worn' : ''), 'metal gable end' + (bWorn ? ' (worn)' : ''), RenderConfig.TEXTURES.walls[3]);
  }

  // fake contact shadow under the parapet: instanced gradient decals on the roof
  static function addRoofShadows(scene:Scene):Void {
    var geo = new PlaneGeometry(1, 1);
    inline function mkMat(alphaMap:Texture):MeshBasicMaterial return new MeshBasicMaterial({
      color: 0x000000, alphaMap: alphaMap, transparent: true, opacity: RenderConfig.ROOF_SHADOW_ALPHA,
      depthWrite: false, side: THREE.DoubleSide });
    var q = new Quaternion();
    var qx = new Quaternion().setFromAxisAngle(new Vector3(1, 0, 0), -Math.PI / 2);
    var up = new Vector3(0, 1, 0);
    var pos = new Vector3();
    var scl = new Vector3();
    var W = RenderConfig.ROOF_SHADOW_W;
    var CW = W * 1.7;
    var OV = 0;
    var edgeM:Array<Matrix4> = [];
    var cornM:Array<Matrix4> = [];
    inline function push(arr:Array<Matrix4>, len1:Float, len2:Float, yaw:Float, px:Float, py:Float, pz:Float) {
      q.setFromAxisAngle(up, yaw).multiply(qx);
      pos.set(px, py, pz);
      scl.set(len1, len2, 1);
      arr.push(new Matrix4().compose(pos, q, scl));
    }
    for (b in buildings) {
      if (b.facade == 3) continue; // metal warehouses have a gable roof, not a flat parapet roof
      var wWorld = b.w * CELL;
      var dWorld = b.d * CELL;
      var center = cellToWorld(b.col + (b.w - 1) / 2, b.row + (b.d - 1) / 2);
      var y = b.h + 0.03;
      var offX = wWorld / 2 - RenderConfig.PARAPET_T / 2 + OV;
      var offZ = dWorld / 2 - RenderConfig.PARAPET_T / 2 + OV;
      // skip shadow where the parapet was removed at a same-height junction, else
      // a contact-shadow band lingers on the roof with no wall to cast it
      var covered = coveredEdges(b);
      var bxMin = center.x - wWorld / 2, bxMax = center.x + wWorld / 2;
      var bzMin = center.z - dWorld / 2, bzMax = center.z + dWorld / 2;
      // shadow follows wall: edge bands only on exposed (parapet-bearing) spans, cut
      // at same-height seams where the parapet — and so its shadow — was removed
      for (seg in exposedSpans(covered, 0, bxMin, bxMax, 0)) push(edgeM, seg.b - seg.a, W, 0, (seg.a + seg.b) / 2, y, center.z + offZ - W / 2);
      for (seg in exposedSpans(covered, 1, bxMin, bxMax, 0)) push(edgeM, seg.b - seg.a, W, Math.PI, (seg.a + seg.b) / 2, y, center.z - offZ + W / 2);
      for (seg in exposedSpans(covered, 2, bzMin, bzMax, 0)) push(edgeM, seg.b - seg.a, W, Math.PI / 2, center.x + offX - W / 2, y, (seg.a + seg.b) / 2);
      for (seg in exposedSpans(covered, 3, bzMin, bzMax, 0)) push(edgeM, seg.b - seg.a, W, -Math.PI / 2, center.x - offX + W / 2, y, (seg.a + seg.b) / 2);
      // convex corner radials — only at real outline corners. skip any corner whose
      // adjacent edge is covered there (a junction/colinear point, no two walls meet)
      function coveredAt(dir:Int, coord:Float):Bool {
        for (iv in covered[dir]) if (iv.a - 1e-4 <= coord && coord <= iv.b + 1e-4) return true;
        return false;
      }
      var SR = W * 0.7; // concave radials a touch smaller than the band so they never overgrow it
      inline function concave(px:Float, pz:Float, nsx:Float, nsz:Float) {
        var yaw = nsx > 0 ? (nsz > 0 ? 0.0 : Math.PI / 2) : (nsz > 0 ? -Math.PI / 2 : Math.PI);
        push(cornM, SR, SR, yaw, px - nsx * SR / 2, y, pz - nsz * SR / 2);
      }
      // per outline corner: outward diagonal void (else buried → skip). both edges
      // exposed → real convex corner. both edges covered but the diagonal still open →
      // a reentrant corner where the void is only the diagonal notch (e.g. a + centre,
      // fully ringed by arms); its two interior walls meet here → concave radial. one
      // edge covered → a colinear straight point, no radial
      var corners:Array<Array<Float>> = [[1, 1, 0], [1, -1, Math.PI / 2], [-1, -1, Math.PI], [-1, 1, -Math.PI / 2]];
      for (cdef in corners) {
        var sx = cdef[0], sz = cdef[1], yaw = cdef[2];
        var cornerX = center.x + sx * wWorld / 2, cornerZ = center.z + sz * dWorld / 2;
        if (cornerBuried(b, cornerX, cornerZ, sx, sz)) continue;
        var ec0 = coveredAt(sz > 0 ? 0 : 1, cornerX), ec1 = coveredAt(sx > 0 ? 2 : 3, cornerZ);
        if (!ec0 && !ec1) push(cornM, CW, CW, yaw, center.x + sx * (offX - CW / 2), y, center.z + sz * (offZ - CW / 2));
        else if (ec0 && ec1) concave(cornerX, cornerZ, sx, sz);
      }
      // reentrant corner at the interior end of a covered span (an L/T tip), where two
      // exposed perimeter walls meet at an inside corner — fill that nook
      for (iv in covered[0]) { if (iv.a > bxMin + 1e-4) concave(iv.a, bzMax, -1, 1); if (iv.b < bxMax - 1e-4) concave(iv.b, bzMax, 1, 1); }
      for (iv in covered[1]) { if (iv.a > bxMin + 1e-4) concave(iv.a, bzMin, -1, -1); if (iv.b < bxMax - 1e-4) concave(iv.b, bzMin, 1, -1); }
      for (iv in covered[2]) { if (iv.a > bzMin + 1e-4) concave(bxMax, iv.a, 1, -1); if (iv.b < bzMax - 1e-4) concave(bxMax, iv.b, 1, 1); }
      for (iv in covered[3]) { if (iv.a > bzMin + 1e-4) concave(bxMin, iv.a, -1, -1); if (iv.b < bzMax - 1e-4) concave(bxMin, iv.b, -1, 1); }
    }
    var sets = [{ mats: edgeM, tex: Textures.makeShadowGradient() }, { mats: cornM, tex: Textures.makeRadialShadowGradient() }];
    for (s in sets) {
      var mesh = new InstancedMesh(geo, mkMat(s.tex), s.mats.length);
      for (k in 0...s.mats.length) mesh.setMatrixAt(k, s.mats[k]);
      mesh.instanceMatrix.needsUpdate = true;
      scene.add(mesh);
    }
  }

  // roof details: a top-down sprite decal per sector, instanced per type
  static function addRoofDetails(scene:Scene):Void {
    var sprites = [for (t in DETAIL_TYPES) Textures.loadKeyedTexture(t.tex, t.crop, RenderConfig.DETAIL_BOX_COLOR)];
    var decalM:Array<Array<Matrix4>> = [for (t in DETAIL_TYPES) []];
    var q = new Quaternion();
    var qx = new Quaternion().setFromAxisAngle(new Vector3(1, 0, 0), -Math.PI / 2);
    var up = new Vector3(0, 1, 0);
    var pos = new Vector3();
    var scl = new Vector3();

    for (b in buildings) {
      if (b.facade == 3) continue; // metal warehouses have a gable roof — no rooftop details
      var wWorld = b.w * CELL;
      var dWorld = b.d * CELL;
      var hx = wWorld / 2 - RenderConfig.ROOF_DETAIL_MARGIN;
      var hz = dWorld / 2 - RenderConfig.ROOF_DETAIL_MARGIN;
      if (hx <= 0 || hz <= 0) continue;
      var center = cellToWorld(b.col + (b.w - 1) / 2, b.row + (b.d - 1) / 2);

      var cols = Std.int(imax(1, Math.round((2 * hx) / RenderConfig.ROOF_SECTOR)));
      var rows = Std.int(imax(1, Math.round((2 * hz) / RenderConfig.ROOF_SECTOR)));
      while (cols * rows > RenderConfig.DETAIL_MAX) { if (cols >= rows) cols--; else rows--; }
      var secW = (2 * hx) / cols;
      var secD = (2 * hz) / rows;

      var order = [for (i in 0...DETAIL_TYPES.length) i];
      var i = order.length - 1;
      while (i > 0) {
        var j = Std.int(Math.random() * (i + 1));
        var tmp = order[i]; order[i] = order[j]; order[j] = tmp;
        i--;
      }
      var pick = 0;
      for (ci in 0...cols) {
        for (cj in 0...rows) {
          var t = order[(pick++) % order.length];
          var type = DETAIL_TYPES[t];
          var yaw = Std.int(Math.random() * 4) * (Math.PI / 2);
          var x = center.x - hx + (ci + 0.5) * secW;
          var z = center.z - hz + (cj + 0.5) * secD;
          q.setFromAxisAngle(up, yaw).multiply(qx);
          pos.set(x, b.h + 0.05, z);
          scl.set(type.w, type.d, 1);
          decalM[t].push(new Matrix4().compose(pos, q, scl));
        }
      }
    }

    var decalGeo = new PlaneGeometry(1, 1);
    for (t in 0...DETAIL_TYPES.length) {
      if (decalM[t].length == 0) continue;
      var mat = new MeshStandardMaterial({ map: sprites[t], roughness: 1, metalness: 0, transparent: false, alphaTest: 0.5, side: THREE.DoubleSide });
      var decals = new InstancedMesh(decalGeo, mat, decalM[t].length);
      for (k in 0...decalM[t].length) decals.setMatrixAt(k, decalM[t][k]);
      decals.instanceMatrix.needsUpdate = true;
      scene.add(decals);
    }
  }

  // every window as an instance, bucketed by facade variant × lit/dark
  static function addWindows(scene:Scene):Void {
    var dark = [for (i in 0...TEXTURES.windows.length) spriteTex(TEXTURES.windows[i], i)];
    var lit = [for (i in 0...TEXTURES.litWindows.length) spriteTex(TEXTURES.litWindows[i], i)];
    var variants = dark.length;

    var buckets:Array<Array<Array<Matrix4>>> = [for (i in 0...variants) [[], []]];
    var q = new Quaternion();
    var pos = new Vector3();

    for (b in buildings) {
      if (b.shop >= 0) continue; // single-story shops have no upper-floor windows
      if (b.facade == 3) continue; // metal warehouses: no windows (closed doors instead)
      if (frontInfo(b).simple && !frontInfo(b).windows) continue; // plain (window-roll fail) or small building: no windows
      var v = b.facade % variants;
      var crop = RenderConfig.WINDOW_SPRITE_CROP[v];
      var winH = RenderConfig.WIN_W * (crop.y / crop.x);
      var scl = new Vector3(RenderConfig.WIN_W, winH, 1);
      var wWorld = b.w * CELL;
      var dWorld = b.d * CELL;
      var center = cellToWorld(b.col + (b.w - 1) / 2, b.row + (b.d - 1) / 2);
      var eps = 0.06;

      var faces = [
        { faceW: wWorld, rotY: 0.0, dir: 0, place: function(u:Float) return { x: center.x + u, z: center.z + dWorld / 2 + eps } },
        { faceW: wWorld, rotY: Math.PI, dir: 1, place: function(u:Float) return { x: center.x + u, z: center.z - dWorld / 2 - eps } },
        { faceW: dWorld, rotY: Math.PI / 2, dir: 2, place: function(u:Float) return { x: center.x + wWorld / 2 + eps, z: center.z + u } },
        { faceW: dWorld, rotY: -Math.PI / 2, dir: 3, place: function(u:Float) return { x: center.x - wWorld / 2 - eps, z: center.z + u } },
      ];

      var floors = Std.int(imax(1, Math.round((b.h - GROUND_H) / FLOOR_H)));
      for (f in faces) {
        var forced = b.winForce != null && b.winForce.indexOf(f.dir) >= 0;
        var blocked = b.winBlock != null && b.winBlock.indexOf(f.dir) >= 0;
        var centerAlong = f.dir < 2 ? center.x : center.z;
        q.setFromEuler(new Euler(0, f.rotY, 0));
        // place one window column (all floors) at world position `cx` along the face
        function emit(cx:Float):Void {
          winSeen.set(b, true); // checklist: this building rendered at least one window
          var p = f.place(cx - centerAlong);
          for (j in 0...floors) {
            if (j == b.skipWindowFloor) continue;
            var y = GROUND_H + (j + 0.5) * FLOOR_H;
            pos.set(p.x, y, p.z);
            var m = new Matrix4().compose(pos, q, scl);
            var isLit = Math.random() < RenderConfig.LIT_RATIO ? 1 : 0;
            buckets[v][isLit].push(m);
          }
        }
        // forced courtyard wall: own centred grid, inset from the face edges
        if (forced && b.winInset > 0) {
          var half = f.faceW / 2 - b.winInset;
          for (cx in centeredCols(centerAlong - half, centerAlong + half)) emit(cx);
          continue;
        }
        // which tile-runs of this face are windowed: street/forced frontage = whole
        // face; otherwise the open runs (partial L/T/+ inner walls). winBlock only
        // suppresses the street/forced frontage — an inner wall that opens onto a
        // notch/alley (openWinRuns) still earns windows even if blocked
        var runs:Array<{lo:Int, hi:Int}>;
        if (forced || (faceIsStreet(b, f.dir) && !blocked)) {
          var fl = f.dir < 2 ? b.col : b.row;
          var fh = (f.dir < 2 ? b.col + b.w : b.row + b.d) - 1;
          runs = [{ lo: fl, hi: fh }];
        } else runs = openWinRuns(b, f.dir, blocked);
        for (run in runs) {
          // centre window columns on the WHOLE contiguous wall (this run extended
          // through flush neighbour pieces), then emit only this run's own slice so
          // each piece's part is symmetric yet continuous across a shared seam
          var ext = wallExtent(b, f.dir, run.lo, run.hi);
          var extA = (ext.lo - GRID / 2) * CELL, extB = (ext.hi + 1 - GRID / 2) * CELL;
          var runA = (run.lo - GRID / 2) * CELL, runB = (run.hi + 1 - GRID / 2) * CELL;
          for (cx in centeredCols(extA, extB)) if (cx >= runA - 0.01 && cx < runB - 0.01) emit(cx);
        }
      }
    }

    var geo = new PlaneGeometry(1, 1);
    var litColor = new Color(RenderConfig.WINDOW_LIT_COLOR);
    for (v in 0...variants) {
      for (l in 0...2) {
        var mats = buckets[v][l];
        if (mats.length == 0) continue;
        var tex = l == 1 ? lit[v] : dark[v];
        var mat = new MeshStandardMaterial({ map: tex, roughness: 1, metalness: 0, alphaTest: 0.5 });
        tag(mat, l == 1 ? 'window-lit-${v + 1}' : 'window-${v + 1}',
          l == 1 ? 'lit window ${v + 1}' : 'window ${v + 1}',
          (l == 1 ? TEXTURES.litWindows : TEXTURES.windows)[v]);
        if (l == 1) {
          mat.emissive = litColor;
          mat.emissiveMap = tex;
          mat.emissiveIntensity = RenderConfig.WINDOW_LIT_INTENSITY;
        }
        var inst = new InstancedMesh(geo, mat, mats.length);
        for (k in 0...mats.length) inst.setMatrixAt(k, mats[k]);
        inst.instanceMatrix.needsUpdate = true;
        scene.add(inst);
      }
    }
  }

  static function spriteTex(path:String, variant:Int):Texture {
    var crop = RenderConfig.WINDOW_SPRITE_CROP[variant];
    var tex = Textures.loadCroppedTexture(path, crop.x, crop.y);
    tex.wrapS = tex.wrapT = THREE.ClampToEdgeWrapping;
    return tex;
  }
}
