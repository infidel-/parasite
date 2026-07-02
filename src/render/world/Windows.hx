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
    var dark = [for (i in 0...TEXTURES.windows.length) spriteTex(TEXTURES.windows[i], i)];
    var lit = [for (i in 0...TEXTURES.litWindows.length) spriteTex(TEXTURES.litWindows[i], i)];
    var variants = dark.length;

    var buckets:Array<Array<Array<Matrix4>>> = [for (i in 0...variants) [[], []]];
    var q = new Quaternion();
    var pos = new Vector3();

    for (b in buildings) {
      if (b.shop >= 0) continue; // single-story shops have no upper-floor windows
      if (b.facade == 3) continue; // metal warehouses: no windows (closed doors instead)
      if (Geom.frontInfo(b).simple && !Geom.frontInfo(b).windows) continue; // plain (window-roll fail) or small building: no windows
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
          WorldCtx.winSeen.set(b, true); // checklist: this building rendered at least one window
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
