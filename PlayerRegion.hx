// player state (region mode)

import com.haxepunk.HXP;

import entities.PlayerEntity;

class PlayerRegion
{
  var game: Game; // game state link
  var region: Region; // region link
  var player: Player; // player state link

  public var entity: PlayerEntity; // player ui entity (region mode)
  public var x: Int; // x,y on grid
  public var y: Int;


  public function new(g: Game, r: Region)
    {
      game = g;
      player = game.player;
      region = r;

      x = 0;
      y = 0;
    }


// create player entity
  public inline function createEntity(vx: Int, vy: Int)
    {
      x = vx;
      y = vy;
      entity = new PlayerEntity(game, x, y);
      game.scene.add(entity);
    }


// action: move player by dx,dy
  public function actionMove(dx: Int, dy: Int)
    {
      // try to move to the new location
      moveBy(dx, dy);
    }


// move player by dx, dy
// returns true on success
  public function moveBy(dx: Int, dy: Int): Bool
    {
      var nx = x + dx;
      var ny = y + dy;

      // cell not walkable
      if (!region.isWalkable(nx, ny))
        return false;

      x = nx;
      y = ny;

      entity.setPosition(x, y); // move player entity

      game.turn(); // new turn

      game.updateHUD(); // update HUD info

      // update AI visibility to player
//      region.updateVisibility();

      return true;
    }
}
