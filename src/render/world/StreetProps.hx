package render.world;

import three.Three;
import citygen.CityConfig;
import citygen.CityConfig.cellToWorld;
import citygen.CityModel.Building;
import citygen.CityModel.City;
import citygen.CityModel.Tile;
import render.RenderConfig;
import render.Chunks;
import render.Models.InstancedProp;
import render.Models.PropPlace;
import render.world.AreaStyle.GroundProp;
import render.world.Debris.DebrisSpot;
import render.world.Pile.PileKind;
import game.AreaGame;
import citygen.CityGen;
import render.world.roofs.Gables;

// one module of a wall kit set down on a building
typedef KitPlace = {
  b:Building, // the building it hangs on, which its merged mesh is tagged with
  key:String, // the module: the suffix of its mesh's name in the kit glb (floor, base, pipe, ...)
  m:Matrix4,  // where it stands
};

// the street wall kit: fire escapes and downpipes on the residential facades, conduit, junction
// boxes and intake louvres on downtown's service walls (AreaStyle.wallKit). one glb per kit, every
// module a mesh of its own authored in world units against the wall (models-src/city/kit/wallkit.py),
// and every dressed building in a render.Chunks cell MERGED into one mesh (KitChunk): one draw call
// per chunk while its buildings are solid. each building keeps an undrawn proxy over its slice, which
// render.Occlusion fades and ghosts like any other mesh of the building; `sync` drops a hidden
// proxy's slice from the chunk's draw. render-only and hashed off the footprint, like the wall
// decals, so a building dresses the same on every entry
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
  // the open hopper head's height (wallkit.py HH): its module stands on its floor, its stub reaching
  // down over the run's last length
  static inline var HOPPER_H = 0.4;
  // a kerb prop's centre in from the kerb line, how far one may slide along its kerb or wall either
  // way, and the gap a wall prop keeps off its wall
  static inline var KERB_IN = 0.8;
  static inline var SLIDE = 0.7;
  static inline var WALL_GAP = 0.08;
  // a dealt pile (deal): how far in from the kerb line a kerb heap's back line runs, how far in from
  // the cell's ends a piece keeps, a back part's and a front part's distance off the back line (and
  // how much further a front one may spill), how deep the rest scatter, a stack's gap off the wall,
  // how many tries a piece gets at a clear spot, and how close two pieces may sit, of their two radii
  static inline var KERB_BACK = 0.35;
  static inline var PILE_MARGIN = 0.8;
  static inline var BACK_OFF = 0.1;
  static inline var FRONT_OFF = 0.9;
  static inline var FRONT_RUN = 0.6;
  static inline var HEAP_RUN = 0.7;
  static inline var STACK_OFF = 0.05;
  static inline var TRIES = 10;
  static inline var CLOSE = 0.65;
  // a broken downpipe's puddle: its centre off the wall, past the pipe (0.18 out) by about its own half
  // length, so its art stays on the open ground
  static inline var PUDDLE_OUT = 0.8;

  static var checked = false;

// lay the area style's wall kit out over the city WorldCtx holds, then merge it per chunk once the
// kit glb is in. `done` gets the chunks: right away when the glb is cached (the boot warm loads it),
// on the loader callback otherwise, when the caller's fader has to adopt their proxies. returns the
// puddles under the broken downpipes, litter for the street's debris decals
  public static function build(scene:Scene, done:Array<KitChunk>->Void):Array<DebrisSpot>
    {
      if (!checked)
        {
          checked = true;
          if (!demo())
            js.Browser.console.warn('[street-props] self-check FAILED');
        }
      var st = WorldCtx.style;
      var puddles:Array<DebrisSpot> = [];
      if (st.wallKit == null)
        return puddles;
      var list:Array<KitPlace> = [];
      for (b in WorldCtx.buildings)
        {
          // a setback tier stands on the deck of the one below, so nothing of it reaches the street
          var cols = WorldCtx.winCols.get(b);
          if (cols != null &&
              b.buriedH == 0)
            {
              var pool = downpipe(b, cols, st, fireEscape(b, cols, st, list), list);
              if (pool != null)
                puddles.push(pool);
            }
          if (st.serviceChance > 0)
            service(b, st, list);
        }
      Models.get(st.wallKit, function(t)
        {
          done(merge(scene, t, list));
        });
      return puddles;
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
// and at the end away from it: the hopper head under the roofline (headTop), a length per window
// floor, the shoe at the foot. a broken one (AreaStyle.downpipeBroken) has lost its shoe and one length,
// and returns the puddle it leaves (puddle); null otherwise
  static function downpipe(b:Building, cols:Array<WorldCtx.WinCol>, st:AreaStyle, fe:Array<WorldCtx.WinCol>, list:Array<KitPlace>):DebrisSpot
    {
      var h = hash(b, 2);
      if (h % 1000 >= st.downpipeChance * 1000)
        return null;
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
            m: at(x, headTop(b, st) - HOPPER_H, z, e.rotY),
          });
          return (broken && st.pipePuddle != null ? puddle(x, z, e.rotY, h, st) : null);
        }
      return null;
    }

// the puddle a broken downpipe leaves at its foot: the style's pipePuddle pack cell, laid PUDDLE_OUT
// off the wall at (x, z) along the face's outward normal, sized and turned off the building's hash
  static function puddle(x:Float, z:Float, rotY:Float, h:Int, st:AreaStyle):DebrisSpot
    {
      var px = x + Math.sin(rotY) * PUDDLE_OUT;
      var pz = z + Math.cos(rotY) * PUDDLE_OUT;
      var c = CityConfig.worldToCell(px, pz);
      var ix = st.pipePuddle[0];
      var iy = st.pipePuddle[1];
      return {
        col: c.col,
        row: c.row,
        dx: px / CELL + GRID / 2 - 0.5 - c.col,
        dy: pz / CELL + GRID / 2 - 0.5 - c.row,
        scale: st.debrisSizes[iy][ix] * (0.8 + 0.4 * ((h >> 20) % 1000) / 1000),
        angle: (h >> 6) % 1000 / 1000 * 2 * Math.PI,
        ix: ix,
        iy: iy,
        img: st.debrisPack,
      };
    }

// where a downpipe's hopper head tops out, under whatever the roofline over it does (Buildings picks
// the roof the same way): a gable's eave slab; the cap of a brick parapet, which is flush with the
// wall and whose cap starts 0.18 under its top (Parapets.addParapet); and a concrete coping, which
// hangs PARAPET_EMBED below the roofline and juts 0.37 off the wall. a head at the old
// b.h - TOP_MARGIN stood INSIDE that coping band and z-fought its underside, and behind brick it hung
// 1.4 under the cap
  static function headTop(b:Building, st:AreaStyle):Float
    {
      if (Gables.isGabled(b))
        return b.h - RenderConfig.GABLE_THICK - 0.05;
      if (b.shop < 0 &&
          st.isMasonry(b.facade))
        return b.h + RenderConfig.PARAPET_H_BRICK - 0.18 - 0.04;
      return b.h - RenderConfig.PARAPET_EMBED - 0.04;
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

// scatter the style's ground props (AreaStyle.groundProps): one per cell at most, first the cells
// beside a dumpster (`bins`, grid keys row * GRID + col), then every kerb and wall cell, each prop in
// list order taking its `chance` off a hash of the cell. `blocked` cells (objects) and the lamps' cells
// stay clear, and a wall prop never stands across a door. a prop with a `pile` deals its pieces there
// (deal). one instanced batch per glb; the steam vents' open tops are pushed onto `vents`
  public static function ground(scene:Scene, city:City, blocked:Map<Int, Bool>, bins:Array<Int>, vents:Array<Vector3>):Array<InstancedProp>
    {
      var props = WorldCtx.style.groundProps;
      if (props == null)
        return [];
      var taken = new Map<Int, Bool>();
      for (k in blocked.keys())
        taken.set(k, true);
      for (l in city.lamps)
        taken.set(l.row * GRID + l.col, true);
      // which building stands on each cell, for the door test
      var owner = new Map<Int, Building>();
      for (b in WorldCtx.buildings)
        for (r in b.row...b.row + b.d)
          for (c in b.col...b.col + b.w)
            owner.set(r * GRID + c, b);
      // one batch per glb, at the height it was first dealt at: a piece dealt at another rides `scale`
      var order:Array<String> = [];
      var heights = new Map<String, Float>();
      var batches = new Map<String, Array<PropPlace>>();
      function put(path:String, h:Float, pl:PropPlace):Void
        {
          if (!batches.exists(path))
            {
              order.push(path);
              heights.set(path, h);
              batches.set(path, []);
            }
          pl.scale = (pl.scale != null ? pl.scale : 1.0) * h / heights.get(path);
          batches.get(path).push(pl);
        }
      // try every prop of this spot on one cell, in list order; the first whose hash comes up stands
      // there. `dir` is the road (KERB) or the wall (WALL, BIN) the cell faces
      function pick(col:Int, row:Int, spot:AreaStyle.PropSpot, dir:Int):Void
        {
          var key = row * GRID + col;
          if (taken.exists(key))
            return;
          for (i in 0...props.length)
            {
              var gp = props[i];
              var h = cellHash(col, row, i);
              if (gp.spot != spot ||
                  h % 10000 >= gp.chance * 10000)
                continue;
              taken.set(key, true);
              var c = cellToWorld(col, row);
              // a walkway stands a kerb's height up
              var y = (WorldCtx.tiles[row][col] == Tile.Walkway ? RenderConfig.CURB_H : 0.0);
              var face = Geom.faceRotY(spot == KERB ? dir : OPP[dir]);
              var rng = CityGen.mulberry32(h);
              // a heap or a stack has no prop of its own: it is dealt off its back line, the wall's foot
              // or just in from the kerb, toward the street
              if (gp.path == null)
                {
                  var back = (spot == KERB ? CELL / 2 - KERB_BACK : CELL / 2 - WALL_GAP);
                  deal(gp.pile, {
                    x: c.x + DX[dir] * back,
                    z: c.z + DZ[dir] * back,
                    y: y,
                    yaw: face,
                    nx: -DX[dir],
                    nz: -DZ[dir],
                    span: CELL / 2 - PILE_MARGIN,
                    rng: rng,
                  }, put);
                  return;
                }
              var turn = ((h >> 4) % 1000 / 1000.0 - 0.5) * 2 * gp.turn;
              var lean = (gp.lean != null ? ((h >> 20) % 1000 / 1000.0 - 0.5) * 2 * gp.lean : 0.0);
              var out = (spot == KERB ? CELL / 2 - KERB_IN : CELL / 2 - gp.depth / 2 - WALL_GAP);
              // a turned wall prop's corner swings toward the wall by its half width, and a leant one's
              // top moves off it by its height (a positive pitch tips the top toward the street)
              if (spot != KERB &&
                  gp.width != null)
                out -= gp.width / 2 * Math.abs(Math.sin(turn));
              out += gp.h * Math.sin(lean);
              var slide = ((h >> 14) % 1000 / 1000.0 - 0.5) * 2 * SLIDE;
              var x = c.x + DX[dir] * out + DZ[dir] * slide;
              var z = c.z + DZ[dir] * out + DX[dir] * slide;
              var pl:PropPlace = {
                x: x,
                z: z,
                y: y,
                yaw: face + turn,
              };
              if (gp.lean != null)
                pl.pitch = lean;
              put(gp.path, gp.h, pl);
              if (gp.pile != null)
                deal(gp.pile, {
                  x: x,
                  z: z,
                  y: y,
                  yaw: face + turn,
                  nx: 0,
                  nz: 0,
                  span: 0,
                  rng: rng,
                }, put);
              if (gp.vent == true)
                vents.push(new Vector3(x, y + gp.h, z));
              return;
            }
        }
      // the cells either side of a dumpster along its wall
      for (k in bins)
        {
          var col = k % GRID;
          var row = Std.int(k / GRID);
          var w = wallDir(col, row);
          if (w < 0)
            continue;
          for (s in (w < 2 ? [2, 3] : [0, 1]))
            {
              var nc = col + Std.int(DX[s]);
              var nr = row + Std.int(DZ[s]);
              if (open(nc, nr) &&
                  wallDir(nc, nr) == w &&
                  !doorAt(owner, nc, nr, w))
                pick(nc, nr, BIN, w);
            }
        }
      // every kerb and wall cell
      for (row in 0...GRID)
        for (col in 0...GRID)
          {
            if (!open(col, row))
              continue;
            var r = roadDir(col, row);
            if (r >= 0 &&
                WorldCtx.tiles[row][col] == Tile.Walkway)
              pick(col, row, KERB, r);
            var w = wallDir(col, row);
            if (w < 0 ||
                doorAt(owner, col, row, w))
              continue;
            if (WorldCtx.tiles[row][col] == Tile.Alley)
              pick(col, row, SERVICE, w);
            pick(col, row, WALL, w);
          }
      return [for (path in order) Models.instanced(scene, path, batches.get(path), heights.get(path), SOLID)];
    }

// the slums' car wrecks, render-only: game.CityAreaGenerator.placeCars parks each over two road cells
// along one walkway and flips both to Const.TILE_ROAD_UNWALKABLE, which nothing else in a city does,
// so every such pair IS a car. the shell stands over the pair's middle, its length (model x) along it
// and its local -z to the kerb, parked SlumsStyle.CAR_KERB in toward the kerb and turned up to
// CAR_TURN off square, pulled back off the kerb by what the turn swings its corner out. one batch
  public static function wrecks(scene:Scene, area:AreaGame):InstancedProp
    {
      var places:Array<PropPlace> = [];
      for (row in 0...GRID)
        for (col in 0...GRID)
          {
            // each pair once, off its west or north cell
            var east = wreck(area, col + 1, row);
            if (!wreck(area, col, row) ||
                (!east &&
                !wreck(area, col, row + 1)))
              continue;
            // the kerb: the walkway beside the pair, across its length
            var k = -1;
            for (d in (east ? [0, 1] : [2, 3]))
              if (area.getCellType(col + Std.int(DX[d]), row + Std.int(DZ[d])) == Const.TILE_WALKWAY)
                k = d;
            if (k < 0)
              continue;
            var turn = ((cellHash(col, row, -1) >> 4) % 1000 / 1000.0 - 0.5) * 2 * SlumsStyle.CAR_TURN;
            var c = cellToWorld(col + (east ? 0.5 : 0.0), row + (east ? 0.0 : 0.5));
            var kerb = SlumsStyle.CAR_KERB - SlumsStyle.CAR_HALF * Math.abs(Math.sin(turn));
            places.push({
              x: c.x + DX[k] * kerb,
              z: c.z + DZ[k] * kerb,
              yaw: Geom.faceRotY(OPP[k]) + turn,
            });
          }
      return Models.instanced(scene, RenderConfig.MODELS.cityCarWreck, places, SlumsStyle.CAR_H, SOLID);
    }

// is this cell one of a car wreck's two? false off the grid
  static inline function wreck(area:AreaGame, col:Int, row:Int):Bool
    {
      return area.getCellType(col, row) == Const.TILE_ROAD_UNWALKABLE;
    }

// deal one pile's pieces at `s`, each handed to `put` with the height it is drawn at: a HEAP scattered
// over the spot, a STACK piled flat with the rest stood on edge or lying beside, a LOAD over its bed
  static function deal(p:Pile, s:PileSpot, put:String->Float->PropPlace->Void):Void
    {
      var n = p.min + Std.int(s.rng() * (p.max - p.min + 1));
      // a step `d` off the back line and `a` along it, to the world; LOAD's frame is the prop's own
      var ax = s.nz;
      var az = s.nx;
      function lay(part:PilePart, a:Float, d:Float, pl:PropPlace):Void
        {
          pl.x = s.x + s.nx * d + ax * a;
          pl.z = s.z + s.nz * d + az * a;
          pl.y = s.y + (pl.y != null ? pl.y : 0.0);
          put(part.path, part.h, pl);
        }
      // a yaw square to the street give or take the part's `turn`, or any way at all
      function yaw(part:PilePart):Float
        return (part.turn != null ? s.yaw + (s.rng() * 2 - 1) * part.turn : s.rng() * 2 * Math.PI);
      switch (p.kind)
        {
          case HEAP:
            // [along, off, radius] of each piece laid, so the next keeps (mostly) off it
            var laid:Array<Array<Float>> = [];
            for (_ in 0...n)
              {
                var part = draw(p.parts, s.rng);
                var sc = 0.85 + 0.3 * s.rng();
                var r = part.r * sc;
                for (_ in 0...TRIES)
                  {
                    var a = (s.rng() * 2 - 1) * Math.max(0.0, s.span - r);
                    var d = (part.back == true ? BACK_OFF :
                      part.front == true ? FRONT_OFF + s.rng() * FRONT_RUN : r * 0.8 + s.rng() * HEAP_RUN);
                    if (!clear(laid, a, d, r))
                      continue;
                    laid.push([a, d, r]);
                    lay(part, a, d, {
                      x: 0,
                      z: 0,
                      yaw: yaw(part),
                      scale: sc,
                    });
                    break;
                  }
              }
          case STACK:
            // the flat ones one on another at the wall's foot, each a little off the one below
            var flat = Std.int(Math.min(n, 1 + Std.int(s.rng() * 4)));
            var sc = 0.9 + 0.2 * s.rng();
            var r = p.parts[0].r * sc;
            var a0 = (s.rng() * 2 - 1) * Math.max(0.0, s.span - 3 * r);
            var d0 = r + STACK_OFF;
            var lift = 0.0;
            for (_ in 0...flat)
              {
                var part = draw(p.parts, s.rng);
                lay(part, a0 + (s.rng() - 0.5) * 0.12, d0 + (s.rng() - 0.5) * 0.12, {
                  x: 0,
                  z: 0,
                  y: lift,
                  yaw: s.rng() * 2 * Math.PI,
                  pitch: (s.rng() - 0.5) * 0.08,
                  scale: sc,
                });
                lift += part.h * sc;
              }
            // the rest stood on the tread in front, leant back on the stack (a positive pitch tips the
            // top toward the wall; it turns about the bottom face's centre, so the tread is lifted back
            // onto the ground by the radius), or lying flat on one side of it. ONE to each of those
            // three places: two stood within a radius of each other, or two lying on one side, passed
            // through one another. a piece whose place is taken takes another, and with all three
            // taken it is not laid
            var front = false;
            var sides = [false, false];
            for (_ in flat...n)
              {
                var part = draw(p.parts, s.rng);
                var side = (s.rng() < 0.5 ? 0 : 1);
                if (sides[side])
                  side = 1 - side;
                var stand = !front &&
                  (s.rng() < 0.6 ||
                  sides[side]);
                if (!stand &&
                    sides[side])
                  continue;
                if (stand)
                  {
                    front = true;
                    var pitch = Math.PI / 2 - 0.25 - s.rng() * 0.15;
                    // kept square on the stack, so its rim clears a tyre lying either side
                    lay(part, a0 + (s.rng() - 0.5) * 0.1, d0 + r + STACK_OFF, {
                      x: 0,
                      z: 0,
                      y: r * Math.sin(pitch),
                      yaw: s.yaw + (s.rng() - 0.5) * 0.7,
                      pitch: pitch,
                      scale: sc,
                    });
                  }
                else
                  {
                    sides[side] = true;
                    lay(part, a0 + (side * 2 - 1) * (2 * r + 0.1 + s.rng() * 0.3),
                      r + STACK_OFF + s.rng() * 0.5, {
                        x: 0,
                        z: 0,
                        yaw: s.rng() * 2 * Math.PI,
                        scale: sc,
                      });
                  }
              }
          case LOAD:
            var cos = Math.cos(s.yaw);
            var sin = Math.sin(s.yaw);
            var laid:Array<Array<Float>> = [];
            var pinned = false;
            for (_ in 0...n)
              {
                var part = draw(p.parts, s.rng);
                var lx = 0.0;
                var lz = 0.0;
                var ly = p.bed.y;
                var turn = s.rng() * 2 * Math.PI;
                // a pinned part has one place in the basket, and only one of it
                if (part.at != null)
                  {
                    if (pinned)
                      continue;
                    pinned = true;
                    lx = part.at[0];
                    ly = part.at[1];
                    lz = part.at[2];
                    turn = s.yaw + (s.rng() - 0.5) * 0.2;
                  }
                else
                  {
                    var ok = false;
                    for (_ in 0...TRIES)
                      {
                        lx = p.bed.x0 + part.r + s.rng() * Math.max(0.0, p.bed.x1 - p.bed.x0 - 2 * part.r);
                        lz = p.bed.z0 + part.r + s.rng() * Math.max(0.0, p.bed.z1 - p.bed.z0 - 2 * part.r);
                        if (clear(laid, lx, lz, part.r))
                          {
                            ok = true;
                            break;
                          }
                      }
                    if (!ok)
                      continue;
                    laid.push([lx, lz, part.r]);
                  }
                // the prop's frame to the world, as Models.instanced turns it
                put(part.path, part.h, {
                  x: s.x + lx * cos + lz * sin,
                  z: s.z - lx * sin + lz * cos,
                  y: s.y + ly,
                  yaw: turn,
                });
              }
        }
    }

// one part off a pile's list, by weight
  static function draw(parts:Array<PilePart>, rng:Void->Float):PilePart
    {
      var total = 0.0;
      for (p in parts)
        total += p.weight;
      var t = rng() * total;
      for (p in parts)
        {
          t -= p.weight;
          if (t < 0)
            return p;
        }
      return parts[parts.length - 1];
    }

// is (a, d) far enough off every piece laid: they may overlap a little, which is what a heap does
  static function clear(laid:Array<Array<Float>>, a:Float, d:Float, r:Float):Bool
    {
      for (q in laid)
        if ((q[0] - a) * (q[0] - a) + (q[1] - d) * (q[1] - d) < (q[2] + r) * (q[2] + r) * CLOSE * CLOSE)
          return false;
      return true;
    }

  // a direction's unit step on the grid, as Geom numbers the faces (0 +z, 1 -z, 2 +x, 3 -x), and the
  // direction opposite it
  static final DX:Array<Float> = [0, 0, 1, -1];
  static final DZ:Array<Float> = [1, -1, 0, 0];
  static final OPP:Array<Int> = [1, 0, 3, 2];

// is the cell on the grid and open ground (alley or walkway)?
  static function open(col:Int, row:Int):Bool
    {
      if (col < 0 ||
          row < 0 ||
          col >= GRID ||
          row >= GRID)
        return false;
      var t = WorldCtx.tiles[row][col];
      return t == Tile.Alley ||
        t == Tile.Walkway;
    }

// the one direction from this cell that holds a tile of kind `k`, or -1 for none or several
  static function onlyDir(col:Int, row:Int, k:Tile):Int
    {
      var found = -1;
      for (d in 0...4)
        {
          var c = col + Std.int(DX[d]);
          var r = row + Std.int(DZ[d]);
          if (c < 0 ||
              r < 0 ||
              c >= GRID ||
              r >= GRID ||
              WorldCtx.tiles[r][c] != k)
            continue;
          if (found >= 0)
            return -1;
          found = d;
        }
      return found;
    }

// the single road beside this cell (a corner has two and is left bare)
  static inline function roadDir(col:Int, row:Int):Int
    {
      return onlyDir(col, row, Tile.Road);
    }

// the single building wall beside this cell (an alley between two has none)
  static inline function wallDir(col:Int, row:Int):Int
    {
      return onlyDir(col, row, Tile.Building);
    }

// would a prop against the wall at `w` from this cell stand across a door in that wall?
  static function doorAt(owner:Map<Int, Building>, col:Int, row:Int, w:Int):Bool
    {
      var b = owner.get((row + Std.int(DZ[w])) * GRID + col + Std.int(DX[w]));
      var c = cellToWorld(col, row);
      return b != null &&
        onDoor(b, OPP[w], (w < 2 ? c.x : c.z), CELL / 2 - 0.2);
    }

// a per-cell, per-prop decision hash
  static inline function cellHash(col:Int, row:Int, i:Int):Int
    {
      return ((col * 73856093) ^ (row * 19349663) ^ ((i + 1) * 83492791)) & 0x7fffffff;
    }

// merge the kit per render.Chunks cell in the kit's own material: each building's modules into one
// slice, the slices of the buildings whose centre falls in the cell into one mesh, centred on its
// contents so the chunk pass buckets it where it stands. the modules are the kit glb's meshes, keyed
// by the suffix kit_build.py `pack` names them with
  static function merge(scene:Scene, t:Models.ModelTemplate, list:Array<KitPlace>):Array<KitChunk>
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
      var CH = CELL * Chunks.CELLS;
      var by = new haxe.ds.ObjectMap<Building, Array<BufferGeometry>>();
      var cells = new Map<String, Array<Building>>();
      var order:Array<String> = [];
      for (k in list)
        {
          var geos = by.get(k.b);
          if (geos == null)
            {
              geos = [];
              by.set(k.b, geos);
              var c = cellToWorld(k.b.col + (k.b.w - 1) / 2, k.b.row + (k.b.d - 1) / 2);
              var key = Math.floor(c.x / CH) + ':' + Math.floor(c.z / CH);
              if (!cells.exists(key))
                {
                  cells.set(key, []);
                  order.push(key);
                }
              cells.get(key).push(k.b);
            }
          var g:BufferGeometry = src.get(k.key);
          geos.push(g.clone().applyMatrix4(k.m));
        }
      // the material is the kit glb's own (three's, Dynamic on Object3D): the proxies wear an
      // invisible clone of it, which three skips before it ever compiles or draws
      var mat:Dynamic = first.material;
      var hidden:Dynamic = mat.clone();
      hidden.visible = false;
      var out:Array<KitChunk> = [];
      for (key in order)
        {
          var bs = cells.get(key);
          var slices:Array<BufferGeometry> = [];
          for (b in bs)
            {
              var geos = by.get(b);
              slices.push(THREE.mergeGeometries(geos, false));
              for (g in geos)
                g.dispose();
            }
          // one group per slice, in building order: the index ranges the parts keep
          var geo:BufferGeometry = THREE.mergeGeometries(slices, true);
          for (g in slices)
            g.dispose();
          geo.computeBoundingBox();
          var cx = (geo.boundingBox.min.x + geo.boundingBox.max.x) / 2;
          var cz = (geo.boundingBox.min.z + geo.boundingBox.max.z) / 2;
          geo.translate(-cx, 0, -cz);
          var parts:Array<KitPart> = [];
          for (i in 0...bs.length)
            {
              var gr = geo.groups[i];
              // the same buffers, so the proxy and its ghost cost no memory and no upload
              var pg = new BufferGeometry();
              for (name in Reflect.fields(geo.attributes))
                pg.setAttribute(name, geo.getAttribute(name));
              pg.setIndex(geo.index);
              pg.setDrawRange(gr.start, gr.count);
              var proxy = new Mesh(pg, hidden);
              proxy.name = 'wall kit';
              proxy.position.set(cx, 0, cz);
              proxy.userData.b = bs[i];
              scene.add(proxy);
              parts.push({
                proxy: proxy,
                start: gr.start,
                count: gr.count,
                shown: true,
              });
            }
          geo.clearGroups();
          geo.addGroup(0, geo.index.count, 0);
          // a material ARRAY, so three draws the groups `sync` lays down rather than the whole index
          var mesh = new Mesh(geo, [mat]);
          mesh.name = 'wall kit';
          mesh.position.set(cx, 0, cz);
          // never bucketed into a building by the fader: its proxies are
          mesh.userData.occMarker = true;
          // darkens with the wall under a neighbour's or a lamp's shadow, as the windows do
          mesh.receiveShadow = true;
          scene.add(mesh);
          out.push({
            mesh: mesh,
            parts: parts,
          });
        }
      return out;
    }

// per frame, after the fader: a chunk draws one group per run of slices whose proxy the fader has
// not hidden (render.Occlusion hides the real under a ghost once it fully covers), so a solid chunk
// is one draw and a faded building leaves its ghost alone where its kit stood. no-op unless a proxy
// flipped since the last call
  public static function sync(kits:Array<KitChunk>):Void
    {
      for (k in kits)
        {
          var changed = false;
          for (p in k.parts)
            if (p.shown != p.proxy.visible)
              {
                p.shown = p.proxy.visible;
                changed = true;
              }
          if (!changed)
            continue;
          var geo:BufferGeometry = k.mesh.geometry;
          geo.clearGroups();
          var start = -1;
          var end = 0;
          for (p in k.parts)
            {
              if (p.shown)
                {
                  if (start < 0)
                    start = p.start;
                  end = p.start + p.count;
                }
              else if (start >= 0)
                {
                  geo.addGroup(start, end - start, 0);
                  start = -1;
                }
            }
          if (start >= 0)
            geo.addGroup(start, end - start, 0);
        }
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
      // a heap dealt off a back line along x stays within its span and in front of the line, a stack
      // climbs, and a load lands inside its bed
      var part:PilePart = {
        path: 'a',
        h: 0.5,
        r: 0.4,
        weight: 1,
      };
      var got:Array<PropPlace> = [];
      var spot:PileSpot = {
        x: 0,
        z: 0,
        y: 0,
        yaw: 0,
        nx: 0,
        nz: 1,
        span: 1.2,
        rng: CityGen.mulberry32(7),
      };
      var take = function(_:String, _:Float, pl:PropPlace) got.push(pl);
      deal({
        kind: HEAP,
        parts: [ part ],
        min: 5,
        max: 5,
      }, spot, take);
      var ok = got.length > 0;
      for (pl in got)
        if (Math.abs(pl.x) > 1.2 ||
            pl.z < 0 ||
            pl.z > 2)
          ok = false;
      got = [];
      deal({
        kind: STACK,
        parts: [ part ],
        min: 3,
        max: 3,
      }, spot, take);
      ok = ok && got.length == 3 && got[0].y < 1e-9;
      // and a full stack keeps its extras apart: one leant on it at most, and nothing on the ground
      // within a tyre's width of anything else there
      for (seed in 0...40)
        {
          got = [];
          spot.rng = CityGen.mulberry32(seed);
          deal({
            kind: STACK,
            parts: [ part ],
            min: 5,
            max: 5,
          }, spot, take);
          var ground = [for (pl in got) if (pl.y < 1e-9) pl];
          for (a in ground)
            for (b in ground)
              if (a != b &&
                  Math.sqrt((a.x - b.x) * (a.x - b.x) + (a.z - b.z) * (a.z - b.z)) < 0.7)
                ok = false;
          ok = ok && [for (pl in got) if (pl.pitch != null && pl.pitch > 1) pl].length <= 1;
        }
      got = [];
      spot.yaw = Math.PI / 2;
      deal({
        kind: LOAD,
        parts: [ part ],
        min: 4,
        max: 4,
        bed: {
          x0: -1,
          x1: 1,
          z0: -0.5,
          z1: 0.5,
          y: 0.7,
        },
      }, spot, take);
      // turned a quarter, the bed's x runs along -z and its z along x
      for (pl in got)
        if (Math.abs(pl.z) > 1 + 1e-9 ||
            Math.abs(pl.x) > 0.5 + 1e-9 ||
            Math.abs(pl.y - 0.7) > 1e-9)
          ok = false;
      return ok &&
        Math.abs(v.x - 1) < 1e-9 &&
        Math.abs(w.z + 1) < 1e-9;
    }
}
