// gather clues ordeal - anthropomancy
package cult.ordeals;

import game.Game;
import ai.*;
import cult.Ordeal;
import cult.Cult;
import _PlayerAction;
import scenario.Event;

class GatherClues extends Ordeal
{
  static inline var alienShipReceiveTriesVar = 'gatherCluesAlienShipReceiveTries';
  static inline var alienShipCompleteTriesVar = 'gatherCluesAlienShipCompleteTries';

  public var memberType: String; // job type of the member

// returns the initiate-menu price hint for this ordeal
  public static function priceHint(): String
    {
      return Const.smallgray(' (') +
        Const.col('cult-power', '200k') + Icon.money +
        Const.smallgray(', ') +
        Const.col('cult-power', 10) + ' PWR' +
        Const.smallgray(')');
    }

  public function new(g: Game)
    {
      super(g);
      init();
      initPost(false);

      // get one random free level 3 member
      var free = cult.getFreeMembers(3, true);
      var mid = free[Std.random(free.length)];
      var m = cult.getMemberByID(mid);
      
      // get member job group and convert to string
      var job = game.jobs.getJobInfo(m.job);
      this.memberType = (job != null ? game.jobs.groupToName(job.group) : 'combat');
      addMembers([mid]);
      
      // set power based on member type
      power.inc(memberType, 10);
      power.money = 200000;
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      name = 'Anthropomancy';
      type = ORDEAL_COMMUNAL;
      requiredMembers = 1;
      requiredMemberLevels = 3;
      actions = requiredMembers;
      note = 'A master haruspex reads the entrails of fate to uncover hidden knowledge.';
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }

// handle member death
  public override function onDeath(aidata: AIData)
    {
      fail();
    }

// handle successful completion
  public override function onSuccess()
    {
      var hadShipGoal = game.goals.has(SCENARIO_ALIEN_FIND_SHIP);
      var forceSpecificClue = getAlienShipSpecificClue();
      var clueRolls = (forceSpecificClue != null ? 2 : 3);

      // give the usual random clue bundles first
      for (i in 0...clueRolls)
        learnRandomClues();

      // replace the last random bundle with a specific ship clue when needed
      if (forceSpecificClue != null)
        {
          if (!applyAlienShipSpecificClue(forceSpecificClue))
            learnRandomClues();
        }

      // reset pity counters once the ship goal advances naturally or through pity
      if (!hadShipGoal &&
          (game.goals.has(SCENARIO_ALIEN_FIND_SHIP) ||
            game.goals.completed(SCENARIO_ALIEN_FIND_SHIP)))
        {
          game.timeline.setVar(alienShipReceiveTriesVar, 0);
          game.timeline.setVar(alienShipCompleteTriesVar, 0);
        }
      else if (hadShipGoal &&
          game.goals.completed(SCENARIO_ALIEN_FIND_SHIP))
        game.timeline.setVar(alienShipCompleteTriesVar, 0);
    }

// learn one random timeline clue bundle
  function learnRandomClues()
    {
      var event = game.timeline.getRandomLearnableEvent();
      if (event != null)
        game.timeline.learnClues(event, false);
    }

// get the next specific ship clue for anthropomancy
  function getAlienShipSpecificClue(): String
    {
      if (game.scenarioStringID != 'alien' ||
          game.goals.completed(SCENARIO_ALIEN_FIND_SHIP))
        return null;

      if (game.goals.has(SCENARIO_ALIEN_FIND_SHIP))
        {
          var tries = game.timeline.getIntVar(alienShipCompleteTriesVar) + 1;
          game.timeline.setVar(alienShipCompleteTriesVar, tries);

          if (tries >= 2)
            return 'complete';
          return 'shipNote';
        }

      var tries = game.timeline.getIntVar(alienShipReceiveTriesVar) + 1;
      game.timeline.setVar(alienShipReceiveTriesVar, tries);
      if (tries >= 3)
        return 'receive';

      return null;
    }

// apply a specific ship clue for anthropomancy
  function applyAlienShipSpecificClue(type: String): Bool
    {
      switch (type)
        {
          case 'receive':
            if (game.goals.has(SCENARIO_ALIEN_FIND_SHIP) ||
                game.goals.completed(SCENARIO_ALIEN_FIND_SHIP))
              return false;

            var event = getAlienShipReceiveEvent();
            return (event != null ? event.learnNote() : false);

          case 'shipNote':
            if (!game.goals.has(SCENARIO_ALIEN_FIND_SHIP) ||
                game.goals.completed(SCENARIO_ALIEN_FIND_SHIP))
              return false;

            var event = game.timeline.getEvent('alienShipStudy');
            return (event != null ? event.learnNote() : false);

          case 'complete':
            if (!game.goals.has(SCENARIO_ALIEN_FIND_SHIP) ||
                game.goals.completed(SCENARIO_ALIEN_FIND_SHIP))
              return false;

            var event = game.timeline.getEvent('alienShipStudy');
            return (event != null ? event.learnLocation() : false);
        }

      return false;
    }

// get the branch event that can reveal the ship goal
  function getAlienShipReceiveEvent(): Event
    {
      var event = game.timeline.getEvent('liveAlienStudy');
      if (event != null)
        return event;

      return game.timeline.getEvent('deadAlienStudy');
    }

// static method to add gatherClues action to actions array
  public static function initiateAction(game: Game, cult: Cult, actions: Array<_PlayerAction>): Void
    {
      // check if there are free level 3 members and timeline is enabled
      var free = cult.getFreeMembers(3, true);
      if (free.length < 1 ||
          !game.player.vars.timelineEnabled)
        return;
      
      actions.push({
        id: 'gatherClues',
        type: ACTION_CULT,
        name: 'Anthropomancy' + priceHint(),
        energy: 0,
        obj: {}
      });
    }
}
