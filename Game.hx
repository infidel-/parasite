// game state

import com.haxepunk.HXP;

class Game
{
  public var scene: GameScene; // ui scene
  public var world: World; // game world
  public var worldManager: WorldManager; // game world manager
  public var areaManager: AreaManager; // area event manager
  public var area: Area; // area player is currently in 
  public var player: Player; // game player
  public var debug: Debug; // debug actions

  public var turns: Int; // number of turns passed since game start
  public var isFinished: Bool; // is the game finished?

  public function new()
    {
      scene = new GameScene(this);
      worldManager = new WorldManager(this);
      areaManager = new AreaManager(this);
      debug = new Debug(this);
      HXP.scene = scene;
    }


// init game stuff - called from GameScene.begin()
  public function init()
    {
      Const.todo('proper title screen');
      log('You are alone. You are scared. You need to find a host or you will die soon.');
      turns = 0;
      isFinished = false;

      // generate world
      world = new World(this);
      world.generate();

      // generate initial area
      area = new Area(this, "gfx/tileset.png", 50, 50);
      area.generate();
      scene.add(area.entity);

      // init player
      var loc = area.findEmptyLocation();
      player = new Player(this, loc.x, loc.y);
      player.createEntity();

      updateHUD(); // update HUD state

      // center camera on player
      scene.updateCamera();

      // update AI visibility to player
      area.updateVisibility();
    }


// game turn ends
  public function turn()
    {
      // player turn
      player.turn();
      if (isFinished)
        return;

      // turns counter
      turns++;

      // AI movement
      area.turn();
      if (isFinished)
        return;

      // area turn
      areaManager.turn();
      if (isFinished)
        return;

      // update AI visibility to player
      area.updateVisibility();
    }


// game finish
// result - win, lose
// condition - noHost, etc
  public function finish(result: String, condition: String)
    {
      Const.todo('proper finish screen');
      isFinished = true;

      // game lost
      if (result == 'lose')
        {
          log('You have lost the game.');
          if (condition == 'noHost')
            log('You cannot survive without a host for long.');
          else if (condition == 'noHost')
            log('You have succumbed to injuries.');
        }
      else
        {
          log('You have won the game!');
        }

      Sys.exit(1);
    }


// update HUD state from game state
  public inline function updateHUD()
    {
      scene.hud.update(); // update hud state
    }


// add entry to game log
  public inline function log(s: String, ?col: Int = 0)
    { 
      Sys.println(s);
      scene.hud.log("<font color='" + Const.TEXT_COLORS[col] + "'>" + s + "</font>");
    }
}
