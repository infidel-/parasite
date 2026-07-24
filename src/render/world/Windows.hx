package render.world;

import three.Three;
import citygen.CityConfig;
import citygen.CityConfig.cellToWorld;
import render.RenderConfig;
import render.RenderConfig.TEXTURES;
import render.Textures;
import render.Poly.tag;

// every upper-floor window as an instance, bucketed by facade variant × lit/dark.
// Which faces/runs get windows comes from Geom (street frontage, forced courtyard
// walls, or open L/T/+ inner runs); lit windows emit for the night bloom. Writes winSeen.
class Windows {
  static inline var GRID = CityConfig.GRID;
  static inline var CELL = CityConfig.CELL;
  static inline var GROUND_H = CityConfig.GROUND_H;
  static inline var FLOOR_H = CityConfig.FLOOR_H;

  static inline function imax(a:Float, b:Float):Float return a > b ? a : b;

  public static function add(scene:Scene):Void {
    var buildings = WorldCtx.buildings;
    var st = WorldCtx.style;
    var dark = [for (i in 0...st.windows.length) spriteTex(st.windows[i], st.winCrop[i])];
    var lit = [for (i in 0...st.litWindows.length) spriteTex(st.litWindows[i], st.winCrop[i])];
    var variants = dark.length;

    // one shared unit quad; windows are instanced PER BUILDING (own material) so the occlusion
    // fade can turn a single building's windows transparent without touching the rest of the city
    var geo = new PlaneGeometry(1, 1);
    var litColor = new Color(st.litColor);
    var q = new Quaternion();
    var pos = new Vector3();

    for (b in buildings) {
      if (b.shop >= 0) continue; // single-story shops have no upper-floor windows
      if (st.isSpecial(b.facade)) continue; // metal warehouses: no windows (closed doors instead)
      if (st.noWinSlots != null && st.noWinSlots.indexOf(b.facade) >= 0) continue; // glass curtain towers: windows live in the facade art
      if (Geom.frontInfo(b).simple && !Geom.frontInfo(b).windows) continue; // plain (window-roll fail) or small building: no windows
      var v = b.facade % variants;
      var buckets:Array<Array<Matrix4>> = [[], []]; // this building's [dark, lit] instance matrices
      var crop = st.winCrop[v];
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
        var wf = b.winForce != null && b.winForce.indexOf(f.dir) >= 0;
        var forced = wf || Geom.noBackWalls(b);
        var blocked = b.winBlock != null && b.winBlock.indexOf(f.dir) >= 0;
        var centerAlong = f.dir < 2 ? center.x : center.z;
        q.setFromEuler(new Euler(0, f.rotY, 0));
        // place one window column (all floors) at world position `cx` along the face
        function emit(cx:Float):Void {
          WorldCtx.winSeen.set(b, true); // checklist: this building rendered at least one window
          var p = f.place(cx - centerAlong);
          for (j in 0...floors) {
            if (j == b.skipWindowFloor) continue;
            var y = GROUND_H + (j + 0.5) * FLOOR_H;
            pos.set(p.x, y, p.z);
            var m = new Matrix4().compose(pos, q, scl);
            var isLit = Math.random() < st.litRatio ? 1 : 0;
            buckets[isLit].push(m);
          }
        }
        // forced courtyard wall: own centred grid, inset from the face edges. keyed off the
        // building's OWN winForce, not the style's no-back-walls rule — that one must not pull
        // a tall courtyard strip's street faces onto the inner wall's inset grid
        if (wf && b.winInset > 0) {
          var half = f.faceW / 2 - b.winInset;
          for (cx in Geom.centeredCols(centerAlong - half, centerAlong + half)) emit(cx);
          continue;
        }
        // which tile-runs of this face are windowed: street/forced frontage = whole
        // face; otherwise the open runs (partial L/T/+ inner walls). winBlock only
        // suppresses the street/forced frontage — an inner wall that opens onto a
        // notch/alley (openWinRuns) still earns windows even if blocked
        var runs:Array<{lo:Int, hi:Int}>;
        if (forced || (Geom.faceIsStreet(b, f.dir) && !blocked)) {
          var fl = f.dir < 2 ? b.col : b.row;
          var fh = (f.dir < 2 ? b.col + b.w : b.row + b.d) - 1;
          runs = [{ lo: fl, hi: fh }];
        } else runs = Geom.openWinRuns(b, f.dir, blocked);
        for (run in runs) {
          // centre window columns on the WHOLE contiguous wall (this run extended
          // through flush neighbour pieces), then emit only this run's own slice so
          // each piece's part is symmetric yet continuous across a shared seam
          var ext = Geom.wallExtent(b, f.dir, run.lo, run.hi);
          var extA = (ext.lo - GRID / 2) * CELL, extB = (ext.hi + 1 - GRID / 2) * CELL;
          var runA = (run.lo - GRID / 2) * CELL, runB = (run.hi + 1 - GRID / 2) * CELL;
          for (cx in Geom.centeredCols(extA, extB)) if (cx >= runA - 0.01 && cx < runB - 0.01) emit(cx);
        }
      }

      // one instanced mesh per lit state actually used, tagged with the building so Occlusion
      // fades its windows along with the rest of the building box
      for (l in 0...2) {
        var mats = buckets[l];
        if (mats.length == 0) continue;
        var tex = l == 1 ? lit[v] : dark[v];
        var mat = new MeshStandardMaterial({
          map: tex,
          roughness: 1,
          metalness: 0,
          alphaTest: 0.5,
        });
        tag(mat, l == 1 ? 'window-lit-${v + 1}' : 'window-${v + 1}',
          l == 1 ? 'lit window ${v + 1}' : 'window ${v + 1}',
          (l == 1 ? st.litWindows : st.windows)[v]);
        if (l == 1) {
          mat.emissive = litColor;
          mat.emissiveMap = tex;
          mat.emissiveIntensity = st.litIntensity;
        }
        var inst = new InstancedMesh(geo, mat, mats.length);
        for (k in 0...mats.length) inst.setMatrixAt(k, mats[k]);
        inst.instanceMatrix.needsUpdate = true;
        inst.userData.b = b;
        inst.receiveShadow = true; // so windows darken with the wall in shadow (don't cast — thin planes)
        scene.add(inst);
      }
    }
  }

  static function spriteTex(path:String, crop:{ x:Float, y:Float }):Texture {
    var tex = Textures.loadCroppedTexture(path, crop.x, crop.y);
    tex.wrapS = tex.wrapT = THREE.ClampToEdgeWrapping;
    return tex;
  }

// sparse scattered accents over the baked glass-curtain grid: a fraction of the (already
// cell-locked) window cells get a tint variant or a lit/glowing pane, breaking the uniform
// tiled look. deterministic per cell (stable frame-to-frame), instanced PER BUILDING so
// Occlusion fades them with the tower. runs only for glass slots (winPerCell > 0); the 80%+
// of base cells stay the cheap baked texture with no instance at all.
  public static function addGlassAccents(scene:Scene):Void {
    var st = WorldCtx.style;
    if (st.glassAccents == null || st.winPerCell == null) return;
    // accent texture sets are per-facade (distinct families per glass tower type); load lazily & cache
    var setCache = new Map<Int, { tints:Array<Texture>, lit:Texture }>();
    inline function accentSet(f:Int):{ tints:Array<Texture>, lit:Texture } {
      if (!setCache.exists(f))
        setCache.set(f, { tints: [for (p in st.glassAccents[f]) accentTex(p)], lit: accentTex(st.glassAccentLit[f]) });
      return setCache.get(f);
    }
    var geo = new PlaneGeometry(1, 1);
    var q = new Quaternion();
    var pos = new Vector3();
    var eps = 0.07; // stand proud of the baked face (matches Windows.add standoff, avoids z-fight)

    for (b in WorldCtx.buildings) {
      var wpc = st.winPerCell[b.facade % st.winPerCell.length];
      if (wpc <= 0 || st.glassAccents[b.facade] == null) continue; // not a glass tower / no accent set
      var set = accentSet(b.facade);
      var cc = st.glassLitColor != null ? st.glassLitColor[b.facade] : 0;
      var litColor = new Color(cc != 0 ? cc : 0xffffff); // this tower type's glow tint (0/absent → white)
      var tints = set.tints;
      var litTex = set.lit;
      var nVar = tints.length;
      var wWorld = b.w * CELL;
      var dWorld = b.d * CELL;
      var center = cellToWorld(b.col + (b.w - 1) / 2, b.row + (b.d - 1) / 2);
      // vertical grid matches the baked tiling exactly (repeat_v = round(b.h/CELL))
      var rowsAll = Std.int(imax(1, Math.round(b.h / CELL)));
      var rowH = b.h / rowsAll;
      var rows = rowsAll; // top row is a real window floor — the coping rides on the wall head
      // a setback tier's rows below its deck are enclosed by the tier beneath — nothing there is
      // ever visible, so skip them (~29% of all glass cells on a stepped tower). glass heights are
      // CELL multiples, so the deck lands exactly on a row boundary. the bottom rows are the
      // solid podium band, which no accent may show through either
      var row0 = Std.int(Math.round(b.buriedH / rowH));
      if (row0 < CityConfig.GLASS_PODIUM_ROWS) row0 = CityConfig.GLASS_PODIUM_ROWS;
      var buckets:Array<Array<Matrix4>> = [for (i in 0...nVar + 1) []]; // per tint variant + lit
      var faces = [
        { n: b.w, rotY: 0.0,          dir: 0, place: function(u:Float) return { x: center.x + u, z: center.z + dWorld / 2 + eps } },
        { n: b.w, rotY: Math.PI,      dir: 1, place: function(u:Float) return { x: center.x + u, z: center.z - dWorld / 2 - eps } },
        { n: b.d, rotY: Math.PI / 2,  dir: 2, place: function(u:Float) return { x: center.x + wWorld / 2 + eps, z: center.z + u } },
        { n: b.d, rotY: -Math.PI / 2, dir: 3, place: function(u:Float) return { x: center.x - wWorld / 2 - eps, z: center.z + u } },
      ];
      var scl = new Vector3(CELL, rowH, 1);
      for (f in faces) {
        if (Geom.isWornFace(b, f.dir)) continue; // back/service face is baked blank (facade-glass-back) — no windows there
        q.setFromEuler(new Euler(0, f.rotY, 0));
        for (i in 0...f.n) {
          var p = f.place((i - (f.n - 1) / 2) * CELL); // this cell's centre along the face
          for (j in row0...rows) {
            // deterministic hash of the cell → base / tint variant / lit
            var hv = (b.col * 92837111) ^ (b.row * 689287499) ^ (f.dir * 283923481) ^ (i * 374761393) ^ (j * 668265263);
            hv = hv ^ (hv >>> 15);
            var r = (hv & 0xffff) / 65536;
            var bucket = -1;
            if (r < st.glassLitRatio) bucket = nVar; // lit pane
            else if (nVar > 0 && r < st.glassLitRatio + st.glassAccentRatio) bucket = (hv >>> 16) % nVar; // tint variant (nVar 0 → lit-only slot, e.g. sleek)
            if (bucket < 0) continue; // base cell: baked grid shows through, no instance
            pos.set(p.x, rowH * (j + 0.5), p.z);
            buckets[bucket].push(new Matrix4().compose(pos, q, scl));
          }
        }
      }
      // one instanced mesh per used bucket, tagged with the building so Occlusion fades it too
      for (bk in 0...buckets.length) {
        var mats = buckets[bk];
        if (mats.length == 0) continue;
        var lit = bk == nVar;
        var tex = lit ? litTex : tints[bk];
        var mat = new MeshStandardMaterial({ map: tex, roughness: 1, metalness: 0 });
        tag(mat, lit ? 'glass-lit-${b.facade}' : 'glass-accent-${b.facade}-${bk + 1}', lit ? 'lit glass pane' : 'glass accent ${bk + 1}',
          lit ? st.glassAccentLit[b.facade] : st.glassAccents[b.facade][bk]);
        if (lit) {
          mat.emissive = litColor;
          mat.emissiveMap = tex;
          mat.emissiveIntensity = st.glassLitIntensity; // skyscraper glow, independent of mid-rise windows
          // hand-cut window alpha on the lit tile: only the glowing glass draws (mullion/surround
          // transparent → baked wall shows through), so bloom is confined to the window, not the whole
          // cell. no-op while the texture is still fully opaque; activates once the alpha is painted.
          mat.alphaTest = 0.5;
        }
        var inst = new InstancedMesh(geo, mat, mats.length);
        for (k in 0...mats.length) inst.setMatrixAt(k, mats[k]);
        inst.instanceMatrix.needsUpdate = true;
        inst.userData.b = b;
        inst.receiveShadow = true;
        scene.add(inst);
      }
    }
  }

  static function accentTex(path:String):Texture {
    var tex = Textures.loadTexture(path, 'wall');
    tex.wrapS = tex.wrapT = THREE.ClampToEdgeWrapping;
    return tex;
  }
}
