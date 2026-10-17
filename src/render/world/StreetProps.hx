package render.world;

import three.Three;
import citygen.CityConfig;
import citygen.CityConfig.cellToWorld;
import citygen.CityModel.Building;
import render.RenderConfig;

// one module of a wall kit set down on a building
typedef KitPlace = {
  b:Building, // the building it hangs on, which its merged mesh is tagged with
  key:String, // the module: the suffix of its mesh's name in the kit glb (floor, base, pipe, ...)
  m:Matrix4,  // where it stands
};

// the street wall kit: fire escapes and downpipes on the residential facades, conduit, junction
// boxes and intake louvres on downtown's service walls (AreaStyle.wallKit). one glb per kit, every
// module a mesh of its own authored in world units against the wall (models-src/city/kit/wallkit.py),
// and every building's modules MERGED into one mesh tagged userData.b: one draw call per dressed
// building, faded with its walls by render.Occlusion. render-only and hashed off the footprint, like
// the wall decals, so a building dresses the same on every entry
class StreetProps
{
  static inline var GRID = CityConfig.GRID;
  static inline var CELL = CityConfig.CELL;
  // the kit's own numbers (models-src/city/kit/wallkit*.py): a fire-escape platform's half width, a
  // downpipe's offset past its end window column and the half width it keeps clear of a door, the
  // downtown conduit run's height (over the 3.9 door quads) and a riser's and a louvre's half widths
  static inline var PLATFORM_HALF = 2.4;
  static inline var PIPE_OFF = 1.25;
  static inline var PIPE_HALF = 0.3;
  static inline var RUN_Y = 4.3;
  static inline var RISER_HALF = 0.6;
  static inline var LOUVRE_HALF = 0.75;

  static var checked = false;

// lay the area style's wall kit out over the city WorldCtx holds, then merge each building's set into
// one mesh once the kit glb is in. `done` gets the meshes: right away when the glb is cached (the boot
// warm loads it), on the loader callback otherwise, when the caller's fader has to adopt them
  public static function build(scene:Scene, done:Array<Mesh>->Void):Void
    {
      if (!checked)
        {
          checked = true;
          if (!demo())
            js.Browser.console.warn('[street-props] self-check FAILED');
        }
      var st = WorldCtx.style;
      if (st.wallKit == null)
        return;
      var list:Array<KitPlace> = [];
      for (b in WorldCtx.buildings)
        {
          // a setback tier stands on the deck of the one below, so nothing of it reaches the street
          var cols = WorldCtx.winCols.get(b);
          if (cols != null &&
              b.buriedH == 0)
            downpipe(b, cols, st, fireEscape(b, cols, st, list), list);
          if (st.serviceChance > 0)
            service(b, st, list);
        }
      Models.get(st.wallKit, function(t)
        {
          done(merge(scene, t, list));
        });
    }

// a fire escape over two neighbouring window columns of one face, clear of that face's doors: the
// base platform on the first window floor, a platform and its stair down on every floor above.
// returns the two columns, or null when the building drew none
  static function fireEscape(b:Building, cols:Array<WorldCtx.WinCol>, st:AreaStyle, list:Array<KitPlace>):Array<WorldCtx.WinCol>
    {
      var h = hash(b, 1);
      var floors = floorsOf(b);
      if (h % 1000 >= st.fireEscapeChance * 1000 ||
          floors < 2)
        return null;
      var pairs:Array<Array<WorldCtx.WinCol>> = [];
      for (a in cols)
        for (c in cols)
          if (a.dir == c.dir &&
              Math.abs(along(c) - along(a) - RenderConfig.WIN_PITCH_X) < 0.05 &&
              !onDoor(b, a.dir, (along(a) + along(c)) / 2, PLATFORM_HALF))
            pairs.push([a, c]);
      if (pairs.length == 0)
        return null;
      var p = pairs[(h >> 10) % pairs.length];
      for (j in 0...floors)
        list.push({
          b: b,
          key: (j == 0 ? 'base' : 'floor'),
          m: at((p[0].x + p[1].x) / 2, CityConfig.GROUND_H + j * CityConfig.FLOOR_H, (p[0].z + p[1].z) / 2, p[0].rotY),
        });
      return p;
    }

// a downpipe down the wall beside one end window column, on the fire escape's face when there is one
// and at the end away from it: the hopper head under the roofline, a length per window floor, the
// shoe at the foot. a broken one (AreaStyle.downpipeBroken) has lost its shoe and one length
  static function downpipe(b:Building, cols:Array<WorldCtx.WinCol>, st:AreaStyle, fe:Array<WorldCtx.WinCol>, list:Array<KitPlace>):Void
    {
      var h = hash(b, 2);
      if (h % 1000 >= st.downpipeChance * 1000)
        return;
      var dirs:Array<Int> = [];
      for (c in cols)
        if (dirs.indexOf(c.dir) < 0)
          dirs.push(c.dir);
      var dir = (fe != null ? fe[0].dir : dirs[(h >> 10) % dirs.length]);
      var face = [for (c in cols) if (c.dir == dir) c];
      face.sort(function(a, c) return (along(a) < along(c) ? -1 : 1));
      var lo = face[0];
      var hi = face[face.length - 1];
      var mid = (fe != null && fe[0].dir == dir ? (along(fe[0]) + along(fe[1])) / 2 : null);
      // the end away from the fire escape first
      var ends = (mid != null && mid > (along(lo) + along(hi)) / 2 ? [lo, hi] : [hi, lo]);
      for (e in ends)
        {
          var a = along(e) + (e == hi ? PIPE_OFF : -PIPE_OFF);
          if (onDoor(b, dir, a, PIPE_HALF) ||
              (mid != null &&
              Math.abs(a - mid) < PLATFORM_HALF + PIPE_HALF))
            continue;
          var x = (dir < 2 ? a : e.x);
          var z = (dir < 2 ? e.z : a);
          var floors = floorsOf(b);
          var broken = (h >> 12) % 1000 < st.downpipeBroken * 1000;
          var lost = (broken && floors > 1 ? (h >> 4) % (floors - 1) : -1);
          if (!broken)
            list.push({
              b: b,
              key: 'shoe',
              m: at(x, 0, z, e.rotY),
            });
          for (j in 0...floors)
            if (j != lost)
              list.push({
                b: b,
                key: 'pipe',
                m: at(x, CityConfig.GROUND_H + j * CityConfig.FLOOR_H, z, e.rotY),
              });
          list.push({
            b: b,
            key: 'head',
            m: at(x, b.h - CityConfig.TOP_MARGIN, z, e.rotY),
          });
          return;
        }
    }

// a downtown service wall: on each open run of a worn face, a conduit run the run's whole length
// hung over the doors, a riser into a junction box at one cell and an intake louvre at another, each
// left out where it would land on a door
  static function service(b:Building, st:AreaStyle, list:Array<KitPlace>):Void
    {
      if (b.buriedH > 0 ||
          b.h < RUN_Y + 1.0)
        return;
      var c = cellToWorld(b.col + (b.w - 1) / 2, b.row + (b.d - 1) / 2);
      for (f in Geom.buildingFaces(c, b.w * CELL, b.d * CELL, 0.06))
        {
          var h = hash(b, 3 + f.dir);
          if (!Geom.isWornFace(b, f.dir) ||
              h % 1000 >= st.serviceChance * 1000)
            continue;
          for (run in Geom.doorRuns(b, f.dir))
            {
              var n = run.hi - run.lo + 1;
              if (n < 2)
                continue;
              // a cell of the run as the world coordinate along the face, and the face point there
              function pos(i:Int, y:Float, key:String):Void
                {
                  var a = (run.lo + i + 0.5 - GRID / 2) * CELL;
                  list.push({
                    b: b,
                    key: key,
                    m: at((f.dir < 2 ? a : f.fx), y, (f.dir < 2 ? f.fz : a), f.rotY),
                  });
                }
              function clear(i:Int, half:Float):Bool
                return !onDoor(b, f.dir, (run.lo + i + 0.5 - GRID / 2) * CELL, half);
              for (i in 0...n)
                pos(i, RUN_Y, 'conduit');
              var ri = (h >> 8) % n;
              var li = (ri + 1 + (h >> 12) % (n - 1)) % n;
              if (clear(ri, RISER_HALF))
                pos(ri, 0, 'riser');
              if (clear(li, LOUVRE_HALF))
                pos(li, 0, 'louvre');
            }
        }
    }

// merge every building's modules into one mesh in the kit's own material, tagged with the building.
// the modules are the kit glb's meshes, keyed by the suffix kit_build.py `pack` names them with
  static function merge(scene:Scene, t:Models.ModelTemplate, list:Array<KitPlace>):Array<Mesh>
    {
      var src = new Map<String, BufferGeometry>();
      var first:Object3D = null;
      t.pivot.traverse(function(o)
        {
          if (o.geometry == null)
            return;
          src.set(o.name.substr(o.name.lastIndexOf('-') + 1), o.geometry);
          if (first == null)
            first = o;
        });
      var by = new haxe.ds.ObjectMap<Building, Array<BufferGeometry>>();
      var order:Array<Building> = [];
      for (k in list)
        {
          var geos = by.get(k.b);
          if (geos == null)
            {
              geos = [];
              by.set(k.b, geos);
              order.push(k.b);
            }
          var g:BufferGeometry = src.get(k.key);
          geos.push(g.clone().applyMatrix4(k.m));
        }
      var out:Array<Mesh> = [];
      for (b in order)
        {
          var geos = by.get(b);
          var mesh = new Mesh(THREE.mergeGeometries(geos, false), first.material);
          for (g in geos)
            g.dispose();
          mesh.name = 'wall kit';
          mesh.userData.b = b;
          // darkens with the wall under a neighbour's or a lamp's shadow, as the windows do
          mesh.receiveShadow = true;
          scene.add(mesh);
          out.push(mesh);
        }
      return out;
    }

// how many window floors the building has, as Windows.add counts them
  static inline function floorsOf(b:Building):Int
    {
      return Std.int(Math.max(1, Math.round((b.h - CityConfig.GROUND_H) / CityConfig.FLOOR_H)));
    }

// a window column's world coordinate ALONG its face (x on the north/south faces, z on east/west)
  static inline function along(c:WorldCtx.WinCol):Float
    {
      return (c.dir < 2 ? c.x : c.z);
    }

// does a span of half width `half` centred at world coordinate `a` along face `dir` overlap a door
// Entrances placed there? its spans are offsets off the building's centre along that face
  static function onDoor(b:Building, dir:Int, a:Float, half:Float):Bool
    {
      var c = cellToWorld(b.col + (b.w - 1) / 2, b.row + (b.d - 1) / 2);
      var off = a - (dir < 2 ? c.x : c.z);
      for (ds in WorldCtx.doorSpans)
        if (ds.b == b &&
            ds.dir == dir &&
            off - half < ds.hi &&
            off + half > ds.lo)
          return true;
      return false;
    }

// a module standing at (x, y, z), turned to face out along rotY
  static function at(x:Float, y:Float, z:Float, rotY:Float):Matrix4
    {
      return new Matrix4().makeRotationY(rotY).setPosition(x, y, z);
    }

// a per-building decision hash off the footprint (`salt` keeps the decisions apart)
  static inline function hash(b:Building, salt:Int):Int
    {
      return ((b.col * 83492791) ^ (b.row * 50331653) ^ (salt * 961748941)) & 0x7fffffff;
    }

// self-check: a module turned to face +x stands out along +x (the kit's local +z, its outward side),
// so every face's rotY puts the kit on the street side of its wall
  static function demo():Bool
    {
      var v = new Vector3(0, 0, 1).applyMatrix4(at(0, 0, 0, Geom.faceRotY(2)));
      var w = new Vector3(0, 0, 1).applyMatrix4(at(0, 0, 0, Geom.faceRotY(1)));
      return Math.abs(v.x - 1) < 1e-9 &&
        Math.abs(w.z + 1) < 1e-9;
    }
}
