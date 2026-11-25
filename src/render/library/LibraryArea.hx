package render.library;

import three.Three;
import citygen.CityConfig;
import game.Game;
import render.Area3D;
import render.Area3DTickOpts;
import render.Models;
import render.RenderConfig;
import render.SceneSetup;
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
// placed off the furniture tiles (models-src/library/library_build.py); the books on its shelves are
// render.library.LibraryBooks' quads, and its decor slots (lamps, book stacks, baskets, what lies on
// the tables, the pictures and posters) are LibraryDecor's and LibraryWall's, off the cell hash
class LibraryArea implements Area3D
{
  static inline var CELL = CityConfig.CELL;
  // the room-side margin of a wall cell a piece backed onto masonry stands in (the slab is WALL_T)
  static inline var MARGIN = (CityConfig.CELL - FacilityStyle.WALL_T) / 2;

  var game:Game;
  var model:Facility;
  var chunks = new render.Chunks();
  var lampLights:LampLights;
  var propLights:render.particles.PropLights;
  var posts:Array<LampPost> = [];
  var props:Array<render.world.ObjModels.PropBatch>;
  var furniture:Array<InstancedProp> = [];
  var sounds:LibrarySounds;
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
      var tile = function(col, row)
        {
          return (col < 0 || row < 0 || col >= model.w || row >= model.h ? -1 :
            area.getCellType(col, row));
        };
      var places = plan(model, tile);
      // the decor slots before the repaint: the floor props lay their contact shadows as they go
      var decor = LibraryDecor.plan(scene, model, tile, places[0].places, places[1].places,
        places[6].places);
      FacilityDetail.halos(scene, model);
      ContactMask.repaint();
      props = render.world.ObjModels.build(scene, game, objYaw, objLift, objWall);
      chunks.build(scene, pre);
      // the batches AFTER the chunks: an instanced batch sits at the origin and a cached glb would be
      // bucketed into the chunk there and culled with it
      for (p in places)
        furniture.push(batch(scene, p.path, p.places, p.h));
      var M = RenderConfig.MODELS;
      furniture.push(batch(scene, M.libraryLamp, decor.lamps, LibraryStyle.LAMP_H));
      for (i in 0...M.libraryBooks.length)
        furniture.push(batch(scene, M.libraryBooks[i], decor.books[i], LibraryStyle.BOOK_T));
      furniture.push(batch(scene, M.libraryBasket, decor.baskets, LibraryStyle.BASKET_H));
      // the books on the shelves, and the pictures and posters on the walls and the rank ends
      LibraryBooks.build(scene, places[0].places, places[1].places);
      var wall = LibraryWall.build(scene, model, tile);
      posts = lamps(model, tile);
      sounds = new LibrarySounds(game, wall.clocks);
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
      // which wall a bookcase backs onto: north, else west, else east (0/1/2), -1 for no bookcase
      var backing = function(col, row)
        {
          if (tile(col, row) != Const.TILE_LIB_BOOKCASE)
            return -1;
          return (wall(col, row - 1) ? 0 : (wall(col - 1, row) ? 1 : 2));
        };
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            var t = tile(col, row);
            var c = CityConfig.cellToWorld(col, row);
            if (t == Const.TILE_LIB_BOOKCASE)
              {
                // backed onto the wall to its north, else west, else east, in that wall's margin
                var back = (CELL / 2 + MARGIN) - LibraryStyle.CASE_D / 2;
                var b = backing(col, row);
                if (b == 0)
                  put(out[0].places, c.x, c.z - back, 0);
                else if (b == 1)
                  put(out[0].places, c.x - back, c.z, Math.PI / 2);
                else
                  put(out[0].places, c.x + back, c.z, -Math.PI / 2);
                // the run's contact shadow from its first cell, over the cases' own footprint
                var dx = (b == 0 ? 1 : 0);
                var dy = 1 - dx;
                if (backing(col - dx, row - dy) != b)
                  {
                    var len = 1;
                    while (backing(col + dx * len, row + dy * len) == b)
                      len++;
                    var face = (b == 0 ? c.z : c.x) + (b == 2 ? 1 : -1) * (CELL / 2 + MARGIN);
                    var lo = (b == 2 ? face - LibraryStyle.CASE_D : face);
                    // the run's two end cases stop short of their cells' edges
                    var gap = (CELL - LibraryStyle.CASE_W) / 2;
                    var x0 = c.x - CELL / 2 + gap;
                    var z0 = c.z - CELL / 2 + gap;
                    FacilityDetail.ground(m, {
                      col: col,
                      row: row,
                      len: len,
                      alongX: (b == 0),
                      rect: (b == 0 ? {
                        x0: x0,
                        x1: x0 + len * CELL - 2 * gap,
                        z0: lo,
                        z1: lo + LibraryStyle.CASE_D,
                      } : {
                        x0: lo,
                        x1: lo + LibraryStyle.CASE_D,
                        z0: z0,
                        z1: z0 + len * CELL - 2 * gap,
                      }),
                      h: LibraryStyle.CASE_H,
                    });
                  }
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
              {
                // facing the table it is drawn up to, a little off square by the cell hash, on a pool
                var h = FacilityModel.mix((col * 73856093) ^ (row * 19349663));
                put(out[3].places, c.x, c.z,
                  (tile(col, row + 1) == Const.TILE_LIB_TABLE ? 0 : Math.PI) +
                  (((h >>> 1) % 2001) / 1000 - 1) * LibraryStyle.CHAIR_YAW);
                var hw = LibraryStyle.CHAIR_W / 2;
                FacilityDetail.ground(m, {
                  col: col,
                  row: row,
                  len: 1,
                  alongX: true,
                  rect: {
                    x0: c.x - hw,
                    x1: c.x + hw,
                    z0: c.z - hw,
                    z1: c.z + hw,
                  },
                  h: LibraryStyle.CHAIR_H,
                });
              }
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
                // against a side wall, or one of a back-to-back island's two rows, each pushed to
                // the front of its cell so the island has a passage down its middle
                var back = (CELL - LibraryStyle.CATALOGUE_D) / 2;
                var hw = LibraryStyle.CATALOGUE_W / 2;
                var hd = LibraryStyle.CATALOGUE_D / 2;
                var x = c.x;
                var z = c.z;
                if (wall(col - 1, row))
                  x -= back + MARGIN;
                else if (wall(col + 1, row))
                  x += back + MARGIN;
                else
                  z += (tile(col, row + 1) == Const.TILE_LIB_CATALOGUE ? -back : back);
                var side = (x != c.x);
                put(out[6].places, x, z, (side ? (x < c.x ? Math.PI / 2 : -Math.PI / 2) :
                  (z < c.z ? Math.PI : 0)));
                FacilityDetail.ground(m, {
                  col: col,
                  row: row,
                  len: 1,
                  alongX: true,
                  rect: {
                    x0: x - (side ? hd : hw),
                    x1: x + (side ? hd : hw),
                    z0: z - (side ? hw : hd),
                    z1: z + (side ? hw : hd),
                  },
                  h: LibraryStyle.CATALOGUE_H,
                });
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

// the pendants: a lattice over every room, sparser and dimmer in the archive, and along the corridor.
// A lattice point on a stack rank moves into the aisle beside it, and a pendant in an aisle hangs on
// its centre line, so the ranks never stand under a lamp
  static function lamps(m:Facility, tile:Int->Int->Int):Array<LampPost>
    {
      var out:Array<LampPost> = [];
      var stack = function(col, row) return tile(col, row) == Const.TILE_LIB_STACK;
      for (r in m.rooms)
        {
          var archive = (LibraryStyle.roleSurf(r.role) == Surf.LIB_ARCHIVE);
          var nx = Std.int(Math.max(1, Math.round(r.w / LibraryStyle.LAMP_SPACING)));
          var ny = Std.int(Math.max(1, Math.round(r.h / LibraryStyle.LAMP_SPACING)));
          for (i in 0...nx)
            for (j in 0...ny)
              {
                var col = r.x1 + Std.int((i + 0.5) * r.w / nx);
                var row = r.y1 + Std.int((j + 0.5) * r.h / ny);
                if (stack(col, row))
                  col += (col + 1 <= r.x2 && !stack(col + 1, row) ? 1 : -1);
                out.push(post(col, row,
                  (archive ? LibraryStyle.LAMP_ARCHIVE : LibraryStyle.LAMP_COLOR),
                  (archive ? LibraryStyle.LAMP_ARCHIVE_MUL : LibraryStyle.LAMP_MUL),
                  stack(col - 1, row) || stack(col + 1, row)));
              }
        }
      for (row in 0...m.h)
        for (col in 0...m.w)
          if (m.surf[row][col] == Surf.CARPET &&
              col % LibraryStyle.LAMP_SPACING == 0 &&
              (m.surf[row - 1][col] != Surf.CARPET))
            out.push(post(col, row, LibraryStyle.LAMP_COLOR, LibraryStyle.LAMP_MUL, false));
      return out;
    }

// one pendant, jittered off its cell centre and in strength by the cell hash; in an aisle (`aisle`)
// only along it
  static function post(col:Int, row:Int, color:Int, mul:Float, aisle:Bool):LampPost
    {
      var h = FacilityModel.mix((col * 49979687) ^ (row * 86028121));
      var c = CityConfig.cellToWorld(col, row);
      var x = c.x + (aisle ? 0.0 : (((h >>> 13) % 21) - 10) * LibraryStyle.LAMP_JITTER / 10);
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
      sounds.tick(opts.playerCol, opts.playerRow, opts.dtMs);
      for (f in furniture)
        Models.cull(f, opts.camera, LibraryStyle.PIECE_CULL_R);
      chunks.cull(opts.camera, opts.player, RenderConfig.MOON_SHADOW.halfExtent);
      render.world.ObjModels.cull(props, opts, tactical && opts.ui);
      render.world.PropShader.tick(opts.dtMs);
      render.world.PropGlow.tick(opts.dtMs);
      // the object props' glbs arrive over a loader callback, so there is no build-time moment to
      // patch them; the chain is shared with the warm scene (ObjModels.patchRow's note)
      for (b in props)
        render.world.ObjModels.patchRow(b.model, b.solid.mesh, b.ghost.mesh, b.hull.mesh);
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
        { path: M.libraryLamp, h: LibraryStyle.LAMP_H },
        { path: M.libraryBasket, h: LibraryStyle.BASKET_H },
      ];
      for (p in M.libraryBooks)
        rows.push({
          path: p,
          h: LibraryStyle.BOOK_T,
        });
      LibraryBooks.warm(sc);
      LibraryWall.warm(sc);
      LibraryDecor.warm(sc);
      // and the floor's object props in their three variants, patched in the build's order: the
      // stairs and the Necronomicon
      var C = RenderConfig.OBJMARK;
      var objs = [for (m in render.world.ObjModels.MODELS)
        if (m.keys.indexOf('stairs') >= 0 ||
            m.keys.indexOf('pickup_necronomicon') >= 0) m];
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
          var left = rows.length + objs.length;
          for (r in rows)
            Models.get(r.path, function(_)
              {
                left--;
                if (left == 0)
                  res(null);
              });
          for (m in objs)
            Models.get(m.path, function(_)
              {
                var place = [{
                  x: 0.0,
                  z: 0.0,
                  yaw: 0.0,
                }];
                render.world.ObjModels.patchRow(m,
                  Models.instanced(sc, m.path, place, m.h, render.world.ObjModels.solidVariant(m)).mesh,
                  Models.instanced(sc, m.path, place, m.h, GHOST).mesh,
                  Models.instanced(sc, m.path, place, m.h, HULL(C.color, C.hullW)).mesh);
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
