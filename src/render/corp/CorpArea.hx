package render.corp;

import three.Three;
import game.Game;
import render.Area3D;
import render.Area3DTickOpts;
import render.RenderConfig;
import render.SceneSetup;
import render.particles.LampLights;
import render.particles.LampPost;
import render.facility.FacilityDetail;
import render.facility.FacilityDoors;
import render.facility.FacilityDoors.DoorBatch;
import render.facility.FacilityGeom;
import render.facility.FacilityGeom.Shell;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Wall;
import render.facility.FacilityScene;
import render.facility.FacilityStyle;
import render.world.ContactMask;
import render.world.IndoorMask;
import render.world.VisionMask;
import render.world.WorldCtx;

// the corp tower area kind (AREA_CORP): one floor plate, twenty storeys up. it is the facility's
// INDOOR half with the outdoor half deleted — no lot, no lawn, no gate, no roof deck — so it owns
// almost no geometry of its own and instead drives render.facility's emitters off a ShellTex that
// names corp art (render.corp.CorpStyle.shell).
//
// what differs from a compound, and why each one follows from "the player is always inside":
//   - NO ROOF. FacilityGeom's flat deck is gated off for kind 'corp' — a ceiling over a plate the
//     player never leaves is permanently faded, i.e. dead geometry in the sorted pass.
//   - NO REVEAL EASE. there is one structure and the player is in it, so `inside` is pinned at 1
//     at build and the glazing tint never moves. nothing to ease, so no per-frame ease pass.
//   - NO OCCLUSION and no buildings list, exactly as the compound.
//
// phase 2 of the 2D -> 3D port: shell, doors, object props, masks. the furniture, the props, the
// lighting rig and the street below come in later phases and are each one more line in `build`
class CorpArea implements Area3D
{
  var game:Game;
  var model:Facility;
  var chunks = new render.Chunks();
  var lampLights:LampLights;
  var coneGroup:Object3D;
  var lampCorners:Map<Int,Int>;
  var shells:Array<Shell>;
  var doors:Array<DoorBatch>;
  var props:Array<render.world.ObjModels.PropBatch>;
  var built:Scene;
  var tactical = false;

  public function new(game:Game, model:Facility)
    {
      this.game = game;
      this.model = model;
    }

// the compound's rig with the tower's sky and its much tighter fog — see CorpStyle.FOG_NEAR
  public function scene(renderer:WebGLRenderer, lampPool:Int):SceneSetup.SceneBundle
    {
      var bundle = FacilityScene.build(renderer, lampPool,
        CorpStyle.SKY, CorpStyle.FOG_NEAR, CorpStyle.FOG_FAR);
      lampLights = bundle.lampLights;
      coneGroup = bundle.coneGroup;
      lampCorners = bundle.lampCorners;
      return bundle;
    }

// the floor plate's shell, its doors and its object props
  public function build(scene:Scene):Void
    {
      // a plate is flat and has nothing to climb, so both of those are CLEARED rather than left:
      // the kind that sets one owns clearing it, or the next area inherits the wilderness's height
      // field and its guard rails (WorldCtx). the two that are set are the two a tower shares with
      // a compound — masonry that carries objects, and masonry that does not fill its cell
      WorldCtx.tiles = null;
      WorldCtx.ground = null;
      WorldCtx.climbArc = null;
      WorldCtx.wallMounts = function(col, row) return FacilityGeom.wallMounts(model, col, row);
      // masonry is a slab CENTRED in its cell and not the cell itself, so a decal laid on the cell
      // boundary hangs a whole unit off the wall
      WorldCtx.wallFace = function(col, row, dir) return FacilityGeom.wallFace(model, col, row, dir);
      WorldCtx.standOff = null;
      WorldCtx.buildings = [];
      WorldCtx.seed = -1;
      // both masks go BEFORE the builders and not after: each reads `on` at MATERIAL-CREATION time
      // to decide whether to compile its swap into a surface at all, and every material this kind
      // owns is created by FacilityGeom.build three lines down
      IndoorMask.attach(FacilityStyle.INDOOR, model.w, model.h,
        function(col, row) return FacilityModel.isInterior(model, col, row));
      var masonry = FacilityDetail.masonry(model);
      ContactMask.attach(FacilityStyle.CONTACT, model.w, model.h, masonry.solid, masonry.holes);
      render.world.PropEnv.attach(FacilityStyle.PROP_ENV);
      var pre = scene.children.copy();
      built = scene;
      shells = FacilityGeom.build(scene, model);
      // the inside-corner strips, which are the one piece of FacilityDetail a bare shell wants:
      // without them every reentrant corner of the plate shows the seam between two wall slabs
      FacilityDetail.corners(scene, model);
      // the glazing is pinned OPEN rather than eased. see the class header: one structure, and the
      // player is standing in it from the first frame
      for (s in shells)
        s.glaze.value = 1.0;
      doors = FacilityDoors.build(scene, model, game.area);
      props = render.world.ObjModels.build(scene, game, objYaw, objLift);
      chunks.build(scene, pre);
      // the same pair of predicates the compound passes: a blocker is masonry that is not glazed,
      // and `carries` is what slab() insets against, so the reveal pulls back off exactly the floor
      // the masonry left open
      VisionMask.attach(FacilityStyle.MASK, model.w, model.h,
        function(col, row) return FacilityModel.isWall(model, col, row) &&
          model.wall[row][col] != Wall.WINDOW,
        function(col, row) return FacilityGeom.carries(model, col, row));
    }

// nothing in a tower stands on anything but the floor
  function objLift(col:Int, row:Int):Float
    {
      return 0.0;
    }

// which way an object prop faces from its cell — the compound's three branches unchanged
  function objYaw(col:Int, row:Int, mode:render.world.ObjModels.PropYaw):Float
    {
      switch (mode)
        {
          case FRONTAL:
            return 0;
          case HASHED:
            return (FacilityModel.mix((col * 40503151) ^ (row * 57885161)) % 3600) / 3600.0 * 2 * Math.PI;
          case WALL:
            if (FacilityModel.isWall(model, col, row - 1))
              return 0;
            if (FacilityModel.isWall(model, col, row + 1))
              return Math.PI;
            if (FacilityModel.isWall(model, col - 1, row))
              return Math.PI / 2;
            if (FacilityModel.isWall(model, col + 1, row))
              return -Math.PI / 2;
            return 0;
        }
    }

// the per-frame world tick. no occlusion, no reveal ease and, in this phase, no lamps to pool —
// what is left is the vision sweep and the chunk cull
  public function tick(opts:Area3DTickOpts):Void
    {
      if (opts.outro)
        return;
      // off the SMOOTHED position and not opts.playerCol/Row — see VisionMask's own note on why
      // the logical cell is the wrong origin
      VisionMask.update(game, opts.player.x, opts.player.z);
      lampLights.update([], opts.playerCol, opts.playerRow, opts.dtMs);
      chunks.cull(opts.camera, opts.player, RenderConfig.MOON_SHADOW.halfExtent);
    }

  public function setTactical(v:Bool):Void
    {
      tactical = v;
    }

  public function bloomThreshold():Float
    {
      return CorpStyle.BLOOM_THRESHOLD;
    }

// the compound's preset: a corp floor is the same kind of thing to look at — interior rooms seen
// over a wall head, not a street and not a tunnel
  public function cameraOffsets():RenderConfig.CameraOffsets
    {
      return RenderConfig.CAMERA_FACILITY;
    }

// nothing lies on a maintained corporate floor
  public function debris():Array<render.world.Debris.DebrisSpot>
    {
      return [];
    }

  public function setLampLights(l:LampLights):Void
    {
      lampLights = l;
    }

// no citygen City here yet — the street below arrives in the last phase of the port
  public function city():citygen.CityModel.City
    {
      return null;
    }

  public function shadowLamps():Array<LampPost>
    return [];

  public function flyLamps():Array<LampPost>
    return [];

// the leaves and the glb props are both placed ONCE at build off the live object list, so an object
// added to or removed from the area leaves them stale. rebuilt whole rather than patched, on the
// compound's own reasoning: the geometry is shared and cached, and this fires on an object edit
  public function refreshObjects():Void
    {
      if (doors == null)
        return;
      FacilityDoors.dispose(built, doors);
      model.doors = CorpModel.fromArea(game.area).doors;
      doors = FacilityDoors.build(built, model, game.area);
      render.world.ObjModels.dispose(built, props);
      props = render.world.ObjModels.build(built, game, objYaw, objLift);
    }
}
