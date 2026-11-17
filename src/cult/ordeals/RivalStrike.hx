// strike marked members of a rival cult in the city
package cult.ordeals;

import l10n.Loc;
import cult.Cult;
import cult.Ordeal;
import cult.missions.CombatTargetsWithGuards;
import _PlayerAction;

class RivalStrike extends Ordeal
{
  // pressure on the player's base that a won strike takes off
  public static inline var PRESSURE_RELIEF = 5;
  public var rivalCultID: Int;

// create a strike on a rival: two members and a mission against some of its roster
  public function new(g: game.Game, rivalCultID: Int)
    {
      super(g);
      init();
      this.rivalCultID = rivalCultID;
      initPost(false);
      addRandomMembers({
        level: 1,
        amount: 2,
      });
      missions.push(new CombatTargetsWithGuards(game, CombatTargetsWithGuards.rivalInfo(), rivalCultID));
    }

// init ordeal fields
  public override function init()
    {
      super.init();
      name = N('Strike Rival Cult');
      type = ORDEAL_COMMUNAL;
      requiredMembers = 2;
      rivalCultID = -1;
      note = N('Kill marked members of the rival in the city.');
    }

// get custom name for display
  public override function customName(): String
    {
      var rival = game.getRivalCultByID(rivalCultID);
      if (rival != null)
        return Loc.tr(name) + ' (' + rival.customName() + ')';
      return Loc.tr(name);
    }

// adds strike actions for rivals revealed at least once that have members besides their leader, one strike
// per rival at a time
  public static function initiateAction(cult: Cult, actions: Array<_PlayerAction>)
    {
      for (rival in cult.game.getRivalCults(true))
        {
          if (rival.rivalRevealedLevel < 1 ||
              rival.members.length < 2)
            continue;
          var running = false;
          for (ordeal in cult.ordeals.list)
            if (Std.isOfType(ordeal, RivalStrike) &&
                cast(ordeal, RivalStrike).rivalCultID == rival.id)
              running = true;
          if (running)
            continue;
          actions.push({
            id: 'rivalStrike',
            type: ACTION_CULT,
            name: T('Strike {cult}', { cult: Loc.tr(rival.name) }),
            energy: 0,
            obj: { rivalCultID: rival.id }
          });
        }
    }

// the marked members are dead and out of the roster: the rival is weaker and the base breathes
  override function onSuccess()
    {
      game.getRivalCultByID(rivalCultID).recalc();
      if (cult.base != null)
        cult.base.attackPressure = Std.int(Math.max(0, cult.base.attackPressure - PRESSURE_RELIEF));
    }

// a failed strike may leave the rival a recruit stronger
  override function onFail()
    {
      if (Std.random(100) < const.CultConst.RIVAL_FAIL_RECRUIT_PCT)
        game.getRivalCultByID(rivalCultID).recruitMember();
    }
}
