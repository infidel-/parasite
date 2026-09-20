package render.corp;

import three.Three;
import citygen.CityConfig;
import citygen.CityGen;
import citygen.CityModel.City;
import citygen.CityModel.Tile;
import citygen.CityProfile.Profiles;
import render.RenderConfig;
import render.Textures;
import render.facility.FacilityGeom;
import render.world.AreaStyle;
import render.world.DowntownStyle;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;

// the floor plate's own footprint in world, and how far past it the street is built.
//
// ONE RECORD FOR BOTH TESTS, because they are the same question asked twice: a cell is street when
// it is OUTSIDE the plate and INSIDE the plate grown by the reach. `reach` is half an area on each
// hand, which is what "eight half-areas around the building" means once it is written down
typedef PlateBox = {
  var x0:Float;
  var x1:Float;
  var z0:Float;
  var z1:Float;
  var reachX:Float;
  var reachZ:Float;
};

// what went down there, for __corp()
typedef CorpStreetSet = {
  var group:Group;      // everything, parented at y = STREET_Y so one transform moves the lot
  var city:City;        // the model, handed to Area3D.city() so the crowd and the game can read it
  var road:Int;         // quads
  var walk:Int;
  var blocks:Int;       // street buildings actually built
  var walls:Int;        // and their wall quads
  var lit:Int;          // lit window panes
};

// the city street 114 units under the floor plate — AROUND the tower and never under it.
//
// A REAL citygen CITY AT LOW LOD. The MODEL is the real thing — `CityGen.generate` with the
// downtown profile off a seed derived from the area id, so the block structure, the road hierarchy,
// the dead ends and the building footprints down there are a city and not a pattern, and they come
// back identical on every rebuild with nothing persisted. What is LOW is the rendering: render
// .World runs eleven passes and lands a city area in the hundreds of draw calls, and the nearest
// thing here is 114 units away and mostly roof. So this emits merged meshes off that model instead
// of running those passes, which is what "low LOD" was always going to have to mean.
//
// **THE PLATE'S OWN FOOTPRINT IS A HOLE IN IT**, and that is the whole of `PlateBox`. The first
// build filtered by a RADIUS from the plate centre, and a plate is 224 x 180 world units with a
// half-diagonal of ~143 against a radius of 160 — so nearly all of the city was directly under the
// floor the player stands on, where it is invisible by construction and where its towers rise into
// the shaft CorpFacade encloses. What is wanted is the ring: nothing under the building, and the
// eight half-areas around it carrying the street you see out of the windows.
//
// **AND IT WEARS DOWNTOWN'S OWN ART, not a set of its own.** The tower stands in a downtown; new
// art for the same materials one storey-count away reads as a different zone, which is what it
// looked like. So the labels come straight off `DowntownStyle.get()` — the very style the city
// model is generated with (`Profiles.forArea(AREA_CITY_HIGH)`) — and the four `corp/street-*`
// labels are retired. A building takes ITS OWN `facade` slot's wall, podium and roof, so the mix of
// glass-light, glass-dark and sleek towers down there is the real one.
//
// WHAT IS DELIBERATELY NOT DOWN THERE, each for a reason that is about the DISTANCE and not about
// the effort: no lawns, no entrances, no wall decals, no roof shadows, no roof props, no kerb (the
// pavement's own paving is what separates road from footpath at this range), no street lamps (the
// 12-slot spotlight pool belongs to the office) and no `Check` audit — nobody walks this city.
//
// AND NO MASK OF ANY KIND. render.world.VisionMask's rim channel sinks a surface to the fog colour
// at the AREA BORDER, and the border is the tower's own edge — patched, the street would be cut to
// nothing exactly where the player leans over the parapet to look at it. IndoorMask likewise: it is
// keyed on the plate's cells and a street cell is not one of them. The ground, the walls and the
// roofs are UNLIT (MeshBasicMaterial), for CorpFacade's reason: the plate's lighting rig has
// nothing to do with a road 114 units below it. The LIT PANES are the one exception and have to be
// — a bloom needs an emissive term, so those take a lambert. Fog still applies to all of it, which
// is what makes the far city dissolve into the background colour instead of stopping at a line.
class CorpStreet
{
  static inline var CELL = CityConfig.CELL;

// generate the city and emit it. `id` is the area's, and the seed is derived from it rather than
// stored: the street is a function of which area this is and nothing else
  public static function build(scene:Scene, id:Int, p:PlateBox):CorpStreetSet
    {
      var city = CityGen.generate(seed(id),
        Profiles.forArea(_AreaType.AREA_CITY_HIGH));
      var st = DowntownStyle.get();
      var group = new Group();
      group.position.y = CorpStyle.STREET_Y;
      // keyed by TEXTURE and not by kind, the whole file's one structural decision: two facade
      // slots that happen to share a wall share a draw call, and the ground surfaces cost three
      // whatever the city rolled
      var bufs = new Map<String, MeshBuf>();
      var lit = new Map<Int, MeshBuf>();
      var nRoad = 0;
      var nWalk = 0;
      for (row in 0...CityConfig.GRID)
        for (col in 0...CityConfig.GRID)
          {
            var t = city.tiles[row][col];
            if (t == Tile.Building)
              continue;
            var x0 = cellX(p, col);
            var z0 = cellZ(p, row);
            if (!ring(p, x0, x0 + CELL, z0, z0 + CELL))
              continue;
            var tex = (t == Tile.Walkway ? st.walkway : (t == Tile.Alley ? st.alley : st.asphalt));
            var per = (t == Tile.Walkway ? RenderConfig.WALKWAY_TILE :
              (t == Tile.Alley ? RenderConfig.ALLEY_TILE : RenderConfig.ROAD_TILE));
            FacilityGeom.cap(buf(bufs, tex), x0, x0 + CELL, z0, z0 + CELL, 0.0, per);
            if (t == Tile.Walkway)
              nWalk++;
            else
              nRoad++;
          }
      var blocks = 0;
      var nWall = 0;
      var nLit = 0;
      var list:Array<citygen.CityModel.Building> = city.buildings;
      for (b in list)
        {
          var x0 = cellX(p, b.col);
          var z0 = cellZ(p, b.row);
          var x1 = x0 + b.w * CELL;
          var z1 = z0 + b.d * CELL;
          if (!ring(p, x0, x1, z0, z1))
            continue;
          // CAPPED, and it is not cosmetic: the plate is at 0 and the street at -114, so a
          // downtown tower taller than that would come up THROUGH the floor the player is
          // standing on. The profile's own maximum is well under it, but the cap is what makes
          // that a guarantee rather than an observation about today's numbers
          var h = (b.h > CorpStyle.STREET_MAX_H ? CorpStyle.STREET_MAX_H : b.h);
          var f = b.facade % st.walls.length;
          var glass = (st.winPerCell != null && st.winPerCell[f] > 0);
          // a glass tower's curtain art is CELL-LOCKED — one window per cell each way, which is
          // how the real city draws it (render.world.Buildings' winPerCell path) and the only
          // period at which the lit panes below land on their own bays. masonry keeps WALL_TILE
          var per = (glass ? CELL * 1.0 : RenderConfig.WALL_TILE * 1.0);
          // and the street-level plinth: the bottom two window rows of a glass tower are solid
          // granite, not glass, which is what stops a downtown reading as a stack of aquariums
          var pod = (glass && st.glassPodium != null && st.glassPodium[f] != null ?
            CELL * CityConfig.GLASS_PODIUM_ROWS : 0.0);
          if (pod > h)
            pod = h;
          for (dir in 0...4)
            {
              if (pod > 0)
                FacilityGeom.face(buf(bufs, st.glassPodium[f]), x0, x1, z0, z1, dir, 0.0, pod,
                  per);
              FacilityGeom.face(buf(bufs, st.walls[f]), x0, x1, z0, z1, dir, pod, h, per);
              nWall++;
            }
          FacilityGeom.cap(buf(bufs, st.roofBases[f % st.roofBases.length]), x0, x1, z0, z1, h,
            RenderConfig.ROOF_TILE);
          nLit += panes(lit, st, b, x0, x1, z0, z1, pod, h);
          blocks++;
        }
      for (tex in bufs.keys())
        add(group, bufs.get(tex), tex);
      for (f in lit.keys())
        addLit(group, lit.get(f), st, f);
      scene.add(group);
      return {
        group: group,
        city: city,
        road: nRoad,
        walk: nWalk,
        blocks: blocks,
        walls: nWall,
        lit: nLit,
      };
    }

// the CITY GRID IS RECENTRED ON THE PLATE, and it has to be: CityConfig's 100x100 frame is
// 400 units square centred on the world origin, while a corp area sits off in the -x/-z quadrant
// and its plate against the top-left of that. Measured on a live tower, the plate's own west edge
// is at x -180 against a grid edge at -200 — twenty units of city, on the side the player is
// most likely to be looking out of. The city is scenery and nothing indexes it in world space, so
// the cheap fix is the right one: slide the whole model so its centre is the plate's
  public static inline function ox(p:PlateBox):Float
    return (p.x0 + p.x1) / 2;

  public static inline function oz(p:PlateBox):Float
    return (p.z0 + p.z1) / 2;

// the world corner of a city cell, with that offset folded in. render.corp.CorpCrowd lays its
// lanes off the same pair, so an agent cannot walk beside the road instead of on it
  public static inline function cellX(p:PlateBox, col:Int):Float
    return col * CELL - (CityConfig.GRID * CELL) / 2 + ox(p);

  public static inline function cellZ(p:PlateBox, row:Int):Float
    return row * CELL - (CityConfig.GRID * CELL) / 2 + oz(p);

// is this rect part of the ring — clear of the plate, and inside the eight half-areas around it?
//
// PUBLIC because render.corp.CorpCrowd asks exactly the same question of a lane: a pedestrian
// walking under the building is a pedestrian nobody can see, and a lane that ran under it would
// spend most of its length there
  public static function ring(p:PlateBox, x0:Float, x1:Float, z0:Float, z1:Float):Bool
    {
      // clear of the plate, by a cell, so nothing abuts the facade it would z-fight
      if (x1 > p.x0 - CELL &&
          x0 < p.x1 + CELL &&
          z1 > p.z0 - CELL &&
          z0 < p.z1 + CELL)
        return false;
      return x1 > p.x0 - p.reachX &&
        x0 < p.x1 + p.reachX &&
        z1 > p.z0 - p.reachZ &&
        z0 < p.z1 + p.reachZ;
    }

// the lit windows of one street tower, on the CELL-locked grid its curtain art is drawn at.
//
// the selection is render.world.Windows.addGlassAccents' own — the same hash over
// (col, row, dir, i, j) against the same glassLitRatio — so the two would agree pane for pane if
// they ever drew the same building. What differs is the GEOMETRY: that pass instances a quad per
// pane because a city area chunks and occludes; here nothing moves, nothing fades and the whole
// street is one transform, so the panes merge into one mesh per family and cost one call
  static function panes(lit:Map<Int, MeshBuf>, st:AreaStyle, b:citygen.CityModel.Building,
      x0:Float, x1:Float, z0:Float, z1:Float, pod:Float, h:Float):Int
    {
      var f = b.facade % st.walls.length;
      if (st.glassAccentLit == null ||
          st.glassAccentLit[f] == null ||
          st.winPerCell == null ||
          st.winPerCell[f] <= 0)
        return 0;
      var buf = litBuf(lit, f);
      var rows = Std.int(Math.max(1, Math.round(h / CELL)));
      var rowH = h / rows;
      var row0 = Std.int(Math.round(pod / rowH));
      var n = 0;
      for (dir in 0...4)
        {
          var alongX = (dir < 2);
          var lo = (alongX ? x0 : z0);
          var cells = Std.int(Math.round(((alongX ? x1 - x0 : z1 - z0)) / CELL));
          for (i in 0...cells)
            for (j in row0...rows)
              {
                var hv = (b.col * 92837111) ^ (b.row * 689287499) ^ (dir * 283923481) ^
                  (i * 374761393) ^ (j * 668265263);
                hv = hv ^ (hv >>> 15);
                if ((hv & 0xffff) / 65536 >= st.glassLitRatio)
                  continue;
                var a = lo + i * CELL;
                var e = CorpStyle.LIT_PROUD;
                // the pane stands a hair off the curtain wall, on the face's own plane
                var px0 = alongX ? a : (dir == 2 ? x0 - e : x1 + e);
                var px1 = alongX ? a + CELL : px0;
                var pz0 = alongX ? (dir == 0 ? z0 - e : z1 + e) : a;
                var pz1 = alongX ? pz0 : a + CELL;
                FacilityGeom.pane(buf, px0, px1, pz0, pz1, dir, rowH * j, rowH * (j + 1));
                n++;
              }
        }
      return n;
    }

// compile the street's LIT pane program into a warm scene without generating a city for it. the
// ground, the walls and the roofs are the same unlit basic CorpFacade already warms; the lit pane
// is not — an emissive map plus alphaTest on a lambert is its own key and nothing else in the kind
// asks for one. one quad per facade family compiles exactly what a hundred of them would
  public static function warm(scene:Scene):Void
    {
      var st = DowntownStyle.get();
      if (st.glassAccentLit == null)
        return;
      var g = new Group();
      scene.add(g);
      for (f in 0...st.glassAccentLit.length)
        {
          if (st.glassAccentLit[f] == null)
            continue;
          var b = MeshBufTools.make();
          FacilityGeom.pane(b, 0, CELL, 0, 0, 0, 0, CELL);
          addLit(g, b, st, f);
        }
    }

// the street's seed, off the area id. a plain scramble rather than the id itself, so two adjacent
// corp areas do not get two cities that differ only in their low bits
  public static inline function seed(id:Int):Int
    {
      return render.facility.FacilityModel.mix(id * 2654435 + 12345);
    }

// the lit buffer of one facade slot. keyed by the SLOT and not by the texture, unlike everything
// else here: a lit pane carries a glow COLOUR as well as a map (DowntownStyle gives the light,
// dark and sleek towers each their own), and two slots that shared a texture but not a colour
// would have to be two meshes anyway
  static function litBuf(m:Map<Int, MeshBuf>, f:Int):MeshBuf
    {
      var b = m.get(f);
      if (b == null)
        {
          b = MeshBufTools.make();
          m.set(f, b);
        }
      return b;
    }

// the buffer this texture draws into, made on first use
  static function buf(m:Map<String, MeshBuf>, tex:String):MeshBuf
    {
      var b = m.get(tex);
      if (b == null)
        {
          b = MeshBufTools.make();
          m.set(tex, b);
        }
      return b;
    }

// one merged UNLIT mesh into the street group
  static function add(group:Group, b:MeshBuf, tex:String):Void
    {
      if (b.idx.length == 0)
        return;
      var mesh = new Mesh(FacilityGeom.geom(b), new MeshBasicMaterial({
        map: Textures.loadTexture(tex, 'wall', 1),
        color: new Color(0xffffff).multiplyScalar(CorpStyle.STREET_DIM),
        side: THREE.FrontSide,
      }));
      mesh.receiveShadow = false;
      mesh.castShadow = false;
      group.add(mesh);
    }

// and one merged LIT one. PUBLIC because render.corp.CorpFacade hangs the tower's OWN lit bays off
// it: the tower is a downtown glass tower seen from the inside, so its lit panes are the street's
// lit panes and one recipe serves both.
//
// a lambert and not a basic, which is the only lit material down here:
// bloom is driven off the emissive term, so a pane that has to glow has to have one. the recipe is
// render.world.Windows' exactly — the lit texture is its own emissive map, tinted by the facade's
// own glow colour at an intensity over 1, with alphaTest so the mullion around the glass does not
// emit and the bloom is confined to the pane
  public static function addLit(group:Object3D, b:MeshBuf, st:AreaStyle, f:Int):Void
    {
      if (b.idx.length == 0)
        return;
      var t = Textures.loadTexture(st.glassAccentLit[f], 'wall', 1);
      var cc = (st.glassLitColor != null ? st.glassLitColor[f] : 0);
      var mat = new MeshLambertMaterial({
        map: t,
        alphaTest: 0.5,
        side: THREE.FrontSide,
      });
      mat.emissive = new Color(cc != 0 ? cc : 0xffffff);
      mat.emissiveMap = t;
      mat.emissiveIntensity = st.glassLitIntensity;
      var mesh = new Mesh(FacilityGeom.geom(b), mat);
      mesh.receiveShadow = false;
      mesh.castShadow = false;
      group.add(mesh);
    }
}
