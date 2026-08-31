package render.facility;

import three.Three;
import citygen.CityConfig;
import render.ActorAnim;
import render.LightCone;
import render.Models;
import render.RenderConfig;
import render.particles.LampPost;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.VisionMask;

// what one facility's lighting rig placed. the two families are kept apart rather than concatenated
// because everything downstream wants them apart: only the masts have a model to cull and a cone to
// draw, and __facility() reports them as two counts
typedef LampSet = {
  masts:Array<LampPost>,     // the outdoor lamp posts, one bulb each at the head
  ceilings:Array<LampPost>,  // one fixture per lit room, hung under the roof deck
  prop:Models.InstancedProp, // the mast batch, frustum-culled per frame
};

// one cell the scan accepted, before anything is built from it
typedef LampHit = {
  col:Int,  // the cell the mast stands on
  row:Int,  // ^
  dir:Int,  // which of the four cell edges faces the surface it lights (FacilityGeom's numbering)
};

// the facility's light SOURCES: the masts standing along its outdoor lit lines, and the fixtures
// hung over its rooms. a mast draws its own model — whose head carries an emissive map and so glows
// and blooms on its own, the way a street lamp's lens does — plus its cone of lit air; a ceiling
// fixture draws nothing at all, and what lands on the surfaces is render.facility.FacilityGlow.
//
// both families become plain LampPosts and go into the SHARED spotlight pool
// (render.particles.LampLights), which the facility has been building at full size since phase 0 and
// handing no bulbs at all — purely so NUM_SPOT_LIGHTS matches every other area kind. so the 12
// lights are already in every lit material's program key and already run their per-fragment loop:
// claiming them costs nothing that was not already being paid. two features come free with them,
// both keyed off LampLights.active(): the fake actor ground shadows (render.actors.LampShadows) and
// the real spotlight shadow maps on the low 8 slots.
//
// nothing here flickers. an institutional compound is powered, so every post takes phase 0 — which
// is also the STEADY marker LampLights and LightCone.pulse key on, so no cone is ever repacked and
// the per-frame cost of this whole file is one LampLights.update call
class FacilityLamps
{
  static inline var CELL = CityConfig.CELL;

  // the cell-edge directions render.facility.FacilityGeom.DC/DR number: 0 = -z, 1 = +z, 2 = -x, 3 = +x
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];
  // the same four in render.ActorAnim.cornerBend's OWN numbering, which is a different one and reads
  // the direction of the ROAD the post stands beside (0 = +row, 1 = -row, 2 = +col, 3 = -col). the
  // map exists so the bend routes an actor's diagonal slide around the mast on the pavement side
  static var BEND_DIR = [1, 0, 3, 2];

  // where a mast goes: the surface it stands on, and the surface it must border to be a lit LINE
  // rather than a lamp in the middle of a field. one row per line the compound actually has, and a
  // cell can match at most one because `on` is different in every row.
  //
  // the generator lays a 4-wide main road with a 2-wide sidewalk against it, a 2-wide walkway up the
  // west edge with the park beside it, and fills everything else with lot (game.FacilityAreaGenerator
  // lines 66-107) — so these three rows are the kerb along the road, the lot's edge against that
  // sidewalk, and the park path. the last one is NOT satisfied by `by` alone: see the isParkPath
  // test in `build`, without which it matches the pavement round the park as well as the path in it
  static final LINES = [
    { on: Surf.WALKWAY, by: Surf.ROAD },
    { on: Surf.LOT, by: Surf.WALKWAY },
    { on: Surf.GRASS, by: Surf.WALKWAY },
  ];

// place every mast and every ceiling fixture, build the mast batch and its cones, and fill `corners`
// so the actor and camera slides bend past a post
  public static function build(scene:Scene, coneGroup:Object3D, m:Facility, area:game.AreaGame,
      corners:Map<Int,Int>):LampSet
    {
      var masts = [];
      var places:Array<Models.PropPlace> = [];
      var bulbY = FacilityStyle.LAMP_H * FacilityStyle.LAMP_HEAD_Y;
      var reach = FacilityStyle.LAMP_H * FacilityStyle.LAMP_HEAD_Z;
      // the scan COLLECTS rather than places, because the park line cannot be settled cell by cell:
      // it takes a fixed few posts out of a run whose length is only known once the whole run has
      // been seen
      var hits:Array<LampHit> = [];
      var parkHits:Array<LampHit> = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if ((col + row) % FacilityStyle.LAMP_SPACING != 0)
              continue;
            var s = m.surf[row][col];
            // a park cell already holding a tree or a bush is occupied — the greenery is placed off
            // the same tile grid (render.facility.FacilityGround.green), so this is the same test
            if (s == Surf.GRASS &&
                area.getCellType(col, row) != Const.TILE_GRASS)
              continue;
            for (ln in LINES)
              {
                if (s != ln.on)
                  continue;
                var dir = borders(m, col, row, ln.by);
                if (dir < 0)
                  continue;
                // the lot line runs right through the parking ENTRY, whose asphalt has a pavement
                // beside it like any other lot cell — and a post there stands in the middle of the
                // gateway the cars come in through. FacilityPaint strikes no bay on it for the same
                // reason
                if (ln.on == Surf.LOT &&
                    FacilityPaint.isEntry(m, col, row))
                  break;
                var hit = {
                  col: col,
                  row: row,
                  dir: dir,
                };
                // the park line is the one that has to ask WHICH walkway. the compound's own
                // pavement wraps the lawn on every side, so `by: WALKWAY` alone matched the rim
                // as readily as the path — and with a row-major scan and a hard cap of four, the
                // rim is all that ever got picked: measured 4 of 4 on the park's top and side
                // edges, every head aimed OUT of the park. the path is what wants lighting
                if (ln.on == Surf.GRASS)
                  {
                    if (FacilityModel.isParkPath(m, col + DC[dir], row + DR[dir]))
                      parkHits.push(hit);
                    break;
                  }
                hits.push(hit);
                break;
              }
          }
      // and thin the path's candidates to the cap, spread along the run instead of taken off its
      // head — the scan is row-major, so the first PARK_LAMPS of them are the first PARK_LAMPS
      // rows of a path that may be twenty-five long
      var take = (parkHits.length < FacilityStyle.PARK_LAMPS
        ? parkHits.length : FacilityStyle.PARK_LAMPS);
      for (i in 0...take)
        hits.push(parkHits[Std.int((i + 0.5) * parkHits.length / take)]);

      for (h in hits)
        {
          // the post stands on the grid VERTEX between this cell and the surface it lights, not in
          // the middle of a walkable cell. the free axis takes the +x/+z side, the
          // arbitrary-but-consistent choice render.SceneSetup makes for a city lamp
          var a = (h.dir == 2 ? h.col - 1 : h.col);
          var b = (h.dir == 0 ? h.row - 1 : h.row);
          // that vertex is a cell BOUNDARY on the free axis, and along a lot kerb every other
          // boundary carries a bay divider — so the rule above stands a mast in the paint. step one
          // cell back along the kerb, onto the boundary that falls mid-bay. never forward: back is
          // always a boundary the run either divides on the other phase or does not reach at all
          if (m.surf[h.row][h.col] == Surf.LOT &&
              ((h.dir < 2 ? h.col + 1 : h.row + 1)
                - FacilityPaint.runStart(m, h.col, h.row, h.dir))
                % FacilityStyle.BAY_SPACING == 0)
            {
              a -= (h.dir < 2 ? 1 : 0);
              b -= (h.dir < 2 ? 0 : 1);
            }
          var v = CityConfig.cellToWorld(a, b);
          var px = v.x + CELL / 2;
          var pz = v.z + CELL / 2;
          places.push({
            x: px,
            z: pz,
            // the head hangs off the mast toward the surface being lit, so the yaw is the aim
            // vector's own angle — the glb's head points at local +z (FacilityStyle.LAMP_HEAD_Z)
            yaw: Math.atan2(DC[h.dir], DR[h.dir]),
            // the MODEL follows the surface it stands on — a park mast would otherwise float
            // the kerb step over its own lawn. the LampPost below deliberately does not: its
            // `y` is the bulb height render.actors.LampShadows scales an actor's fake shadow
            // by (refY / post.y), and moving it 0.2 for a mast on grass would rescale every
            // shadow it throws for nothing anyone can see
            y: FacilityGround.surfY(m.surf[h.row][h.col]),
          });
          masts.push({
            x: px + DC[h.dir] * reach,
            z: pz + DR[h.dir] * reach,
            y: bulbY,
            // straight down: the head is a shrouded DOWNlight, so it pools at its own feet
            // where a sewer wall bracket rakes metres out along the wall
            tx: px + DC[h.dir] * reach,
            tz: pz + DR[h.dir] * reach,
            color: FacilityStyle.LAMP_COLOR,
            col: h.col,
            row: h.row,
            phase: 0.0,
            flick: 1.0,
            mul: 1.0,
          });
          corners.set(ActorAnim.lampVertexKey(a, b), BEND_DIR[h.dir]);
        }

      var ceilings = [];
      for (r in m.rooms)
        {
          if (!lit(m, r))
            continue;
          var c = CityConfig.cellToWorld(Std.int((r.x1 + r.x2) / 2), Std.int((r.y1 + r.y2) / 2));
          ceilings.push({
            x: c.x,
            z: c.z,
            y: FacilityStyle.ROOF_Y - FacilityStyle.CEIL_DROP,
            tx: c.x,
            tz: c.z,
            color: FacilityStyle.LAMP_COLOR,
            col: Std.int((r.x1 + r.x2) / 2),
            row: Std.int((r.y1 + r.y2) / 2),
            phase: 0.0,
            flick: 1.0,
            // see FacilityStyle.CEIL_MUL: this is the compensation for INDOOR.direct, not a taste knob
            mul: FacilityStyle.CEIL_MUL,
          });
        }

      var prop = Models.instanced(scene, RenderConfig.MODELS.facilityLamp, places,
        FacilityStyle.LAMP_H, SOLID);
      // the mask has to go on behind the loader callback — the mesh does not exist until the glb
      // resolves — and only when the batch actually placed something, or an empty batch's material
      // is patched and warmed for nothing (the same shape FacilityGround.green takes)
      if (places.length > 0)
        Models.get(RenderConfig.MODELS.facilityLamp, function(_) VisionMask.patchMesh(prop.mesh));
      // the cone of lit air under each head. one instanced draw, in the scene's coneGroup so the
      // debug 5 / 0 keys price and hide it here exactly as they do on a street
      var L = RenderConfig.LAMP_LIGHT;
      LightCone.instanced({
        group: coneGroup,
        bulbs: [for (p in masts) { x: p.x, z: p.z }],
        bulbY: bulbY,
        radius: bulbY * Math.tan(L.angle) * RenderConfig.LAMP_CONE.radiusMul,
        topR: RenderConfig.LAMP_CONE.topR,
        color: FacilityStyle.LAMP_COLOR,
        startFrac: FacilityStyle.LAMP_CONE_START,
      });
      return {
        masts: masts,
        ceilings: ceilings,
        prop: prop,
      };
    }

// does this room get a fixture? public because render.facility.FacilityGlow asks the same question
// of the same list and the two must not drift — a panel over a room with no bulb, or the reverse,
// is a light with no fitting. the guard is against a stale generatorInfo: `rooms` comes straight off
// it, and nothing else here trusts it to still describe the saved grid
  public static inline function lit(m:Facility, r:_Room):Bool
    return FacilityModel.isIndoor(m, Std.int((r.x1 + r.x2) / 2), Std.int((r.y1 + r.y2) / 2));

// the first of the four cell-edge directions whose neighbour paints `by`, or -1 for none
  static function borders(m:Facility, col:Int, row:Int, by:Surf):Int
    {
      for (dir in 0...4)
        {
          var c = col + DC[dir];
          var r = row + DR[dir];
          if (c < 0 ||
              r < 0 ||
              c >= m.w ||
              r >= m.h)
            continue;
          if (m.surf[r][c] == by)
            return dir;
        }
      return -1;
    }
}
