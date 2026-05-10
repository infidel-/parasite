// attack a revealed rival cult base
package cult.ordeals;

import cult.Cult;
import cult.Ordeal;
import cult.missions.RivalBase;
import _PlayerAction;

class RivalAttack extends Ordeal
{
  public var rivalCultID: Int;

  public function new(g: game.Game, rivalCultID: Int)
    {
      super(g);
      this.rivalCultID = rivalCultID;
      init();
      initPost(false);
      var rival = game.getRivalCultByID(rivalCultID);
      missions.push(new RivalBase(game, rivalCultID,
        rival.rivalBaseAreaID));
    }

// init ordeal fields
  public override function init()
    {
      super.init();
      name = 'Attack Rival Base';
      type = ORDEAL_COMMUNAL;
      actions = 0;
      rivalCultID = -1;
      note = 'Destroy the rival sanctum.';
    }

// adds attack actions for fully revealed rivals
  public static function initiateAction(cult: Cult, actions: Array<_PlayerAction>)
    {
      for (rival in cult.game.getRivalCults(true))
        {
          if (rival.rivalRevealedLevel < 3 ||
              rival.rivalBaseAreaID < 0)
            continue;
          actions.push({
            id: 'rivalAttack',
            type: ACTION_CULT,
            name: 'Attack ' + rival.name,
            energy: 0,
            obj: { rivalCultID: rival.id }
          });
        }
    }
}
