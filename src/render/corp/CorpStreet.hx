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
import render.world.roofs.FlatRoofs;
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
  var deco:Int;         // rooftop plant decals
  var pent:Int;         // and mechanical penthouses
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
      // the rooftop plant, keyed by RenderConfig.DETAIL_TYPES index — its own map because each
      // type is its own chroma-cut image and so its own material
      var deco = new Map<Int, MeshBuf>();
      var nRoad = 0;
      var nWalk = 0;
      // THE MODEL IS MIRROR-TILED and the loop runs over WORLD cell indices — see `fold`. Three
      // tiles each way is more than the reach can ask for, and folding is what stops the street
      // ending in a straight edge inside the fog
      for (row in -CityConfig.GRID...2 * CityConfig.GRID)
        for (col in -CityConfig.GRID...2 * CityConfig.GRID)
          {
            var t = city.tiles[fold(row)][fold(col)];
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
      var nDeco = 0;
      var nPent = 0;
      var list:Array<citygen.CityModel.Building> = city.buildings;
      // and every building once per TILE, its own footprint reflected on an odd one. a
      // mirrored rect is still a rect, so nothing downstream learns this happened
      for (tz in -1...2)
        for (tx in -1...2)
          for (b in list)
            {
              var x0 = cellX(p, span(tx, b.col, b.w));
              var z0 = cellZ(p, span(tz, b.row, b.d));
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
              var r = roof(bufs, deco, st, b, f, x0, x1, z0, z1, h, per);
              nDeco += r.deco;
              nPent += r.pent;
              blocks++;
            }
      for (tex in bufs.keys())
        add(group, bufs.get(tex), tex);
      for (f in lit.keys())
        addLit(group, lit.get(f), st, f);
      for (t in deco.keys())
        addDeco(group, deco.get(t), t);
      scene.add(group);
      return {
        group: group,
        city: city,
        road: nRoad,
        walk: nWalk,
        blocks: blocks,
        walls: nWall,
        lit: nLit,
        deco: nDeco,
        pent: nPent,
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

// a WORLD cell index folded back into the model, by MIRRORING at each of its edges.
//
// THE STREET'S OUTER EDGE WAS THE CITY'S EDGE AND NOT THE REACH, which is what this exists for: the
// model is GRID 100 x CELL 4 = 400 units square and the ring around a 224 x 180 plate already
// overran it by 20 units in x before the reach was touched at all, so a player leaning over the
// west parapet saw the city STOP. Growing the reach alone would have bought nothing.
//
// MIRRORING AND NOT A MODULO. A plain wrap butts the model's west edge against its east one, and
// every road, block and kerb line that does not happen to line up is cut in half at the seam; a
// reflection matches its neighbour by construction, whatever the pattern. The cost is that the far
// city is symmetrical about each seam, which at 114 units down through fog nothing can read.
  public static inline function fold(i:Int):Int
    {
      var n = CityConfig.GRID;
      var m = ((i % (2 * n)) + 2 * n) % (2 * n);
      return m < n ? m : 2 * n - 1 - m;
    }

// and the inverse for a RUN: the world index the low corner of `n` cells starting at `i0` lands on
// in tile `t`. a building's footprint is a run on each axis, and a reflected rect is still a rect —
// which is the whole reason the buildings can be tiled without touching anything downstream
  public static inline function span(t:Int, i0:Int, n:Int):Int
    return (t & 1) == 0 ? t * CityConfig.GRID + i0 :
      t * CityConfig.GRID + CityConfig.GRID - i0 - n;

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

// what stands on one street roof: a coping rim, a mechanical penthouse, and the rooftop plant.
//
// THE RIM IS FOUR THIN RECTS AND NOT A RING OF BOXES. Each side is a `ROOF_PARA_T`-deep rect and
// the band is its OUTER hand, its INNER hand and a top cap — taking the inner skin off the same
// thin rect rather than off an inset one is what gets the winding right without a second rect and
// without a flipped face. The caps are cut so no two are coplanar at a corner.
//
// AND THE SKINS GO IN THE BUILDING'S OWN WALL BUFFER, which is the whole economy of this: 200-odd
// roofs of rim cost exactly ONE new draw call, the coping cap's.
//
// The penthouse is render.world.roofs.FlatRoofs.penthouseRect verbatim — a pure function of the
// Building and already deterministic, so the street agrees with the real city about which roofs
// carry one without sharing any state with it.
  static function roof(bufs:Map<String, MeshBuf>, deco:Map<Int, MeshBuf>, st:AreaStyle,
      b:citygen.CityModel.Building, f:Int, x0:Float, x1:Float, z0:Float, z1:Float, h:Float,
      per:Float):{ deco:Int, pent:Int }
    {
      var t = CorpStyle.ROOF_PARA_T;
      var hi = h + CorpStyle.ROOF_PARA_H;
      var w = buf(bufs, st.walls[f]);
      var cope = buf(bufs, CorpStyle.COPING_STREET);
      if (x1 - x0 < 3 * t ||
          z1 - z0 < 3 * t)
        return { deco: 0, pent: 0 };
      // the four sides. `sides` is {rect, the hand that looks out}, and the inner skin is the
      // opposite hand of the SAME rect
      var sides = [
        { a: x0, b: x1, c: z0, d: z0 + t, out: 0 },
        { a: x0, b: x1, c: z1 - t, d: z1, out: 1 },
        { a: x0, b: x0 + t, c: z0, d: z1, out: 2 },
        { a: x1 - t, b: x1, c: z0, d: z1, out: 3 },
      ];
      for (i in 0...sides.length)
        {
          var s = sides[i];
          FacilityGeom.face(w, s.a, s.b, s.c, s.d, s.out, h, hi, per);
          FacilityGeom.face(w, s.a, s.b, s.c, s.d, s.out ^ 1, h, hi, per);
          // the cap ring, mitred by shortening the two rects that run the long way
          var ca = (i < 2 ? s.a : s.a);
          var cc = (i < 2 ? s.c : s.c + t);
          var cd = (i < 2 ? s.d : s.d - t);
          FacilityGeom.cap(cope, ca, s.b, cc, cd, hi, CorpStyle.COPING_TILE);
        }
      // the mechanical penthouse, in the building's own wall and its own roof base
      var cx = (x0 + x1) / 2;
      var cz = (z0 + z1) / 2;
      var pen = FlatRoofs.penthouseRect(b, { x: cx, z: cz }, x1 - x0, z1 - z0);
      var pent = 0;
      if (pen != null)
        {
          var ph = citygen.CityConfig.FLOOR_H * (1.4 + (hash(b, 3) % 2) * 0.6);
          var px0 = pen.x - pen.w / 2;
          var px1 = pen.x + pen.w / 2;
          var pz0 = pen.z - pen.d / 2;
          var pz1 = pen.z + pen.d / 2;
          for (dir in 0...4)
            FacilityGeom.face(w, px0, px1, pz0, pz1, dir, h, h + ph, per);
          FacilityGeom.cap(buf(bufs, st.roofBases[f % st.roofBases.length]),
            px0, px1, pz0, pz1, h + ph, RenderConfig.ROOF_TILE);
          pent = 1;
        }
      // and the plant, one item per sector, dealt round the type list off the building's own hash
      // so a roof is not six of the same unit
      var e = CorpStyle.ROOF_DECO_EDGE;
      var ax0 = x0 + e;
      var ax1 = x1 - e;
      var az0 = z0 + e;
      var az1 = z1 - e;
      if (ax1 - ax0 < 2 ||
          az1 - az0 < 2)
        return { deco: 0, pent: pent };
      var cols = Std.int(Math.round((ax1 - ax0) / CorpStyle.ROOF_SECTOR));
      var rows = Std.int(Math.round((az1 - az0) / CorpStyle.ROOF_SECTOR));
      if (cols < 1)
        cols = 1;
      if (rows < 1)
        rows = 1;
      while (cols * rows > CorpStyle.ROOF_DECO_MAX)
        {
          if (cols >= rows)
            cols--;
          else
            rows--;
        }
      var n = 0;
      for (ci in 0...cols)
        for (cj in 0...rows)
          {
            var ty = (hash(b, ci * 7 + cj * 13) % RenderConfig.DETAIL_TYPES.length);
            var d = RenderConfig.DETAIL_TYPES[ty];
            var x = ax0 + (ci + 0.5) * (ax1 - ax0) / cols;
            var z = az0 + (cj + 0.5) * (az1 - az0) / rows;
            // never on the penthouse, which is real massing and would swallow it
            if (pen != null &&
                Math.abs(x - pen.x) < pen.w / 2 + d.w / 2 &&
                Math.abs(z - pen.z) < pen.d / 2 + d.d / 2)
              continue;
            // ponytail: no yaw. RoofDetails turns each unit by a multiple of 90 degrees, which on
            // a MERGED quad means permuting its corners rather than setting a matrix — and at 114
            // units down through fog nothing can read which way a vent faces. Upgrade path is the
            // corner permutation, four cases, if a closer camera ever looks at this
            quadFlat(litBuf(deco, ty), x - d.w / 2, x + d.w / 2, z - d.d / 2, z + d.d / 2, h + 0.05);
            n++;
          }
      return { deco: n, pent: pent };
    }

// a horizontal quad with its OWN 0..1 uv, which is what a decal wants and FacilityGeom.cap cannot
// give — `cap` writes world-aligned uv so a surface tiles, and a rooftop unit is a picture
  static inline function quadFlat(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, y:Float):Void
    MeshBufTools.quad(b, [x0, y, z1], [x1, y, z1], [x1, y, z0], [x0, y, z0],
      [0, 0, 1, 0, 1, 1, 0, 1]);

// one stable number per building, salted. the street is rebuilt from the model on every entry and
// nothing about a roof may move between two of them
  static inline function hash(b:citygen.CityModel.Building, salt:Int):Int
    return render.facility.FacilityModel.mix((b.col * 374761393) ^ (b.row * 40503) ^ (salt * 668265263));

// one merged mesh of rooftop units of ONE type. the city's own art, chroma-keyed at load exactly
// as render.world.roofs.RoofDetails keys it, and unlit like everything else down here
  static function addDeco(group:Group, b:MeshBuf, ty:Int):Void
    {
      if (b.idx.length == 0)
        return;
      var d = RenderConfig.DETAIL_TYPES[ty];
      var mesh = new Mesh(FacilityGeom.geom(b), new MeshBasicMaterial({
        map: Textures.loadKeyedTexture(d.tex, d.crop, RenderConfig.DETAIL_BOX_COLOR),
        color: new Color(0xffffff).multiplyScalar(CorpStyle.STREET_DIM),
        alphaTest: 0.5,
        side: THREE.DoubleSide,
      }));
      mesh.receiveShadow = false;
      mesh.castShadow = false;
      group.add(mesh);
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
// the same, keyed by an Int — the lit panes by facade slot, the rooftop plant by detail type
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
