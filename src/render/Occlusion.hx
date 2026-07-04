package render;

import three.Three;
import citygen.CityConfig;
import citygen.CityConfig.cellToWorld;
import citygen.CityModel.Building;

// one fadeable material + the base state we lerp its opacity down from and back to.
// curT tracks the live transparent flag so we recompile (needsUpdate) only when it flips
typedef FadeMat = { mat:Dynamic, opacity:Float, transparent:Bool, depthWrite:Bool, emissive:Float, curT:Bool };
// per-building fade record: its world AABB, its (de-shared) materials, and the eased fade
typedef Occ = {
  minX:Float, maxX:Float, minZ:Float, maxZ:Float, maxY:Float, cx:Float, cz:Float,
  mats:Array<FadeMat>, fade:Float, target:Float
};

// fades a building to semi-transparent while it sits between the camera and the player, so
// the player never hides behind a wall. Built once per city: derives each building's world
// AABB and buckets every scene mesh into the building it belongs to (by userData.b, else by
// position), cloning any material shared between buildings so each fades independently. Each
// frame a segment/AABB slab test picks the occluders and eases their opacity. StreetView owns
// and drives it.
class Occlusion {
  static inline var CELL = CityConfig.CELL;
  static var checked = false;

  var occ:Array<Occ> = [];

  public function new(scene:Scene, buildings:Array<Building>)
    {
      if (!checked) { checked = true; if (!demo()) js.Browser.console.warn('[occlusion] self-check FAILED'); }
      // one fade record + world AABB per building; map Building -> index for userData bucketing
      var idxOf = new haxe.ds.ObjectMap<Building, Int>();
      for (i in 0...buildings.length)
        {
          var b = buildings[i];
          var c = cellToWorld(b.col + (b.w - 1) / 2, b.row + (b.d - 1) / 2);
          var hw = b.w * CELL / 2, hd = b.d * CELL / 2;
          occ.push({ minX: c.x - hw, maxX: c.x + hw, minZ: c.z - hd, maxZ: c.z + hd, maxY: b.h,
            cx: c.x, cz: c.z, mats: [], fade: 1.0, target: 1.0 });
          idxOf.set(b, i);
        }
      // bucket every mesh into its building and de-share its materials
      scene.traverse(function(o:Object3D) {
        if (untyped o.isMesh != true && o.isInstancedMesh != true) return;
        var bi = pick(o, idxOf);
        if (bi < 0) return;
        var m:Dynamic = o.material;
        if (m == null) return;
        if (Std.isOfType(m, Array))
          {
            var arr:Array<Dynamic> = m;
            for (k in 0...arr.length) arr[k] = own(arr[k], bi);
          }
        else o.material = own(m, bi);
      });
    }

// which building a mesh belongs to: its userData.b tag if present (box + window meshes),
// else the nearest-centre building whose AABB (margin-expanded for face-proud decals) holds it
  function pick(o:Object3D, idxOf:haxe.ds.ObjectMap<Building, Int>):Int
    {
      var b:Building = (o.userData != null) ? o.userData.b : null;
      if (b != null && idxOf.exists(b)) return idxOf.get(b);
      var px = o.position.x, pz = o.position.z, m = RenderConfig.OCCLUSION.margin;
      var best = -1;
      var bestD = 1e18;
      for (i in 0...occ.length)
        {
          var e = occ[i];
          if (px < e.minX - m || px > e.maxX + m || pz < e.minZ - m || pz > e.maxZ + m) continue;
          var dx = px - e.cx, dz = pz - e.cz, d = dx * dx + dz * dz;
          if (d < bestD) { bestD = d; best = i; }
        }
      return best;
    }

// hand back a material private to building bi, recording its base state once: return it as-is
// the first time (tagged owner=bi), skip if already ours, clone it if another building owns it
  function own(m:Dynamic, bi:Int):Dynamic
    {
      var owner:Null<Int> = untyped m.__occOwner;
      if (owner == bi) return m;               // already ours + recorded
      if (owner == null) { untyped m.__occOwner = bi; record(m, bi); return m; }
      var c:Dynamic = m.clone();               // shared with another building -> private copy
      untyped c.__occOwner = bi;
      record(c, bi);
      return c;
    }

// snapshot a material's solid-state values so fade can scale from them and restore them
  function record(m:Dynamic, bi:Int):Void
    {
      occ[bi].mats.push({ mat: m,
        opacity: (m.opacity == null ? 1.0 : m.opacity),
        transparent: (m.transparent == true),
        depthWrite: (m.depthWrite == null ? true : m.depthWrite),
        emissive: (m.emissiveIntensity == null ? -1.0 : m.emissiveIntensity),
        curT: (m.transparent == true) });
    }

// per frame: target-fade the occluders, ease every non-resting building toward its target
  public function update(camPos:Vector3, player:Vector3, dtMs:Float):Void
    {
      // frame-rate-independent smoothing (same exponential decay as CameraRig zoom)
      var k = 1 - Math.pow(1 - RenderConfig.OCCLUSION.lerp, dtMs / (1000 / 30));
      for (o in occ)
        {
          o.target = segHitsBox(camPos.x, camPos.y, camPos.z, player.x, player.y, player.z,
            o.minX, o.maxX, o.minZ, o.maxZ, o.maxY) ? RenderConfig.OCCLUSION.fade : 1.0;
          if (o.fade == o.target && o.target == 1.0) continue; // solid and staying solid
          o.fade += (o.target - o.fade) * k;
          if (Math.abs(o.fade - o.target) < 0.003) o.fade = o.target;
          apply(o);
        }
    }

// push the current fade onto a building's materials (opacity + see-through depth + bloom cut)
  function apply(o:Occ):Void
    {
      var f = o.fade, faded = f < 0.999;
      for (fm in o.mats)
        {
          var m = fm.mat;
          var wantT = fm.transparent || faded;
          // three keeps the opaque shader until needsUpdate; only recompile on the actual flip
          if (wantT != fm.curT) { fm.curT = wantT; m.needsUpdate = true; }
          m.transparent = wantT;
          m.opacity = fm.opacity * f;
          m.depthWrite = faded ? false : fm.depthWrite;
          if (fm.emissive >= 0) m.emissiveIntensity = fm.emissive * f; // lit windows stop blooming
        }
    }

// does segment a->b pass through the box (strictly between the endpoints)? slab clip
  static function segHitsBox(ax:Float, ay:Float, az:Float, bx:Float, by:Float, bz:Float,
    x0:Float, x1:Float, z0:Float, z1:Float, y1:Float):Bool
    {
      var t = [0.0, 1.0];
      if (!clip(ax, bx, x0, x1, t)) return false;
      if (!clip(ay, by, 0, y1, t)) return false;
      if (!clip(az, bz, z0, z1, t)) return false;
      return t[1] > 0.001 && t[0] < 0.999 && t[0] <= t[1];
    }

// clip param range t=[enter,exit] against one axis slab [lo,hi]; false if it empties the range
  static function clip(p0:Float, p1:Float, lo:Float, hi:Float, t:Array<Float>):Bool
    {
      var d = p1 - p0;
      if (d > -1e-9 && d < 1e-9) return p0 >= lo && p0 <= hi; // parallel: inside slab or miss
      var ta = (lo - p0) / d, tb = (hi - p0) / d;
      if (ta > tb) { var tmp = ta; ta = tb; tb = tmp; }
      if (ta > t[0]) t[0] = ta;
      if (tb < t[1]) t[1] = tb;
      return t[0] <= t[1];
    }

// self-check for the slab test: a box on the line hits, boxes beside/behind it miss
  static function demo():Bool
    {
      // box [-1..1]^3-ish straddling the segment from (0,0,-10) to (0,0,10)
      var hit = segHitsBox(0, 0, -10, 0, 0, 10, -1, 1, -1, 1, 2);
      // box off to the side of the same line
      var side = segHitsBox(0, 0, -10, 0, 0, 10, 5, 7, -1, 1, 2);
      // box beyond the far endpoint (player at z=10, box at z=20..22)
      var beyond = segHitsBox(0, 0, -10, 0, 0, 10, -1, 1, 20, 22, 2);
      return hit && !side && !beyond;
    }
}
