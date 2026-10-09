package render.wild;

import three.Three;
import citygen.CityConfig;
import game.Game;
import render.Area3D;
import render.Area3DTickOpts;
import render.RenderConfig;
import render.SceneSetup;
import render.particles.LampLights;
import render.wild.WildModel.Wild;
import render.world.VisionMask;
import render.world.WorldCtx;

// the open wilderness area kind (AREA_GROUND). the smallest of the three: no buildings, so no
// occlusion pass and no window switches; no lamps, so no live pool to park and no flicker to repack.
// what it does have that a tunnel does not is a MOON — so the shadow box has to follow the player,
// and the chunk cull has to keep an offscreen block alive while it is still inside that box
class WildArea implements Area3D
{
  var game:Game;
  var model:Wild;
  var chunks = new render.Chunks();
  var moon:DirectionalLight;                 // shadow-casting moon, repositioned each frame
  var lampLights:LampLights;                 // the pool exists for program-key parity, with no bulbs
  var props:Array<render.Models.InstancedProp>; // one instanced batch per WildStyle.PROPS entry
  // objects that draw as a real glb instead of their sprite — out here that is the relocated alien
  // ship. a SECOND field and not merged into `props` above: that one is index-aligned with
  // WildStyle.PROPS for __wild(), and a PropBatch is a solid/ghost/hull triple anyway
  var objProps:Array<render.world.ObjModels.PropBatch>;
  var sceneRef:Scene;                        // held for refreshObjects, which rebuilds those batches
  var tactical = false;                      // tactical view up: the props draw their outline shells
  var sounds:WildSounds;                     // the band's bed, the highway's, the night one-shots

  public function new(game:Game, model:Wild)
    {
      this.game = game;
      this.model = model;
    }

// the wilderness scene: night sky, fog closing the far edge, fill + a moon, and no lamps
  public function scene(renderer:WebGLRenderer, lampPool:Int):SceneSetup.SceneBundle
    {
      var bundle = WildScene.build(renderer, lampPool);
      moon = bundle.moon;
      lampLights = bundle.lampLights;
      return bundle;
    }

// the ground, the grass and the scatter, then the chunk buckets over the result
  public function build(scene:Scene):Void
    {
      // the relief FIRST: every builder below samples it, and so does the whole actor layer, which
      // reads ground height through WorldCtx.floorY. that returns a flat 0 with no city tile grid,
      // which is what lets actors, choreo, particles and decals run untouched in a tunnel — out here
      // WorldCtx.ground redirects it at the height field instead, and nothing else has to know.
      // buildings stays a live empty array: the shot pass iterates it.
      //
      // the field's AMPLITUDE is not set here — WildBand.use does it, from render.View.showWild,
      // because the Wild model is built before this object exists and already needs the band
      WildHeight.use(game.area.id);
      // the highway is graded into the field BEFORE any builder samples it, so the ribbon, its
      // shoulder, the props beside it and every actor that walks it all read one surface. the rect
      // came out of the saved TILE_ROAD cells in WildModel.fromArea — nothing here re-asks the map
      // the graded band is WIDENED to the VERGE and not to the road cells, because a dirt shoulder
      // carrying a run of crash barrier is exactly the part of a road cross-section that IS level —
      // and because the alpha masks can leave a spur past either nominal edge, and a spur standing on
      // the ramp would be a tilted slab. it is widened to the verge's NOMINAL line rather than to its
      // mesh reach on purpose: the ramp is a smoothstep, so its derivative is zero where it starts
      // and the outermost verge spurs still stand on ground that is flat for practical purposes,
      // without paying the steeper batter a wider flat band costs (see WildStyle.ROAD_RAMP)
      if (model.road != null)
        WildHeight.grade(model.road.alongX,
          model.road.centre * CityConfig.CELL - (CityConfig.GRID * CityConfig.CELL) / 2,
          WildStyle.VERGE_HALF * CityConfig.CELL,
          WildStyle.ROAD_RAMP * CityConfig.CELL);
      WorldCtx.tiles = null;
      WorldCtx.ground = WildHeight.at;
      // the guard rails, for the actor layer. they are the one thing out here an actor walks THROUGH
      // in the game and should be seen to climb OVER in the render — nothing is stamped on the tiles
      // for a rail, so this is a pure animation hook and carries no gameplay with it
      WorldCtx.climbArc = function(fc, fr, tc, tr) return WildRoad.climbArc(model, fc, fr, tc, tr);
      // nothing out here is a wall, so nothing hangs on one — nor stands pushed off one — and a stale
      // hook from a facility would mount an object on masonry the wilderness never built
      WorldCtx.wallMounts = null;
      WorldCtx.wallFace = null;
      WorldCtx.standOff = null;
      WorldCtx.buildings = [];
      WorldCtx.seed = -1;
      // snapshot what the scene rig parented (lights, the empty cone group) so the chunk pass only
      // ever touches the static geometry the builders below add
      var pre = scene.children.copy();
      sceneRef = scene;
      WildGround.build(scene, model);
      WildPatches.build(scene, model);
      WildRoad.build(scene, model, game.area.id);
      WildGrass.build(scene, model);
      props = WildProps.build(scene, model);
      // and the objects that draw as real geometry: the alien ship, once the scenario has moved it
      // out of the compound. their y comes off the HEIGHT FIELD — see the floorYAt call in
      // render.world.ObjModels.build, which is a no-op in the two flat area kinds and the whole of
      // what stops a ship out here floating or burying itself in the relief
      objProps = render.world.ObjModels.build(scene, game, objYaw);
      // the ground and grass blocks bucket; the prop batches span the whole area and so are left at
      // the scene root by Chunks' own size guard, which is right — they are frustum-culled per
      // INSTANCE in tick() instead
      chunks.build(scene, pre);
      sounds = new WildSounds(game, model);
      // the vision mask's texture and world->uv transform. the builders above patched their own
      // materials as they made them; this only has to exist before the first sample.
      //
      // the blocker predicate is canSeeThrough, where a tunnel deliberately does NOT use it — down
      // there it is object-aware and would call a closed door a wall, and the green channel it paints
      // has to be static. out here there is no door and no destructible: the only cells that fail this
      // test are the two large obstacles the generator stamped (Const.TILE_ROCK_LARGE /
      // TILE_TREE_CLUSTER), so it IS static, and reading the tiles beats carrying a copy of them
      VisionMask.attach(WildStyle.MASK, model.w, model.h,
        function(col, row) return !game.area.canSeeThrough(col, row));
      attachDbg();
    }

// which way an object prop faces from its cell, one branch per render.world.ObjModels.PropYaw.
// nothing out here is masonry, so WALL has nothing to turn its back on and answers the same 0
// FRONTAL does — the camera rests with no yaw of its own, so unturned IS facing it
  function objYaw(col:Int, row:Int, mode:render.world.ObjModels.PropYaw):Float
    {
      switch (mode)
        {
          case FRONTAL, WALL:
            return 0;
          case HASHED:
            return (WildModel.mix((col * 40503151) ^ (row * 57885161)) % 3600) / 3600.0 * 2 * Math.PI;
        }
    }

// console debug helper (persistent) — what this wilderness area actually built.
//   __wild() -> { ground, reliefAmp, rocks:[{col,row}], thicket:[{col,row}],
//                 road:{alongX,centre,half}, batches:[{path,count}] }
//
// the two lists come back whole rather than as counts, because the first question after "how many"
// is always "where is one" — an instanced batch carries no userData.cls, so render.Debug.find cannot
// locate a prop out here and there is nothing else to point a camera or a `go xy` at
//
// there is no other way to ask: parasiteHx is the class registry and holds STATICS only, so
// WildBand.cur reads out fine but the Wild model does not — WildModel.fromArea needs an AreaGame and
// nothing reaches one from JS. "did eight boulders actually get placed, and did the thicket cells get
// their understorey" cannot be answered by counting things on screen, and every change out here since
// the bands has needed that class of question settled numerically rather than off a screenshot
  function attachDbg():Void
    {
      untyped js.Browser.window.__wild = function()
        {
          var batches = [];
          for (i in 0...props.length)
            batches.push({
              path: WildStyle.PROPS[i].path,
              count: props[i].matrices.length,
            });
          return {
            ground: WildBand.cur.ground,
            reliefAmp: WildBand.reliefAmp,
            rocks: model.rocks,
            thicket: model.thicket,
            road: model.road,
            batches: batches,
          };
        };
    }

// per-frame world tick: the moon's shadow box, the wind clock, the chunk cull and the per-instance
// prop cull. no occlusion, no window switches, no lamp pool to park
  public function tick(opts:Area3DTickOpts):Void
    {
      // the wind runs through the outro as well: the camera is still looking at the area during the
      // pull-out, and a field that freezes mid-lean is exactly when it would show
      WildGrass.tick(opts.dtMs);
      // the object props, ABOVE the outro gate for the reason the wind is: the camera is still on
      // the area through the pull-out, and a player who left standing IN the ship would otherwise
      // stay behind a see-through hull for the whole shot. cull() reads opts.outro itself
      render.world.ObjModels.cull(objProps, opts, tactical && opts.ui);
      render.world.PropShader.tick(opts.dtMs);
      render.world.PropGlow.tick(opts.dtMs);
      // their glbs land over a loader callback, so there is no build-time moment to catch them. the
      // chain is render.world.ObjModels.patchRow, shared with every other kind that draws these
      for (b in objProps)
        render.world.ObjModels.patchRow(b.model, b.solid.mesh, b.ghost.mesh, b.hull.mesh);
      if (opts.outro)
        return;
      sounds.tick(opts.playerCol, opts.playerRow, opts.dtMs);
      SceneSetup.fitMoon(moon, opts.player);
      // what the player cannot see, off the SMOOTHED position and not opts.playerCol/Row — see
      // VisionMask's own note on why the logical cell is the wrong origin. out here the sweep is
      // cheap: an open area holds ~15 blocker rects against a tunnel's hundreds of wall cells, so it
      // casts ~7.5k ray/segment tests where a tunnel casts ~250k
      VisionMask.update(game, opts.player.x, opts.player.z);
      chunks.cull(opts.camera, opts.player, RenderConfig.MOON_SHADOW.halfExtent);
      for (p in props)
        render.Models.cull(p, opts.camera, WildStyle.PROP_CULL_R);
    }

// nothing FADES out here — there is no building to occlude — so the only thing the tactical view
// changes is the object props: a modelled object drops its sprite icon, and this backface shell is
// what replaces the green ring it would have carried
  public function setTactical(v:Bool):Void
    {
      tactical = v;
    }

// nothing out here glows, so this is the street's own level
  public function bloomThreshold():Float
    {
      return WildStyle.BLOOM_THRESHOLD;
    }

// steeper than the street's, for want of an occlusion fade — see RenderConfig.CAMERA_WILD
  public function cameraOffsets():RenderConfig.CameraOffsets
    {
      return RenderConfig.CAMERA_WILD;
    }

// no street litter in open country EXCEPT along the highway, where every piece is something thrown
// out of a car. thins with distance from the corridor and is empty in an area the road misses, which
// is most of them — so this still returns nothing at all for the open wilderness it always did
  public function debris():Array<render.world.Debris.DebrisSpot>
    {
      return WildDebris.build(model);
    }

// re-bind after a settings change rebuilt the live spotlight pool (View.setLampLights)
  public function setLampLights(l:LampLights):Void
    {
      lampLights = l;
    }

// no citygen City out here; the debug tools' city readers all handle null
  public function city():citygen.CityModel.City
    {
      return null;
    }

// the object props are placed once at build, so the ship the scenario relocates INTO the area the
// player is standing in would draw nothing at all until re-entry — render.Actors drops an object's
// sprite the moment it has a model. cheap: the glb templates are cached, so only the instance
// buffers are remade
  public function refreshObjects():Void
    {
      if (objProps == null)
        return;
      render.world.ObjModels.dispose(sceneRef, objProps);
      objProps = render.world.ObjModels.build(sceneRef, game, objYaw);
    }

// the wilderness has no light but the moon, and the moon is not a fake-shadow caster
  public function shadowLamps():Array<render.particles.LampPost>
    return [];

// no park out here, so no swarm — see render.Area3D.flyLamps
  public function flyLamps():Array<render.particles.LampPost>
    return [];
}
