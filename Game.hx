// game state

import com.haxepunk.HXP;

class Game
{
  public var scene: GameScene; // ui scene
  public var world: World; // game world
  public var worldManager: WorldManager; // game world manager
  public var region: Region; // region view 
  public var area: Area; // area view 
  public var player: Player; // game player
  public var location(default, null): String; // player location type - area, region, world 

  public var turns: Int; // number of turns passed since game start
  public var isFinished: Bool; // is the game finished?

  public function new()
    {
      scene = new GameScene(this);
      worldManager = new WorldManager(this);
      HXP.scene = scene;
    }


// init game stuff - called from GameScene.begin()
  public function init()
    {
      Const.todo('proper title screen');
      log('You are alone. You are scared. You need to find a host or you will die soon.');
      turns = 0;
      isFinished = false;
      player = new Player(this);

      region = new Region(this, "gfx/tileset.png");
      scene.add(region.entity);
      area = new Area(this, "gfx/tileset.png");
      scene.add(area.entity);

      // generate world
      world = new World(this);
      world.generate();

      // set random region (currently only 1 at all)
      var r = world.get(0);
      region.setRegion(r);
      var a = r.getRandom();
      region.player.createEntity(a.x, a.y);
      region.hide();

      area.setArea(a);

/* FIX
      region.generate();
      scene.add(region.entity);
      region.player.createEntity(2, 2); // TODO: change to proper area
      region.hide();

      // generate initial area
      area = new Area(this, "gfx/tileset.png", 50, 50);
      area.generate();
      scene.add(area.entity);
*/
      // init player
      location = LOCATION_AREA;
      var loc = area.findEmptyLocation();
      area.player.createEntity(loc.x, loc.y);

      updateHUD(); // update HUD state

      // center camera on player
      scene.updateCamera();

      // update AI visibility to player
      area.updateVisibility();
    }


// set location
  public function setLocation(vloc: String)
    {
      // hide previous gui
      if (location == LOCATION_AREA)
        {
          area.hide();
        }

      location = vloc;

      // show new gui
      if (location == LOCATION_REGION)
        {
          region.show();
        }

      // center camera on player
      scene.updateCamera();
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
      if (location == LOCATION_AREA)
        {
          area.turn();
          if (isFinished)
            return;

          // area turn
          area.manager.turn();
          if (isFinished)
            return;
        }

      else if (location == LOCATION_REGION)
        {
          region.turn();
          if (isFinished)
            return;
        }

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


  public static var LOCATION_AREA = 'area'; 
  public static var LOCATION_REGION = 'region'; 
}
