package render.corp;

import three.Three;
import citygen.CityConfig;
import citygen.CityModel.City;
import citygen.CityModel.Tile;
import render.Textures;
import render.corp.CorpStreet.PlateBox;
import render.facility.FacilityModel;
import Images;

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
// **THE PEOPLE ARE THE GAME'S OWN AI ICONS**, and this is the one shape decision in the file.
// `AI` is the NPC class here (see src/ai/AI.hx, `createIcon`), and `Images.getRandomCivilianAI`
// deals every civilian in the game a cell off `images.male` / `images.female`. The 2D corp view
// drew this same fake crowd from those same sheets — `AreaView.paintFakeHost`, commit ab37666,
// `ix: Std.random(10), iy: Std.random(isMale ? 8 : 6)` at half alpha. The first 3D pass replaced
// them with additive radial gradients on the argument that at 114 units down a pedestrian is the
// patch of light they stand in rather than a silhouette. That argument was wrong twice over: it
// is not what was asked for, and the sheets cost nothing — the two 640x1024 atlases stack into
// ONE canvas, so both sexes and all 134 civilian icons ride one instanced batch and one draw
// call, exactly as the four cars do off `corp/traffic`.
//
// They stand UP and lean back by render.particles.Sprites.TILT, which is what every actor
// billboard in this game does and is "slanted so we can see it better": a quad flat on the
// pavement shows a person from directly overhead.
//
// **POSITION IS CLOSED FORM IN t**, so nothing is stored per agent and nothing can drift: each
// one's lane, direction, speed and phase come from a stable hash of its index, and where it is is
// a modulo of the clock. Pause the game for an hour and the street is exactly where the arithmetic
// says it should be.
//
// ponytail: one fixed yaw for every walker, not a facing off the lane. A figure this far away
// subtends a few pixels and the actor billboards it is borrowing from are frontal by rule
// (render.particles.Sprites' own header). Upgrade path is `head[]`, which the cars already carry.
class CorpCrowd
{
  static inline var CELL = CityConfig.CELL;

  var walk:Array<Lane>;
  var road:Array<Lane>;
  var walkMesh:InstancedMesh;
  var carMesh:InstancedMesh;
  // and the cars' headlights, two instances per car — see `lights`
  var lightMesh:InstancedMesh;
  // the cars' own atlas window, one vec4 per instance — see `cars`
  var carUV:js.lib.Float32Array;
  var carAttr:InstancedBufferAttribute;
  // and the people's, off the two civilian sheets — see `people`
  var walkUV:js.lib.Float32Array;
  var walkAttr:InstancedBufferAttribute;
  var images:Images;
  // seconds since the area was built, off RAW dtMs — see the class header
  var clock = 0.0;
  var tmp = new Matrix4();
  // the ONE rotation every quad takes: a PlaneGeometry stands in XY facing +z, and -PI/2 about x
  // lays it flat facing up. built once — compose() applies scale, then this, then the position
  var flat = new Quaternion().setFromEuler(new Euler(-Math.PI / 2, 0, 0));
  // and the one an UPRIGHT quad takes: a PlaneGeometry already stands in XY facing +z, so all it
  // wants is the lean back toward the overhead camera that every actor sprite takes
  var lean = new Quaternion().setFromEuler(
    new Euler(-render.particles.Sprites.TILT, 0, 0));
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
  public function new(group:Group, ?city:City, ?p:PlateBox, ?images:Images)
    {
      this.images = images;
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
          walkMesh = people(group, n.walkers);
          stroll();
        }
      if (n.cars > 0)
        {
          carMesh = cars(group, n.cars);
          lightMesh = lights(group, n.cars * 2);
          drive();
        }
    }

// advance the street. `dtMs` is RAW — see the class header — and this is the whole per-frame cost
// of the feature: 80 matrix writes and two buffer uploads
  public function tick(dtMs:Float):Void
    {
      clock += dtMs / 1000.0;
      if (walkMesh != null)
        stroll();
      if (carMesh != null)
        drive();
    }

// walk every pedestrian for the current clock, and pick the civilian each of them is.
//
// the same contract `drive` runs on and for the same reason: NOTHING IS STORED. Lane, direction,
// speed, phase and which of the 134 civilian icons this walker wears are all a pure function of
// the index, so the street is wherever the arithmetic says after any pause.
//
// THE FEET GO ON THE PAVEMENT, NOT THE CENTRE. A quad leaned back by TILT about its own middle
// swings its base toward the camera and lifts it, so the centre is pushed up by
// `H/2 * cos(TILT)` and back by `H/2 * sin(TILT)` to put the drawn feet on the lane — the same
// correction render.facility.FacilityModel makes for every tilted sprite in the compound
  function stroll():Void
    {
      var h2 = CorpStyle.WALK_H / 2;
      var up = h2 * Math.cos(render.particles.Sprites.TILT);
      var back = h2 * Math.sin(render.particles.Sprites.TILT);
      for (i in 0...n.walkers)
        {
          var h = FacilityModel.mix((i + 1) * 374761393);
          var ln = walk[h % walk.length];
          var rev = ((h >>> 7) & 1) == 1;
          var v = CorpStyle.WALK_SPEED *
            (1 + (((h >>> 9) % 1000) / 1000 - 0.5) * 2 * CorpStyle.CROWD_SPEED_VAR);
          var s = (((h >>> 19) % 1000) / 1000 * ln.len + clock * v) % ln.len;
          if (rev)
            s = ln.len - s;
          pos.set(ln.x0 + ln.dx * s, CorpStyle.CROWD_Y + up, ln.z0 + ln.dz * s - back);
          scl.set(CorpStyle.WALK_H, CorpStyle.WALK_H, 1);
          tmp.compose(pos, lean, scl);
          walkMesh.setMatrixAt(i, tmp);
          cellUV(walkUV, i, h);
        }
      walkMesh.instanceMatrix.needsUpdate = true;
      walkAttr.needsUpdate = true;
    }

// which civilian icon walker `i` wears, as a uv rect into the stacked atlas.
//
// the cell comes from Images' OWN civilian tables — the same `civiliansMale` / `civiliansFemale`
// rows `AI.createIcon` deals a real NPC's portrait from — so a face on the street below is a face
// that could walk past the player upstairs, and no cell that is empty on the sheet is ever picked
  function cellUV(dst:js.lib.Float32Array, i:Int, h:Int):Void
    {
      var male = ((h >>> 3) & 1) == 1;
      var list = (male ? Images.civiliansMale : Images.civiliansFemale);
      var c = list[(h >>> 11) % list.length];
      var t = Const.TILE_SIZE_CLEAN;
      var aw = CorpStyle.WALK_ATLAS_W;
      var ah = CorpStyle.WALK_ATLAS_H;
      // the male sheet is drawn on top of the female one, so the whole canvas is 2 * ah tall
      var px = c.x * t;
      var py = c.y * t + (male ? 0 : ah);
      // half a texel in on every edge: the cells sit edge to edge and a linear tap exactly on the
      // boundary pulls in the neighbour's pixels. `v` is flipped because a CanvasTexture uploads
      // flipY while atlas rows grow downward
      var e = 0.5;
      dst[i * 4] = (px + e) / aw;
      dst[i * 4 + 1] = 1.0 - (py + t - e) / (2 * ah);
      dst[i * 4 + 2] = (t - 2 * e) / aw;
      dst[i * 4 + 3] = (t - 2 * e) / (2 * ah);
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
          // and its two headlights, off the SAME heading and the same cell crop, so a longer car
          // really does carry its lamps further forward and further apart
          var nose = cell.len * (0.5 - CorpStyle.CAR_LIGHT_IN);
          var side = cell.wide * CorpStyle.CAR_LIGHT_SPREAD;
          for (k in 0...2)
            {
              var sg = (k == 0 ? 1.0 : -1.0);
              pos.set(ln.x0 + ln.dx * s + hx * nose - hz * sg * side,
                CorpStyle.CAR_LIGHT_Y,
                ln.z0 + ln.dz * s + hz * nose + hx * sg * side);
              scl.set(CorpStyle.CAR_LIGHT_SZ, CorpStyle.CAR_LIGHT_SZ, 1);
              tmp.compose(pos, flat, scl);
              lightMesh.setMatrixAt(i * 2 + k, tmp);
            }
        }
      carMesh.instanceMatrix.needsUpdate = true;
      carAttr.needsUpdate = true;
      lightMesh.instanceMatrix.needsUpdate = true;
    }

// the headlight batch: one additive glow quad per lamp, lying on the road.
//
// THE MAP IS render.Textures.makeGlowGradient AND IT WAS ALREADY IN THE TREE — the centred radial
// falloff the first 3D pass drew the whole crowd with, referenced by nothing since. See
// CorpStyle.CAR_LIGHT_COLOR.
//
// no per-instance anything: every lamp is the same picture at the same size, so this is a plain
// InstancedMesh with no attribute injection and no cache key of its own. NOT lambert and not
// alpha-tested, which is the one place it departs from the two batches above: a glow is light
// ADDED to whatever is under it and has no albedo for a moon to fall on
  function lights(group:Group, count:Int):InstancedMesh
    {
      var mat = new MeshBasicMaterial({
        map: Textures.makeGlowGradient(),
        color: new Color(CorpStyle.CAR_LIGHT_COLOR)
          .multiplyScalar(CorpStyle.CAR_LIGHT_MUL),
        transparent: true,
        depthWrite: false,
        blending: untyped THREE.AdditiveBlending,
        // FRONT SIDE ONLY, AND IT IS WORTH A DRAW CALL: three renders a TRANSPARENT DoubleSide
        // material in two passes (back faces, then front) unless forceSinglePass is set, and
        // MEASURED here that is 84 -> 86 calls against 84 -> 85. `flat` turns the quad face up
        // and this camera never goes under the street, so the back face is never seen
        side: THREE.FrontSide,
      });
      var mesh = new InstancedMesh(new PlaneGeometry(1, 1), mat, count);
      mesh.instanceMatrix.setUsage(untyped THREE.DynamicDrawUsage);
      untyped mesh.frustumCulled = false;
      mesh.renderOrder = render.particles.Sprites.ORD_FIXTURE;
      group.add(mesh);
      return mesh;
    }

// the traffic batch: one instanced quad per car, each showing a different crop of the one sheet.
//
// THE PER-INSTANCE UV RECT IS render.decals.DecalBatch's, cloned rather than shared — that class
// is a POOL with its own capacity, atlas and alpha channel and owns none of this. What is borrowed
// is the two lines that matter: an `instanceUV` vec4 attribute, and the `vMapUv` rewrite that has
// to land AFTER <uv_vertex> because that is what assigns it. Without them four cars would be four
// materials and four draw calls.
//
// AND IT IS NOT ADDITIVE: a picture blended additively over the road is a stain rather than a car.
// A LAMBERT with an alphaTest, like every other street surface since the outside was given real
// light — and the headlights still bloom, because they are painted past the threshold.
//
// lambert and not basic for the reason the walkers below are: an UNLIT sprite cannot be made to
// sit in a lit street's value range by a multiplier, because the multiplier scales a value the
// street's own light is meanwhile scaling too. Under the same moon it simply lands where the road
// lands
  function cars(group:Group, count:Int):InstancedMesh
    {
      carUV = new js.lib.Float32Array(count * 4);
      carAttr = new InstancedBufferAttribute(carUV, 4);
      untyped carAttr.setUsage(THREE.DynamicDrawUsage);
      var geo:Dynamic = new PlaneGeometry(1, 1);
      geo.setAttribute('instanceUV', carAttr);
      var mat:Dynamic = new MeshLambertMaterial({
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
      c.people(g, 1);
      c.cars(g, 1);
      c.lights(g, 1);
    }

// the people batch: one upright quad per pedestrian, each showing a different civilian icon.
//
// SAME MACHINERY AS THE CARS, and deliberately — an `instanceUV` vec4 plus the `vMapUv` rewrite
// after <uv_vertex>, with a cache key of its own. What differs is only the atlas and the lean.
//
// BOTH SHEETS GO IN ONE CANVAS. `images.male` and `images.female` are 640x1024 each; drawn one
// above the other they are a single CanvasTexture, which is what keeps 134 possible icons and two
// sexes at ONE draw call. Mipmaps are off for render.particles.Sprites.atlasTex's reason: the
// cells sit edge to edge, so a coarse mip averages a neighbouring civilian into this one.
//
// NO vision mask and NO indoor mask, the street's own rule.
//
// AND LAMBERT, WHICH IS THE WHOLE OF "the fake street ai looks too bright". A civilian icon is
// painted for a lit 2D map at full size — flat, saturated, high value — so an UNLIT quad wearing
// one is the brightest thing on a night street whatever it is multiplied by, and at WALK_DIM 0.42
// against a road at 0.0032 linear it still read as a sticker. Under the street's own moon it takes
// the same key the pavement takes and cannot out-shine it
  function people(group:Group, count:Int):InstancedMesh
    {
      walkUV = new js.lib.Float32Array(count * 4);
      walkAttr = new InstancedBufferAttribute(walkUV, 4);
      untyped walkAttr.setUsage(THREE.DynamicDrawUsage);
      var geo:Dynamic = new PlaneGeometry(1, 1);
      geo.setAttribute('instanceUV', walkAttr);
      var mat:Dynamic = new MeshLambertMaterial({
        map: atlas(),
        color: new Color(0xffffff).multiplyScalar(CorpStyle.WALK_DIM),
        alphaTest: 0.5,
        side: untyped THREE.DoubleSide,
      });
      mat.onBeforeCompile = function(shader:Dynamic)
        {
          shader.vertexShader = 'attribute vec4 instanceUV;\n' +
            StringTools.replace(shader.vertexShader, '#include <uv_vertex>',
              '#include <uv_vertex>\n  vMapUv = uv * instanceUV.zw + instanceUV.xy;');
        };
      untyped mat.customProgramCacheKey = function() return 'corpWalkUV';
      var mesh = new InstancedMesh(geo, mat, count);
      mesh.instanceMatrix.setUsage(untyped THREE.DynamicDrawUsage);
      // three frustum-culls an InstancedMesh against the geometry's own bounding sphere, which for
      // a unit plane is half a unit — so the whole street's crowd would vanish the moment the
      // origin instance left the frame. the batch spans the city; it is never worth culling
      untyped mesh.frustumCulled = false;
      mesh.renderOrder = render.particles.Sprites.ORD_FIXTURE;
      group.add(mesh);
      return mesh;
    }

// the two civilian sheets stacked into one texture. `warm` has no Images, and an empty canvas
// compiles exactly the same program a filled one does
  function atlas():CanvasTexture
    {
      var aw = CorpStyle.WALK_ATLAS_W;
      var ah = CorpStyle.WALK_ATLAS_H;
      var cv = js.Browser.document.createCanvasElement();
      cv.width = aw;
      cv.height = 2 * ah;
      if (images != null)
        {
          var cx = cv.getContext2d();
          var m:Dynamic = images.getImage('male');
          var f:Dynamic = images.getImage('female');
          if (m != null && m.complete)
            cx.drawImage(m, 0, 0);
          if (f != null && f.complete)
            cx.drawImage(f, 0, ah);
        }
      var tex = new CanvasTexture(cv);
      tex.colorSpace = THREE.SRGBColorSpace;
      untyped tex.generateMipmaps = false;
      untyped tex.minFilter = THREE.LinearFilter;
      return tex;
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
