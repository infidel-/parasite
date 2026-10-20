package render.cave;

import three.Three;
import citygen.CityConfig;
import gen.cave.CaveField;
import render.Models;
import render.cave.CaveStyle.CaveLight;
import render.cave.CaveStyle.CaveProp;
import render.cave.CaveStyle.CavePropSpot;
import render.sewer.SewerModel;
import render.sewer.SewerModel.Sewer;
import render.sewer.SewerProps;
import render.world.VisionMask;

// one glowing piece: what render.cave.CaveScene hangs its pooled spotlight off and render.cave.CaveGeom
// bakes its glow from
typedef CaveGlow = {
  x:Float,          // world position of the piece
  z:Float,
  top:Float,        // its crown, world units over the floor
  dx:Float,         // the way it faces, unit, in xz
  dz:Float,
  light:CaveLight,  // its row's light
}

// the cave's dressing — stalagmites, flowstone, fallen rock, rimstone pools, crystals, fungus and root
// curtains — dealt against the wall foot. a rimstone basin is not dealt: it lies on each pool cell the
// generator blocked to walking (gen.cave.CaveGen.pools), since it fills most of a cell and an actor
// stood in it. render.sewer.SewerProps' idiom (per 2x2 block, gated per
// eligible wall face, dealt from a deck so a run cannot repeat, never the camera-side face, never next
// to an exit) with one difference that is the cave's: the wall is not on the cell edge. the outline
// sits wherever gen.cave.CaveField crosses ISO, a lumpy distance into the rock, so each prop finds its
// own wall by walking the field and stands off THAT, then steps out until its whole footprint clears
// the rock (a corner rounds off, a lumpy wall comes forward across a wide prop) or is dropped.
//
// pure decoration, like the sewer's: no AreaObject behind it, one instanced batch per glb
class CaveProps
{
  static inline var CELL = CityConfig.CELL;

  // a wall face's neighbour, as render.sewer.SewerProps: 0 north, 1 south, 2 west, 3 east
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];
  // the south face stands between the camera and its cell and hides anything against it
  // (render.sewer.SewerProps.CAM_DIR measured why)
  static inline var CAM_DIR = 1;
  // see render.sewer.SewerProps.PICK_ODD: a deck index reduced through an odd modulus, not a bit
  static inline var PICK_ODD = 997;
  // points round a footprint ellipse that clear() tests against the rock
  static inline var FOOT_SAMPLES = 16;

// scatter, then batch: one InstancedMesh per glb
  public static function build(scene:Scene, m:Sewer):Void
    {
      var models = CaveStyle.PROP_MODELS;
      var places = places(m);
      // ponytail: no per-frame cull, for render.sewer.SewerProps' reason (a static level's handful)
      for (i in 0...models.length)
        {
          // a cave dealt none of a piece builds no batch (a cave from before the pools has no basin)
          if (places[i].length == 0)
            continue;
          var path = models[i].path;
          var prop = Models.instanced(scene, path, places[i], models[i].h, SOLID);
          Models.get(path, function(_) patch(path, prop.mesh));
        }
    }

// the patches a dressing batch draws with: the pools' water surface first, then the shading (the
// crystals' shimmer and glints with it), then the vision mask over both. shared with
// render.cave.CaveWarm, so the warm compiles the same programs
  public static function patch(path:String, mesh:InstancedMesh):Void
    {
      if (path == render.RenderConfig.MODELS.caveRimstone)
        CaveWater.patch(mesh.material);
      var h = 0.0;
      for (mdl in CaveStyle.PROP_MODELS)
        if (mdl.path == path)
          h = mdl.h;
      CaveShade.patch(mesh.material, h, path == render.RenderConfig.MODELS.caveCrystals);
      VisionMask.patchMesh(mesh);
    }

// the glowing pieces, off the same deal build() draws: one per crystal cluster and fungus patch
  public static function glows(m:Sewer):Array<CaveGlow>
    {
      var models = CaveStyle.PROP_MODELS;
      var places = places(m);
      var out = [];
      for (i in 0...models.length)
        {
          var mdl = models[i];
          if (mdl.light == null)
            continue;
          for (p in places[i])
            {
              // the prop's local +z faces (nx, nz), and its yaw is atan2 of that (see place())
              out.push({
                x: p.x,
                z: p.z,
                top: mdl.h * p.scale,
                dx: Math.sin(p.yaw),
                dz: Math.cos(p.yaw),
                light: mdl.light,
              });
            }
        }
      return out;
    }

// the scatter itself: one placement list per PROP_MODELS entry, readable without a scene —
// parasiteHx['render.cave.CaveProps'].places(render.cave.CaveModel.demo())
  public static function places(m:Sewer):Array<Array<Models.PropPlace>>
    {
      var models = CaveStyle.PROP_MODELS;
      var places:Array<Array<Models.PropPlace>> = [for (_ in models) []];
      var decks:Array<Array<Int>> = [[], [], [], []];
      // the basins first, each against the first of its north, west and east walls that is rock (the
      // generator's straight run of it)
      var pool = 0;
      while (models[pool].spot != POOL)
        pool++;
      for (c in m.pools)
        {
          var dir = (!SewerModel.isFloor(m, c.col, c.row - 1) ? 0 :
            !SewerModel.isFloor(m, c.col - 1, c.row) ? 2 : 3);
          var h = SewerModel.mix((c.col * 73856093) ^ (c.row * 19349663));
          places[pool].push(place(m, c.col, c.row, dir, -1, models[pool], h));
        }
      for (brow in 0...Std.int((m.h + 1) / 2))
        for (bcol in 0...Std.int((m.w + 1) / 2))
          {
            var bc = bcol * 2;
            var br = brow * 2;
            // multipliers of their own, so these rolls do not correlate with anything else's
            var hh = SewerModel.mix((bc * 83492791) ^ (br * 29986577));
            var hang = SewerModel.mix((bc * 15485863) ^ (br * 32452843));
            var faces = [];
            var north = [];
            for (dr in 0...2)
              for (dc in 0...2)
                {
                  var col = bc + dc;
                  var row = br + dr;
                  if (!SewerModel.isFloor(m, col, row) ||
                      isPool(m, col, row) ||
                      SewerProps.nearExit(m, col, row))
                    continue;
                  for (dir in 0...4)
                    if (dir != CAM_DIR &&
                        !SewerModel.isFloor(m, col + DC[dir], row + DR[dir]))
                      {
                        var face = {
                          col: col,
                          row: row,
                          dir: dir,
                        };
                        faces.push(face);
                        if (dir == 0 &&
                            (northFace(m, col - 1, row) ||
                            northFace(m, col + 1, row)))
                          north.push(face);
                      }
                }

            // a floor prop: a corner deals from the corner deck, a flat run of wall from the flat one
            if (faces.length > 0 &&
                hh % 100 < CaveStyle.PROP_PCT * faces.length)
              {
                var f = faces[(hh >> 7) % faces.length];
                var perp = -1;
                for (g in faces)
                  if (g.col == f.col &&
                      g.row == f.row &&
                      (g.dir < 2) != (f.dir < 2))
                    {
                      perp = g.dir;
                      break;
                    }
                var h2 = SewerModel.mix(hh ^ 0x85EBCA6B);
                var mi = deal(decks, perp >= 0 ? CORNER : FLAT, h2);
                var p = place(m, f.col, f.row, f.dir, perp, models[mi], h2);
                if (p != null)
                  places[mi].push(p);
              }

            // a root curtain, down a north face only
            if (north.length > 0 &&
                hang % 100 < CaveStyle.HANG_PCT * north.length)
              {
                var f = north[(hang >> 7) % north.length];
                var h2 = SewerModel.mix(hang ^ 0xC2B2AE35);
                var mi = deal(decks, HANG, h2);
                var p = place(m, f.col, f.row, f.dir, -1, models[mi], h2);
                if (p != null)
                  places[mi].push(p);
              }
          }
      return places;
    }

// is (col, row) one of the cave's pool cells?
  static function isPool(m:Sewer, col:Int, row:Int):Bool
    {
      for (c in m.pools)
        if (c.col == col &&
            c.row == row)
          return true;
      return false;
    }

// is this a floor cell with rock to its north and no exit beside it — a cell a root curtain may hang
// over? a curtain is wider than its cell, so it is dealt only where the face runs on into a neighbour
  static function northFace(m:Sewer, col:Int, row:Int):Bool
    {
      return SewerModel.isFloor(m, col, row) &&
        !SewerModel.isFloor(m, col, row - 1) &&
        !SewerProps.nearExit(m, col, row);
    }

// the next model index off the spot's deck, refilled and Fisher-Yates shuffled off the hash chain
// when it runs dry (render.sewer.SewerProps: a deck caps a run by construction, a roll cannot)
  static function deal(decks:Array<Array<Int>>, spot:CavePropSpot, h:Int):Int
    {
      var deck = decks[spot.getIndex()];
      if (deck.length == 0)
        {
          var models = CaveStyle.PROP_MODELS;
          for (i in 0...models.length)
            if (models[i].spot == spot)
              deck.push(i);
          var r = h;
          var k = deck.length;
          while (k > 1)
            {
              r = SewerModel.mix(r);
              k--;
              var j = (r % PICK_ODD) % (k + 1);
              var t = deck[k];
              deck[k] = deck[j];
              deck[j] = t;
            }
        }
      return deck.pop();
    }

// stand one prop off the wall foot of face `dir` of a cell (and of `perp` too, for a corner): find
// where the field crosses ISO along the face normal, step back toward the floor by the prop's own
// standoff, less the tuck, then clear its footprint. a hung prop is set flush on the foot nearest the
// floor across its width and lifted so its top sits just under the rock top's lip there. null when it
// does not fit: a floor prop the far wall blocks, a curtain on a wall that wanders too much
  static function place(m:Sewer, col:Int, row:Int, dir:Int, perp:Int, mdl:CaveProp,
      h:Int):Models.PropPlace
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var sLo = (mdl.spot == POOL ? CaveStyle.POOL_SCALE_LO : CaveStyle.PROP_SCALE_LO);
      var sHi = (mdl.spot == POOL ? CaveStyle.POOL_SCALE_HI : CaveStyle.PROP_SCALE_HI);
      var scale = sLo + (sHi - sLo) * ((h >> 5) % 1001) / 1000.0;
      var off = mdl.r * mdl.h * scale * (1 - CaveStyle.PROP_TUCK);
      // the cell centre, slid along a flat wall (a corner pins both axes, so it does not slide, and a
      // basin owns its cell, so it stays centred in it)
      var slide = (perp < 0 &&
        mdl.spot != POOL ? (((h >> 11) % 2001) / 1000.0 - 1.0) * CaveStyle.PROP_SLIDE / CELL : 0.0);
      var u = col + 0.5 + (dir < 2 ? slide : 0.0);
      var v = row + 0.5 + (dir < 2 ? 0.0 : slide);
      // a curtain hangs inside its run of north face, clear of the rounded corners at both ends: one
      // hung at the end of a wall ran on past it and stuck out of the rock beside it (asked for)
      var hw = mdl.w * mdl.h * scale / CELL;
      if (mdl.spot == HANG)
        {
          var c0 = col;
          while (northFace(m, c0 - 1, row))
            c0--;
          var c1 = col;
          while (northFace(m, c1 + 1, row))
            c1++;
          var lo = c0 + CaveStyle.HANG_END + hw;
          var hi = c1 + 1 - CaveStyle.HANG_END - hw;
          if (lo > hi)
            return null;
          u = Math.max(lo, Math.min(hi, u));
        }
      var nx = 0.0;
      var nz = 0.0;
      var footU = u;
      var footV = v;
      for (d in [dir, perp])
        {
          if (d < 0)
            continue;
          var foot = foot(m, col, row, d, u, v);
          switch (d)
            {
              case 0:
                footV = foot;
                v = foot + off / CELL;
                nz += 1;
              case 2:
                footU = foot;
                u = foot + off / CELL;
                nx += 1;
              case 3:
                footU = foot;
                u = foot - off / CELL;
                nx -= 1;
              default:
            }
        }
      // a curtain's back on the foot nearest the floor across its whole width, so no part of it is
      // buried, and none if the wall wanders more than HANG_FLUSH behind it
      if (mdl.spot == HANG)
        {
          var lo = footV;
          var hi = footV;
          for (e in [u - hw, u + hw])
            {
              var f = foot(m, col, row, 0, e, footV);
              lo = Math.min(lo, f);
              hi = Math.max(hi, f);
            }
          if (hi - lo > CaveStyle.HANG_FLUSH)
            return null;
          v += hi - footV;
        }
      var jit = (((h >> 3) % 2001) / 1000.0 - 1.0) * CaveStyle.PROP_YAW_JITTER;
      var p:Models.PropPlace = {
        x: u * CELL - half,
        z: v * CELL - half,
        yaw: Math.atan2(nx, nz) + (mdl.spot == HANG ? 0.0 : jit),
        scale: scale,
      };
      if (mdl.spot == HANG)
        {
          p.y = CaveGeom.topY(footU, footV, 0) - mdl.h * scale - CaveStyle.HANG_TUCK;
          return p;
        }
      var x = p.x;
      var z = p.z;
      if (clear(m, p, mdl, nx, nz))
        return p;
      if (mdl.spot != POOL)
        return null;
      // a basin is always drawn: it is what blocks its cell. the generator only picks a cell backed by
      // a straight run of rock, so what stopped it is a lump of the wall, never the far side
      p.x = x;
      p.z = z;
      return p;
    }

// step a floor prop out along its facing until its footprint clears the rock: an ellipse of its own
// half width and half depth at its scale plus PROP_CLEAR, turned with it, every sample of which has
// to be on the floor side of the outline — and, for anything but the basin, off the pool cells, so
// nothing stands in one. false when PROP_PUSH_MAX runs out first
  static function clear(m:Sewer, p:Models.PropPlace, mdl:CaveProp, nx:Float, nz:Float):Bool
    {
      var isFloor = function(c:Int, r:Int) return SewerModel.isFloor(m, c, r);
      var half = (CityConfig.GRID * CELL) / 2;
      var a = mdl.w * mdl.h * p.scale + CaveStyle.PROP_CLEAR;
      var b = mdl.r * mdl.h * p.scale + CaveStyle.PROP_CLEAR;
      var nl = Math.sqrt(nx * nx + nz * nz);
      var cs = Math.cos(p.yaw);
      var sn = Math.sin(p.yaw);
      var pushed = 0.0;
      while (pushed <= CaveStyle.PROP_PUSH_MAX)
        {
          var hit = false;
          for (k in 0...FOOT_SAMPLES)
            {
              var t = 2 * Math.PI * k / FOOT_SAMPLES;
              var lx = Math.cos(t) * a;
              var lz = Math.sin(t) * b;
              // the prop's local x and z turned by its yaw, as three turns it (local +z faces (nx, nz))
              var x = p.x + lx * cs + lz * sn;
              var z = p.z - lx * sn + lz * cs;
              var u = (x + half) / CELL;
              var v = (z + half) / CELL;
              if (CaveField.field(isFloor, u, v) < CaveField.ISO ||
                  (mdl.spot != POOL &&
                  isPool(m, Math.floor(u), Math.floor(v))))
                {
                  hit = true;
                  break;
                }
            }
          if (!hit)
            return true;
          p.x += nx / nl * CaveStyle.PROP_PUSH;
          p.z += nz / nl * CaveStyle.PROP_PUSH;
          pushed += CaveStyle.PROP_PUSH;
        }
      return false;
    }

// the wall foot behind face `d` of a cell, in cells along that face's axis: walk from the cell edge
// into the neighbour until the field falls under ISO. the oracle (gen.GenCheck.caveSane) asserts a
// rock cell's centre is always under it, so the walk ends within half a cell. public for
// render.cave.CaveArea.objWall, which stands the exit arch off the same foot
  public static function foot(m:Sewer, col:Int, row:Int, d:Int, u:Float, v:Float):Float
    {
      var isFloor = function(c:Int, r:Int) return SewerModel.isFloor(m, c, r);
      var t = 0.0;
      while (t < 0.5)
        {
          var f = switch (d)
            {
              case 0: CaveField.field(isFloor, u, row - t);
              case 2: CaveField.field(isFloor, col - t, v);
              default: CaveField.field(isFloor, col + 1 + t, v);
            }
          if (f < CaveField.ISO)
            break;
          t += 0.02;
        }
      return switch (d)
        {
          case 0: row - t;
          case 2: col - t;
          default: col + 1 + t;
        }
    }
}
