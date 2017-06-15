// player state (region mode)

package game;

import com.haxepunk.HXP;
import openfl.Lib;

import entities.PlayerEntity;
import const.WorldConst;

class PlayerRegion
{
  var game: Game; // game state link
  var player: Player; // player state link

  public var currentArea(get, null): AreaGame; // area player is in

  public var entity: PlayerEntity; // player ui entity (region mode)
  public var x: Int; // x,y on grid
  public var y: Int;
  public var target(default, null): { x: Int, y: Int }; // current player target x,y
  var pathTS: Int; // last time player moved to target


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
      game.scene.add(entity);
      entity.visible = false;
    }


// end of turn for player (in region mode)
  public function turn()
    {
      // automatically gain control over host each turn
      if (player.state == PLR_STATE_HOST && player.hostControl < 100)
        player.hostControl += 25;
    }


// ==============================   ACTIONS   =======================================


// helper: add action to list by string  id and check for energy
  inline function addActionToList(list: List<_PlayerAction>, name: String)
    {
      var action = Const.getAction(name);
      if (action.energy <= player.energy)
        list.add(action);
    }


// helper: add action to list and check for energy
  inline function addActionToList2(list: List<_PlayerAction>, action: _PlayerAction)
    {
      if (action.energy <= player.energy)
        list.add(action);
    }


// get actions list (area mode)
  public function getActionList(): List<_PlayerAction>
    {
      var tmp = new List<_PlayerAction>();

      // enter area
      if (currentArea.info.canEnter)
        addActionToList(tmp, 'enterArea');

      // create a new habitat
      if (player.evolutionManager.getLevel(IMP_MICROHABITAT) > 0 &&
          !currentArea.hasHabitat && currentArea.info.isInhabited)
        {
          // count total number of habitats
          var params = player.evolutionManager.getParams(IMP_MICROHABITAT);
          var maxHabitats = params.numHabitats;
          var numHabitats = game.region.getHabitatsCount();

          if (numHabitats < maxHabitats)
            addActionToList2(tmp, {
              id: 'createHabitat',
              type: ACTION_REGION,
              name: 'Create habitat',
              energy: 10 });
        }

      // enter habitat
      if (currentArea.hasHabitat)
        addActionToList2(tmp, {
          id: 'enterHabitat',
          type: ACTION_REGION,
          name: 'Enter habitat',
          energy: 0 });

      return tmp;
    }


// do a player action by string id
// action energy availability is checked when the list is formed
  public function action(action: _PlayerAction)
    {
      var ret = true;

      if (action.id == 'enterArea')
        ret = enterAreaAction();
      else if (action.id == 'createHabitat')
        createHabitatAction();
      else if (action.id == 'enterHabitat')
        enterHabitatAction();

      // action failed
      if (!ret)
        {
          game.updateHUD();
          return;
        }

      player.energy -= action.energy;

      if (player.energy == 0)
        Const.todo('Zero energy as a result of a region action. Fix this.');

      // update HUD info
      game.updateHUD();
    }


// action: enter area
  function enterAreaAction(): Bool
    {
      // cannot enter area with high alertness
      if (currentArea.alertness >= 75)
        {
          game.log("This area is too dangerous at the moment.", COLOR_HINT);
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
      area.parent = currentArea;
      game.scene.region.updateIconsArea(x, y);

      // complete goal
      game.goals.complete(GOAL_CREATE_HABITAT);
    }


// action: enter habitat
  function enterHabitatAction()
    {
      var habitatArea = game.region.get(currentArea.habitatAreaID);
      if (game.group.team != null && game.group.team.state == TEAM_AMBUSH)
        game.log("You enter the habitat. It looks like someone is here!");
      else game.log("You enter the habitat. You feel much safer here.");

      game.setLocation(LOCATION_AREA, habitatArea);
    }


// action: move player by dx,dy
  public function moveAction(dx: Int, dy: Int): Bool
    {
      // parasite state: check for energy
      if (player.state == PLR_STATE_PARASITE)
        {
          if (player.energy < player.vars.regionEnergyPerTurn)
            {
              game.log("Not enough energy to move in region mode.",
                COLOR_HINT);
              return false;
            }
        }

      // host state: check for energy
      if (player.state == PLR_STATE_HOST)
        {
          if (player.host.energy <= 0)
            {
              onHostDeath();

              game.log('Your host has expired somewhere in the sewers. You have to find a new one.');
              game.scene.state = UISTATE_DEFAULT; // close window just in case
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


// move to next path waypoint
  public function nextPath()
    {
      // path clear
      if (target == null || Lib.getTimer() - pathTS < game.config.pathDelay)
        return;

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
      pathTS = Lib.getTimer();
      var ret = moveAction(dx, dy);
      if (!ret)
        {
          target = null;
          return;
        }

      // finish
      if (target.x == x && target.y == y)
        target = null;
    }


// ================================ EVENTS =========================================


// event: host expired
// in region mode we simply destroy it without any repercussions
// simplifying that the body is somewhere in the sewers and probably won't be found
// or if found won't be tied to parasite
// if we add travel by car later, this would have to be changed to accomodate that
  public inline function onHostDeath()
    {
      // set state
      player.state = PLR_STATE_PARASITE;

      // set image
      entity.setMask(Const.FRAME_EMPTY, Const.ROW_PARASITE);
      entity.setImage(Const.FRAME_DEFAULT, Const.ROW_PARASITE);

      // make player entity visible again
      entity.visible = true;

      player.host = null;
    }


// ==================================================================================


// move player by dx, dy
// returns true on success
  public inline function moveBy(dx: Int, dy: Int): Bool
    {
      var nx = x + dx;
      var ny = y + dy;

      return moveTo(nx, ny);
    }


// move player to nx, ny
  public function moveTo(nx, ny): Bool
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

      game.region.updateVisibility(); // update visibility of tiles

      game.turn(); // new turn

      game.updateHUD(); // update HUD info

      // update AI visibility to player
//      region.updateVisibility();

      return true;
    }


// =========================== GETTERS AND SETTERS ==================================


// get area player is in
  function get_currentArea(): AreaGame
    {
      return game.region.getXY(x, y);
    }
}
