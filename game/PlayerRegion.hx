// player state (region mode)

package game;

import com.haxepunk.HXP;

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


  public function new(g: Game)
    {
      game = g;
      player = game.player;

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
      if (player.skills.has(KNOW_HABITAT) && !currentArea.hasHabitat)
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
      if (action.id == 'enterArea')
        enterAreaAction();
      else if (action.id == 'createHabitat')
        createHabitatAction();
      else if (action.id == 'enterHabitat')
        enterHabitatAction();

      player.energy -= action.energy;

      if (player.energy == 0)
        Const.todo('Zero energy as a result of a region action. Fix this.');

      // update HUD info
      game.updateHUD();
    }


// action: enter area
  function enterAreaAction()
    {
      game.log(currentArea.info.isInhabited ?
        "You emerge from the sewers." : "You enter the area.");
      game.setLocation(LOCATION_AREA);
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
        game.log("You enter the habitat. Looks like someone is here!");
      else game.log("You enter the habitat. You feel much safer here.");

      game.setLocation(LOCATION_AREA, habitatArea);
    }


// action: move player by dx,dy
  public function moveAction(dx: Int, dy: Int)
    {
      // parasite state: check for energy
      if (player.state == PLR_STATE_PARASITE)
        {
          if (player.energy < player.vars.regionEnergyPerTurn)
            {
              game.log("Not enough energy to move in region mode.");
              return;
            }

//          player.energy -= player.vars.regionMoveEnergy;
        }

      // host state: check for energy
      if (player.state == PLR_STATE_HOST)
        {
//          player.host.energy -= player.vars.regionMoveEnergy;
          if (player.host.energy <= 0)
            {
              onHostDeath();

              game.log('Your host has expired somewhere in the sewers. You have to find a new one.');
              game.scene.setState(HUDSTATE_DEFAULT); // close window just in case
            }
        }

      // try to move to the new location
      moveBy(dx, dy);
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
