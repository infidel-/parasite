// cult ordeals management class
package cult;

import game.Game;
import game.AreaGame;
import _PlayerAction;
import ai.AIData;
import cult.ordeals.*;
import cult.ordeals.profane.*;
import cult.ProfaneOrdeal;

class Ordeals extends _SaveObject
{
  static var _ignoredFields = [ 'cult' ];
  public var game: Game;
  public var list: Array<Ordeal>; // active ordeals
  public var profaneTimeout: Int; // timeout after profane ordeal completion/failure
  public var cult(get, never): Cult;
  function get_cult() return game.cults[0];

  public function new(g: Game)
    {
      game = g;
      list = [];
      init();
      initPost(false);
    }

// init object before loading/post creation
// NOTE: new object fields should init here!
  public function init()
    {
      profaneTimeout = 0;
    }

// called after load or creation
  public function initPost(onLoad: Bool)
    {
    }

// handle member death
  public function onDeath(aidata: AIData)
    {
      for (ordeal in list)
        ordeal.onDeath(aidata);
    }

// fail an ordeal
  public function fail(ordeal: Ordeal)
    {
      cult.log('ordeal ' + ordeal.coloredName() + ' has failed');

      // increment profane timeout if this was a profane ordeal
      if (ordeal.type == ORDEAL_PROFANE)
        profaneTimeout = 10 + Const.roll(1, 4);

      list.remove(ordeal);

      // reset cult UI to root state
      game.ui.cult.reset();
    }

// complete an ordeal successfully
  public function success(ordeal: Ordeal)
    {
      cult.log('ordeal ' + ordeal.coloredName() + ' completed successfully');

      // increment profane timeout if this was a profane ordeal
      if (ordeal.type == ORDEAL_PROFANE)
        profaneTimeout = 10 + Const.roll(1, 4);

      list.remove(ordeal);

      // reset cult UI to root state
      game.ui.cult.reset();
    }

// turn processing for ordeals
  public function turn()
    {
      // reset actions counter for all active ordeals
      for (ordeal in list)
        {
          ordeal.actions = 0;

          // turn effects
          for (effect in ordeal.effects)
            effect.turn(cult, 1);

          // handle profane ordeal effects and timer
          if (ordeal.type == ORDEAL_PROFANE)
            {
              var profane: ProfaneOrdeal = cast ordeal;
              
              // decrease timer and check for failure
              profane.timer--;
              if (profane.timer <= 0)
                profane.fail();
            }
        }
      
      // decrement profane timeout
      if (profaneTimeout > 0)
        profaneTimeout--;
      
      // check for spawning new profane ordeals
      turnSpawnProfane();
    }

// check for spawning new profane ordeals
  function turnSpawnProfane()
    {
      // check cult size
      if (cult.members.length < 3)
        return;

      // for now cult must have free members
      // might change later
      var free = cult.getFreeMembers(1);
      if (free.length < 2)
        return;

      // count profane ordeals
      var profaneCount = 0;
      for (ordeal in list)
        {
          if (ordeal.type == ORDEAL_PROFANE)
            profaneCount++;
        }

      // check profane ordeal limit based on cult size
      if (cult.members.length < 6)
        {
          // must have 0 profane ordeals
          if (profaneCount > 0)
            return;
        }
      else
        {
          // must have < 2 profane ordeals
          if (profaneCount >= 2)
            return;
        }

      // check random chance
      if (Const.d100() >= 20)
        return;

      // check timeout
      if (profaneTimeout != 0)
        return;

      // spawn new profane ordeal
      var newOrdeal: ProfaneOrdeal = new GenericProfaneOrdeal(game);
      list.push(newOrdeal);
      game.message('A tribulation most foul has descended upon us: ' + newOrdeal.coloredName() + '.', null, COLOR_DEFAULT);
    }

// get initiate ordeal actions
  public function getInitiateOrdealActions(): Array<_PlayerAction>
    {
      // check for block communal effect
      var actions: Array<_PlayerAction> = [];
      if (cult.effects.has(CULT_EFFECT_BLOCK_COMMUNAL))
        return actions;

      RecruitFollower.initiateAction(cult, actions);
      UpgradeFollower.initiateAction(cult, actions);
      UpgradeFollower2.initiateAction(cult, actions);
      GatherClues.initiateAction(game, cult, actions);

      return actions;
    }

// handle action execution
// menu returns to root after this action
  public function action(action: _PlayerAction)
    {
      var ordeal: Ordeal = null;
      var o = action.obj;
      switch (action.id)
        {
          case 'recruit':
            ordeal = new RecruitFollower(game, o.type);
          case 'upgrade':
            ordeal = new UpgradeFollower(game, o.targetID, 1);
          case 'upgrade2':
            ordeal = new UpgradeFollower2(game, o.targetID);
          case 'gatherClues':
            ordeal = new GatherClues(game);
          default:
            return;
        }
      if (ordeal != null)
        {
          list.push(ordeal);
          game.ui.updateWindow();
        }
    }

// check if the provided area is a mission area
  public function isMissionArea(area: AreaGame): Bool
    {
      for (ordeal in list)
        for (m in ordeal.missions)
          if (!m.isCompleted &&
              m.x == area.x &&
              m.y == area.y)
            return true;
      return false;
    }

// get mission for the provided area
  public function getAreaMission(area: AreaGame): Mission
    {
      for (ordeal in list)
        for (m in ordeal.missions)
          if (!m.isCompleted &&
              m.x == area.x &&
              m.y == area.y)
            return m;
      return null;
    }
}
