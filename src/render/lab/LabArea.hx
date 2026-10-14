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
      posts = [];
      vats = LabVats.build(scene, game, drain, posts);
      lift = LabLift.build(scene, model);
      furniture = LabInterior.build(scene, interior);
      // the flat cut-outs after the chunks too: a sheet with few quads would be bucketed by its origin
      decals = LabDecals.build(scene, model, tile, interior.lids);
      // the compound's sockets, leads and floor units, the one family the lab borrows: LabModel marks
      // every furniture and machine cell taken, so nothing lands behind or under a piece
      elec = render.facility.FacilityCable.build(scene, model, render.world.MeshBuf.MeshBufTools.make());
      // a blocker is masonry or rock: anything that is not floor. `carries` is what slab() insets
      // against, so the reveal pulls back off exactly the floor the masonry left open
      VisionMask.attach(FacilityStyle.MASK, model.w, model.h,
        function(col, row) return !FacilityModel.isIndoor(model, col, row),
        function(col, row) return FacilityGeom.carries(model, col, row));
      attachDbg();
    }

// console debug helper (permanent) — what this lab actually built.
//   __lab() -> { structures, rooms, surfs, doors, lift, vats, furniture, rock, decals, elec,
//     objProps, shadows }
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
            elec: {
              mounts: elec.mounts.length,
              runs: elec.runs,
              units: elec.units,
              scatter: elec.scatter,
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
      lampLights.update(posts, opts.playerCol, opts.playerRow, opts.dtMs);
      propLights.update(game, opts.playerCol, opts.playerRow, opts.dtMs);
      LabDoors.tick(doors, opts);
      LabVats.tick(vats, opts);
      for (f in furniture)
        render.Models.cull(f, opts.camera, LabStyle.PIECE_CULL_R);
      LabLift.tick(lift, opts, game.ui.state != UISTATE_DEFAULT);
      chunks.cull(opts.camera, opts.player, RenderConfig.MOON_SHADOW.halfExtent);
      render.world.ObjModels.cull(props, opts, tactical && opts.ui);
      render.world.PropShader.tick(opts.dtMs);
      render.world.PropGlow.tick(opts.dtMs);
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

  public function shadowLamps():Array<LampPost>
    return [];

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
      vats = LabVats.build(built, game, drain, posts);
    }

// does this area draw this object as real geometry, so the actor layer must not also lay its 2D
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
