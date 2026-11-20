package render.library;

import three.Three;
import citygen.CityConfig;
import game.Game;
import render.Area3D;
import render.Area3DTickOpts;
import render.Models;
import render.RenderConfig;
import render.SceneSetup;
import render.SoundSources;
import render.Warmup;
import render.particles.LampLights;
import render.particles.LampPost;
import render.facility.FacilityDetail;
import render.facility.FacilityGeom;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.facility.FacilityStyle;
import render.world.ContactMask;
import render.world.VisionMask;
import render.world.WorldCtx;

// the university library area kind (AREA_LIBRARY): its reading floor, one plate in a void, left by
// the stairs (gen.library). A SHELL KIND like the lab: render.facility's emitters off LibraryStyle's
// ShellTex, no deck and no parapet (a lid would hide the floor), no moon (it is indoors at night) —
// only its own warm pendants. The furniture is seven hand-modelled glbs, one instanced batch each,
// placed off the furniture tiles (models-src/library/library_build.py)
class LibraryArea implements Area3D
{
  static inline var CELL = CityConfig.CELL;
  // the room-side margin of a wall cell a piece backed onto masonry stands in (the slab is WALL_T)
  static inline var MARGIN = (CityConfig.CELL - FacilityStyle.WALL_T) / 2;
  // the beds: everywhere but the archive, and the archive
  static var BEDS = [ 'library/hall', 'library/archive' ];

  var game:Game;
  var model:Facility;
  var chunks = new render.Chunks();
  var lampLights:LampLights;
  var propLights:render.particles.PropLights;
  var posts:Array<LampPost> = [];
  var props:Array<render.world.ObjModels.PropBatch>;
  var furniture:Array<InstancedProp> = [];
  var bed:Array<Float> = [ 0.0, 0.0 ];
  var built:Scene;
  var tactical = false;

  public function new(game:Game, model:Facility)
    {
      this.game = game;
      this.model = model;
    }

// the rig: no sky, no moon, warm fill, the live spotlight pool and the glowing props' point lights.
// The light counts match every other kind's (LabScene's note), so the shared materials' programs
// are reused
  public function scene(renderer:WebGLRenderer, lampPool:Int):SceneSetup.SceneBundle
    {
      var bundle = rig(renderer, lampPool);
      lampLights = bundle.lampLights;
      propLights = bundle.propLights;
      return bundle;
    }

  static function rig(renderer:WebGLRenderer, lampPool:Int):SceneSetup.SceneBundle
    {
      var scene = new Scene();
      scene.background = new Color(LibraryStyle.DARK);
      scene.fog = new Fog(LibraryStyle.DARK, LibraryStyle.FOG_NEAR, LibraryStyle.FOG_FAR);
      var lights:Array<Object3D> = [];
      var ambient = new AmbientLight(LibraryStyle.AMBIENT, LibraryStyle.AMBIENT_I);
      var hemi = new HemisphereLight(LibraryStyle.HEMI_SKY, LibraryStyle.HEMI_GROUND,
        LibraryStyle.HEMI_I);
      for (l in [ ambient, hemi ])
        {
          lights.push(l);
          scene.add(l);
        }
      var coneGroup = new Group();
      scene.add(coneGroup);
      var lampLights = new LampLights(scene, lampPool);
      var pts:Array<Object3D> = [];
      for (l in lampLights.debugList())
        {
          lights.push(l);
          pts.push(l);
        }
      pts.push(coneGroup);
      var propLights = new render.particles.PropLights(scene);
      for (l in propLights.debugList())
        {
          lights.push(l);
          pts.push(l);
        }
      var tail = SceneSetup.lightingTail(scene, renderer, lights);
      return {
        scene: scene,
        toggleLighting: tail.toggleLighting,
        setLightsOff: tail.setLightsOff,
        fill: [ ambient, hemi ],
        lights: lights,
        moon: null,
        pointLights: pts,
        coneGroup: coneGroup,
        lampLights: lampLights,
        lampPosts: [],
        lampCorners: new Map(),
        lampProp: null,
        lampPropDead: null,
        coneFlick: null,
        lampMask: [],
        lampMaskDead: [],
        wallGlow: null,
        propLights: propLights,
      };
    }

// the shell, the furniture, the stairs and the pickups, the lamps and the beds
  public function build(scene:Scene):Void
    {
      WorldCtx.tiles = null;
      WorldCtx.ground = null;
      WorldCtx.climbArc = null;
      WorldCtx.wallMounts = function(col, row) return FacilityGeom.wallMounts(model, col, row);
      WorldCtx.wallFace = function(col, row, dir) return FacilityGeom.wallFace(model, col, row, dir);
      WorldCtx.standOff = null;
      WorldCtx.buildings = [];
      WorldCtx.seed = -1;
      // the contact field before the builders: a floor material reads it when it is created
      var masonry = FacilityDetail.masonry(model);
      ContactMask.attach(FacilityStyle.CONTACT, model.w, model.h, masonry.solid, masonry.holes);
      var pre = scene.children.copy();
      built = scene;
      FacilityGeom.build(scene, model);
      FacilityDetail.corners(scene, model);
      var area = game.area;
      var places = plan(model, function(col, row)
        {
          return (col < 0 || row < 0 || col >= model.w || row >= model.h ? -1 :
            area.getCellType(col, row));
        });
      FacilityDetail.halos(scene, model);
      ContactMask.repaint();
      props = render.world.ObjModels.build(scene, game, objYaw, objLift, objWall);
      chunks.build(scene, pre);
      // the batches AFTER the chunks: an instanced batch sits at the origin and a cached glb would be
      // bucketed into the chunk there and culled with it
      for (p in places)
        furniture.push(batch(scene, p.path, p.places, p.h));
      posts = lamps(model);
      SoundSources.beds = BEDS.copy();
      SoundSources.events = [];
      VisionMask.attach(FacilityStyle.MASK, model.w, model.h,
        function(col, row) return !FacilityModel.isIndoor(model, col, row),
        function(col, row) return FacilityGeom.carries(model, col, row));
    }

// every furniture placement, one list per glb, and the contact shadow of each run laid as it goes
  static function plan(m:Facility, tile:Int->Int->Int):Array<{ path:String, h:Float,
      places:Array<PropPlace> }>
    {
      var M = RenderConfig.MODELS;
      var out = [
        { path: M.libraryBookcase, h: LibraryStyle.CASE_H, places: [] },
        { path: M.libraryStack, h: LibraryStyle.CASE_H, places: [] },
        { path: M.libraryTable, h: LibraryStyle.TABLE_H, places: [] },
        { path: M.libraryChair, h: LibraryStyle.CHAIR_H, places: [] },
        { path: M.libraryCounter, h: LibraryStyle.COUNTER_H, places: [] },
        { path: M.libraryLectern, h: LibraryStyle.LECTERN_H, places: [] },
        { path: M.libraryCatalogue, h: LibraryStyle.CATALOGUE_H, places: [] },
      ];
      var wall = function(col, row) return tile(col, row) == Const.TILE_LIB_WALL;
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            var t = tile(col, row);
            var c = CityConfig.cellToWorld(col, row);
            if (t == Const.TILE_LIB_BOOKCASE)
              {
                // backed onto the wall to its north, else west, else east, in that wall's margin
                var back = (CELL / 2 + MARGIN) - LibraryStyle.CASE_D / 2;
                if (wall(col, row - 1))
                  put(out[0].places, c.x, c.z - back, 0);
                else if (wall(col - 1, row))
                  put(out[0].places, c.x - back, c.z, Math.PI / 2);
                else
                  put(out[0].places, c.x + back, c.z, -Math.PI / 2);
                ground(m, col, row, LibraryStyle.CASE_H);
              }
            else if (t == Const.TILE_LIB_STACK)
              {
                // a rank runs north-south, its books facing east and west
                put(out[1].places, c.x, c.z, Math.PI / 2);
                if (tile(col, row - 1) != Const.TILE_LIB_STACK)
                  {
                    var len = 1;
                    while (tile(col, row + len) == Const.TILE_LIB_STACK)
                      len++;
                    FacilityDetail.ground(m, {
                      col: col,
                      row: row,
                      len: len,
                      alongX: false,
                      rect: {
                        x0: c.x - LibraryStyle.STACK_D / 2,
                        x1: c.x + LibraryStyle.STACK_D / 2,
                        z0: c.z - CELL / 2,
                        z1: c.z - CELL / 2 + len * CELL,
                      },
                      h: LibraryStyle.CASE_H,
                    });
                  }
              }
            else if (t == Const.TILE_LIB_TABLE &&
                tile(col - 1, row) != Const.TILE_LIB_TABLE &&
                tile(col, row - 1) != Const.TILE_LIB_TABLE)
              {
                // the 4x2 block, from its north-west cell
                put(out[2].places, c.x + 1.5 * CELL, c.z + 0.5 * CELL, 0);
                block(m, col, row, 4, 2, LibraryStyle.TABLE_H);
              }
            else if (t == Const.TILE_LIB_CHAIR)
              // facing the table it is drawn up to
              put(out[3].places, c.x, c.z,
                (tile(col, row + 1) == Const.TILE_LIB_TABLE ? 0 : Math.PI));
            else if (t == Const.TILE_LIB_COUNTER &&
                tile(col - 1, row) != Const.TILE_LIB_COUNTER)
              {
                put(out[4].places, c.x + 1.5 * CELL, c.z, 0);
                block(m, col, row, 4, 1, LibraryStyle.COUNTER_H);
              }
            else if (t == Const.TILE_LIB_LECTERN)
              {
                put(out[5].places, c.x, c.z, 0);
                block(m, col, row, 1, 1, LibraryStyle.LECTERN_H);
              }
            else if (t == Const.TILE_LIB_CATALOGUE)
              {
                // against a side wall, or one of a back-to-back island's two rows
                var back = (CELL - LibraryStyle.CATALOGUE_D) / 2;
                if (wall(col - 1, row))
                  put(out[6].places, c.x - back - MARGIN, c.z, Math.PI / 2);
                else if (wall(col + 1, row))
                  put(out[6].places, c.x + back + MARGIN, c.z, -Math.PI / 2);
                else if (tile(col, row + 1) == Const.TILE_LIB_CATALOGUE)
                  put(out[6].places, c.x, c.z + back, Math.PI);
                else
                  put(out[6].places, c.x, c.z - back, 0);
                block(m, col, row, 1, 1, LibraryStyle.CATALOGUE_H);
              }
          }
      return out;
    }

  static function put(list:Array<PropPlace>, x:Float, z:Float, yaw:Float):Void
    {
      list.push({
        x: x,
        z: z,
        yaw: yaw,
      });
    }

// the contact shadow of a piece filling a block of cells
  static function block(m:Facility, col:Int, row:Int, w:Int, h:Int, height:Float):Void
    {
      var c = CityConfig.cellToWorld(col, row);
      FacilityDetail.ground(m, {
        col: col,
        row: row,
        len: (w > h ? w : h),
        alongX: (w >= h),
        rect: {
          x0: c.x - CELL / 2 + 0.2,
          x1: c.x - CELL / 2 + w * CELL - 0.2,
          z0: c.z - CELL / 2 + 0.2,
          z1: c.z - CELL / 2 + h * CELL - 0.2,
        },
        h: height,
      });
    }

// a bookcase's contact shadow: one cell, against its wall (the halo goes on the wall it backs onto)
  static function ground(m:Facility, col:Int, row:Int, h:Float):Void
    {
      block(m, col, row, 1, 1, h);
    }

// one batch, its pieces casting under the pendants and shaded by the vision sweep
  static function batch(scene:Scene, path:String, places:Array<PropPlace>, h:Float):InstancedProp
    {
      var prop = Models.instanced(scene, path, places, h, SOLID);
      Models.get(path, function(_)
        {
          if (prop.mesh == null)
            return;
          VisionMask.patchMesh(prop.mesh);
          prop.mesh.castShadow = true;
        });
      return prop;
    }

// the pendants: a lattice over every room, sparser and dimmer in the archive, and along the corridor
  static function lamps(m:Facility):Array<LampPost>
    {
      var out:Array<LampPost> = [];
      for (r in m.rooms)
        {
          var archive = (LibraryStyle.roleSurf(r.role) == Surf.LIB_ARCHIVE);
          var nx = Std.int(Math.max(1, Math.round(r.w / LibraryStyle.LAMP_SPACING)));
          var ny = Std.int(Math.max(1, Math.round(r.h / LibraryStyle.LAMP_SPACING)));
          for (i in 0...nx)
            for (j in 0...ny)
              out.push(post(r.x1 + Std.int((i + 0.5) * r.w / nx), r.y1 + Std.int((j + 0.5) * r.h / ny),
                (archive ? LibraryStyle.LAMP_ARCHIVE : LibraryStyle.LAMP_COLOR),
                (archive ? LibraryStyle.LAMP_ARCHIVE_MUL : LibraryStyle.LAMP_MUL)));
        }
      for (row in 0...m.h)
        for (col in 0...m.w)
          if (m.surf[row][col] == Surf.CARPET &&
              col % LibraryStyle.LAMP_SPACING == 0 &&
              (m.surf[row - 1][col] != Surf.CARPET))
            out.push(post(col, row, LibraryStyle.LAMP_COLOR, LibraryStyle.LAMP_MUL));
      return out;
    }

// one pendant, jittered off its cell centre and in strength by the cell hash
  static function post(col:Int, row:Int, color:Int, mul:Float):LampPost
    {
      var h = FacilityModel.mix((col * 49979687) ^ (row * 86028121));
      var c = CityConfig.cellToWorld(col, row);
      var x = c.x + (((h >>> 13) % 21) - 10) * LibraryStyle.LAMP_JITTER / 10;
      var z = c.z + (((h >>> 18) % 21) - 10) * LibraryStyle.LAMP_JITTER / 10;
      return {
        x: x,
        z: z,
        y: LibraryStyle.LAMP_Y,
        tx: x,
        tz: z,
        color: color,
        col: col,
        row: row,
        phase: 0.0,
        flick: 1.0,
        mul: mul * (1 - LibraryStyle.LAMP_MUL_VAR * ((h >>> 23) % 11) / 10),
        noCast: false,
      };
    }

// an object on the lectern (the Necronomicon) lies on its board, everything else on the floor
  function objLift(col:Int, row:Int):Float
    {
      return (game.area.getCellType(col, row) == Const.TILE_LIB_LECTERN ? LibraryStyle.BOOK_Y : 0.0);
    }

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
            // the stairs, one cell off their end wall over the sealed well: CorpArea.objYaw's test
            var dirs = [ [ 0, -1, 0.0 ], [ 0, 1, Math.PI ], [ -1, 0, Math.PI / 2 ],
              [ 1, 0, -Math.PI / 2 ] ];
            for (d in dirs)
              {
                var dx = Std.int(d[0]);
                var dy = Std.int(d[1]);
                if (hole(col + dx, row + dy) &&
                    hole(col + dx - dy, row + dy + dx) &&
                    FacilityModel.isWall(model, col + 2 * dx, row + 2 * dy))
                  return d[2];
              }
            return 0;
        }
    }

// whether a cell is the stairs' well
  function hole(col:Int, row:Int):Bool
    {
      return FacilityModel.inside(model, col, row) &&
        model.fit[row][col] == FacilityModel.FIT_HOLE;
    }

// per frame: the vision sweep, the lamp pools, the beds and the culls
  public function tick(opts:Area3DTickOpts):Void
    {
      if (opts.outro)
        return;
      VisionMask.update(game, opts.player.x, opts.player.z);
      lampLights.update(posts, opts.lightCol, opts.lightRow, opts.dtMs);
      propLights.update(game, opts.lightCol, opts.lightRow, opts.dtMs);
      // the beds crossfaded over four BASE_MS by the room the player stands in
      var room = game.area.generatorInfo.getRoomAt(opts.playerCol, opts.playerRow);
      var on = (room != null && room.role == gen.library.LibraryGen.ROLE_ARCHIVE ? 1 : 0);
      var kb = Math.min(1, opts.dtMs / (RenderConfig.BASE_MS * 4));
      for (i in 0...BEDS.length)
        {
          bed[i] += ((i == on ? 1.0 : 0.0) - bed[i]) * kb;
          game.scene.sounds.updateLoop(BEDS[i], bed[i], game.config.ambientVolume);
        }
      for (f in furniture)
        Models.cull(f, opts.camera, LibraryStyle.PIECE_CULL_R);
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

// the object props are placed once at build off the live object list: rebuilt whole when it changes
// (the Necronomicon taken off its lectern)
  public function refreshObjects():Void
    {
      if (props == null)
        return;
      render.world.ObjModels.dispose(built, props);
      props = render.world.ObjModels.build(built, game, objYaw, objLift, objWall);
    }

// the warm scene: build's pass list over LibraryStyle.demo, under this kind's own rig, with one of
// every furniture glb. It rots the moment build grows a pass this does not (every *Warm's warning).
// Run once per session, from render.View.warmKind on the first library entry
  public static function warm(renderer:WebGLRenderer, camera:PerspectiveCamera, lampPool:Int):Dynamic
    {
      var model = LibraryStyle.demo();
      var masonry = FacilityDetail.masonry(model);
      ContactMask.attach(FacilityStyle.CONTACT, model.w, model.h, masonry.solid, masonry.holes);
      var bundle = rig(renderer, lampPool);
      var sc = bundle.scene;
      FacilityGeom.build(sc, model);
      FacilityDetail.corners(sc, model);
      FacilityDetail.halos(sc, model);
      var M = RenderConfig.MODELS;
      var rows = [
        { path: M.libraryBookcase, h: LibraryStyle.CASE_H },
        { path: M.libraryStack, h: LibraryStyle.CASE_H },
        { path: M.libraryTable, h: LibraryStyle.TABLE_H },
        { path: M.libraryChair, h: LibraryStyle.CHAIR_H },
        { path: M.libraryCounter, h: LibraryStyle.COUNTER_H },
        { path: M.libraryLectern, h: LibraryStyle.LECTERN_H },
        { path: M.libraryCatalogue, h: LibraryStyle.CATALOGUE_H },
      ];
      for (r in rows)
        batch(sc, r.path, [{
          x: 0.0,
          z: 0.0,
          yaw: 0.0,
        }], r.h);
      var fx = new Group();
      sc.add(fx);
      Warmup.actorLayer(fx, camera);
      ContactMask.detach();
      return new js.lib.Promise(function(res, _)
        {
          var left = rows.length;
          for (r in rows)
            Models.get(r.path, function(_)
              {
                left--;
                if (left == 0)
                  res(null);
              });
        }).then(function(_)
          {
            sc.traverse(function(o:Object3D)
              {
                if (untyped o.isInstancedMesh)
                  o.castShadow = true;
              });
            var l:SpotLight = cast bundle.lampLights.debugList()[0];
            l.position.set(0, 10, 0);
            l.target.position.set(0, 0, 1);
            untyped l.shadow.needsUpdate = true;
            return Warmup.compile(renderer, camera, sc);
          });
    }
}
