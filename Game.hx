// game state

import com.haxepunk.HXP;

class Game
{
  public var scene: GameScene; // ui scene
  public var map: MapGrid; // game world map
  public var player: Player; // game player
  public var debug: Debug; // debug actions

  public var turns: Int; // number of turns passed since game start
  public var isFinished: Bool; // is the game finished?

  public var vars: { // game variables
    parasiteEnergyPerTurn: Int, // energy spent per turn without a host
    parasiteHealth: Int, // starting parasite health
    parasiteEnergy: Int, // starting parasite energy 
    };

  public function new()
    {
      scene = new GameScene(this);
      debug = new Debug(this);
      HXP.scene = scene;

      vars = {
        parasiteEnergyPerTurn: 10,
        parasiteHealth: 10,
        parasiteEnergy: 100
        };
    }


// init game stuff - called from GameScene.begin()
  public function init()
    {
      Const.todo('proper title screen');
      log('You are alone. You are scared. You need to find a host or you will die soon.');
      turns = 0;
      isFinished = false;

      // init and generate map
      map = new MapGrid(this, "gfx/tileset.png", 50, 50);
      map.generate();
      scene.add(map.entity);

      // init player
      var loc = map.findEmptyLocation();
      player = new Player(this, loc.x, loc.y);
      player.createEntity();

      updateHUD(); // update HUD state

      // center camera on player
      scene.updateCamera();

      // update AI visibility to player
      map.updateVisibility();
    }


// player turn ends
  public function endTurn()
    {
      player.turn();
      if (isFinished)
        return;

      // turns counter
      turns++;

      // AI movement
      map.aiTurn();

      // host AI logic
//      if (player.state == Player.STATE_HOST)
//        player.host.stateHost();

      // update AI visibility to player
      map.updateVisibility();
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
  public function updateHUD()
    {
      scene.hud.update(); // update hud state
    }


// add entry to game log
  public function log(s: String, ?col: Int = 0)
    { 
      Sys.println(s);

      var colstr = '#FFFFFF';
      if (col == Const.COLOR_ALERT)
        colstr = '#FF0000';
      else if (col == Const.COLOR_EVOLUTION)
        colstr = '#00FFFF';
      scene.hud.log("<font color='" + colstr + "'>" + s + "</font>");
    }
}
