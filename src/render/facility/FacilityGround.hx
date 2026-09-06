package render.facility;

import three.Three;
import citygen.CityConfig;
import render.Models;
import render.RenderConfig;
import render.Textures;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.Kerb;
import render.world.Kerb.KerbSeg;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// one park model and which tile id plants it
typedef GreenProp = {
  // the tile the generator wrote (Const.TILE_TREE1..+3, Const.TILE_BUSH, TILE_GRASS_UNWALKABLE)
  tile:Int,
  // RenderConfig.MODELS entry
  path:String,
  // world height, and with it the width: render.Models.instanced scales by HEIGHT alone
  h:Float,
  // how far off its cell centre a prop may sit, as a fraction of a cell
  jitter:Float,
  // per-instance SIZE spread, as a fraction of h either side of 1.0. a batch is one glb drawn many
  // times, so without this 163 bushes are one bush repeated — render.Models.PropPlace.scale carries
  // the same obituary. 0 for anything MANUFACTURED: the wilderness's guard rail is alone in its own
  // table at 0 for exactly this reason, a run of made objects at visibly different sizes reads as
  // broken rather than as varied
  scaleJit:Float,
  // how far the prop is SUNK below the ground it stands on, as a fraction of its own height. a
  // generated canopy tapers to a ragged fringe of holes and spikes where its trunk ought to be, and
  // burying that fringe is cheaper and better-looking than any amount of regeneration. 0 for
  // anything whose base is a real footprint
  sink:Float,
  // does this prop have an AUTHORED FRONT? a plant takes a full random turn, a bench is turned to
  // face the path beside it — see `green`, which is where the two yaws part company
  faces:Bool,
  // does it cast a shadow? every other prop in the game does — render.Models.instanced turns both
  // shadow flags on for a real batch — and the park shrub is the one thing that says otherwise. an
  // instanced batch is drawn into the moon's shadow map as many times as it is drawn into the frame,
  // so 163 shrubs at 4955 tris each were 45% of the park's triangles for a dome 42 screen-pixels
  // across whose moon shadow is a few pixels of lawn. the trees keep theirs — theirs is the shadow
  // that reads. receives either way: a shrub standing in a tree's shadow still darkens
  casts:Bool,
};

// the facility's OUTDOORS: the four ground surfaces, the kerb between them, and the park's trees,
// bushes, benches and railing. what is PAINTED on the asphalt — the parking lot and the road's lane
// lines — is render.facility.FacilityPaint, which `build` calls last and which reads its heights
// back off `surfY` here.
//
// one merged mesh per surface type rather than per cell, exactly as render.world.Ground does for a
// city street, and world-aligned UVs on both axes so nothing is ever stretched and abutting cells
// share one continuous grid. a facility has no relief, so a surface is flat — but the four are not
// all at one height: see FacilityStyle.KERB_DROP for which three dropped and why it is those three
class FacilityGround
{
  static inline var CELL = CityConfig.CELL;
  // the four cell-edge directions, in render.facility.FacilityGeom's own numbering
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

  // the park is dressed with the wilderness's own plants: same night, same style, and TWO of the
  // four trees the tile ids distinguish. the other two are dead wood and have no row here — +3 is
  // the dead snag outright, and +1 is `tree-broadleaf`, a BARE broadleaf with thick limbs and no
  // foliage, which is a dead tree by any reading however the wilderness files it. `green` folds both
  // ids onto the two that are in leaf. a maintained institutional park keeps no dead wood, and doing
  // it on this side as well as in the generator is what makes it RETROACTIVE: an area saved before
  // the generator stopped dealing those ids still has them on its grid
  public static final GREEN:Array<GreenProp> = [
    {
      tile: Const.TILE_TREE1,
      path: RenderConfig.MODELS.wildTreeConifer,
      h: 7.5,
      jitter: 0.20,
      scaleJit: FacilityStyle.PLANT_SCALE_JIT,
      faces: false,
      casts: true,
      sink: 0.0,
    },
    {
      tile: Const.TILE_TREE1 + 2,
      path: RenderConfig.MODELS.wildTreeBroadleafFull,
      h: 9.5,
      jitter: 0.22,
      scaleJit: FacilityStyle.PLANT_SCALE_JIT,
      faces: false,
      casts: true,
      // its canopy runs all the way down and ends in a ragged fringe of holes and spikes instead of
      // a trunk, which stood proud of the lawn and read as torn geometry. sunk, the fringe is under
      // the ground and the dome above it is all that shows. the SAME constant the wilderness sinks
      // the same glb by, because it is a property of the mesh and not of either area
      sink: render.wild.WildStyle.BROADLEAF_SINK,
    },
    {
      tile: Const.TILE_BUSH,
      path: RenderConfig.MODELS.wildBushLow,
      h: 1.1,
      jitter: 0.28,
      scaleJit: FacilityStyle.PLANT_SCALE_JIT,
      faces: false,
      casts: false,
      sink: 0.0,
    },
    // the park bench, which the generator writes as an unwalkable grass cell beside its path. it is
    // the one entry here that MUST draw: a green cell with nothing on it is a wall the player cannot
    // see, and unlike a plant this tile has no other meaning
    {
      tile: Const.TILE_GRASS_UNWALKABLE,
      path: RenderConfig.MODELS.facilityBenchPark,
      h: FacilityStyle.PARK_BENCH_H,
      jitter: 0.0,
      // and it does NOT vary in size. it is manufactured, so a run of them at different sizes reads
      // as broken; and `bins` places the litter bin off this bench's own half-extents (BIN_SIDE /
      // BIN_BACK, both fitted against a fixed 3.57-unit seat), so a scaled bench would walk its bin
      scaleJit: 0.0,
      faces: true,
      casts: true,
      sink: 0.0,
    },
  ];

// the ground surfaces, the kerb along every pavement edge that steps down, and the paint
  public static function build(scene:Scene, m:Facility):Void
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var road = MeshBufTools.make();
      var walkway = MeshBufTools.make();
      var lot = MeshBufTools.make();
      var grass = MeshBufTools.make();
      var curbs:Array<KerbSeg> = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            var s = m.surf[row][col];
            var b = surfBuf(s, road, walkway, lot, grass);
            if (b == null)
              continue;
            var x0 = col * CELL - half, x1 = x0 + CELL;
            var z0 = row * CELL - half, z1 = z0 + CELL;
            var y = surfY(s);
            quad(b, x0, x1, z0, z1, y);
            // and the vertical step at every edge where this cell's surface is not its neighbour's.
            // two cases, and the first is the one the eye reads: a PAVEMENT edge over a lower
            // neighbour takes the mitred kerb strip, which carries its own face. anything else
            // higher than its neighbour just needs the gap closing in its own texture, which on a
            // generated compound is the sidewalk's parking entry and nothing else.
            //
            // MASONRY is NOT a third case, and it used to be one. a wall cell paints no ground, so
            // a dropped surface beside it was made to close its own slot upward — but the strip
            // INSIDE that wall cell is laid at the neighbour's height by the floorStrips pass below,
            // so both sides of the riser came out at -KERB_DROP and it stood in the lot as a 0.2 fin
            // one unit off the hangar wall, with the 0.2 gap it was meant to close still open at the
            // wall face beyond it. the masonry closes it now, from FacilityStyle.WALL_BASE
            for (dir in 0...4)
              {
                var nc = col + DC[dir];
                var nr = row + DR[dir];
                var ny = (FacilityModel.inside(m, nc, nr) ? surfY(m.surf[nr][nc]) : y);
                if (ny >= y)
                  continue;
                var ax = (dir == 3 ? x1 : x0);
                var az = (dir == 1 ? z1 : z0);
                var bx = (dir == 2 ? x0 : x1);
                var bz = (dir == 0 ? z0 : z1);
                if (s == Surf.WALKWAY)
                  {
                    Kerb.push(curbs, ax, az, bx, bz,
                      (x0 + x1) / 2 + DC[dir] * CELL, (z0 + z1) / 2 + DR[dir] * CELL);
                    continue;
                  }
                riser(b, ax, az, bx, bz, dir < 2, Math.min(y, ny), Math.max(y, ny));
              }
          }
      // a wall is only HALF a cell thick, so the rest of every wall cell is ground — and it is the
      // ground of whichever neighbour the strip abuts, laid on the same world-aligned grid so it
      // continues that surface without a seam. render.facility.FacilityGeom emits the indoor half of
      // the same strips off the same FacilityGeom.strips(); this pass takes the outdoor ones because
      // this is where the ground buffers are.
      //
      // DOOR cells too, not just walls: a doorway's slab is its lintel, so an exterior door leaves
      // the same strip of pavement inside its cell that the wall beside it does. tested with isWall
      // alone, those 7 strips got no ground at all and the door cell's own floor covered them —
      // 28 square units of corridor lino painted out on the walkway.
      //
      // and `floorStrips` rather than `strips`, which is what carries the OUTER HALF of an exterior
      // doorway: there is no masonry under a lintel, so the threshold's outdoor half is pavement all
      // the way to the wall line rather than lino to within a unit of it
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (!FacilityGeom.carries(m, col, row))
              continue;
            for (sp in FacilityGeom.floorStrips(m, col, row))
              {
                var s = m.surf[sp.row][sp.col];
                var b = surfBuf(s, road, walkway, lot, grass);
                if (b == null)
                  continue;
                quad(b, sp.x0, sp.x1, sp.z0, sp.z1, surfY(s));
              }
          }
      add(scene, road, FacilityStyle.GROUND_ROAD);
      add(scene, walkway, FacilityStyle.GROUND_WALKWAY);
      add(scene, lot, FacilityStyle.GROUND_LOT);
      add(scene, grass, FacilityStyle.GROUND_GRASS);
      // the kerb edging, in its own mesh because it is the one outdoor surface with a texture of its
      // own. the pavement is the RAISED side here where a street's is the raised side over a road at
      // zero, so the pair goes in the other way up — see FacilityStyle.KERB_DROP
      var border = MeshBufTools.make();
      Kerb.emit(border, curbs, RenderConfig.WALKWAY_BORDER_W, RenderConfig.WALKWAY_BORDER_TILE,
        0.0, -FacilityStyle.KERB_DROP);
      add(scene, border, FacilityStyle.GROUND_BORDER);
      FacilityPaint.build(scene, m);
    }

// the height a surface's floor lies at. only the pavement and the indoor floors hold 0, and
// FacilityStyle.KERB_DROP says at length why it is those and not the three outdoors ones
  public static inline function surfY(s:Surf):Float
    return (s == Surf.ROAD || s == Surf.GRASS || s == Surf.LOT
      ? -FacilityStyle.KERB_DROP : 0.0);

// the vertical face closing a step at a cell edge, in the surface's own texture. `alongX` says which
// axis the edge runs on, so u follows the run and v the height — world-aligned like everything else
  static function riser(b:MeshBuf, ax:Float, az:Float, bx:Float, bz:Float, alongX:Bool,
      y0:Float, y1:Float):Void
    {
      var t = FacilityStyle.GROUND_TILE;
      var u0 = (alongX ? ax : az) / t;
      var u1 = (alongX ? bx : bz) / t;
      MeshBufTools.quad(b, [ax, y0, az], [bx, y0, bz], [bx, y1, bz], [ax, y1, az],
        [u0, y0 / t, u1, y0 / t, u1, y1 / t, u0, y1 / t]);
    }

// the outdoor buffer a surface belongs in, or null if the surface is not outdoors at all
  static function surfBuf(s:Surf, road:MeshBuf, walkway:MeshBuf, lot:MeshBuf, grass:MeshBuf):MeshBuf
    {
      return switch (s)
        {
          case Surf.ROAD: road;
          case Surf.WALKWAY: walkway;
          case Surf.LOT: lot;
          case Surf.GRASS: grass;
          default: null;
        };
    }

// one ground quad at its surface's own height, world-aligned on BOTH axes so abutting cells share
// one continuous grid and nothing is ever stretched
  static function quad(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, y:Float):Void
    {
      var t = FacilityStyle.GROUND_TILE;
      MeshBufTools.quad(b, [x0, y, z1], [x1, y, z1], [x1, y, z0], [x0, y, z0],
        [x0 / t, z1 / t, x1 / t, z1 / t, x1 / t, z0 / t, x0 / t, z0 / t]);
    }

// the park's trees and bushes, one instanced batch per model. the tiles are already unwalkable, so
// this is not decoration: a green cell with nothing drawn on it is a wall the player cannot see
  public static function green(scene:Scene, m:Facility, area:game.AreaGame):Array<Models.InstancedProp>
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var places = [for (_ in GREEN) new Array<Models.PropPlace>()];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (m.surf[row][col] != Surf.GRASS)
              continue;
            var t = area.getCellType(col, row);
            // the two dead-wood ids fold onto the two trees that are in leaf: the bare broadleaf
            // (+1) onto the full one, the dead snag (+3) onto the conifer. GREEN has no row for
            // either, and a green cell with nothing drawn on it is a wall the player cannot see, so
            // this is a REMAP and not a skip. it fires only on areas generated before the park
            // stopped dealing those ids
            if (t == Const.TILE_TREE1 + 1)
              t = Const.TILE_TREE1 + 2;
            else if (t == Const.TILE_TREE1 + 3)
              t = Const.TILE_TREE1;
            for (i in 0...GREEN.length)
              {
                if (GREEN[i].tile != t)
                  continue;
                // three rolls off one mixed hash, with multipliers of their own so a plant's offset
                // does not correlate with its turn
                var hx = FacilityModel.mix((col * 30011) ^ (row * 50021));
                var hz = FacilityModel.mix((col * 19349663) ^ (row * 83492791));
                var hy = FacilityModel.mix((col * 24036583) ^ (row * 32582657));
                var j = GREEN[i].jitter;
                // the size roll rides the HIGH bits of the yaw hash, which only spends its low ones
                // (% 6283) — the same pair of ranges render.wild.WildProps takes off one hash
                var s = 1.0 + (((hy >> 17) % 2001) / 1000.0 - 1.0) * GREEN[i].scaleJit;
                places[i].push({
                  x: (col + 0.5 + lean(m, col, row, ((hx % 2001) / 1000.0 - 1.0) * j, 1, 0)) * CELL
                    - half,
                  z: (row + 0.5 + lean(m, col, row, ((hz % 2001) / 1000.0 - 1.0) * j, 0, 1)) * CELL
                    - half,
                  // a plant takes a full random turn; a prop with a front is turned to face the path
                  // beside it, and a bench facing the shrubbery is the whole failure mode
                  yaw: (GREEN[i].faces ? facing(m, col, row) : (hy % 6283) / 1000.0),
                  // the park lies a kerb BELOW the pavement, and nothing here places a prop anywhere
                  // else — every entry in GREEN is keyed on a grass tile. `sink` then buries a
                  // fraction of the prop's own height under that, and it has to ride the instance
                  // SCALE with it: the ragged fringe being buried shrinks when the tree does, so a
                  // fixed burial would leave a small broadleaf standing on its own torn edge. the
                  // reasoning render.wild.WildProps.sit carries for the same glb
                  y: surfY(Surf.GRASS) - GREEN[i].sink * GREEN[i].h * s,
                  scale: s,
                });
              }
          }
      var props = [];
      for (i in 0...GREEN.length)
        {
          var p = Models.instanced(scene, GREEN[i].path, places[i], GREEN[i].h, SOLID);
          props.push(p);
          // the mask and the shadow flag have to be applied behind the loader callback, because the
          // mesh does not exist until the glb resolves — and only for a batch that actually placed
          // something, or an empty batch's material is patched and warmed for nothing
          var casts = GREEN[i].casts;
          if (places[i].length > 0)
            Models.get(GREEN[i].path, function(_)
              {
                VisionMask.patchMesh(p.mesh);
                p.mesh.castShadow = casts;
              });
        }
      return props;
    }

// how far a railing run has to be pulled back at ONE of its ends, in world units. two cases, and
// both are about the run stopping where the thing it meets begins:
//
//   a CORNER, where this cell also fences the perpendicular edge `dir`. each run reaches its full
//   half-cell along its own axis while the other run's line sits FENCE_INSET short of it, so at full
//   length the two crossed by that much and read as one fence laid over another rather than a
//   corner. pulled back by the inset, they end on each other's line and meet.
//
//   a PARK PATH, where the run dies into the mouth of the path. the path is pavement and so carries
//   its own kerb, and that band protrudes WALKWAY_BORDER_W over this lawn — a run taken to the cell
//   boundary laid its last stretch on top of the border. pulled back by the band's width, it stops
//   where the turf does.
//
// the caller shortens by lo + hi and shifts by half their difference, so whichever end is untouched
// stays exactly where it was
  static function endCut(m:Facility, col:Int, row:Int, dir:Int):Float
    {
      if (rimEdge(m, col, row, dir))
        return FacilityStyle.FENCE_INSET;
      var c = col + DC[dir];
      var r = row + DR[dir];
      if (FacilityModel.inside(m, c, r) &&
          FacilityModel.isParkPath(m, c, r))
        return RenderConfig.WALKWAY_BORDER_W;
      return 0.0;
    }

// does this grass cell's `dir` edge want a railing: the neighbour is pavement, and pavement that
// RINGS the park rather than the path running through it
  static inline function rimEdge(m:Facility, col:Int, row:Int, dir:Int):Bool
    return isRim(m, col + DC[dir], row + DR[dir]);

// is this cell the pavement that RINGS the park, rather than the path running through it? the one
// thing a railing ever stands against, and so the one thing an actor ever climbs it to reach
  static inline function isRim(m:Facility, col:Int, row:Int):Bool
    return FacilityModel.inside(m, col, row) &&
      m.surf[row][col] == Surf.WALKWAY &&
      !FacilityModel.isParkPath(m, col, row);

// is this cell lawn?
  static inline function isGrass(m:Facility, col:Int, row:Int):Bool
    return FacilityModel.inside(m, col, row) &&
      m.surf[row][col] == Surf.GRASS;

// the arc an actor takes stepping over the park railing, or 0 for a move that crosses none.
//
// the railing lines are not stored anywhere: they fall back out of the two predicates above, the same
// pair `fence` places the instances from, so the animation and the geometry cannot drift apart — the
// same reason render.wild.WildRoad.climbArc rebuilds the guard rail's lines instead of remembering
// them. the railing is render-only, nothing is stamped on the tiles for it and the park is walked
// straight into through the fence, so this is the whole of what says the bar is there.
//
// a railing stands between lawn and the pavement that RINGS it, so a move crosses one exactly when
// one end is grass and the other is rim pavement. that reads a DIAGONAL step correctly for free:
// there is one barrier under that move whichever leg render.ActorAnim.cornerBend routes the slide
// along. a step onto the park PATH crosses nothing, which is right — no railing is drawn there
  public static function climbArc(m:Facility, fromCol:Int, fromRow:Int, toCol:Int, toRow:Int):Float
    {
      if ((isGrass(m, fromCol, fromRow) && isRim(m, toCol, toRow)) ||
          (isGrass(m, toCol, toRow) && isRim(m, fromCol, fromRow)))
        return FacilityStyle.CLIMB_ARC;
      return 0.0;
    }

// one axis of a plant's jitter, CANCELLED when it leans at a cell that is not lawn. bush-low is
// 2.10 world units across (its own aspect 1.91 at h 1.1, so a radius of 1.05) and the jitter reaches
// 0.28 of a 4-unit cell = 1.12, which is 2.17 against a half-cell of 2.0 — at full lean a bush
// crossed its own boundary and came out over the park path, or past the railing, which stands
// FENCE_INSET inside that boundary. leaning INWARD is untouched, so an edge cell keeps half its
// spread and only the direction that would overhang is given up
  static function lean(m:Facility, col:Int, row:Int, off:Float, dc:Int, dr:Int):Float
    {
      if (isGrass(m, col + (off < 0 ? -dc : dc), row + (off < 0 ? -dr : dr)))
        return off;
      return 0.0;
    }

// the railing round the park: one segment per grass cell edge that faces the pavement RING around
// the lawn, and NONE against the path through it — which is the whole reason
// render.facility.FacilityModel.isParkPath exists. fence the path too and the park is not enclosed,
// it is subdivided.
//
// no gate cell has to be cut for the way in, either: the path meets the perimeter pavement
// walkway-to-walkway, so those edges are not grass edges and this loop never reaches them. measured
// on a generated compound: 120 grass-to-walkway edges, 70 rim and 50 path, and the two mouths open
// by themselves.
//
// one segment is exactly a cell long (see FacilityStyle.FENCE_H), so consecutive segments meet
// instead of leaving gaps, and the yaw is the run's own axis rather than a random turn — a railing
// has an authored front and a run of them at odd angles is a scrapyard, the same rule
// render.wild.WildProps.rails states for the guard rail
  public static function fence(scene:Scene, m:Facility):Models.InstancedProp
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var places:Array<Models.PropPlace> = [];
      var ins = FacilityStyle.FENCE_INSET;
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (m.surf[row][col] != Surf.GRASS)
              continue;
            for (dir in 0...4)
              {
                if (!rimEdge(m, col, row, dir))
                  continue;
                // and where this run has to STOP, one end at a time — see `endCut`
                var lo = endCut(m, col, row, (dir < 2 ? 2 : 0));
                var hi = endCut(m, col, row, (dir < 2 ? 3 : 1));
                var shift = (lo - hi) / 2;
                places.push({
                  x: (col + 0.5) * CELL - half + DC[dir] * (CELL / 2 - ins) +
                    (dir < 2 ? shift : 0.0),
                  z: (row + 0.5) * CELL - half + DR[dir] * (CELL / 2 - ins) +
                    (dir < 2 ? 0.0 : shift),
                  // the glb runs along its own local x, so an edge lying in x needs no turn at all
                  yaw: (dir < 2 ? 0.0 : Math.PI / 2),
                  // it is planted in the LAWN, which lies a kerb below the pavement it edges
                  y: surfY(Surf.GRASS),
                  scale: (CELL - lo - hi) / CELL,
                });
              }
          }
      var prop = Models.instanced(scene, RenderConfig.MODELS.facilityFence, places,
        FacilityStyle.FENCE_H, SOLID);
      if (places.length > 0)
        Models.get(RenderConfig.MODELS.facilityFence, function(_) VisionMask.patchMesh(prop.mesh));
      return prop;
    }

// the litter bins: one beside every park bench, and one tucked into the angle at a corridor's dead
// end. ONE BATCH for both, which is the whole reason the indoor pass lives in here rather than beside
// the corridor's other fittings — a second batch of the same glb would be a second draw call for
// nothing.
//
// the park half is placed off the BENCH and not off a tile of its own, which is the same design: no
// new tile id, no generator change, and every compound already saved gets its bins the moment it is
// drawn again.
//
// there is no room for it INSIDE the bench's own footprint — a 2.34-high bench draws 3.57 long in a
// 4-unit cell — so it stands off the bench's back corner, on the two local offsets
// FacilityStyle.BIN_SIDE and BIN_BACK, which are sized to clear the seat and still land inside the
// cell. the side is hashed off the cell so a run of benches does not put every bin on the same hand
  public static function bins(scene:Scene, m:Facility, area:game.AreaGame):Models.InstancedProp
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var places:Array<Models.PropPlace> = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (m.surf[row][col] != Surf.GRASS ||
                area.getCellType(col, row) != Const.TILE_GRASS_UNWALKABLE)
              continue;
            // the BENCH's own yaw, because the bin is placed in the BENCH's frame: local +x is the
            // front it looks down the path with, local +z runs along the seat
            var look = facing(m, col, row);
            var side = FacilityStyle.BIN_SIDE *
              (FacilityModel.mix((col * 40009) ^ (row * 15486277)) % 2 == 0 ? 1.0 : -1.0);
            places.push({
              x: (col + 0.5) * CELL - half + side * Math.sin(look) -
                FacilityStyle.BIN_BACK * Math.cos(look),
              z: (row + 0.5) * CELL - half + side * Math.cos(look) +
                FacilityStyle.BIN_BACK * Math.sin(look),
              // and the bin's OWN front is local +z where the bench's is local +x, so it is turned a
              // further quarter to put its mouth on the same world direction — at the path, where the
              // people are. MEASURED off the built glb rather than guessed: the mouth is a hole in the
              // lid, so it REMOVES surface at one azimuth, and binning the lid band's area by azimuth
              // leaves the two sectors straddling +z at 0.054 / 0.055 against the other ten's 0.085
              yaw: look + Math.PI / 2,
              y: surfY(Surf.GRASS),
            });
          }
      indoorBins(m, places);
      // and the LOW floor decorations that ARE a lidded bin (Const.FACILITY_FITTINGS, FIT_BIN). they
      // ride this batch rather than earning one of their own, which is the whole reason the bin was
      // the glb picked for them: a handful of bins in the labs would otherwise be a second draw call
      // for the same model. BIN_H is already FacilityStyle.DECO_ROUND_H, so they are the same size
      FacilityDeco.placeRound(m, _FittingKind.FIT_BIN, places);
      var prop = Models.instanced(scene, RenderConfig.MODELS.facilityBin, places,
        FacilityStyle.BIN_H, SOLID);
      // and this batch CASTS NOTHING, which the corridor half is what forced. an instanced batch is
      // drawn into the moon's shadow map as many times as it is drawn into the frame, so the second
      // draw is a second call the moment the batch is in view at all: measured from a corridor with
      // one bin visible, 66 calls with the shadow against 65 without and 64 with the batch hidden
      // outright. one 0.97-unit drum is not worth half the cost of the whole fitting, which is the
      // park shrub's own finding (see GreenProp.casts) reached from the other end
      if (places.length > 0)
        Models.get(RenderConfig.MODELS.facilityBin, function(_)
          {
            VisionMask.patchMesh(prop.mesh);
            prop.mesh.castShadow = false;
          });
      return prop;
    }

// the corridor half: one bin in the angle where a corridor's own two walls meet, which on this
// generator's plan is the dead end every passage finishes in.
//
// the CORNER is the whole placement rule, and it is the same predicate the corridor casework rejects
// on (FacilityTables.hugs) — so the two families divide the corridor between them without either
// having to run first or read the other's list. It is also the right fiction on its own terms: junk
// collects where something stops it, which is what stood the lot's own drums against a kerb rather
// than out in the aisle (FacilityDebris.place)
  static function indoorBins(m:Facility, places:Array<Models.PropPlace>):Void
    {
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (!FacilityModel.inside(m, col, row) ||
                m.surf[row][col] != Surf.LINO ||
                FacilityModel.nearDoor(m, col, row))
              continue;
            // which hand each wall is on, in FacilityGeom's own direction numbering. a bin needs one
            // wall on EACH axis or there is no angle to stand in — a cell with a single wall is a
            // straight stretch and belongs to the casework
            var dz = (FacilityModel.isSolidWall(m, col, row - 1) ? 0 :
              (FacilityModel.isSolidWall(m, col, row + 1) ? 1 : -1));
            var dx = (FacilityModel.isSolidWall(m, col - 1, row) ? 2 :
              (FacilityModel.isSolidWall(m, col + 1, row) ? 3 : -1));
            if (dz < 0 ||
                dx < 0)
              continue;
            if (FacilityModel.mix((col * 16777619) ^ (row * 87178291)) % 1000 >=
                FacilityStyle.BIN_IN_PCT * 1000)
              continue;
            // off the WALL FACE and not off the cell, which is a unit away: FacilityGeom.slab insets
            // a straight run, so the corridor floor carries on under the masonry's overhang
            var sz = FacilityGeom.slab(m, col, row + (dz == 0 ? -1 : 1));
            var sx = FacilityGeom.slab(m, col + (dx == 2 ? -1 : 1), row);
            places.push({
              x: (dx == 2 ? sx.x1 + FacilityStyle.BIN_IN_GAP : sx.x0 - FacilityStyle.BIN_IN_GAP),
              z: (dz == 0 ? sz.z1 + FacilityStyle.BIN_IN_GAP : sz.z0 - FacilityStyle.BIN_IN_GAP),
              // the bin's mouth is its local +z, measured off the built glb by the park pass above.
              // here it is turned to look OUT of the angle it stands in, away from both walls at once
              yaw: Math.atan2(dx == 2 ? 1.0 : -1.0, dz == 0 ? 1.0 : -1.0),
              y: surfY(Surf.LINO),
            });
          }
    }

// which way a prop with an authored front is turned: at the first walkway beside it, so a bench put
// down by the park path looks along it.
//
// the bench's front is local +X, MEASURED off the built mesh — it lies along local z (bbox
// 0.477 x 0.655 x 0.998) with its depth on x, and the backrest, being the tall part, averages
// x -0.138 against the whole mesh's -0.012. so the seat overhangs toward +x and the yaw that aims a
// +x front down (dx, dz) is atan2(-dz, dx), which is the mast's own atan2(DC, DR) less PI/2. THE
// PREVIOUS BENCH FACED +z and used that atan2 bare; the regenerated one is a different model and
// this is the line that had to move with it. no walkway at all leaves it unturned, which is what an
// unplaceable bench deserves
  static function facing(m:Facility, col:Int, row:Int):Float
    {
      for (dir in 0...4)
        {
          var c = col + DC[dir];
          var r = row + DR[dir];
          if (FacilityModel.inside(m, c, r) &&
              m.surf[r][c] == Surf.WALKWAY)
            return Math.atan2(DC[dir], DR[dir]) - Math.PI / 2;
        }
      return 0.0;
    }

// merge one surface buffer into a lit mesh
  static function add(scene:Scene, b:MeshBuf, tex:String):Void
    {
      if (b.idx.length == 0)
        return;
      var geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(b.pos, 3));
      geo.setAttribute('uv', new Float32BufferAttribute(b.uv, 2));
      geo.setIndex(b.idx);
      geo.computeVertexNormals();
      var mesh = new Mesh(geo, VisionMask.patch(new MeshLambertMaterial({
        map: Textures.loadTexture(tex, 'ground', 1),
        side: THREE.FrontSide,
      })));
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
    }
}
