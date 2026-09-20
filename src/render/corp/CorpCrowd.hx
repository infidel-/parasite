package render.corp;

import three.Three;
import citygen.CityConfig;
import citygen.CityModel.City;
import citygen.CityModel.Tile;
import render.Textures;
import render.corp.CorpStreet.PlateBox;
import render.facility.FacilityModel;

// one straight run of walkable cells, in world. an agent walks it end to end and wraps
typedef Lane = {
  var x0:Float;      // the run's first end
  var z0:Float;
  var dx:Float;      // and its unit direction
  var dz:Float;
  var len:Float;     // world length
};

// what the crowd placed, for __corp()
typedef CorpCrowdSet = {
  var walkers:Int;
  var cars:Int;
  var walkLanes:Int;
  var roadLanes:Int;
};

// the fake crowd on the street 114 units down: people on the walkways and traffic on the roads.
//
// PURELY VISUAL AND THAT IS THE BRIEF. No entity, no AI, no state, no spawn or despawn, nothing
// persisted and nothing the game layer can see — the same contract render.particles.PropFX's gnat
// swarms run on, and the direct 3D successor to the 2D `_FakeHost` / `turnCorp` / `paintFakeHost`
// code the corp AreaView used to carry.
//
// **ON A WALL CLOCK, NOT ON THE TURN CLOCK AND NOT ON ANIM_SPEED.** Every other timed animation in
// this game derives from RenderConfig.BASE_MS and is scaled by the global ANIM_SPEED; this one
// takes RAW dtMs, which is the documented exception for ambient city life. That is the point of
// the feature: the street keeps moving while the player stands still thinking, and traffic that
// sped up when somebody turned their animation speed up would be wrong.
//
// **FLAT QUADS OF LIGHT, NOT BILLBOARDS OF PEOPLE**, and this is the one shape decision in the
// file. At 114 units down, through fog, at a 51-degree camera pitch, a pedestrian is not a
// silhouette — they are the patch of light they are standing in, and a car is its headlights. So
// each agent is ONE quad lying on the road wearing the shared radial glow gradient, additive. That
// buys: no billboarding maths, no atlas, no new art at all, two draw calls for the whole street,
// and a read that is actually MORE correct than an upright sprite three pixels tall would be.
//
// **POSITION IS CLOSED FORM IN t**, so nothing is stored per agent and nothing can drift: each
// one's lane, direction, speed and phase come from a stable hash of its index, and where it is is
// a modulo of the clock. Pause the game for an hour and the street is exactly where the arithmetic
// says it should be.
//
// ponytail: the pedestrians are points of light rather than little people. Upgrade path if they
// ever need to be figures — one InstancedMesh of upright quads leaned back by Sprites.TILT with a
// per-instance UV rect injected the way render.decals.DecalBatch does it, off the people atlas;
// still one draw call, but it needs the atlas plumbed through and it buys nothing at this range.
class CorpCrowd
{
  static inline var CELL = CityConfig.CELL;

  var walk:Array<Lane>;
  var road:Array<Lane>;
  var walkMesh:InstancedMesh;
  var carMesh:InstancedMesh;
  // seconds since the area was built, off RAW dtMs — see the class header
  var clock = 0.0;
  var tmp = new Matrix4();
  // the ONE rotation every quad takes: a PlaneGeometry stands in XY facing +z, and -PI/2 about x
  // lays it flat facing up. built once — compose() applies scale, then this, then the position
  var flat = new Quaternion().setFromEuler(new Euler(-Math.PI / 2, 0, 0));
  var pos = new Vector3();
  var scl = new Vector3();

  public var n(default, null):CorpCrowdSet;

// find the lanes and build the two batches into the street's own group, so they ride its transform
// down to CorpStyle.STREET_Y with everything else
  public function new(group:Group, ?city:City, ?p:PlateBox)
    {
      // the warm path takes no city and builds no agents — see `warm`
      if (city == null)
        {
          walk = [];
          road = [];
          n = {
            walkers: 0,
            cars: 0,
            walkLanes: 0,
            roadLanes: 0,
          };
          return;
        }
      walk = lanes(city, p, Tile.Walkway);
      road = lanes(city, p, Tile.Road);
      n = {
        walkers: (walk.length == 0 ? 0 : CorpStyle.WALKERS),
        cars: (road.length == 0 ? 0 : CorpStyle.CARS),
        walkLanes: walk.length,
        roadLanes: road.length,
      };
      if (n.walkers > 0)
        {
          walkMesh = batch(group, n.walkers, CorpStyle.WALK_COLOR, CorpStyle.WALK_GLOW);
          place(walkMesh, walk, n.walkers, CorpStyle.WALK_SZ, CorpStyle.WALK_SZ,
            CorpStyle.WALK_SPEED, 0);
        }
      if (n.cars > 0)
        {
          carMesh = batch(group, n.cars, CorpStyle.CAR_COLOR, CorpStyle.CAR_GLOW);
          place(carMesh, road, n.cars, CorpStyle.CAR_LEN, CorpStyle.CAR_WIDE,
            CorpStyle.CAR_SPEED, 977);
        }
    }

// advance the street. `dtMs` is RAW — see the class header — and this is the whole per-frame cost
// of the feature: 80 matrix writes and two buffer uploads
  public function tick(dtMs:Float):Void
    {
      clock += dtMs / 1000.0;
      if (walkMesh != null)
        place(walkMesh, walk, n.walkers, CorpStyle.WALK_SZ, CorpStyle.WALK_SZ,
          CorpStyle.WALK_SPEED, 0);
      if (carMesh != null)
        place(carMesh, road, n.cars, CorpStyle.CAR_LEN, CorpStyle.CAR_WIDE,
          CorpStyle.CAR_SPEED, 977);
    }

// write every agent's transform for the current clock. `salt` keeps the two families' hashes apart
// so a car and a walker with the same index do not take the same lane fraction
  function place(mesh:InstancedMesh, ls:Array<Lane>, count:Int, along:Float, across:Float,
      speed:Float, salt:Int):Void
    {
      for (i in 0...count)
        {
          var h = FacilityModel.mix((i + salt + 1) * 374761393);
          var ln = ls[h % ls.length];
          // WHICH WAY down the lane, how fast, and where it started — all three off the same hash,
          // so an agent is a pure function of its index and the clock
          var back = ((h >>> 7) & 1) == 1;
          var v = speed * (1 + (((h >>> 9) % 1000) / 1000 - 0.5) * 2 * CorpStyle.CROWD_SPEED_VAR);
          var phase = ((h >>> 19) % 1000) / 1000 * ln.len;
          var s = (phase + clock * v) % ln.len;
          if (back)
            s = ln.len - s;
          // the lane's own axis carries the quad's LENGTH: a car is 8 long and 3.6 wide and has to
          // point down the road it is on, and a walker's quad is square so the same code is a no-op
          // for it
          var px = ln.x0 + ln.dx * s;
          var pz = ln.z0 + ln.dz * s;
          var sx = (ln.dx != 0 ? along : across);
          var sz = (ln.dx != 0 ? across : along);
          pos.set(px, CorpStyle.CROWD_Y, pz);
          // the LOCAL y of a laid-flat plane is world z, so the second scale is the run across
          scl.set(sx, sz, 1);
          tmp.compose(pos, flat, scl);
          mesh.setMatrixAt(i, tmp);
        }
      mesh.instanceMatrix.needsUpdate = true;
    }

// compile the two crowd programs into a warm scene without generating a city for them. an
// InstancedMesh's USE_INSTANCING is a program define and additive + a map + transparent are all in
// three's key, so nothing else in this kind covers it — and a one-instance batch compiles exactly
// the same program a sixty-four-instance one does
  public static function warm(scene:Scene):Void
    {
      var g = new Group();
      scene.add(g);
      var c = new CorpCrowd(g);
      c.batch(g, 1, CorpStyle.WALK_COLOR, CorpStyle.WALK_GLOW);
      c.batch(g, 1, CorpStyle.CAR_COLOR, CorpStyle.CAR_GLOW);
    }

// one additive batch of glow quads. NO vision mask and NO indoor mask, the street's own rule —
// and no depth write, because a hundred overlapping glows sorting against each other is a hundred
// chances to get it wrong for no gain
  function batch(group:Group, count:Int, color:Int, mul:Float):InstancedMesh
    {
      var geo = new PlaneGeometry(1, 1);
      var mat = new MeshBasicMaterial({
        color: new Color(color).multiplyScalar(mul),
        map: Textures.makeGlowGradient(),
        transparent: true,
        depthWrite: false,
        blending: untyped THREE.AdditiveBlending,
      });
      var mesh = new InstancedMesh(geo, mat, count);
      mesh.instanceMatrix.setUsage(untyped THREE.DynamicDrawUsage);
      // three frustum-culls an InstancedMesh against the geometry's own bounding sphere, which for
      // a unit plane is half a unit — so the whole street's traffic would vanish the moment the
      // origin instance left the frame. the batch spans the city; it is never worth culling
      untyped mesh.frustumCulled = false;
      mesh.renderOrder = render.particles.Sprites.ORD_FIXTURE;
      group.add(mesh);
      return mesh;
    }

// every straight run of `kind` at least LANE_MIN cells long, ON THE STREET THAT WAS BUILT.
//
// RUNS AND NOT A PATHFINDER, which is the whole of the "fake to simplify logic" the brief asks
// for: a lane is a straight length of road or footpath and an agent walks it end to end and wraps.
// Nobody turns a corner, and from 114 units up nobody can tell — what reads is that the street is
// moving. Both axes are scanned, so a crossroads really does carry traffic both ways
  static function lanes(city:City, p:PlateBox, kind:Tile):Array<Lane>
    {
      var out = [];
      // the SAME predicate CorpStreet emitted the ground with, so a lane can never run over a cell
      // that was never built — under the plate above all, where an agent walks in the dark
      var ok = function(col:Int, row:Int)
        {
          // FOLDED, exactly as CorpStreet's own ground loop folds: the model is mirror-tiled out
          // to the reach, so there are no out-of-range indices any more and a lane must be able
          // to run in a tile the model was reflected into
          if (city.tiles[CorpStreet.fold(row)][CorpStreet.fold(col)] != kind)
            return false;
          var x0 = CorpStreet.cellX(p, col);
          var z0 = CorpStreet.cellZ(p, row);
          return CorpStreet.ring(p, x0, x0 + CELL, z0, z0 + CELL);
        };
      for (axis in 0...2)
        {
          var dc = (axis == 0 ? 1 : 0);
          var dr = (axis == 0 ? 0 : 1);
          for (row in -CityConfig.GRID...2 * CityConfig.GRID)
            for (col in -CityConfig.GRID...2 * CityConfig.GRID)
              {
                // only the FIRST cell of a run starts one, or every cell of a 20-long road would
                // start a lane and the crowd would pile into its head
                if (!ok(col, row) ||
                    ok(col - dc, row - dr))
                  continue;
                var len = 0;
                while (ok(col + dc * len, row + dr * len))
                  len++;
                if (len < CorpStyle.LANE_MIN)
                  continue;
                out.push({
                  x0: CorpStreet.cellX(p, col) + CELL / 2,
                  z0: CorpStreet.cellZ(p, row) + CELL / 2,
                  dx: dc * 1.0,
                  dz: dr * 1.0,
                  len: (len - 1) * CELL * 1.0,
                });
              }
        }
      return out;
    }
}
