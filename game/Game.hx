// game state

package game;

import com.haxepunk.HXP;
import scenario.Timeline;

class Game
{
  public var scene: GameScene; // ui scene
  public var timeline: Timeline; // scenario timeline
  public var goals: Goals; // game.goals
  public var world: World; // game world
  public var managerWorld: WorldManager; // game world manager
  public var region: RegionGame; // region info link

  public var area: AreaGame; // current area link
  public var managerArea: AreaManager; // area event manager
  public var debugArea: DebugArea; // debug actions (area mode)

  public var managerRegion: RegionManager; // event manager (region mode)
  public var playerRegion: PlayerRegion; // game player (region mode)
  public var debugRegion: DebugRegion; // debug actions (region mode)

  public var player: Player; // game player
  public var playerArea: PlayerArea; // game player (area mode)
  public var location(default, null): _LocationType; // player location type - area, region, world 

  public var turns: Int; // number of turns passed since game start
  public var turnsArea: Int; // number of turns passed since player entered this area 
  public var isFinished: Bool; // is the game finished?
  public var messageList: List<String>; // last X messages of log

  public function new()
    {
      scene = new GameScene(this);
      managerWorld = new WorldManager(this);
      HXP.frameRate = 30;
      HXP.scene = scene;
      messageList = new List();

      area = null;
      region = null;
    }


// init game stuff - called from GameScene.begin()
  public function init()
    {
      Const.todo('proper title screen');
      turns = 0;
      turnsArea = 0;
      isFinished = false;

      player = new Player(this);
      managerArea = new AreaManager(this);
      playerArea = new PlayerArea(this);
      debugArea = new DebugArea(this);

      managerRegion = new RegionManager(this);
      playerRegion = new PlayerRegion( this);
      debugRegion = new DebugRegion(this);

      // generate world
      world = new World(this);
      world.generate();

      // generate timeline from a scenario
      timeline = new Timeline(this);
      goals = new Goals(this);
      timeline.init();

      // initial goal
      message('You are alone. You are scared. You need to find a host or you will die soon.');
      goals.receive(GOAL_INVADE_HOST);

      // set random region (currently only 1 at all)
      region = world.get(0);

      // find random inhabited area near player starting location 
      var event = timeline.getStartEvent();
      area = region.getRandomAround(event.location.area, {
        isInhabited: true,
        minRadius: 2,
        maxRadius: 5 });
      playerRegion.createEntity(area.x, area.y);

      // make area tiles around player known 
      for (yy in (area.y - 1)...(area.y + 2))
        for (xx in (area.x - 1)...(area.x + 2))
          {
            var aa = region.getXY(xx, yy);
            if (aa == null)
              continue;
            
            aa.isKnown = true;
          }

      location = LOCATION_AREA;
      area.enter();

      // spawn initial dog nearby
      var spot = area.findEmptyLocationNear(playerArea.x, playerArea.y);
      var ai = new ai.DogAI(this, spot.x, spot.y);
      ai.isCommon = true;
      area.addAI(ai);

      updateHUD(); // update HUD state
    }


// set location
  public function setLocation(vloc: _LocationType, ?newarea: AreaGame)
    {
      // hide previous gui, despawn area, etc
      if (location == LOCATION_AREA)
        area.leave();

      else if (location == LOCATION_REGION)
        region.leave();

      location = vloc;

      // show new gui
      if (location == LOCATION_AREA)
        {
          turnsArea = 0;
          area = region.getXY(playerRegion.x, playerRegion.y);
          if (newarea != null) // enter specified area
             area = newarea;
          area.enter();
        }

      else if (location == LOCATION_REGION)
        {
          region.updateAlertness();
          region.enter();
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
          managerArea.turn();
          if (isFinished)
            return;

          // goals turn
          goals.turn();
          if (isFinished)
            return;

          // current area turns
          turnsArea++;
          if (turnsArea % 10 == 0)
            region.turnDetectHabitats();
        }

      else if (location == LOCATION_REGION)
        {
          region.turn();
          if (isFinished)
            return;

          // goals turn
          goals.turn();
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


// display text message in a window
  public inline function message(s: String)
    {
      Const.todo('display important message');
      log(s, COLOR_MESSAGE);
    }


// add debug entry to game log
  public inline function debug(s: String)
    {
#if mydebug
      log(s, COLOR_DEBUG);
#end
    }


// add entry to game log
  public function log(s: String, ?col: _TextColor)
    { 
      if (col == null)
        col = COLOR_DEFAULT;
      Sys.println(s);
      var hs = "<font color='" + Const.TEXT_COLORS[col] + "'>" + s + "</font>";
      scene.hud.log(hs);

      // add message to buffer
      messageList.add(hs);
      if (messageList.length > 100)
        messageList.pop();
    }
}
