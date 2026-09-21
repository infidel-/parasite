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
  // DOES THE TOWER ITSELF STAND OVER THIS WORLD RECT — not "is it inside the bounding box".
  //
  // the rect above is `structures[0]`'s, which comes off a FLOOD FILL, and the flood fill swallows
  // the lift car: `Surf.LIFT` is inside FacilityModel.isIndoor's range and the car is 4-connected
  // to the plate through its own door. gen.blocks.ElevatorBlock stands that car OUTSIDE the wall
  // ring, so the box grows four cells across the whole of whichever wall the lift landed on and
  // the street was cut back by 22 units along a 224-unit face — the black band under the south
  // wall. render.corp.CorpFacade has always built the tower per CELL and known better.
  //
  // a closure rather than the model itself, so CorpStreet still knows nothing about the plate
  // beyond its own box
  var covers:(Float, Float, Float, Float) -> Bool;
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
// `no roof shadows` still means render.world.roofs.RoofShadows, the contact band under a parapet;
// a building's shadow on its OWN STREET is a different thing and is projected, see `shadows`.
//
// AND NO MASK OF ANY KIND. render.world.VisionMask's rim channel sinks a surface to the fog colour
// at the AREA BORDER, and the border is the tower's own edge — patched, the street would be cut to
// nothing exactly where the player leans over the parapet to look at it. IndoorMask likewise: it is
// keyed on the plate's cells and a street cell is not one of them, and NOT patching these materials
// is what lets the street keep the scene's real night rig while the office keeps its indoor swap.
// Fog still applies to all of it, which is what makes the far city dissolve into the background
// colour instead of stopping at a line.
//
// EVERYTHING DOWN HERE IS LAMBERT AND LIT, which it was not until the fourth defect pass. It was
// MeshBasicMaterial with a hand-baked per-face key in the vertex colour channel and a hand-marched
// heightfield for shadow, and both read as what they were. See `light` below for the one piece
// that made a real shadow map affordable.
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
            var g = buf(bufs, tex);
            FacilityGeom.cap(g, x0, x0 + CELL, z0, z0 + CELL, 0.0, per);
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
              // `tileH` carries the cap, and the cap is not cosmetic: the plate is at 0 and the
              // street at -114, so a downtown tower taller than that would come up THROUGH the
              // floor the player is standing on. The profile's own maximum is well under it, but
              // the cap is what makes that a guarantee rather than an observation about today's
              // numbers — and the mirror jitter could otherwise push one past it
              var h = tileH(b, tx, tz);
              var f = tileF(b, tx, tz, st.walls.length);
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
                    {
                      var pb = buf(bufs, st.glassPodium[f]);
                      FacilityGeom.face(pb, x0, x1, z0, z1, dir, 0.0, pod, per);
                    }
                  var wb = buf(bufs, st.walls[f]);
                  FacilityGeom.face(wb, x0, x1, z0, z1, dir, pod, h, per);
                  nWall++;
                }
              // PER CELL and not one rect over the footprint: a roof is most of what is seen from
              // up here, so it is the surface a neighbour's shadow has to be able to cross. The
              // cap writes world-aligned uv, so splitting it changes no texel — 158 rects become
              // ~1,900 and land in the same buffer for the same one draw call
              var rb = buf(bufs, st.roofBases[f % st.roofBases.length]);
              var bc = span(tx, b.col, b.w);
              var br = span(tz, b.row, b.d);
              for (cc in 0...b.w)
                for (rr in 0...b.d)
                  {
                    var rx = x0 + cc * CELL;
                    var rz = z0 + rr * CELL;
                    FacilityGeom.cap(rb, rx, rx + CELL, rz, rz + CELL, h, RenderConfig.ROOF_TILE);
                  }
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
      light(scene, p);
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
      // the tower's own silhouette is the hole, and it is asked per cell — see PlateBox.covers.
      // the margin is a QUARTER of a cell and was a whole one: it exists so a ground quad does not
      // z-fight the facade's drop, the drop is a vertical plane, and a whole cell of it was 4 to 6
      // units of missing street on every hand even where the lift was not
      var e = CELL * 0.25;
      if (p.covers(x0 - e, x1 + e, z0 - e, z1 + e))
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
          // the two rims that RUN ALONG Z take the uv turned 90 degrees: city/coping is authored
          // as a straight-on strip with a horizontal tile, so unturned they run the strip across
          // the rim's 0.6-unit width instead of along its length
          FacilityGeom.cap(cope, ca, s.b, cc, cd, hi, CorpStyle.COPING_TILE, i >= 2);
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
            {
              FacilityGeom.face(w, px0, px1, pz0, pz1, dir, h, h + ph, per);
            }
          var pc = buf(bufs, st.roofBases[f % st.roofBases.length]);
          FacilityGeom.cap(pc, px0, px1, pz0, pz1, h + ph, RenderConfig.ROOF_TILE);
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
            var ty = CorpStyle.ROOF_DECO_TYPES[hash(b, ci * 7 + cj * 13) %
              CorpStyle.ROOF_DECO_TYPES.length];
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
            var db = litBuf(deco, ty);
            quadFlat(db, x - d.w / 2, x + d.w / 2, z - d.d / 2, z + d.d / 2, h + 0.05);
            n++;
          }
      return { deco: n, pent: pent };
    }

// THE FAR MASK, patched into every one of the street's own materials — the input to
// render.StreetBlur, which is the composer pass that actually does the softening.
//
// AN OPAQUE MATERIAL'S ALPHA OUTPUT IS DEAD DATA. Nothing downstream reads it: blending is off for
// an opaque draw, the bloom pass reads rgb and the output pass passes alpha through to a canvas
// that ignores it. So the street writes `1 - farness` there and the blur pass reads it back as its
// mask, which is a whole depth prepass and a DepthTexture on a multisampled target not spent.
//
// the include is REPLACED and not edited, because onBeforeCompile runs BEFORE three resolves
// `#include`: what arrives here is the literal directive, so there is nothing to string-match
// inside the chunk. `<dithering_fragment>` is the LAST chunk of every lit fragment shader, which
// is the one place `gl_FragColor` is already assigned and can still be overwritten.
//
// the varying is our own rather than three's `vFogDepth`, which carries the same number: that one
// only exists under USE_FOG, and a material here losing its fog would silently lose its mask with
// it. And the cache key is mandatory — without one three hands this patched program to the next
// material with the same signature, which is the trap render.corp.CorpCrowd's car UV already hit.
//
// a Float has to be written as a GLSL float LITERAL. Haxe prints 110.0 as "110", and
// `smoothstep(110, 230, x)` is `smoothstep(int, int, float)` — no overload, and the whole street
// compiles to black
  static inline function glsl(v:Float):String
    return (v == Std.int(v) ? Std.string(v) + '.0' : Std.string(v));

  public static function blur(mat:Dynamic):Void
    {
      var b = CorpStyle.BLUR;
      mat.onBeforeCompile = function(sh:Dynamic)
        {
          sh.vertexShader = 'varying float vStreetFar;\n' +
            StringTools.replace(sh.vertexShader, '#include <project_vertex>',
              '#include <project_vertex>\n  vStreetFar = smoothstep(' + glsl(b.near) + ', ' +
              glsl(b.far) + ', -mvPosition.z);');
          sh.fragmentShader = 'varying float vStreetFar;\n' +
            StringTools.replace(sh.fragmentShader, '#include <dithering_fragment>',
              '#include <dithering_fragment>\n  gl_FragColor.a = 1.0 - vStreetFar;');
        };
      untyped mat.customProgramCacheKey = function() return 'corpStreetFar';
    }

// a horizontal quad with its OWN 0..1 uv, which is what a decal wants and FacilityGeom.cap cannot
// give — `cap` writes world-aligned uv so a surface tiles, and a rooftop unit is a picture
  static inline function quadFlat(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, y:Float):Void
    MeshBufTools.quad(b, [x0, y, z1], [x1, y, z1], [x1, y, z0], [x0, y, z0],
      [0, 0, 1, 0, 1, 1, 0, 1]);

// HOW TALL THIS BUILDING IS ON THIS MIRROR TILE. `fold` reflects the model exactly, so the nine
// tiles are nine congruent skylines and the eye reads the repeat long before the fog hides it.
// One hashed multiplier per (building, tile) is all it takes to break — the centre tile keeps its
// generated height, because it is the city the tower really stands in and the only one close
// enough to resolve
  static inline function tileH(b:citygen.CityModel.Building, tx:Int, tz:Int):Float
    {
      var h = (tx == 0 && tz == 0 ? b.h :
        b.h * (1.0 + CorpStyle.TILE_VARY * ((hash(b, tx * 31 + tz * 97 + 7) % 1000) / 1000.0 - 0.5)));
      return (h > CorpStyle.STREET_MAX_H ? CorpStyle.STREET_MAX_H : h);
    }

// and which facade it wears there, re-dealt for the same reason
  static inline function tileF(b:citygen.CityModel.Building, tx:Int, tz:Int, n:Int):Int
    return (tx == 0 && tz == 0 ? b.facade % n : (b.facade + hash(b, tx * 13 + tz * 29)) % n);

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
      var mesh = new Mesh(FacilityGeom.geom(b), new MeshLambertMaterial({
        map: Textures.loadKeyedTexture(d.tex, d.crop, RenderConfig.DETAIL_BOX_COLOR),
        color: new Color(0xffffff).multiplyScalar(CorpStyle.STREET_DIM),
        alphaTest: 0.5,
        side: THREE.DoubleSide,
      }));
      blur(untyped mesh.material);
      // a rooftop unit RECEIVES but does not cast: it is a flat decal quad lying on the roof, so
      // its own shadow would be a stripe of nothing
      mesh.receiveShadow = true;
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

// one merged LIT mesh into the street group. FacilityGeom.geom already runs computeVertexNormals
// and every quad carries its own four vertices, so the normals come out FLAT per face — which is
// what a box of masonry wants and is why a lambert needed no new geometry work
  static function add(group:Group, b:MeshBuf, tex:String):Void
    {
      if (b.idx.length == 0)
        return;
      var mat = new MeshLambertMaterial({
        map: Textures.loadTexture(tex, 'wall', 1),
        color: new Color(0xffffff).multiplyScalar(CorpStyle.STREET_DIM),
        side: THREE.FrontSide,
      });
      blur(mat);
      var mesh = new Mesh(FacilityGeom.geom(b), mat);
      mesh.receiveShadow = true;
      casts(mesh);
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
      blur(mat);
      var mesh = new Mesh(FacilityGeom.geom(b), mat);
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      group.add(mesh);
    }

// THE STREET'S OWN MOON, and why there has to be a second one.
//
// The scene already has a real DirectionalLight with a real shadow map (render.facility
// .FacilityScene) — but RenderConfig.MOON_SHADOW's ortho box is 90 units half-wide and is parked on
// the PLAYER every frame, while the street is up to 195 units out and 114 units DOWN. Widening that
// box to reach it coarsens the office's own shadow texel by 2.2x, which is the trade the third pass
// backed away from into a hand-marched heightfield.
//
// A SECOND LIGHT IS NOT A SECOND PASS'S WORTH OF WORK HERE, because nothing outside ever moves:
// the city is rebuilt from its seed on entry and then stands still. So `shadow.autoUpdate = false`
// renders the map ONCE and freezes it — the depth pass costs a handful of draws on the frame the
// area is entered and exactly nothing on every frame after.
//
// AND THE NEAR PLANE IS WHAT KEEPS THE OFFICE OUT OF IT. three has no per-object light filtering
// (render.world.IndoorMask's header carries the obituary: Light.layers is tested against the
// CAMERA's layers, not the object's), so this light lights the plate too. What it must not do is
// CAST the plate's interior into the street's map — a desk 114 units up would throw a shadow across
// a block. The shadow camera sits up-light of the street, so distance along the light direction
// sorts the two apart: the street plane is at `dist`, the plate is `PLATE_Y / dir.y` nearer, and a
// near plane just short of that clips the whole interior out while leaving the tallest street
// building (STREET_MAX_H, still 121 units of travel away) inside. The tower's own flank keeps
// casting, which is right — a 114-unit tower standing on a street has a shadow.
// THE CASTER REGISTER, and the one trick that keeps a second shadow map free.
//
// `light` below freezes its map after one render, so an outside mesh only has to CAST on the frame
// the area is entered. After that its `castShadow` is dead weight — and not free dead weight: the
// OFFICE moon's own box reaches 353 units of light-travel and the street sits at 353, so every
// merged street mesh was being redrawn into the office's depth pass every frame for a shadow the
// office cannot see. Measured at the pinned pose: 96 calls with them casting, 81 without.
//
// So they cast, the map is written, and `settle` drops them on the next tick. Register here, reset
// per area in `begin` (render.corp.CorpArea.build calls it beside the WorldCtx resets), drop in
// `settle` (render.corp.CorpArea.tick).
  static var casters:Array<Mesh> = [];
  static var sun:DirectionalLight = null;

  public static inline function casts(m:Mesh):Void
    {
      m.castShadow = true;
      casters.push(m);
    }

  public static function begin():Void
    {
      casters = [];
      sun = null;
    }

// drop the register once the frozen map has been written.
//
// THE CONDITION IS `shadow.map != null` AND NOT A TICK COUNT, which cost a build to find. three
// allocates a DirectionalLightShadow's render target inside the shadow pass and AFTER its own
// `autoUpdate == false && needsUpdate == false` early-out (WebGLShadowMap.render), so a non-null
// map is proof that the pass ran at least once — and proof is what is needed here, because a
// counter is a guess about how many ticks precede the first frame. Settling one tick early wrote
// an EMPTY map and the street came back with no shadows at all and nothing to say so
  public static function settle():Void
    {
      if (casters.length == 0 ||
          sun == null ||
          sun.shadow.map == null)
        return;
      for (m in casters)
        m.castShadow = false;
      casters = [];
    }

  static function light(scene:Scene, p:PlateBox):DirectionalLight
    {
      var S = CorpStyle.STREET_SUN;
      var l = new DirectionalLight(S.color, S.intensity);
      var d = S.dir;
      var cx = ox(p);
      var cz = oz(p);
      l.position.set(cx + d[0] * S.distance, CorpStyle.STREET_Y + d[1] * S.distance,
        cz + d[2] * S.distance);
      l.target.position.set(cx, CorpStyle.STREET_Y, cz);
      scene.add(l.target);
      l.castShadow = true;
      var sh:Dynamic = l.shadow;
      sh.mapSize.set(S.mapSize, S.mapSize);
      sh.bias = S.bias;
      sh.normalBias = S.normalBias;
      var sc:Dynamic = sh.camera;
      // the plate is `-STREET_Y` above the street, i.e. this much nearer the light along it
      sc.near = S.distance + CorpStyle.STREET_Y / d[1] + S.clear;
      sc.far = S.distance + S.halfExtent;
      sc.left = -S.halfExtent;
      sc.right = S.halfExtent;
      sc.top = S.halfExtent;
      sc.bottom = -S.halfExtent;
      sc.updateProjectionMatrix();
      // one depth pass on entry and none after — nothing down there moves
      sh.autoUpdate = false;
      sh.needsUpdate = true;
      scene.add(l);
      sun = l;
      return l;
    }
}
