package render.actors;

import three.Three;
import citygen.CityConfig;
import render.RenderConfig;
import render.particles.Sprites;
import render.world.WorldCtx;
import game.Game;

// the persisted + render-only ground/wall decal layer of the actor pass: seed-derived street
// debris, SPLAT blood ground quads, and WALLHOLE bullet holes stood on their wall face. all
// fog-gated on the player's LOS like the 2D view. paints through the shared lit Sprites surface;
// owns only its lazy bullet-hole texture caches + the current debris scatter. driven once a frame
// by Actors.update via paint()
class Decals {
  var game:Game;
  var sprites:Sprites;                                    // lit ground/wall paint surface (shared)
  var holeTex:Array<Texture> = null;                     // masonry bullet-hole wall textures (lazy-loaded once)
  var holeTexMetal:Array<Texture> = null;                // metal-wall bullet-hole textures (lazy-loaded once)
  var debris:Array<render.world.Debris.DebrisSpot> = null; // seed-derived street debris (render-only, not persisted)
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
// in the order the actor pass expects them
  public function paint():Void
    {
      drawDebris();
      drawDecals();
    }

// draw the seed-derived street debris as content-cropped flat ground quads, fog-gated per cell
// like the blood decals. render-only — these are not game-area decorations, so they never persist
  function drawDebris():Void
    {
      if (debris == null)
        return;
      var los = game.player.vars.losEnabled;
      for (s in debris)
        {
          if (los &&
              !game.playerArea.sees(s.col, s.row))
            continue;
          var gs = sprites.texContent('entities', s.ix, s.iy, false, RenderConfig.DECAL.debrisMul);
          if (gs == null)
            continue;
          var w = CityConfig.cellToWorld(s.col + s.dx, s.row + s.dy);
          sprites.paintGround(w.x, WorldCtx.floorY(s.col, s.row) + 0.04, w.z, gs, 1.0, s.scale, s.angle);
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
      var los = game.player.vars.losEnabled;
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
                if (drawDecal(d, x, y, los, t))
                  draw++;
            }
        }
      decalScan = scan; decalDraw = draw;
    }

// paint one tile decoration; returns true if a quad was drawn. SPLAT blood lays flat on the
// ground; WALLHOLE bullet holes stand upright on their wall face. both fog-gate on LOS
  function drawDecal(d:tiles.Decoration, x:Int, y:Int, los:Bool, t:Float):Bool
    {
      // ground blood: fog-gate on this cell, lay flat
      if (d.tag == 'SPLAT')
        {
          if (d.icon == null ||
              (los && !game.playerArea.sees(x, y)))
            return false;
          var dx = (d.dx != null ? d.dx : 0) / t;
          var dy = (d.dy != null ? d.dy : 0) / t;
          var w = CityConfig.cellToWorld(x + dx, y + dy);
          var tex = sprites.tex('entities', d.icon.col, d.icon.row, false, RenderConfig.DECAL.bloodMul);
          if (tex == null)
            return false;
          var sc = (d.scale != null ? d.scale : 1.0);
          sprites.paint(w.x, WorldCtx.floorY(x, y) + 0.04, w.z, tex, 1.0, sc, true,
            (d.angle != null ? d.angle : 0.0));
          return true;
        }
      // bullet hole: stand it on its wall face, fog-gate on the open cell in front
      else if (d.tag == 'WALLHOLE' &&
               d.face != null)
        {
          var hts = holeTextures(d.metal == true);
          if (hts.length == 0)
            return false;
          var fdir:Int = d.face;
          var dv = render.world.Geom.DIRV[fdir];
          if (los && !game.playerArea.sees(x + dv[0], y + dv[1]))
            return false;
          var w = CityConfig.cellToWorld(x + (d.dx != null ? d.dx : 0) / t,
            y + (d.dy != null ? d.dy : 0) / t);
          var roll = (d.angle != null ? d.angle : 0.0);
          // fold the stored roll into the variant so co-cell holes differ (reload-stable)
          var variant = ((x * 31 + y * 17 + Std.int(roll * 10)) % hts.length + hts.length) % hts.length;
          var sc = (d.scale != null ? d.scale : RenderConfig.WALLHOLE.scale);
          var wy = (d.height != null ? d.height : WorldCtx.floorY(x, y) + Sprites.SIZE * 0.4);
          // nudge proud of the wall face along the outward normal (clears the opaque
          // face so the hole isn't depth-culled; no z-fight since depthWrite is off)
          sprites.paintWall(w.x + dv[0] * 0.12, wy, w.z + dv[1] * 0.12,
            hts[variant], 1.0, sc, render.world.Geom.faceRotY(fdir), roll);
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
