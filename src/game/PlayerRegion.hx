// player state (region mode)

package game;

import entities.PlayerEntity;
import region.*;

class PlayerRegion extends _SaveObject
{
  static var _ignoredFields = [ 'player', 'entity', 'target', 'pathTS' ];
  var game: Game; // game state link
  var player: Player; // player state link

  public var currentArea(get, null): AreaGame; // area player is in

  public var entity: PlayerEntity; // player ui entity (region mode)
  public var x: Int; // x,y on grid
  public var y: Int;
  public var target(default, null): { x: Int, y: Int }; // current player target x,y
  var pathTS: Float; // last time player moved to target


  public function new(g: Game)
    {
      game = g;
      player = game.player;
      target = null;
      pathTS = 0;

      x = 0;
      y = 0;
    }


// create player entity
  public inline function createEntity(vx: Int, vy: Int)
    {
      x = vx;
      y = vy;
      entity = new PlayerEntity(game, x, y);
    }


// end of turn for player (in region mode)
  public function turn(time: Int)
    {
      if (player.state == PLR_STATE_HOST)
        {
          // automatically gain control over host each turn
          if (player.hostControl < 100)
            player.hostControl += 25;
          // time passing for chat
          player.host.chatTurn(time);
        }
    }


// ==============================   ACTIONS   =======================================


// get actions list (region mode)
  public function updateActionList()
    {
      // enter area
      if (currentArea.info.canEnter)
        game.ui.hud.addAction({
          id: 'enterArea',
          type: ACTION_REGION,
          name: 'Enter area',
          energy: 0
        });

      // create a new habitat
      // NOTE: maybe add regionActions to ImprovInfo later?
      if (player.evolutionManager.getLevel(IMP_MICROHABITAT) > 0 &&
          !currentArea.hasHabitat &&
          currentArea.info.isInhabited)
        {
          // count total number of habitats
          var params = player.evolutionManager.getParams(IMP_MICROHABITAT);
          var maxHabitats = params.numHabitats;
          var numHabitats = game.region.getHabitatsCount();

          if (numHabitats < maxHabitats)
            game.ui.hud.addAction({
              id: 'createHabitat',
              type: ACTION_REGION,
              name: 'Create habitat',
              energy: 10
            });
        }
      // ovum placement
      if (player.evolutionManager.getLevel(IMP_OVUM) > 0)
        {
          // check if ovum is already on the map
          var hasOvum = false;
          for (o in game.region.getObjects())
            if (o.type == 'ovum')
              {
                hasOvum = true;
                break;
              }
          if (!hasOvum)
            game.ui.hud.addAction({
              id: 'createOvum',
              type: ACTION_REGION,
              name: 'Create ovum',
              energy: 0
            });
        }

      if (player.state == PLR_STATE_HOST)
        {
          // evolution manager actions
          player.evolutionManager.updateActionList();
        }

      // object actions
      var o = game.region.getObjectAt(x, y);
      if (o != null)
        o.updateActionList();

      // enter habitat
      if (currentArea.hasHabitat)
        game.ui.hud.addAction({
          id: 'enterHabitat',
          type: ACTION_REGION,
          name: 'Enter habitat',
          energy: 0
        });
    }


// do a player action by string id
// action energy availability is checked when the list is formed
  public function action(action: _PlayerAction)
    {
      // restart
      if (action.id == 'restart')
        {
          game.restart();
          return;
        }

      var ret = true;
      // object action
      if (action.type == ACTION_OBJECT)
        {
          var o: RegionObject = action.obj;
          ret = o.action(action);
        }
      else if (action.id == 'enterArea')
        ret = enterAreaAction();
      else if (action.id == 'createHabitat')
        createHabitatAction();
      else if (action.id == 'enterHabitat')
        enterHabitatAction();
      else if (action.id == 'skipTurn')
        game.turn();
      else if (action.id == 'createOvum')
        createOvumAction();

      // evolution manager action
      else if (action.type == ACTION_EVOLUTION)
        ret = player.evolutionManager.action(action);

      // action failed
      if (!ret)
        {
          game.updateHUD();
          return;
        }

      player.actionEnergy(action); // spend energy
      actionPost(); // post-action call
    }


// post-action
  public function actionPost()
    {
      // host state: check for energy
      if (player.state == PLR_STATE_HOST)
        {
          if (player.host.energy <= 0)
            {
              game.player.onHostDeath('Your host has expired somewhere in the sewers. You have to find a new one.');

              // close window just in case
              if (game.ui.state != UISTATE_MESSAGE)
                game.ui.state = UISTATE_DEFAULT;
            }
        }

      if (player.energy == 0)
        Const.todo('Zero energy as a result of a region action. Fix this.');

      // update HUD info
      game.updateHUD();
    }


// action: enter area
  function enterAreaAction(): Bool
    {
      // cannot enter corp as parasite
      if (player.state == PLR_STATE_PARASITE &&
          currentArea.info.type == 'corp')
        {
          game.actionFailed("You cannot enter this area without a host.");
          return false;
        }

      // cannot enter area with high alertness
      if (currentArea.alertness >= 75)
        {
          game.actionFailed("This area is too dangerous at the moment.");
          return false;
        }

      target = null;
      game.log(currentArea.info.isInhabited ?
        "You emerge from the sewers." : "You enter the area.");
      game.setLocation(LOCATION_AREA);

      return true;
    }


// action: create habitat
  function createHabitatAction()
    {
      game.log("You have created a habitat in this area.");
      var area = game.region.createArea(AREA_HABITAT);
      area.isHabitat = true;
      area.habitat = new Habitat(game, area);
      currentArea.hasHabitat = true;
      currentArea.habitatAreaID = area.id;
      area.parentID = currentArea.id;
      game.scene.sounds.play('region-habitat');

      // complete goal
      game.goals.complete(GOAL_CREATE_HABITAT);
    }


// action: enter habitat
  function enterHabitatAction()
    {
      var habitatArea = game.region.get(currentArea.habitatAreaID);
      if (game.group.team != null &&
          game.group.team.state == TEAM_AMBUSH &&
          game.group.team.ambushedHabitat != null &&
          currentArea.habitatAreaID == game.group.team.ambushedHabitat.area.id)
        game.log("You enter the habitat. It looks like someone is in here!",
          COLOR_ALERT);
      else game.log("You enter the habitat. You feel much safer here.");

      game.setLocation(LOCATION_AREA, habitatArea);
    }

// action: create ovum
  function createOvumAction()
    {
      game.log("You have spawned an ovum in this area.");
      game.scene.sounds.play('region-ovum');
      var o = new region.Ovum(game, x, y);
      game.region.addObject(o);
      // show info
      o.onMoveTo();
    }

// action: move player by dx,dy
  public function moveAction(dx: Int, dy: Int): Bool
    {
      // parasite state: check for energy
      if (player.state == PLR_STATE_PARASITE)
        {
          if (player.energy < player.vars.regionEnergyPerTurn)
            {
              game.actionFailed("Not enough energy to move in region mode.");
              return false;
            }
        }

      // host state: check for energy
      if (player.state == PLR_STATE_HOST)
        {
          if (player.host.energy <= 0)
            {
              game.player.onHostDeath('Your host has expired somewhere in the sewers. You have to find a new one.');

              // close window just in case
              if (game.ui.state != UISTATE_MESSAGE)
                game.ui.state = UISTATE_DEFAULT;
            }
        }

      // try to move to the new location
      return moveBy(dx, dy);
    }


// create a path to given x,y and start moving on it
  public function setTarget(destx: Int, desty: Int)
    {
      target = { x: destx, y: desty };

      // start moving
      nextPath();
    }


// clear current path (target since path is auto-generated)
  public inline function clearPath()
    {
      target = null;
    }


// move to next path waypoint
// returns true on success
  public function nextPath(): Bool
    {
      // path clear
      if (target == null ||
          (haxe.Timer.stamp() - pathTS) * 1000.0 < game.config.repeatDelay)
        return false;

      var dx = 0;
      var dy = 0;
      if (target.x - x > 0)
        dx = 1;
      else if (target.x - x < 0)
        dx = -1;
      if (target.y - y > 0)
        dy = 1;
      else if (target.y - y < 0)
        dy = -1;
      pathTS = haxe.Timer.stamp();
      var ret = moveAction(dx, dy);
      if (!ret)
        {
          target = null;
          return true;
        }

      // finish
      if (target != null && target.x == x && target.y == y)
        target = null;

      // force update mouse and path
      game.scene.mouse.update(true);

      return true;
    }


// ================================ EVENTS =========================================


// event: host expired
// in region mode we simply destroy it without any repercussions
// simplifying that the body is somewhere in the sewers and probably won't be found
// or if found won't be tied to parasite
// if we add travel by car later, this would have to be changed to accomodate that
  public inline function onHostDeath()
    {
      // call AI death (for NPC and sound)
      player.host.dieRegion();

      // set state
      player.state = PLR_STATE_PARASITE;

      // set entity image
      resetEntity();

      player.host = null;
    }

// reset player entity to parasite
  public function resetEntity()
    {
      // set image
      entity.setMask(-1);
      entity.setIcon('entities', 0, Const.ROW_PARASITE);
    }


// ==================================================================================


// move player by dx, dy
// returns true on success
  public inline function moveBy(dx: Int, dy: Int): Bool
    {
      var nx = x + dx;
      var ny = y + dy;

      return moveTo(nx, ny, true);
    }

// move player to nx, ny
  public function moveTo(nx: Int, ny: Int, doTurn: Bool): Bool
    {
      // cell not walkable
      if (!game.region.isWalkable(nx, ny))
        return false;

      x = nx;
      y = ny;

      // make tiles around player known
      for (yy in (y - 1)...(y + 2))
        for (xx in (x - 1)...(x + 2))
          {
            var a = game.region.getXY(xx, yy);
            if (a == null)
              continue;

            a.isKnown = true;
          }

      entity.setPosition(x, y); // move player entity
      if (doTurn)
        game.turn(); // new turn
      game.updateHUD(); // update HUD info

      // tutorial
      if (game.playerRegion.currentArea.alertness > 20)
        game.goals.complete(GOAL_TUTORIAL_AREA_ALERT);
      var area = game.region.getXY(x, y);
      game.profile.addPediaArticle(area.info.pediaArticle);

      // run trigger on move to
      var o = game.region.getObjectAt(x, y);
      if (o != null)
        o.onMoveTo();

      return true;
    }

// called post-loading game
  public function loadPost()
    {
      entity.setPosition(x, y);
    }


// =========================== GETTERS AND SETTERS ==================================


// get area player is in
  function get_currentArea(): AreaGame
    {
      return game.region.getXY(x, y);
    }
}
