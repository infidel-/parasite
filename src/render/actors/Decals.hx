package render.actors;

import three.Three;
import citygen.CityConfig;
import render.RenderConfig;
import render.particles.Sprites;
import render.world.WorldCtx;
import game.Game;

// the persisted + render-only ground/wall decal layer of the actor pass: seed-derived street
// debris, SPLAT blood ground quads, and WALLHOLE bullet holes stood on their wall face. revealed
// by a radius fade around the player's smoothed world pos (opaque near, fading to invisible at the
// edge), which replaced the old binary LOS gate. paints through the shared lit Sprites surface;
// owns only its lazy bullet-hole texture caches + the current debris scatter. driven once a frame
// by Actors.update via paint()
class Decals {
  var game:Game;
  var sprites:Sprites;                                    // lit ground/wall paint surface (shared)
  var holeTex:Array<Texture> = null;                     // masonry bullet-hole wall textures (lazy-loaded once)
  var holeTexMetal:Array<Texture> = null;                // metal-wall bullet-hole textures (lazy-loaded once)
  var debris:Array<render.world.Debris.DebrisSpot> = null; // seed-derived street debris (render-only, not persisted)
  var px:Float = 0.0;                                     // smoothed player world x for this frame's radius fade
  var pz:Float = 0.0;                                     // smoothed player world z for this frame's radius fade
  // last decal pass counts (leak/perf check), read by Actors.perfLog
  public var decalScan(default, null):Int = 0;
  public var decalDraw(default, null):Int = 0;

  public function new(game:Game, sprites:Sprites)
    {
      this.game = game;
      this.sprites = sprites;
    }

// set the seed-derived debris scatter for the current city (render-only, rebuilt per show)
  public function setDebris(list:Array<render.world.Debris.DebrisSpot>):Void
    {
      debris = list;
    }

// paint this frame's render-only debris, then the persisted tile decals (blood + bullet holes),
// in the order the actor pass expects them. px/pz is the player's smoothed world pos driving the
// radius fade that replaced the old LOS gate
  public function paint(px:Float, pz:Float):Void
    {
      this.px = px;
      this.pz = pz;
      drawDebris();
      drawDecals();
    }

// world-space reveal opacity: fully opaque inside the radius, linear fade to 0 across the edge band.
// replaces the old LOS gate. losEnabled off (debug reveal-all) => full opacity, radius ignored
  inline function radiusOp(wx:Float, wz:Float):Float
    {
      if (!game.player.vars.losEnabled)
        return 1.0;
      var r = RenderConfig.DECAL.radiusCells * CityConfig.CELL;
      var band = RenderConfig.DECAL.fadeCells * CityConfig.CELL;
      var dx = wx - px;
      var dz = wz - pz;
      var d = Math.sqrt(dx * dx + dz * dz);
      var op = (r - d) / band;
      return op < 0 ? 0.0 : (op > 1 ? 1.0 : op);
    }

// draw the seed-derived street debris as content-cropped flat ground quads, fog-gated per cell
// like the blood decals. render-only — these are not game-area decorations, so they never persist
  function drawDebris():Void
    {
      if (debris == null)
        return;
      for (s in debris)
        {
          var gs = sprites.texContent('entities', s.ix, s.iy, false, RenderConfig.DECAL.debrisMul);
          if (gs == null)
            continue;
          var w = CityConfig.cellToWorld(s.col + s.dx, s.row + s.dy);
          var op = radiusOp(w.x, w.z);
          if (op <= 0.001)
            continue;
          sprites.paintGround(w.x, WorldCtx.floorY(s.col, s.row) + 0.04, w.z, gs, op, s.scale, s.angle);
        }
    }

// draw persisted tile decorations: SPLAT blood as flat ground quads, WALLHOLE bullet holes as
// upright quads on their wall face. scans the tile grid (sparse + capped); non-3D floor
// decorations stay 2D-only
  function drawDecals():Void
    {
      var tiles = game.area.tiles;
      if (tiles == null)
        return;
      var t = Const.TILE_SIZE; // dx/dy are pixel offsets in +/-tile/2 (matches 2D splats)
      var scan = 0, draw = 0;
      for (x in 0...game.area.width)
        {
          if (tiles[x] == null)
            continue;
          for (y in 0...game.area.height)
            {
              scan++;
              var tile = tiles[x][y];
              if (tile == null ||
                  tile.decoration == null ||
                  tile.decoration.length == 0)
                continue;
              for (d in tile.decoration)
                if (drawDecal(d, x, y, t))
                  draw++;
            }
        }
      decalScan = scan; decalDraw = draw;
    }

// paint one tile decoration; returns true if a quad was drawn. SPLAT blood lays flat on the
// ground; WALLHOLE bullet holes stand upright on their wall face. both radius-fade around the player
  function drawDecal(d:tiles.Decoration, x:Int, y:Int, t:Float):Bool
    {
      // ground blood: radius-fade around the player, lay flat
      if (d.tag == 'SPLAT')
        {
          if (d.icon == null)
            return false;
          var dx = (d.dx != null ? d.dx : 0) / t;
          var dy = (d.dy != null ? d.dy : 0) / t;
          var w = CityConfig.cellToWorld(x + dx, y + dy);
          var op = radiusOp(w.x, w.z);
          if (op <= 0.001)
            return false;
          var tex = sprites.tex('entities', d.icon.col, d.icon.row, false, RenderConfig.DECAL.bloodMul);
          if (tex == null)
            return false;
          var sc = (d.scale != null ? d.scale : 1.0);
          // wall blood: a drop that flew into a wall stands its splat upright on the struck face
          // (like a bullet hole), nudged proud of the face; same wet sheen as the ground splats
          if (d.face != null)
            {
              var fdir:Int = d.face;
              var dv = render.world.Geom.DIRV[fdir];
              var wy = (d.height != null ? d.height : WorldCtx.floorY(x, y) + Sprites.SIZE * 0.4);
              sprites.paintWall(w.x + dv[0] * 0.12, wy, w.z + dv[1] * 0.12, tex, op, sc,
                render.world.Geom.faceRotY(fdir), (d.angle != null ? d.angle : 0.0),
                RenderConfig.BLOOD.wetRough, RenderConfig.BLOOD.wetMetal);
              return true;
            }
          // wet-blood sheen: BLOOD.wetRough (< 1) makes the flat splat catch a subtle specular
          // glint off the moon/lamp/flame lights. all intervening args are their paint() defaults
          sprites.paint(w.x, WorldCtx.floorY(x, y) + 0.04, w.z, tex, op, sc, true,
            (d.angle != null ? d.angle : 0.0), Sprites.ORD_DECAL, 0, 0.0, true, null, 1.0,
            RenderConfig.BLOOD.wetRough, RenderConfig.BLOOD.wetMetal);
          return true;
        }
      // bullet hole: stand it on its wall face, radius-fade around the player
      else if (d.tag == 'WALLHOLE' &&
               d.face != null)
        {
          var hts = holeTextures(d.metal == true);
          if (hts.length == 0)
            return false;
          var fdir:Int = d.face;
          var dv = render.world.Geom.DIRV[fdir];
          var w = CityConfig.cellToWorld(x + (d.dx != null ? d.dx : 0) / t,
            y + (d.dy != null ? d.dy : 0) / t);
          var op = radiusOp(w.x, w.z);
          if (op <= 0.001)
            return false;
          var roll = (d.angle != null ? d.angle : 0.0);
          // fold the stored roll into the variant so co-cell holes differ (reload-stable)
          var variant = ((x * 31 + y * 17 + Std.int(roll * 10)) % hts.length + hts.length) % hts.length;
          var sc = (d.scale != null ? d.scale : RenderConfig.WALLHOLE.scale);
          var wy = (d.height != null ? d.height : WorldCtx.floorY(x, y) + Sprites.SIZE * 0.4);
          // nudge proud of the wall face along the outward normal (clears the opaque
          // face so the hole isn't depth-culled; no z-fight since depthWrite is off)
          sprites.paintWall(w.x + dv[0] * 0.12, wy, w.z + dv[1] * 0.12,
            hts[variant], op, sc, render.world.Geom.faceRotY(fdir), roll);
          return true;
        }
      return false;
    }

// lazily load the bullet-hole wall textures once, per material (masonry vs metal-warehouse)
  function holeTextures(metal:Bool):Array<Texture>
    {
      if (metal)
        {
          if (holeTexMetal == null)
            holeTexMetal = loadHoleTex(RenderConfig.TEXTURES.bulletHolesMetal);
          return holeTexMetal;
        }
      if (holeTex == null)
        holeTex = loadHoleTex(RenderConfig.TEXTURES.bulletHoles);
      return holeTex;
    }

// load a set of clamp-wrapped alpha hole PNGs
  function loadHoleTex(paths:Array<String>):Array<Texture>
    {
      return [for (p in paths)
        {
          var tx = render.Textures.loadTexture(p, 'wall');
          tx.wrapS = tx.wrapT = THREE.ClampToEdgeWrapping;
          tx;
        }];
    }
}
