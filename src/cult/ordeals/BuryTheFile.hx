// bury the file ordeal - neutralize the group until its priority climbs back
package cult.ordeals;

import game.Game;
import ai.*;
import cult.Ordeal;
import cult.Cult;
import _PlayerAction;

class BuryTheFile extends Ordeal
{
// returns the initiate-menu price hint for this ordeal
  public static function priceHint(): String
    {
      return Const.smallgray(' (') +
        Const.col('cult-power', 20) + ' political, ' +
        Const.col('cult-power', 20) + ' lawfare, ' +
        Const.col('cult-power', 10) + ' media, ' +
        Const.col('cult-power', '500k') + Icon.money +
        Const.smallgray(')');
    }

  public function new(g: Game)
    {
      super(g);
      init();
      initPost(false);

      // the level 3 member leads, two level 2 members assist
      var leaderID = cult.getFreeMembers(3, true)[0];
      addMembers([leaderID]);
      addRandomMembers({
        level: 2,
        amount: 2,
        excluding: leaderID,
        onlyGivenLevel: true,
      });

      power.inc('political', 20);
      power.inc('lawfare', 20);
      power.inc('media', 10);
      power.money = 500000;
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      name = 'Bury the File';
      type = ORDEAL_COMMUNAL;
      requiredMembers = 3;
      requiredMemberLevels = 2;
      actions = requiredMembers;
      note = 'Inter the dread dossier beneath seals and statutes, and let the Group forget.';
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

// cult turn: the group sending a new team first loses the race
  public override function turn()
    {
      raceLost();
    }

// a team spawned before the last payment also loses the race
  public override function check()
    {
      if (raceLost())
        return;
      super.check();
    }

// fail the ordeal if a group team is active
  function raceLost(): Bool
    {
      if (game.group.team == null)
        return false;
      game.message({
        text: 'The Group moved first. A new team has already taken up my file.',
        img: 'pedia/team_basics',
        col: 'alert'
      });
      fail();
      return true;
    }

// handle successful completion
  public override function onSuccess()
    {
      game.group.neutralize();
      game.message({
        text: 'The file lies buried. The Group has forgotten me, for now.',
        img: 'pedia/group',
        col: 'cult'
      });
    }

// static method to add buryTheFile action to actions array
  public static function initiateAction(game: Game, cult: Cult, actions: Array<_PlayerAction>): Void
    {
      // only a known group between teams, with a free level 3 member and two level 2 members
      if (!game.group.isKnown ||
          game.group.isNeutralized ||
          game.group.team != null ||
          cult.getFreeMembers(3, true).length == 0 ||
          cult.getFreeMembers(2, true).length < 2)
        return;

      actions.push({
        id: 'buryTheFile',
        type: ACTION_CULT,
        name: 'Bury the File' + priceHint(),
        energy: 0,
        obj: {}
      });
    }
}
