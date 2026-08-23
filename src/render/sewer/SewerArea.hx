package render.sewer;

import three.Three;
import game.Game;
import render.Area3D;
import render.Area3DTickOpts;
import render.RenderConfig;
import render.SceneSetup;
import render.particles.LampLights;
import render.particles.LampPost;
import render.sewer.SewerModel.Sewer;
import render.world.WorldCtx;

// the underground tunnel area kind (AREA_SEWERS + AREA_HABITAT). deliberately much smaller than
// render.CityArea: there is no ceiling and the camera looks near straight down, so a wall never
// gets between it and the player — which means no occlusion fade, and with nothing to fade the
// whole level welds into five merged meshes (see render.sewer.SewerGeom)
class SewerArea implements Area3D
{
  var game:Game;
  var model:Sewer;
  var lampLights:LampLights;    // live spotlight pool over the corridor nodes
  var lampPosts:Array<LampPost>; // node, exit and wall lamps (for the pool)
  var wallGlow:render.LightCone.ConeSet; // wall-lamp emissive quads, repacked per frame with their bulbs
  var propLights:render.particles.PropLights; // point-light pool for the glowing object props (organs)
  var sceneRef:Scene;                    // held for refreshObjects, which rebuilds the prop batches
  var props:Array<render.world.ObjModels.PropBatch>; // object props: solid / ghost / outline batches
  var tactical = false;                  // tactical view up: the props draw their outline shells

  public function new(game:Game, model:Sewer)
    {
      this.game = game;
      this.model = model;
    }

// the tunnel scene: near-black background, fog that closes in within a few cells, no moon, and the
// same live spotlight pool the streets use hung over the corridor nodes
  public function scene(renderer:WebGLRenderer, lampPool:Int):SceneSetup.SceneBundle
    {
      var bundle = SewerScene.build(renderer, model, lampPool);
      lampLights = bundle.lampLights;
      lampPosts = bundle.lampPosts;
      wallGlow = bundle.wallGlow;
      propLights = bundle.propLights;
      return bundle;
    }

// the whole static shell + its dressing, welded into a handful of merged meshes
  public function build(scene:Scene):Void
    {
      // the whole render layer reads ground height through WorldCtx.floorY, and it returns a flat
      // 0 when there is no city tile grid — which is what lets actors, choreo, particles and decals
      // run down here untouched. buildings stays a live empty array: the shot pass iterates it
      WorldCtx.tiles = null;
      WorldCtx.buildings = [];
      WorldCtx.seed = -1;
      sceneRef = scene;
      SewerGeom.build(scene, model);
      // clutter heaped against the walls. pure decoration — no AreaObject behind it, so no ghost
      // twin, no outline hull and nothing per-frame; see SewerProps for why it is not culled
      SewerProps.build(scene, model);
      // the object props, as real geometry instead of their sprites: the exit ladders, and in a
      // habitat its four grown objects. only tunnel areas ever hold either — WorldConst declares
      // `exit: 'sewer_exit'` on AREA_SEWERS alone and game.Habitat only ever builds into AREA_HABITAT
      props = render.world.ObjModels.build(scene, game, objYaw);
      // the vision mask's texture and world->uv transform. the tunnel materials patched themselves as
      // the builders above made them; this only has to exist before the first sample
      SewerMask.attach(model);
    }

// which way a prop faces from its cell, one branch per render.world.ObjModels.PropYaw.
// WALL turns its back on the adjacent wall (an exit ladder is bracketed to masonry) or stays unturned
// in the open; dir order matches SewerGeom.side (0 north, 1 south, 2 west, 3 east).
// HASHED takes a full-circle turn hashed off the cell, so four of a prop in one level are not four
// clones — and because the hash is the CELL, a level looks the same every time it is entered rather
// than re-rolling on re-entry. No habitat organ takes it any more: each was generated from a single
// front-on reference and so has exactly one authored face (see PropYaw in render.world.ObjModels).
// FRONTAL is a plain 0: the tunnel camera rests looking down -Z with no yaw of its own, so unturned IS
// facing it. a glb whose authored front does not point that way is corrected in render.Models.yawFix,
// baked into the verts at load — that is a fact about the model, not about how a prop is posed
  function objYaw(col:Int, row:Int, mode:render.world.ObjModels.PropYaw):Float
    {
      switch (mode)
        {
          case FRONTAL:
            return 0;
          case HASHED:
            return (SewerModel.mix((col * 40503151) ^ (row * 57885161)) % 3600) / 3600.0 * 2 * Math.PI;
          case WALL:
            if (!SewerModel.isFloor(model, col, row - 1))
              return 0;
            if (!SewerModel.isFloor(model, col, row + 1))
              return Math.PI;
            if (!SewerModel.isFloor(model, col - 1, row))
              return Math.PI / 2;
            if (!SewerModel.isFloor(model, col + 1, row))
              return -Math.PI / 2;
            return 0;
        }
    }

// rebuild the prop batches, after an object was added to or removed from the area we are already
// showing. the 3D scene is otherwise built once per area entry (GameScene.draw3D only rebuilds when
// the area id changes), and an object grown in the habitat the player is standing in would draw
// NOTHING until re-entry — render.Actors drops its sprite the moment the object has a model.
// cheap: the glb templates are cached, so nothing reloads and only the instance buffers are remade
  public function refreshObjects():Void
    {
      if (props == null)
        return;
      render.world.ObjModels.dispose(sceneRef, props);
      props = render.world.ObjModels.build(sceneRef, game, objYaw);
    }

// per-frame world tick — down here that is only the live lamp pool: nothing fades, no windows
// switch, and there are no chunks to cull (the whole level is a handful of merged meshes)
  public function tick(opts:Area3DTickOpts):Void
    {
      // ABOVE the outro gate on purpose: a player who left standing ON a ladder would otherwise stay
      // behind a see-through one for the whole camera pull-out. cull() reads opts.outro itself
      // the outline shells are a tactical READOUT, so a hidden HUD takes them with it
      render.world.ObjModels.cull(props, opts, tactical && opts.ui);
      // the props' idle clock, above the gate for the same reason — the organs are still on screen
      // through the pull-out, and a shared uniform freezing mid-shot is exactly when it would show
      render.world.PropShader.tick(opts.dtMs);
      render.world.PropGlow.tick(opts.dtMs);
      // the exit ladders take the vision mask here rather than in ObjModels, which the city shares:
      // their glb arrives over a loader callback, so there is no build-time moment to catch. patch()
      // marks its own hook and early-outs on the next pass, so this is a couple of reads once landed
      // the idle motion rides the same pass and for the same reason. patched in the SAME ORDER as the
      // mask here and in render.View's boot warm: both chain onto whatever hook a material already
      // carries and both extend its program cache key, so a different order underground than at warm
      // would spell a different key and recompile the lot on the first habitat entry.
      // the HULL is here where the mask skips it (it early-outs on fog:false, a marker not world
      // geometry) — an outline that does not move with the body it traces detaches from it
      for (b in props)
        {
          SewerMask.patchMesh(b.solid.mesh);
          SewerMask.patchMesh(b.ghost.mesh);
          render.world.PropShader.patchMesh(b.solid.mesh, b.model.anim, b.model.pulse, b.model.curl);
          render.world.PropShader.patchMesh(b.ghost.mesh, b.model.anim, b.model.pulse, b.model.curl);
          render.world.PropShader.patchMesh(b.hull.mesh, b.model.anim, b.model.pulse, b.model.curl);
          // the surface glow and the repainted eyes LAST, and neither takes a hull: totalEmissiveRadiance
          // only exists in a lit shader, an outline marker must not luminesce, and an outline that
          // carried eyes would draw them over the body it is meant to trace
          render.world.PropGlow.patchMesh(b.solid.mesh, b.model.shine, b.model.eyes);
          render.world.PropGlow.patchMesh(b.ghost.mesh, b.model.shine, b.model.eyes);
        }
      // nothing else to fade and no window switches underground; the outro needs no world tick at all
      if (opts.outro)
        return;
      // what the player cannot see. driven by the SMOOTHED position and not opts.playerCol/Row: the
      // logical cell snaps to the destination the moment an action resolves, so a cell-keyed mask
      // swung its shadows from a cell the billboard had not reached and held them there for the whole
      // slide. this rebuilds through the ~9 frames of a move (BASE_MS at 60Hz) and then stops dead —
      // the slide is finite, so a rested origin re-keys to the same value and this is a no-op again
      SewerMask.update(game, opts.player.x, opts.player.z);
      lampLights.update(lampPosts, opts.playerCol, opts.playerRow, opts.dtMs);
      // the organs' own coloured lights. a separate pool from the lamps' on purpose: a bracket is a
      // SpotLight aimed along its wall, an organ glows omnidirectionally, and sharing one pool would
      // have the two fighting for slots — the lamps would lose theirs to whatever the player stood near
      propLights.update(game, opts.playerCol, opts.playerRow, opts.dtMs);
      // a wall fixture's glow quad is its ONLY brightness source (no emissive glb head down here), so
      // this is what stops a sputtering lamp from glowing and blooming right through its own outage
      render.LightCone.pulse(wallGlow, lampLights.flickT);
    }

// a tunnel has no occlusion pass, so the only thing tactical changes down here is the prop outlines:
// a modelled object drops its sprite icon, and this backface shell is what replaces the green ring
  public function setTactical(v:Bool):Void
    {
      tactical = v;
    }

// lower than the street's so the few lamps actually bloom against near-black surroundings
  public function bloomThreshold():Float
    {
      return SewerStyle.BLOOM_THRESHOLD;
    }

// near straight down: the walls are low and there is no ceiling, so the shallow street angle
// would stare into a wall face
  public function cameraOffsets():RenderConfig.CameraOffsets
    {
      return RenderConfig.CAMERA_SEWER;
    }

// per-cell-hash litter (no seed underground — the saved cell grid is the layout)
  public function debris():Array<render.world.Debris.DebrisSpot>
    {
      return SewerDebris.build(model);
    }

// re-bind after a settings change rebuilt the live spotlight pool (View.setLampLights)
  public function setLampLights(l:LampLights):Void
    {
      lampLights = l;
    }

// no citygen City underground; the debug tools' city readers all handle null
  public function city():citygen.CityModel.City
    {
      return null;
    }
}
