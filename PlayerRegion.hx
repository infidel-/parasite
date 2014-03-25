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


// end of turn for player (in region mode)
  public function turn()
    {
      // automatically gain control over host each turn
      if (player.state == Player.STATE_HOST && player.hostControl < 100)
        player.hostControl += 10;
    }


// ==============================   ACTIONS   =======================================


// helper: add action to list and check for energy
  inline function addActionToList(list: List<String>, name: String)
    {
      var action = Const.getAction(name);
      if (action.energy <= player.energy)
        list.add(name);
    }


// get actions list (area mode)
  public function getActionList(): List<String>
    {
      var tmp = new List<String>();
      
      addActionToList(tmp, 'enterArea');
      
      return tmp;
    }


// do a player action by string id
// action energy availability is checked when the list is formed
  public function action(actionName: String)
    {
      var action = Const.getAction(actionName);

      if (actionName == 'enterArea')
        actionEnterArea();

      player.energy -= action.energy;

      if (player.energy == 0)
        Const.todo('Zero energy as a result of a region action. Fix this.');

      // update HUD info
      game.updateHUD();
    }


// action: enter area
  function actionEnterArea()
    {
      game.log("You emerge from the sewers.");
      game.setLocation(Game.LOCATION_AREA);
    }


// action: move player by dx,dy
  public function actionMove(dx: Int, dy: Int)
    {
      // try to move to the new location
      moveBy(dx, dy);
    }


// ==================================================================================


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
