package render.facility;

import three.Three;
import citygen.CityConfig;
import render.ActorAnim;
import render.LightCone;
import render.Models;
import render.RenderConfig;
import render.particles.LampPost;
import render.facility.FacilityEntry.Gate;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.VisionMask;

// what one facility's lighting rig placed. the two families are kept apart rather than concatenated
// because everything downstream wants them apart: only the masts have a model to cull and a cone to
// draw, and __facility() reports them as two counts
typedef LampSet = {
  masts:Array<LampPost>,     // the outdoor lamp posts, one bulb each at the head
  // the PARK's own masts, a sub-list of `masts` and the same objects — the ones the lit-line scan
  // took off the park path (FacilityModel.isParkPath). kept apart because a swarm of flies belongs
  // over a lawn and not over a parking bay, and a `park` field on LampPost would be a field every
  // city and sewer construction site had to set for one area kind's atmosphere
  park:Array<LampPost>,
  ceilings:Array<LampPost>,  // the room fixtures, a ROOM_SPACING lattice over each lit room
  corridors:Array<LampPost>, // the corridor fixtures, which no room rect can reach — see `corridors`
  doors:Array<LampPost>,     // the bulkhead lamp over each exterior door — the one WARM light here
  prop:Models.InstancedProp, // the mast batch, frustum-culled per frame
  cones:Array<LightCone.ConeSet>, // the mast and door shafts, frustum-culled per instance per frame
};

// where one mast stands, world: its footing on the grid vertex and the surface height under it
typedef Mast = {
  x:Float,   // the footing, world — where the BATCH places the glb, i.e. its plan centre
  z:Float,   // ^
  ax:Float,  // and where the POLE itself stands, which is not the same point: the head overhangs,
  az:Float,  // so Models.instanced's plan centre lands between the two (FacilityStyle.LAMP_POLE_Z)
  y:Float,   // and the height of the surface it stands on
  col:Int,   // the grid VERTEX it stands on, which is what the actor slide bends past
  row:Int,   // ^
};

// one cell the scan accepted, before anything is built from it
typedef LampHit = {
  col:Int,  // the cell the mast stands on
  row:Int,  // ^
  dir:Int,  // which of the four cell edges faces the surface it lights (FacilityGeom's numbering)
};

// the facility's light SOURCES: the masts standing along its outdoor lit lines, and the fixtures
// hung over its rooms and its corridors. a mast draws its own model — whose head carries an emissive
// map and so glows and blooms on its own, the way a street lamp's lens does — plus its cone of lit
// air; a ceiling fixture draws nothing at all, and what lands on the surfaces is
// render.facility.FacilityGlow.
//
// the two indoor families are placed by two different rules because they are found two different
// ways. a ROOM is a rect in area.generatorInfo and takes a lattice over it; a CORRIDOR is in no list
// at all — it is whatever indoor lino is left over — and is scanned off the grid, see `corridors`.
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
  // rather than a lamp in the middle of a field. the generator lays a 4-wide main road with a 2-wide
  // sidewalk against it, a 2-wide walkway up the west edge with the park beside it, and fills
  // everything else with lot (game.FacilityAreaGenerator lines 66-107) — so these three rows are the
  // kerb along the road, the lot's edge against that sidewalk, and the park path.
  //
  // EVERY LINE STANDS THE MAST ON THE WALKWAY and aims it at what it lights. That is the whole table
  // now, and it used to be a split: the road line stood on the PAVEMENT, while the lot and park
  // lines stood on the ASPHALT and on the LAWN and aimed back at the pavement. Reported from the game
  // as exactly that dichotomy — "normal lamps are all on walkways while park and parking lot ones are
  // on ground/asphalt". A lamp column is planted in paving; it is not planted in a parking bay or in
  // a flower bed.
  //
  // the fix is not a new rule, it is the two rows written the right way round: `on` and `by` swapped
  // puts the mast on the pavement and turns the head to light the lot or the park instead of the
  // pavement it stands on. THE MAST DOES NOT MOVE — the vertex the placer picks is the boundary
  // between those same two cells either way, so all that changes is which side of the kerb the base
  // sits on and which way the head faces.
  //
  // a cell CAN now match more than one row, where the old table's `on` surfaces made that impossible,
  // so the order is load-bearing: a pavement between the road and the lot takes the ROAD line and
  // reads as a street lamp. And the park row is still not satisfied by `by` alone — the compound's
  // pavement wraps the lawn on every side, so it takes the isParkPath test in `build`, which is now
  // asked of the mast's OWN cell rather than of its neighbour
  static final LINES = [
    { on: Surf.WALKWAY, by: Surf.ROAD },
    { on: Surf.WALKWAY, by: Surf.LOT },
    { on: Surf.WALKWAY, by: Surf.GRASS },
  ];

// where the mast for one accepted cell actually STANDS, world. PUBLIC and pure, because the
// checkpoint's service drop has to arrive at the gate's own pole and a second copy of this
// arithmetic is a cable that misses it (render.facility.FacilityEntry.cable)
  public static function mastAt(m:Facility, h:LampHit):Mast
    {
      // the post stands on the grid VERTEX between this cell and the surface it lights, not in
      // the middle of a walkable cell. the free axis takes the +x/+z side, the
      // arbitrary-but-consistent choice render.SceneSetup makes for a city lamp
      var a = (h.dir == 2 ? h.col - 1 : h.col);
      var b = (h.dir == 0 ? h.row - 1 : h.row);
      // that vertex is a cell BOUNDARY on the free axis, and TWO things pull it one cell back
      // along that axis. Either is one step, and back is always a boundary the run either
      // divides on the other phase or does not reach at all.
      //
      // a BAY DIVIDER: along a lot kerb every other boundary carries one, so the rule above
      // stands a mast in the paint. step onto the boundary that falls mid-bay instead.
      //
      // or a DIFFERENT SURFACE on that side, which in a generated compound is the parking ENTRY
      // and only the entry. A post stands on a VERTEX — a corner shared by FOUR cells — while
      // its `y` below comes from ONE of them, and everywhere else that is harmless because the
      // free axis runs ALONG the kerb, so the two cells it straddles are the same surface and the
      // step is only ever across the aim axis, where the kerb edging covers it. The hole punched
      // through the sidewalk band breaks exactly that: at its corners the four cells are not one
      // surface, and both masts at the gate were reported from the game — the one beside the
      // booth stood on walkway with three quadrants hanging over the 0.2 kerb into the hole ("on
      // the kerb and on empty space"), and the gate's own mast stood on lot with the fourth
      // quadrant buried in the band ("too low, goes into the walkway AND on top of the walkway")
      var fc = (h.dir < 2 ? h.col + 1 : h.col);
      var fr = (h.dir < 2 ? h.row : h.row + 1);
      // the bay run belongs to the cell being LIT now that the mast stands on the pavement, so
      // both the surface test and FacilityPaint.runStart read the neighbour, walking it back the
      // other way (`dir ^ 1` is the opposite of any of the four). the FREE-axis coordinate is
      // untouched by the swap — the two cells differ only along the aim axis — so the phase
      // arithmetic below is the same as it ever was
      var bc = h.col + DC[h.dir];
      var br = h.row + DR[h.dir];
      if ((m.surf[br][bc] == Surf.LOT &&
            ((h.dir < 2 ? h.col + 1 : h.row + 1)
              - FacilityPaint.runStart(m, bc, br, h.dir ^ 1))
              % FacilityStyle.BAY_SPACING == 0) ||
          !FacilityModel.inside(m, fc, fr) ||
          m.surf[fr][fc] != m.surf[h.row][h.col])
        {
          a -= (h.dir < 2 ? 1 : 0);
          b -= (h.dir < 2 ? 0 : 1);
        }
      var v = CityConfig.cellToWorld(a, b);
      // the pole's own axis, one step back along the aim from the placed point. `Models.instanced`
      // centres a glb on its bounding box in plan and the head overhangs toward what it lights, so
      // the placed point is out in the air between pole and housing — a cable ended there hangs
      // clear of the post by LAMP_POLE_Z's own 0.37, which is more than the pole's 0.30 radius and
      // was reported from the game as a gap
      var off = FacilityStyle.LAMP_H * FacilityStyle.LAMP_POLE_Z;
      return {
        x: v.x + CELL / 2,
        z: v.z + CELL / 2,
        ax: v.x + CELL / 2 + DC[h.dir] * off,
        az: v.z + CELL / 2 + DR[h.dir] * off,
        col: a,
        row: b,
        // the MODEL follows the surface it stands on — a park mast would otherwise float the
        // kerb step over its own lawn
        y: FacilityGround.surfY(m.surf[h.row][h.col]),
      };
    }

// the gate's own mast, the one the lit-line rules can never deal and the only pole the checkpoint
// can be sure of. THE `dir` IS 2 AND NOT DERIVED, which is `build`'s own choice below for the same
// hit — so the two agree by construction.
//
// ONE CASE IS APPROXIMATE and it is worth naming: where (col + row) % LAMP_SPACING lands on this
// cell and a lit line already claimed it, `build` keeps the scan's hit rather than pushing this one,
// and that hit may aim at a different edge — so in about one compound in LAMP_SPACING the pole
// stands on the adjacent vertex and the drop ends up to one cell short of it. The alternative is
// building the masts before FacilityCable merges its ribbon, which is a documented draw-order move
// for a cable nobody has reported
  public static function gateMast(m:Facility, gate:Gate):Mast
    {
      return mastAt(m, {
        col: gate.lampCol,
        row: gate.row + (gate.lotDR < 0 ? 0 : gate.h - 1),
        dir: 2,
      });
    }

// place every mast and every ceiling fixture, build the mast batch and its cones, and fill `corners`
// so the actor and camera slides bend past a post
  public static function build(scene:Scene, coneGroup:Object3D, m:Facility, area:game.AreaGame,
      corners:Map<Int,Int>):LampSet
    {
      var masts = [];
      var park = [];
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
                // reason. the ENTRY CELL is the one being lit and no longer the one being stood on,
                // so the test moved to the neighbour with the mast
                if (ln.by == Surf.LOT &&
                    FacilityPaint.isEntry(m, col + DC[dir], row + DR[dir]))
                  break;
                var hit = {
                  col: col,
                  row: row,
                  dir: dir,
                };
                // the park line is the one that has to ask WHICH walkway. the compound's own
                // pavement wraps the lawn on every side, so bordering grass alone matched the rim as
                // readily as the path — and with a row-major scan and a hard cap of four, the rim is
                // all that ever got picked: measured 4 of 4 on the park's top and side edges, every
                // head aimed OUT of the park. the path is what wants lighting, and now that the mast
                // stands ON the walkway the question is asked of its own cell, which is exactly what
                // FacilityModel.isParkPath tests for — a walkway with lawn across it both ways
                if (ln.by == Surf.GRASS)
                  {
                    if (FacilityModel.isParkPath(m, col, row))
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
      // remembered by CELL, because the LampPost the loop below builds is what the flies want and
      // it does not exist yet
      var parkCells:Map<Int,Bool> = new Map();
      for (i in 0...take)
        {
          var h = parkHits[Std.int((i + 0.5) * parkHits.length / take)];
          parkCells.set(h.col * 4096 + h.row, true);
          hits.push(h);
        }
      // and the GATE's own mast, which the lit-line scan above cannot ever deal: every entry cell is
      // excluded from the lot line (a post in the gateway stands in the way of the cars), and the
      // boom barrier across that gateway is the one thing out on the asphalt that has to be seen.
      // it stands on the flank OPPOSITE the guard booth so the booth throws nothing on the arm it
      // lights, aimed at the entry — which on the generator's only entry shape, a hole cut along the
      // road, is -x. skipped where the scan has already put a mast on that cell: (col + row) %
      // LAMP_SPACING lands on it once in LAMP_SPACING compounds, and two masts on one vertex is one
      // mast drawn twice
      //
      // it stands on the SIDEWALK BAND, not on the lot: `lampCol` is outside the hole, so the band's
      // own rows are still pavement there, and that is both the rule every other line now follows and
      // the nearest cell to the boom. it takes the barrier's own row — the hole row facing the lot,
      // FacilityEntry.barrier's expression verbatim — so the two are on one line across the mouth
      var gate = FacilityEntry.find(m);
      var gateRow = (gate == null ? 0 : gate.row + (gate.lotDR < 0 ? 0 : gate.h - 1));
      if (gate != null &&
          !taken(hits, gate.lampCol, gateRow))
        hits.push({
          col: gate.lampCol,
          row: gateRow,
          dir: 2,
        });

      for (h in hits)
        {
          var p = mastAt(m, h);
          var px = p.x;
          var pz = p.z;
          places.push({
            x: px,
            z: pz,
            // the head hangs off the mast toward the surface being lit, so the yaw is the aim
            // vector's own angle — the glb's head points at local +z (FacilityStyle.LAMP_HEAD_Z)
            yaw: Math.atan2(DC[h.dir], DR[h.dir]),
            // `mastAt` follows the surface the post stands on — a park mast would otherwise float
            // the kerb step over its own lawn. the LampPost below deliberately does not: its
            // `y` is the bulb height render.actors.LampShadows scales an actor's fake shadow
            // by (refY / post.y), and moving it 0.2 for a mast on grass would rescale every
            // shadow it throws for nothing anyone can see
            y: p.y,
          });
          var post:LampPost = {
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
          };
          masts.push(post);
          if (parkCells.exists(h.col * 4096 + h.row))
            park.push(post);
          corners.set(ActorAnim.lampVertexKey(p.col, p.row), BEND_DIR[h.dir]);
        }

      // the room fixtures, as a LATTICE over each room rather than one bulb at its centre. a
      // downlight has a reach and a room has an area, and the old rule ignored the second: the two
      // big labs and the hangar are 80 to 90 cells each and were lit by one fitting apiece.
      //
      // the count comes off the rect and the positions off FacilityStyle.ROOM_SPACING, so a room
      // under that size is unchanged — nx and ny both fall to 1 and the single point lands back on
      // the centre the old expression picked. the (i + 0.5) / n form is the one the park line above
      // already uses to spread a fixed count along a run instead of taking it off the head
      var ceilings = [];
      for (r in m.rooms)
        {
          if (!lit(m, r))
            continue;
          var nx = Math.ceil(r.w / FacilityStyle.ROOM_SPACING);
          var ny = Math.ceil(r.h / FacilityStyle.ROOM_SPACING);
          // and A DIVIDED ROOM IS TWO ROOMS TO A LIGHT FITTING, whatever its rect says. A washroom's
          // partition runs through the middle of it (game.FacilityToilet.toiletPartition puts the T's
          // STEM on the room's own centre row, and the small-room fallback puts the single line
          // there), so a room under ROOM_SPACING on both axes fell to one point and that point landed
          // on top of the divider — reported from the game as the washroom's lamp sitting on the
          // separator. Forcing the count to 2 ACROSS the divider is the whole fix: the lattice's own
          // (j + 0.5) / n spacing then puts one fixture in each half
          var cut = divider(m, r);
          if (cut == 2 &&
              nx < 2)
            nx = 2;
          if (cut == 1 &&
              ny < 2)
            ny = 2;
          for (i in 0...nx)
            for (j in 0...ny)
              {
                var col = r.x1 + Std.int((i + 0.5) * r.w / nx);
                var row = r.y1 + Std.int((j + 0.5) * r.h / ny);
                // `lit` guards the room's CENTRE against a stale generatorInfo, and away from the
                // centre a lattice point can land on a divider the saved grid has and the rect does
                // not. the same predicate, asked per point — plus a nudge off the divider itself, see
                // `free`. NOTE if FacilityStyle.CEIL_GLOW is ever turned back on:
                // render.facility.FacilityGlow walks these same rects for the panel and the floor pool
                // and must take this lattice with it, or a room gets one fitting drawn over several
                // bulbs
                var q = free(m, r, col, row);
                if (q == null)
                  continue;
                col = q.col;
                row = q.row;
                var c = CityConfig.cellToWorld(col, row);
                ceilings.push({
                  x: c.x,
                  z: c.z,
                  y: FacilityStyle.ROOF_Y - FacilityStyle.CEIL_DROP,
                  tx: c.x,
                  tz: c.z,
                  color: FacilityStyle.LAMP_COLOR,
                  col: col,
                  row: row,
                  phase: 0.0,
                  flick: 1.0,
                  // see FacilityStyle.CEIL_MUL: the compensation for INDOOR.direct, not a taste knob
                  mul: FacilityStyle.CEIL_MUL,
                });
              }
        }

      // the bulkhead lamps over the exterior doors. they are real bulbs in the same shared pool the
      // masts and the fixtures claim from, and the ONLY thing here that is not LAMP_COLOR: a
      // doorway lit in the compound's own cool white is one more lit surface, and lit amber it is a
      // way in. LampPost has carried a per-post `color` all along, so the hue costs nothing.
      //
      // aimed STRAIGHT DOWN, like a mast head and unlike a sewer wall bracket: a hood over a door
      // is a downlight and pools at its own feet, a foot and a half out from the masonry
      var doors = [];
      // the hood each of those bulbs hangs under, kept in step with `doors` so the cone below can
      // ride the housing's centre line rather than its lens plane
      var hoods:Array<FacilityGlow.DoorLamp> = [];
      for (d in m.doors)
        {
          var l = FacilityGlow.lamp(m, d);
          if (l == null)
            continue;
          hoods.push(l);
          doors.push({
            x: l.x,
            z: l.z,
            y: l.y,
            tx: l.x,
            tz: l.z,
            color: FacilityStyle.DOOR_LAMP_COLOR,
            col: d.col,
            row: d.row,
            phase: 0.0,
            flick: 1.0,
            mul: 1.0,
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
      var cones = [];
      cones.push(LightCone.instanced({
        group: coneGroup,
        bulbs: [for (p in masts) { x: p.x, z: p.z }],
        bulbY: bulbY,
        radius: bulbY * Math.tan(L.angle) * RenderConfig.LAMP_CONE.radiusMul,
        topR: RenderConfig.LAMP_CONE.topR,
        color: FacilityStyle.LAMP_COLOR,
        startFrac: FacilityStyle.LAMP_CONE_START,
      }));
      // and the door lamps' own shafts, which have to be a SECOND batch: LightCone takes its tint
      // as one uniform per batch, and the whole point of these is that they are not the mast's
      // white. that is the one draw call this fitting costs.
      //
      // TWO things separate it from the mast batch above and both are about the WALL, which a mast
      // does not stand against.
      //
      // it is HALF A CONE, cut vertically. a mast is out in the open and its shaft is a full shell;
      // a fitting bolted to a wall has its light cut off flat by the masonry, and a full shell there
      // puts half a cone of lit air INSIDE the building — which is what it did, straight through the
      // shut door. the fix is not a smaller cone. That was tried: a radius under 1.22 does keep the
      // shell clear of the leaves, and it also makes the shaft a 13-degree pencil standing in the
      // middle of the wide circle the SpotLight actually throws, which is the mismatch it was
      // reported as. So the radius goes back to the mast's own geometric one — the lit circle,
      // which is what a shaft is drawn to outline — and the half that would be inside the building
      // is simply not built. The cut plane passes through the shaft's axis, i.e. flush with the
      // middle of the hood, and the kept wedge spans a right angle either side of the outward
      // normal, so it never crosses the wall face at any height.
      //
      // and the shaft is pulled BACK off the shared lamp point, which is the LENS PLANE — the
      // housing's front face — because the cut plane passes through the axis and that is where the
      // light is cut off. On the lens plane the shaft stood a whole hood's depth out in the air; on
      // the hood's CENTRE line, which it took next, the cut still hung 0.3 clear of the masonry.
      // It sits on the WALL FACE now, DOOR_LENS_EPS proud of it — that constant and not a new one,
      // because it is the same job it already does for the lens: a physical gap so two coplanar
      // surfaces cannot z-fight, which docs/3d-render.md's standing note says polygonOffset has
      // lost three times. Half a cone is what lets it go this far back at all: the kept wedge's top
      // spans only outward, so a disc of `topR` at the wall face is still inside the hood, where a
      // FULL one would have put half of it inside the building
      var doorY = FacilityStyle.DOOR_LAMP_Y + FacilityStyle.DOOR_LAMP_H / 2;
      if (doors.length > 0)
        cones.push(LightCone.instanced({
          group: coneGroup,
          bulbs: [for (h in hoods) {
            x: h.x - h.nx * (FacilityStyle.DOOR_LAMP_D - FacilityStyle.DOOR_LENS_EPS),
            z: h.z - h.nz * (FacilityStyle.DOOR_LAMP_D - FacilityStyle.DOOR_LENS_EPS),
          }],
          bulbY: doorY,
          radius: doorY * Math.tan(L.angle) * RenderConfig.LAMP_CONE.radiusMul,
          topR: RenderConfig.LAMP_CONE.topR,
          color: FacilityStyle.DOOR_LAMP_COLOR,
          startFrac: FacilityStyle.LAMP_CONE_START,
          arc: Math.PI,
          // the outward normal read as a heading, the same atan2(x, z) the mast heads take
          yaws: [for (h in hoods) Math.atan2(h.nx, h.nz)],
        }));
      return {
        masts: masts,
        park: park,
        ceilings: ceilings,
        corridors: corridors(m),
        doors: doors,
        prop: prop,
        cones: cones,
      };
    }

// hang a fixture over the corridors, which the room pass above cannot reach at all: `m.rooms` is
// area.generatorInfo's TEMP_BUILDING_ROOM blocks, a corridor is never one, and so until this every
// corridor cell in the compound — 279 of them, against 384 of room tile and 88 of hangar concrete,
// so 37% of the 751-cell interior floor — had no light source of any kind and read at the flat
// IndoorMask ambient and nothing else. the floor is also what the gameplay camera mostly sees
// indoors: standing inside, FacilityStyle.ROOF_FADE drops the deck to nothing, so a corridor reads
// as the roof rim, the floor, and the rim again.
//
// row-major greedy against a spacing test, and it finds no RUNS first: a corridor is an L, a T and a
// ring as often as it is a straight length, so the thing a run-finder would have to deal in does not
// exist here. taking the first cell far enough from everything already placed covers any of those
// shapes, and reads only the saved grid — no seed and no Math.random, the rule render.world.Debris
// follows for the same reason
  static function corridors(m:Facility):Array<LampPost>
    {
      var out = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            // Surf.LINO is the corridor floor AND every door cell. isCorr's own isInterior throws
            // out the EXTERIOR doors — one of their four neighbours is the lot — and isDoor throws
            // out the rest: a doorway is a piece of the CIRCULATION, the same call
            // render.facility.FacilityGeom makes when it paints a reveal in the corridor's texture
            // whichever way the door faces, and not somewhere to hang a fitting
            if (!isCorr(m, col, row) ||
                FacilityModel.isDoor(m, col, row) ||
                near(out, col, row))
              continue;
            // and it goes over the middle of the PASSAGE, not over the cell the scan happened to
            // reach first — which on a two-wide corridor is the same side of it every time. the two
            // runs through the cell are its width and its length; the SHORTER is the cross-section,
            // and the longer is what the spacing test above already deals with
            var c = CityConfig.cellToWorld(col, row);
            var rx = run(m, col, row, true);
            var rz = run(m, col, row, false);
            var x = c.x;
            var z = c.z;
            if (rx.lo + rx.hi <= rz.lo + rz.hi)
              x += (rx.hi - rx.lo) * CELL / 2;
            else
              z += (rz.hi - rz.lo) * CELL / 2;
            out.push({
              x: x,
              z: z,
              y: FacilityStyle.ROOF_Y - FacilityStyle.CEIL_DROP,
              // straight down, like a room fixture and unlike a sewer wall bracket
              tx: x,
              tz: z,
              color: FacilityStyle.LAMP_COLOR,
              // the CELL and not the shifted point: this pair is what render.particles.LampLights
              // sorts the pool on and what render.world.IndoorMask.indoorAt reads to keep this lamp
              // out of the outdoor fake-shadow list
              col: col,
              row: row,
              phase: 0.0,
              flick: 1.0,
              mul: FacilityStyle.CORR_MUL,
            });
          }
      return out;
    }

// is this a corridor FLOOR cell — lino that a structure owns on all four sides?
  static inline function isCorr(m:Facility, col:Int, row:Int):Bool
    {
      return FacilityModel.inside(m, col, row) &&
        m.surf[row][col] == Surf.LINO &&
        FacilityModel.isInterior(m, col, row);
    }

// how many cells the corridor through (col,row) carries on for either way along one axis. a door
// cell stops it: it is lino, so counting it would widen a cross-section by the depth of a doorway
// and pull the fixture off centre into the opening
  static function run(m:Facility, col:Int, row:Int, alongX:Bool):{lo:Int, hi:Int}
    {
      var dc = (alongX ? 1 : 0);
      var dr = (alongX ? 0 : 1);
      var lo = 0;
      while (open(m, col - (lo + 1) * dc, row - (lo + 1) * dr))
        lo++;
      var hi = 0;
      while (open(m, col + (hi + 1) * dc, row + (hi + 1) * dr))
        hi++;
      return {
        lo: lo,
        hi: hi,
      };
    }

// corridor floor that is not a doorway — what `run` walks over
  static inline function open(m:Facility, col:Int, row:Int):Bool
    return isCorr(m, col, row) && !FacilityModel.isDoor(m, col, row);

// is a corridor fixture already standing within FacilityStyle.CORR_SPACING cells?
  static function near(out:Array<LampPost>, col:Int, row:Int):Bool
    {
      for (p in out)
        {
          var dc = p.col - col;
          var dr = p.row - row;
          if (dc * dc + dr * dr < FacilityStyle.CORR_SPACING * FacilityStyle.CORR_SPACING)
            return true;
        }
      return false;
    }

// does this room get a fixture? public because render.facility.FacilityGlow asks the same question
// of the same list and the two must not drift — a panel over a room with no bulb, or the reverse,
// is a light with no fitting. the guard is against a stale generatorInfo: `rooms` comes straight off
// it, and nothing else here trusts it to still describe the saved grid
  public static inline function lit(m:Facility, r:_Room):Bool
    return FacilityModel.isIndoor(m, Std.int((r.x1 + r.x2) / 2), Std.int((r.y1 + r.y2) / 2));

// is a DIVIDER standing on this cell? the washroom's partition is the only fitting in the compound
// that is a wall rather than a thing against one, so it is the only one a ceiling fixture has to
// route around
  static inline function isPart(m:Facility, col:Int, row:Int):Bool
    return FacilityModel.inside(m, col, row) &&
      m.deco[row][col] - 1 == _FittingKind.FIT_PARTITION;

// which way a divider through the middle of this room runs, as the axis a fixture lattice must be
// SPLIT ON: 1 for a divider running along x (so the two halves are apart in z), 2 for one running
// along z, 0 for a room with no divider at all.
//
// TAKEN OFF THE CELL NEAREST THE ROOM'S CENTRE, which is where the thing that divides a room is: the
// T's stem sits on the centre row and the small-room fallback's single line sits on the centre of its
// own axis, so the bar — which only separates the lobby from the rest — is never the cell found. The
// run direction is read the way render.facility.FacilityDeco.rectOf reads it, by COUNTING partition
// neighbours on each axis rather than testing for any: at the T's junction one x neighbour stands
// against two in z, and "has an x neighbour" calls that a horizontal run
  static function divider(m:Facility, r:_Room):Int
    {
      var cc = Std.int((r.x1 + r.x2) / 2), cr = Std.int((r.y1 + r.y2) / 2);
      var bx = -1, br = -1, best = 0;
      for (row in r.y1...r.y2 + 1)
        for (col in r.x1...r.x2 + 1)
          {
            if (!FacilityModel.inside(m, col, row) ||
                !isPart(m, col, row))
              continue;
            var d = (col - cc) * (col - cc) + (row - cr) * (row - cr);
            if (bx < 0 ||
                d < best)
              {
                bx = col;
                br = row;
                best = d;
              }
          }
      if (bx < 0)
        return 0;
      var ax = (isPart(m, bx - 1, br) ? 1 : 0) + (isPart(m, bx + 1, br) ? 1 : 0);
      var az = (isPart(m, bx, br - 1) ? 1 : 0) + (isPart(m, bx, br + 1) ? 1 : 0);
      return (ax > 0 && ax >= az ? 1 : 2);
    }

// the cell a fixture at this lattice point actually hangs over: itself, or the nearest of its four
// neighbours still inside the room, when the point landed on the divider. null when none of the five
// will do — a lattice point that is neither indoor nor next to indoor floor has nothing to light
  static function free(m:Facility, r:_Room, col:Int, row:Int):{ col:Int, row:Int }
    {
      for (d in 0...5)
        {
          var c = (d == 0 ? col : col + DC[d - 1]);
          var w = (d == 0 ? row : row + DR[d - 1]);
          if (c < r.x1 ||
              c > r.x2 ||
              w < r.y1 ||
              w > r.y2)
            continue;
          if (FacilityModel.isIndoor(m, c, w) &&
              !isPart(m, c, w))
            return {
              col: c,
              row: w,
            };
        }
      return null;
    }

// does the scan already stand a mast on this cell?
  static function taken(hits:Array<LampHit>, col:Int, row:Int):Bool
    {
      for (h in hits)
        if (h.col == col &&
            h.row == row)
          return true;
      return false;
    }

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
