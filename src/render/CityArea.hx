package render;

import three.Three;
import citygen.CityConfig;
import citygen.CityModel.City;
import citygen.CityModel.Tile;
import game.Game;
import render.particles.LampLights;
import render.particles.LampPost;

// the city street area kind: procedural blocks from a citygen City, a moon whose shadow box
// follows the player, instanced lamp posts with a live spotlight pool, window light switches and
// the building occlusion fade. lifted out of render.View unchanged when render.Area3D landed —
// this is the whole of what used to be View's city-specific half
class CityArea implements Area3D
{
  var game:Game;
  var cityModel:City;                                     // read through city(), which the Area3D contract names
  var seed:Int;                                           // citygen seed (-1 = seedless reconstruction)
  var style:render.world.AreaStyle;                       // per-area textures + facade behaviour
  var chunks = new Chunks();
  var occlusion:Occlusion;                                // fades buildings blocking the player
  var moon:DirectionalLight;                              // shadow-casting moon, repositioned each frame
  var lampLights:LampLights;                              // live spotlight pool, ticked each frame
  var lampPosts:Array<LampPost>;                          // every placed lamp (for the pool)
  var lampProp:render.Models.InstancedProp;               // instanced lamp meshes, frustum-culled per frame
  var lampPropDead:render.Models.InstancedProp;           // dead lamps' posts (unlit bulb), culled alongside
  var coneFlick:render.LightCone.ConeSet;                 // flickering lamps' cones, repacked per frame
  var lampMask:Array<Bool>;                               // draw mask for lampProp — first entries are the flickering lamps
  var lampMaskDead:Array<Bool>;                           // its complement for lampPropDead (same posts, dark material)
  var flickCells:Array<{ col:Int, row:Int }>;            // the flickering lamps' cells, in coneFlick order
  var sounds:CitySounds;                                  // the tier's beds, the street's loops and one-shots
  var sceneRef:Scene;                                     // the built scene, for refreshObjects
  var props:Array<render.world.ObjModels.PropBatch>;     // the object props (dumpsters), culled per frame
  var groundProps:Array<render.Models.InstancedProp> = []; // the street's ground props and car wrecks, culled per frame
  var puddles:Array<render.world.Debris.DebrisSpot> = [];  // the litter under the wall kit's broken downpipes
  var steam:render.world.SteamPuffs;                      // the plumes off the sewer hatches
  var kits:Array<render.world.KitChunk> = [];             // the wall kit per chunk, its slices synced to the fader per frame
  var tactical = false;                                   // tactical view up: the props show their outline

  public function new(game:Game, city:City, seed:Int)
    {
      this.game = game;
      this.cityModel = city;
      this.seed = seed;
    }

// the city scene: night sky, city-span fog, fill lights + the moon, and the instanced lamp posts
// with their live spotlight pool
  public function scene(renderer:WebGLRenderer, lampPool:Int):SceneSetup.SceneBundle
    {
      style = render.world.AreaStyle.forArea(game.area.typeID);
      var bundle = SceneSetup.buildScene(renderer, cityModel, lampPool, style);
      moon = bundle.moon;
      lampLights = bundle.lampLights;
      lampPosts = bundle.lampPosts;
      lampProp = bundle.lampProp;
      lampPropDead = bundle.lampPropDead;
      coneFlick = bundle.coneFlick;
      lampMask = bundle.lampMask;
      lampMaskDead = bundle.lampMaskDead;
      flickCells = bundle.flickCells;
      return bundle;
    }

// all lit world geometry, then the chunk buckets, then the occlusion fader over the result
  public function build(scene:Scene):Void
    {
      // snapshot what SceneSetup parented (lights, lamp cones, the city-wide lamp prop) so the
      // chunk pass only ever touches static geometry the world builder adds below
      var pre = scene.children.copy();
      sceneRef = scene;
      // the street furniture, where the area was generated with it (game.CityAreaGenerator
      // .placeFurniture): its cells are the walkway and alley it flipped unwalkable
      var furniture:Array<Int> = null;
      if (game.area.cityGenVersion >= 1)
        furniture = [for (row in 0...CityConfig.GRID) for (col in 0...CityConfig.GRID)
          if (game.area.getCellType(col, row) == Const.TILE_WALKWAY_UNWALKABLE ||
              game.area.getCellType(col, row) == Const.TILE_ALLEY_UNWALKABLE)
            row * CityConfig.GRID + col];
      // a back door must not open onto a dumpster standing against its wall, nor onto alley furniture
      var bins = new Map<Int, Bool>();
      for (o in game.area.getObjects())
        if (o.type == 'dumpster')
          bins.set(o.y * CityConfig.GRID + o.x, true);
      var solid = bins.copy();
      if (furniture != null)
        for (k in furniture)
          solid.set(k, true);
      // nor onto an alley-mouth fence (game.CityAreaGenerator.placeFences) or the holed panel in a
      // mouth it left open
      var fences = [for (row in 0...CityConfig.GRID) for (col in 0...CityConfig.GRID)
        if (render.world.CityFences.isFence(game.area.getCellType(col, row)))
          row * CityConfig.GRID + col];
      for (k in fences)
        solid.set(k, true);
      for (k in render.world.CityFences.openMouths(game.area).keys())
        solid.set(k, true);
      render.world.WorldCtx.doorBlocked = function(col, row) return solid.exists(row * CityConfig.GRID + col);
      World.build(scene, cityModel, seed, style);
      render.world.WorldCtx.doorBlocked = null;
      // the wall kit, merged per building and tagged with it. a cached glb (the boot warm loads it)
      // lands right here, before the occlusion pass below buckets the scene; a late one is handed to
      // the fader. the puddles under its broken downpipes join the street litter (debris)
      puddles = render.world.StreetProps.build(scene, function(kc)
        {
          kits = kc;
          if (occlusion != null)
            for (k in kc)
              for (p in k.parts)
                occlusion.adopt(p.proxy);
        });
      // the object props: the dumpsters, and only the rows the city may draw unpatched (see
      // render.world.ObjModels.unmasked) — every other object keeps its sprite out here. their glbs
      // land over a loader callback after the chunk pass below, which leaves the batches at the scene
      // root; they are culled per instance in tick()
      props = render.world.ObjModels.build(scene, game, objYaw);
      // the street's ground props, clear of every object's cell, the sacks beside the dumpsters; and
      // steam off every sewer hatch, from the lid it lies flat on (a walkway stands a kerb up)
      var blocked = new Map<Int, Bool>();
      for (k in fences)
        blocked.set(k, true);
      var vents:Array<Vector3> = [];
      for (o in game.area.getObjects())
        {
          blocked.set(o.y * CityConfig.GRID + o.x, true);
          if (o.type == 'sewer_hatch')
            {
              var w = CityConfig.cellToWorld(o.x, o.y);
              vents.push(new Vector3(w.x, (cityModel.tiles[o.y][o.x] == Tile.Walkway ? RenderConfig.CURB_H : 0.0), w.z));
            }
        }
      groundProps = render.world.StreetProps.ground(scene, cityModel, blocked, [for (k in bins.keys()) k], furniture);
      groundProps.push(render.world.StreetProps.wrecks(scene, game.area));
      chunks.build(scene, pre);
      // AFTER the chunk pass: one mesh at the origin holding every plume, so bucketed it went dark
      // whenever the origin's chunk left the frustum
      steam = new render.world.SteamPuffs(scene, vents);
      // and the fences, one merged mesh for the same reason
      render.world.CityFences.build(scene, game.area);
      occlusion = new Occlusion(scene, cityModel.buildings, cityModel.tiles);
      sounds = new CitySounds(game, cityModel, flickCells, coneFlick);
    }

// per-frame world tick: moon shadow box, window switches, occlusion fade, chunk cull and the
// live lamp pool (plus the flicker repack the posts and cones share)
  public function tick(opts:Area3DTickOpts):Void
    {
      // the object props, ABOVE the outro gate: cull() reads opts.outro itself, and the camera is
      // still on the street through the pull-out. no patch chain: the city has no vision mask
      render.world.ObjModels.cull(props, opts, tactical && opts.ui);
      for (p in groundProps)
        render.Models.cull(p, opts.camera, CityConfig.CELL);
      steam.tick(opts.dtMs, opts.player);
      // leaving: keep fading buildings that slide between the zooming-in camera and the (frozen)
      // player, so the marker stays visible through the outro. occlusion reads no game state
      if (opts.outro)
        {
          occlusion.update(opts.camPos, opts.player, null, false, opts.dtMs);
          render.world.StreetProps.sync(kits);
          return;
        }
      sounds.tick(opts.playerCol, opts.playerRow, opts.dtMs);
      // keep the moon's shadow box centered on the player so building/lamp shadows track the view
      SceneSetup.fitMoon(moon, opts.player);
      // someone in the city flips a light: run the window switch countdowns BEFORE the occlusion
      // pass, so a building that is mid-fade re-copies its ghost on the same frame the window changed
      render.world.Windows.pulse(opts.dtMs);
      if (!opts.freeCam)
        occlusion.update(opts.camPos, opts.player, opts.target, opts.aiming, opts.dtMs);
      render.world.StreetProps.sync(kits);
      chunks.cull(opts.camera, opts.player, RenderConfig.MOON_SHADOW.halfExtent);
      // park the live-spotlight pool on the nearest lamps to the player
      lampLights.update(lampPosts, opts.lightCol, opts.lightRow, opts.dtMs);
      // pull the cones of any flickering lamp that is mid-outage out of the draw (no-op most
      // frames), then hand the same on/off state to the post batches: a lamp that is out draws from
      // the DEAD batch instead, so its emissive head stops glowing and blooming for the outage
      render.LightCone.pulse(coneFlick, lampLights.flickT);
      for (i in 0...coneFlick.on.length)
        {
          lampMask[i] = coneFlick.on[i];
          lampMaskDead[i] = !coneFlick.on[i];
        }
      // drop offscreen lamp meshes: one InstancedMesh otherwise draws all ~280 whenever any is
      // visible. radius CELL*2 covers a lamp's full height as an edge margin so none pop at the edges
      render.Models.cull(lampProp, opts.camera, CityConfig.CELL * 2, lampMask);
      render.Models.cull(lampPropDead, opts.camera, CityConfig.CELL * 2, lampMaskDead);
    }

// tactical view toggle — the occlusion pass fades on a different rule when zoomed out
  public function setTactical(v:Bool):Void
    {
      tactical = v;
      occlusion.setTactical(v);
    }

// where the glow starts, per area style (a downtown of lit glass blooms at a different level)
  public function bloomThreshold():Float
    {
      return style.bloomThreshold;
    }

// the shallow street camera (~30 degrees at its closest)
  public function cameraOffsets():RenderConfig.CameraOffsets
    {
      return RenderConfig.CAMERA;
    }

// seed-derived street debris (render-only, deterministic from the seed — no save cost), and the
// puddles under the broken downpipes; old seedless saves (seed -1) get the puddles alone
  public function debris():Array<render.world.Debris.DebrisSpot>
    {
      if (seed == -1)
        return puddles;
      return render.world.Debris.build(seed, cityModel.tiles, game.area.typeID, game.area.highCrime, style).concat(puddles);
    }

// re-bind after a settings change rebuilt the live spotlight pool (View.setLampLights)
  public function setLampLights(l:LampLights):Void
    {
      lampLights = l;
    }

// rebuild the prop batches after an object was added to or removed from the street on screen. cheap:
// the glb templates are cached, so only the instance buffers are remade
  public function refreshObjects():Void
    {
      if (props == null)
        return;
      render.world.ObjModels.dispose(sceneRef, props);
      props = render.world.ObjModels.build(sceneRef, game, objYaw);
    }

// which way a prop faces from its cell, one branch per render.world.ObjModels.PropYaw. WALL turns its
// back on the building beside it — north, then west, then east, then south, since the generator only
// ever stands a dumpster against ONE wall (game.CityAreaGenerator.isDumpsterSpot). HASHED takes a turn
// hashed off the cell, so the street looks the same on every entry; FRONTAL is unturned, the camera's
// rest yaw
  function objYaw(col:Int, row:Int, mode:render.world.ObjModels.PropYaw):Float
    {
      switch (mode)
        {
          case FRONTAL:
            return 0;
          case HASHED:
            return (((col * 40503151) ^ (row * 57885161)) & 0x7fffffff) % 3600 / 3600.0 * 2 * Math.PI;
          case WALL:
            if (isBuilding(col, row - 1))
              return 0;
            if (isBuilding(col - 1, row))
              return Math.PI / 2;
            if (isBuilding(col + 1, row))
              return -Math.PI / 2;
            if (isBuilding(col, row + 1))
              return Math.PI;
            return 0;
        }
    }

// is this cell a building (off the grid counts as one, as citygen's own edge tests do)?
  inline function isBuilding(col:Int, row:Int):Bool
    {
      return col < 0 ||
        row < 0 ||
        col >= CityConfig.GRID ||
        row >= CityConfig.GRID ||
        cityModel.tiles[row][col] == Tile.Building;
    }

// every light on the street owns a pool slot, so the fake shadows come from LampLights.active()
  public function shadowLamps():Array<render.particles.LampPost>
    return [];

// no park out here, so no swarm — see render.Area3D.flyLamps
  public function flyLamps():Array<render.particles.LampPost>
    return [];

// the city this area was built from (the debug tools report against it)
  public function city():City
    {
      return cityModel;
    }
}
