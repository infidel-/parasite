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
  // WHICH WAY TRAFFIC RUNS ON IT, +1 along `dx/dz` or -1 against. Off the lane's OWN lateral cell
  // index, so the two cells of a CityConfig.ROAD_W road carry opposite streams and a car can
  // never meet one coming the other way down the same line
  var dir:Int;
  // and ONE speed for the whole lane, hashed off its own corner. Per-CAR speed is what let two of
  // them on one line converge and drive through each other; with the lane holding it, nothing
  // ever overtakes and the only thing that varies along a lane is where each car started
  var v:Float;
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
  // the cars' own atlas window, one vec4 per instance — see `cars`
  var carUV:js.lib.Float32Array;
  var carAttr:InstancedBufferAttribute;
  // seconds since the area was built, off RAW dtMs — see the class header
  var clock = 0.0;
  var tmp = new Matrix4();
  // the ONE rotation every quad takes: a PlaneGeometry stands in XY facing +z, and -PI/2 about x
  // lays it flat facing up. built once — compose() applies scale, then this, then the position
  var flat = new Quaternion().setFromEuler(new Euler(-Math.PI / 2, 0, 0));
  var pos = new Vector3();
  var scl = new Vector3();
  // the four headings a car can take, in FacilityGeom.face's numbering: 0 = -z, 1 = +z, 2 = -x,
  // 3 = +x. Built once, because a car only ever points down its lane
  static var HX = [0.0, 0.0, -1.0, 1.0];
  static var HZ = [-1.0, 1.0, 0.0, 0.0];
  var head:Array<Quaternion>;

  public var n(default, null):CorpCrowdSet;

// find the lanes and build the two batches into the street's own group, so they ride its transform
// down to CorpStyle.STREET_Y with everything else
  public function new(group:Group, ?city:City, ?p:PlateBox)
    {
      // the art points at -z, so heading 0 takes no yaw at all and the other three fall out of
      // atan2. `flat` lays the plane down FIRST and the yaw turns it in world, which is the order
      // the multiply reads in
      head = [for (d in 0...4) new Quaternion()
        .setFromAxisAngle(new Vector3(0, 1, 0), Math.atan2(-HX[d], -HZ[d])).multiply(flat)];
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
          carMesh = cars(group, n.cars);
          drive();
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
        drive();
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

// write every car's transform and its picture for the current clock.
//
// SEPARATE FROM `place` and not a flag on it, because almost nothing is shared: a car takes a lane
// that has already decided which way it runs and how fast, it is yawed rather than scale-swapped,
// and it carries a crop of the sheet. What the two do share is that NOTHING IS STORED — the lane,
// the cell, the slot and the speed are all a pure function of the index and the clock
  function drive():Void
    {
      for (i in 0...n.cars)
        {
          var h = FacilityModel.mix((i + 978) * 374761393);
          var ln = road[h % road.length];
          var cell = CorpStyle.CAR_CELLS[(h >>> 5) % CorpStyle.CAR_CELLS.length];
          // ONE SLOT PER CAR on its lane rather than a continuous phase: with the lane holding
          // the speed, two cars that start together stay together forever, and a slot is what
          // stops them starting together in the first place
          var slots = Std.int(ln.len / (2 * CorpStyle.CAR_LEN));
          if (slots < 2)
            slots = 2;
          var v = CorpStyle.CAR_SPEED * ln.v;
          var s = (ln.len * ((h >>> 19) % slots) / slots + clock * v) % ln.len;
          if (ln.dir < 0)
            s = ln.len - s;
          var hx = ln.dx * ln.dir;
          var hz = ln.dz * ln.dir;
          pos.set(ln.x0 + ln.dx * s, CorpStyle.CROWD_Y, ln.z0 + ln.dz * s);
          // the quad's local y is the car's LENGTH — the art points nose-up — and the heading
          // quaternion turns it down its lane
          scl.set(cell.wide, cell.len, 1);
          tmp.compose(pos, head[hx != 0 ? (hx > 0 ? 3 : 2) : (hz > 0 ? 1 : 0)], scl);
          carMesh.setMatrixAt(i, tmp);
          carUV[i * 4] = cell.u0;
          carUV[i * 4 + 1] = cell.v0;
          carUV[i * 4 + 2] = cell.du;
          carUV[i * 4 + 3] = cell.dv;
        }
      carMesh.instanceMatrix.needsUpdate = true;
      carAttr.needsUpdate = true;
    }

// the traffic batch: one instanced quad per car, each showing a different crop of the one sheet.
//
// THE PER-INSTANCE UV RECT IS render.decals.DecalBatch's, cloned rather than shared — that class
// is a POOL with its own capacity, atlas and alpha channel and owns none of this. What is borrowed
// is the two lines that matter: an `instanceUV` vec4 attribute, and the `vMapUv` rewrite that has
// to land AFTER <uv_vertex> because that is what assigns it. Without them four cars would be four
// materials and four draw calls.
//
// AND IT IS NOT ADDITIVE, unlike the walkers beside it: a picture blended additively over the road
// is a stain rather than a car. Plain unlit basic with an alphaTest, like every other street
// surface — and the headlights still bloom, because they are painted past the threshold
  function cars(group:Group, count:Int):InstancedMesh
    {
      carUV = new js.lib.Float32Array(count * 4);
      carAttr = new InstancedBufferAttribute(carUV, 4);
      untyped carAttr.setUsage(THREE.DynamicDrawUsage);
      var geo:Dynamic = new PlaneGeometry(1, 1);
      geo.setAttribute('instanceUV', carAttr);
      var mat:Dynamic = new MeshBasicMaterial({
        map: Textures.loadTexture(CorpStyle.TRAFFIC, 'sprite'),
        color: new Color(0xffffff).multiplyScalar(CorpStyle.CAR_DIM),
        alphaTest: 0.5,
        side: untyped THREE.DoubleSide,
      });
      mat.onBeforeCompile = function(shader:Dynamic)
        {
          shader.vertexShader = 'attribute vec4 instanceUV;\n' +
            StringTools.replace(shader.vertexShader, '#include <uv_vertex>',
              '#include <uv_vertex>\n  vMapUv = uv * instanceUV.zw + instanceUV.xy;');
        };
      // three keys its program cache on the base params and NOT on onBeforeCompile, so without an
      // own key this patched program could be handed to any other plain mapped basic
      untyped mat.customProgramCacheKey = function() return 'corpCarUV';
      var mesh = new InstancedMesh(geo, mat, count);
      mesh.instanceMatrix.setUsage(untyped THREE.DynamicDrawUsage);
      untyped mesh.frustumCulled = false;
      mesh.renderOrder = render.particles.Sprites.ORD_FIXTURE;
      group.add(mesh);
      return mesh;
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
      c.cars(g, 1);
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
                // the LATERAL cell index decides the sense — the row for a lane along x, the
                // column for one along z — so the two cells of a two-wide road come out opposed
                var lat = (axis == 0 ? row : col);
                var lh = FacilityModel.mix((col * 92837111) ^ (row * 689287499) ^ axis);
                out.push({
                  x0: CorpStreet.cellX(p, col) + CELL / 2,
                  z0: CorpStreet.cellZ(p, row) + CELL / 2,
                  dx: dc * 1.0,
                  dz: dr * 1.0,
                  len: (len - 1) * CELL * 1.0,
                  dir: (lat & 1) == 0 ? 1 : -1,
                  v: 1 + ((lh % 1000) / 1000 - 0.5) * 2 * CorpStyle.CROWD_SPEED_VAR,
                });
              }
        }
      return out;
    }
}
