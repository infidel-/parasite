package render.decals;

import three.Three;
import citygen.CityConfig;
import render.RenderConfig;
import render.particles.Sprites;
import game.Game;

// the persisted + render-only ground/wall decal layer of the actor pass. coordinator only: owns the
// shared DecalBatch, the radius fade around the player, the per-frame shimmer clock + frame counter,
// and the single tile-grid scan. routes each decoration to a per-type module (Blood/Money/WallHole)
// by tag and drives each module's per-frame paint. NO type-specific draw code lives here — the
// street debris, blood, thrown-money and bullet-hole bodies each own a sibling module in
// render.decals. revealed by a radius fade around the player's smoothed world pos (opaque near,
// fading to invisible at the edge), which replaced the old binary LOS gate. driven once a frame by
// Actors.update via paint(). @:allow lets the sibling modules read the shared batch/sprites/clock
@:allow(render.decals)
class Decals {
  var game:Game;
  var sprites:Sprites;                                    // lit ground/wall paint surface (shared)
  var batch:DecalBatch;                                   // instanced flat-decal draw (plain blood + debris)
  var px:Float = 0.0;                                     // smoothed player world x for this frame's radius fade
  var pz:Float = 0.0;                                     // smoothed player world z for this frame's radius fade
  var clock:Float = 0.0;                                  // black-blood shimmer clock (BASE_MS units)
  var frameNo:Int = 0;                                    // paint-pass counter (star slot liveness stamp)
  var blood:Blood;                                        // SPLAT blood ground/wall + shimmer/star glint
  var money:Money;                                        // MONEY thrown-money perm + fading stains
  var wallhole:WallHole;                                  // WALLHOLE bullet holes on their wall face
  var debris:Debris;                                      // seed-derived street debris (render-only)
  // last decal pass counts (leak/perf check), read by Actors.perfLog
  public var decalScan(default, null):Int = 0;
  public var decalDraw(default, null):Int = 0;

  public function new(game:Game, sprites:Sprites, actorGroup:Object3D)
    {
      this.game = game;
      this.sprites = sprites;
      batch = new DecalBatch(actorGroup);
      blood = new Blood(this);
      money = new Money(this);
      wallhole = new WallHole(this);
      debris = new Debris(this);
    }

// release the instanced-decal GPU buffers on view teardown
  public function dispose():Void
    {
      batch.dispose();
    }

// set the seed-derived debris scatter for the current city (render-only, rebuilt per show)
  public function setDebris(list:Array<render.world.Debris.DebrisSpot>):Void
    {
      debris.set(list);
    }

// lay the lingering money ground stains over the throw radius (perm + fading). thin bridge from
// Actors; the model tile-decoration write + view-side add live in the Money module
  public function throwMoney(x:Int, y:Int, range:Int):Void
    {
      money.throwGround(x, y, range);
    }

// paint this frame's render-only debris, then the persisted tile decals (blood + money + bullet
// holes), then the fading money stains, in the order the actor pass expects. px/pz is the player's
// smoothed world pos driving the radius fade that replaced the old LOS gate; dtMs advances the
// black-blood shimmer clock + the money fade
  public function paint(px:Float, pz:Float, dtMs:Float):Void
    {
      this.px = px;
      this.pz = pz;
      clock += dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
      frameNo++;
      blood.beginFrame();
      batch.begin();
      debris.draw();
      drawDecals();
      money.paintTemp(dtMs);
      batch.end();
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

// scan the tile grid (sparse + capped) and route each persisted decoration to its type module by
// tag. non-3D floor decorations stay 2D-only
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
                if (dispatch(d, x, y, t))
                  draw++;
            }
        }
      decalScan = scan; decalDraw = draw;
    }

// route one tile decoration to its type module by tag; returns true if a quad was drawn
  function dispatch(d:tiles.Decoration, x:Int, y:Int, t:Float):Bool
    {
      switch (d.tag)
        {
          case 'SPLAT':
            return blood.draw(d, x, y, t);
          case 'MONEY':
            return money.draw(d, x, y, t);
          case 'WALLHOLE':
            return wallhole.draw(d, x, y, t);
          default:
            return false;
        }
    }
}
