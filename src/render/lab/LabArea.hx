package render.lab;

import three.Three;
import game.Game;
import render.Area3D;
import render.Area3DTickOpts;
import render.RenderConfig;
import render.SceneSetup;
import render.particles.LampLights;
import render.particles.LampPost;
import render.facility.FacilityDetail;
import render.facility.FacilityGeom;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityStyle;
import render.world.ContactMask;
import render.world.VisionMask;
import render.world.WorldCtx;

// the underground lab area kind (AREA_UNDERGROUND_LAB): one level of rooms off a corridor, cut into
// bedrock and reached by a lift from above. like the corp tower it is a SHELL KIND — it drives
// render.facility's emitters off a ShellTex naming lab art (LabStyle.shell) — and like the tunnels
// it is lit by nothing but its own lamps: no moon, no sky, no roof (the bedrock is the ceiling).
//
// what differs from a compound, and why:
//   - NO DECK AND NO PARAPET (ShellOpts.deck / parapet). a lid would hide the level, and a parapet
//     would stand up out of the rock
//   - THE ROCK CAP (LabGeom) over everything that is not a room, at the wall head
//   - TWO-CELL DOORWAYS with sliding leaves (LabDoors), not the compound's swinging pairs
//   - NO INDOOR MASK. it swaps the moon's term out indoors, and there is no moon
class LabArea implements Area3D
{
  var game:Game;
  var model:Facility;
  var chunks = new render.Chunks();
  var lampLights:LampLights;
  var propLights:render.particles.PropLights;
  var posts:Array<LampPost> = [];
  var doors:Array<LabDoors.LabDoorBatch>;
  var rock = 0;                               // the bedrock cap's quad count, for __lab()
  var props:Array<render.world.ObjModels.PropBatch>;
  var vats:LabVats.LabVatSet;
  var lift:LabLift.LabLiftSet;
  var furniture:Array<render.Models.InstancedProp>;
  var decals:{ grime:Int, marks:Int, tops:Int };
  var elec:render.facility.FacilityCable.ElecCounts;
  var lamps:LabLamps.LabLampSet;
  var wall:LabWall.LabWallSet;
  var flames:LabFlames.LabFlameSet;
  var tanks:Array<LampPost> = [];            // the lit tanks' floor lamps, dimmed as the lab dies
  var tankMul:Array<Float> = [];             // and each one's own strength (LabStyle.TANK_GLOW)
  var spill:Mesh;                            // the fake tank glows on the floor, or null
  var fakes:Array<LampPost> = [];            // and their lights, for the actors' fake shadows
  var spin:LabSpin.LabSpinSet;               // the turning beacon and the workshop fan
  // the mission, taken at build: the area hands back null once it is completed, and the alarm it
  // raised keeps sounding past that (LabLamps)
  var mission:cult.missions.CombatUndergroundLabPurge;
  var sounds:LabSounds;
  // each vat's eased drain, keyed on its root object. the AREA's and not the batch's, so a rebuild of
  // the batches (refreshObjects) carries a drain on from where it was (LabVats)
  var drain = new Map<Int,Float>();
  var built:Scene;
  var tactical = false;

  public function new(game:Game, model:Facility)
    {
      this.game = game;
      this.model = model;
    }

// the tunnels' rig in the lab's own colours — see LabScene
  public function scene(renderer:WebGLRenderer, lampPool:Int):SceneSetup.SceneBundle
    {
      var bundle = LabScene.build(renderer, lampPool);
      lampLights = bundle.lampLights;
      propLights = bundle.propLights;
      return bundle;
    }

// the shell, the rock it is cut into, its doors and its object props
  public function build(scene:Scene):Void
    {
      // the hooks a shell kind shares with the compound; climbArc and the rest CLEARED, since the kind
      // that sets one owns clearing it (WorldCtx)
      WorldCtx.tiles = null;
      // the lift's car, which comes down the shaft on arrival with whoever is standing on it
      WorldCtx.ground = function(x, z) return LabLift.ground(lift, x, z);
      WorldCtx.climbArc = null;
      WorldCtx.wallMounts = function(col, row) return FacilityGeom.wallMounts(model, col, row);
      WorldCtx.wallFace = function(col, row, dir) return FacilityGeom.wallFace(model, col, row, dir);
      WorldCtx.standOff = null;
      WorldCtx.buildings = [];
      WorldCtx.seed = -1;
      // the contact field before the builders, for the reason CorpArea.build gives: a floor material
      // reads `on` when it is created
      var masonry = FacilityDetail.masonry(model);
      ContactMask.attach(FacilityStyle.CONTACT, model.w, model.h, masonry.solid, masonry.holes);
      var pre = scene.children.copy();
      built = scene;
      FacilityGeom.build(scene, model);
      rock = LabGeom.build(scene, model);
      FacilityDetail.corners(scene, model);
      // the furniture and the box machines: placed now, so their contact shadows are in the field
      // before it is painted; their batches come after the chunks (LabInterior)
      var area = game.area;
      var tile = function(col, row)
        {
          return (col < 0 || row < 0 || col >= model.w || row >= model.h ? -1 : area.getCellType(col, row));
        };
      var interior = LabInterior.plan(model, tile);
      // the collector every pass that stands something against a wall fills; draining it is what
      // CLEARS it, so a kind that never calls it hands its list to whichever area drains next
      FacilityDetail.halos(scene, model);
      ContactMask.repaint();
      doors = LabDoors.build(scene, model, game.area);
      props = render.world.ObjModels.build(scene, game, objYaw, objLift, objWall);
      chunks.build(scene, pre);
      // the vats and the lift AFTER the chunks: an instanced batch sits at the origin, and a glb
      // already cached would be bucketed into the chunk there and culled with it
      lift = LabLift.build(scene, model);
      lamps = LabLamps.build(model);
      posts = lamps.all.copy();
      vats = LabVats.build(scene, game, model, drain, posts);
      tanks = interior.glows;
      tankMul = [for (t in tanks) t.mul];
      for (t in tanks)
        posts.push(t);
      mission = Std.downcast(game.area.getAreaMission(), cult.missions.CombatUndergroundLabPurge);
      sounds = new LabSounds(game, model, vats, lamps, lift);
      furniture = LabInterior.build(scene, interior);
      spill = LabInterior.spill(scene, interior);
      LabInterior.halos(scene, interior);
      fakes = interior.fakes;
      spin = LabSpin.build(scene, model, lift, posts);
      flames = LabFlames.build(scene, interior.flames);
      // the flat cut-outs after the chunks too: a sheet with few quads would be bucketed by its origin
      decals = LabDecals.build(scene, model, tile, interior.lids, interior.frosts);
      // the compound's sockets, leads and floor units, the one family the lab borrows: LabModel marks
      // every furniture and machine cell taken, so nothing lands behind or under a piece
      elec = render.facility.FacilityCable.build(scene, model, render.world.MeshBuf.MeshBufTools.make());
      wall = LabWall.build(scene, model, tile);
      // a blocker is masonry or rock: anything that is not floor. `carries` is what slab() insets
      // against, so the reveal pulls back off exactly the floor the masonry left open
      VisionMask.attach(FacilityStyle.MASK, model.w, model.h,
        function(col, row) return !FacilityModel.isIndoor(model, col, row),
        function(col, row) return FacilityGeom.carries(model, col, row));
      attachDbg();
    }

// console debug helper (permanent) — what this lab actually built.
//   __lab() -> { structures, rooms, surfs, doors, lift, vats, furniture, rock, decals, lamps, elec,
//     wall, objProps, shadows }
//
// the same reasoning as __corp(): the door leaves and the object props are instanced batches with
// no userData.cls, parasiteHx is statics-only so the Facility record is unreachable from JS, and
// every question this kind raises — did the plate come back as ONE structure, which leaf did a
// doorway take, is a room's floor the one its role says — has a numeric answer a screenshot cannot
// give. Later phases add the lift, the vats, the lamps and the mission state to it
  function attachDbg():Void
    {
      untyped js.Browser.window.__lab = function()
        {
          var surfs = new Map<Int,Int>();
          for (row in 0...model.h)
            for (col in 0...model.w)
              {
                var s = (model.surf[row][col] : Int);
                surfs.set(s, (surfs.exists(s) ? surfs.get(s) : 0) + 1);
              }
          var leaves = [];
          for (b in doors)
            for (c in 0...b.open.length)
              leaves.push({
                tex: b.prop.mesh.name,
                col: b.cells[c].col,
                row: b.cells[c].row,
                alongX: b.cells[c].alongX,
                live: (b.doors[c] != null),
                isOpen: (b.doors[c] != null && b.doors[c].isOpen),
                t: b.open[c],
              });
          return {
            // exactly ONE: the lobby, the corridor and every room are one flood through the doorways
            structures: [for (st in model.structures) {
              x1: st.x1,
              y1: st.y1,
              x2: st.x2,
              y2: st.y2,
              cells: st.cells,
            }],
            rooms: model.rooms,
            surfs: [for (k in surfs.keys()) { surf: k, cells: surfs.get(k) }],
            doors: leaves,
            lift: {
              col: lift.col,
              row: lift.row,
              t: lift.t,
              y: lift.y,
            },
            vats: LabVats.dbg(vats),
            furniture: [for (f in furniture) {
              path: (f.mesh != null ? f.mesh.name : null),
              count: f.matrices.length,
            }],
            rock: rock,
            decals: decals,
            lamps: {
              rooms: lamps.rooms.length,
              corridor: lamps.corridor.length,
              alarm: lamps.alarm,
              dead: lamps.dead,
            },
            elec: {
              mounts: elec.mounts.length,
              runs: elec.runs,
              units: elec.units,
              scatter: elec.scatter,
            },
            wall: {
              signs: wall.signs,
              fittings: wall.fittings,
              screens: wall.screens,
              lamps: wall.lamps,
              alarm: (wall.alarm != null && wall.alarm.visible),
            },
            objProps: [for (b in props) {
              path: b.model.path,
              count: b.solid.matrices.length,
            }],
            shadows: ContactMask.count,
          };
        }
    }

// nothing stands on anything but the floor yet
  function objLift(col:Int, row:Int):Float
    {
      return 0.0;
    }

// how much nearer the cell a wall prop's masonry stands than its row's `off` assumes: none, every
// lab wall is WALL_T
  function objWall(col:Int, row:Int):Float
    {
      return 0.0;
    }

// which way an object prop faces from its cell: the compound's three branches
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

// the per-frame tick: the vision sweep, the lamp pools, the doors and the culls
  public function tick(opts:Area3DTickOpts):Void
    {
      if (opts.outro)
        return;
      VisionMask.update(game, opts.player.x, opts.player.z);
      lampLights.update(posts, opts.lightCol, opts.lightRow, opts.dtMs);
      propLights.update(game, opts.lightCol, opts.lightRow, opts.dtMs);
      LabDoors.tick(doors, opts);
      LabVats.tick(vats, opts);
      var alarmed = (mission != null && mission.leadTriggerDone);
      var dead = dead();
      LabLamps.tick(lamps, opts, alarmed, dead);
      LabSpin.tick(spin, opts, alarmed, lamps.dead);
      LabInterior.dim(furniture, 1 - lamps.dead * LabStyle.DEAD_EMISSIVE);
      if (spill != null)
        untyped spill.material.color.setScalar(LabStyle.TANK_SPILL_GLOW *
          (1 - lamps.dead * LabStyle.DEAD_EMISSIVE));
      LabWall.tick(wall, alarmed, 1 - lamps.dead * LabStyle.DEAD_EMISSIVE);
      LabFlames.tick(flames, opts.dtMs);
      LabWater.tick(opts.dtMs, 1 - lamps.dead * LabStyle.DEAD_EMISSIVE);
      LabBlink.tick(opts.dtMs);
      for (i in 0...tanks.length)
        tanks[i].mul = tankMul[i] * (1 - lamps.dead * LabStyle.DEAD_EMISSIVE);
      // the kit's status lights blink on the compound's LED clock (LabInterior.leds)
      render.facility.FacilityDeco.tick(opts.dtMs);
      sounds.tick(opts.playerCol, opts.playerRow, opts.dtMs, lift, alarmed, dead);
      for (f in furniture)
        render.Models.cull(f, opts.camera, LabStyle.PIECE_CULL_R);
      LabLift.tick(lift, opts, game.ui.state != UISTATE_DEFAULT);
      chunks.cull(opts.camera, opts.player, RenderConfig.MOON_SHADOW.halfExtent);
      render.world.ObjModels.cull(props, opts, tactical && opts.ui);
      render.world.PropShader.tick(opts.dtMs);
      render.world.PropGlow.tick(opts.dtMs);
    }

// the lift carries the player up the shaft and `leave` leaves the area once it is at the top
// (objects.Elevator, through render.View.liftDepart); false on a plate with no lift or before its car
// has landed in the scene, and the leave goes straight through
  public function depart(leave:Void->Void):Bool
    {
      if (lift.col < 0 ||
          lift.deck.mesh == null)
        return false;
      LabLift.depart(lift, leave);
      return true;
    }

// is the lift carrying the player out? the game takes no input meanwhile (render.View.departing)
  public function departing():Bool
    {
      return (lift.up != null);
    }

  public function setTactical(v:Bool):Void
    {
      tactical = v;
    }

  public function bloomThreshold():Float
    {
      return FacilityStyle.BLOOM_THRESHOLD;
    }

// the compound's preset: rooms seen over a wall head, the same thing to look at
  public function cameraOffsets():RenderConfig.CameraOffsets
    {
      return RenderConfig.CAMERA_FACILITY;
    }

  public function debris():Array<render.world.Debris.DebrisSpot>
    {
      return [];
    }

  public function setLampLights(l:LampLights):Void
    {
      lampLights = l;
    }

  public function city():citygen.CityModel.City
    {
      return null;
    }

// the fake tank glows' lights: the actors throw fake shadows off them, and no pool slot is behind them
  public function shadowLamps():Array<LampPost>
    return fakes;

  public function flyLamps():Array<LampPost>
    return [];

// the leaves and the object props are placed ONCE at build off the live object list, so an object
// added or removed (the mission's vats) leaves them stale: rebuilt whole, on the compound's reasoning
  public function refreshObjects():Void
    {
      if (doors == null)
        return;
      LabDoors.dispose(doors);
      doors = LabDoors.build(built, model, game.area);
      render.world.ObjModels.dispose(built, props);
      props = render.world.ObjModels.build(built, game, objYaw, objLift, objWall);
      LabVats.dispose(vats);
      for (p in vats.posts)
        posts.remove(p);
      vats = LabVats.build(built, game, model, drain, posts);
      sounds.setVats(vats);
    }

// does this area draw this object as real geometry, so the actor layer must not also lay its 2D
// is every vat purged? the lab's power went with them. false before the mission has stood any
  function dead():Bool
    {
      if (vats.roots.length == 0)
        return false;
      for (v in vats.roots)
        if (!v.isFlushed)
          return false;
      return true;
    }

// icon? the lab's door leaves (LabDoors), its lift (LabLift) and the mission's vats (LabVats)
  public static function draws(area:game.AreaGame, o:objects.AreaObject):Bool
    {
      return area != null &&
        area.typeID == AREA_UNDERGROUND_LAB &&
        (o.type == 'door' ||
         o.type == 'elevator' ||
         o.type == 'clone_vat');
    }
}
