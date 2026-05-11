// research a rival cult
package cult.ordeals;

import cult.Cult;
import cult.Ordeal;
import _PlayerAction;

class RivalResearch extends Ordeal
{
  public var rivalCultID: Int;

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

      // pick 2 random power types (including money)
      var allTypes = ['media', 'lawfare', 'corporate', 'political', 'money'];
      var shuffled = [];
      for (t in allTypes)
        shuffled.push(t);
      shuffled.sort(function(a, b) return Std.random(3) - 1);
      var type = shuffled[0];
      if (type == 'money')
        power.money = 40000;
      else
        power.inc(type, 2);
    }

// init ordeal fields
  public override function init()
    {
      super.init();
      name = 'Research Rival Cult';
      type = ORDEAL_COMMUNAL;
      requiredMembers = 2;
      actions = requiredMembers;
      rivalCultID = -1;
      note = 'Find names, habits, and finally the rival base.';
    }

// increases reveal level and creates base area when fully known
  public override function onSuccess()
    {
      var rival = game.getRivalCultByID(rivalCultID);
      rival.rivalRevealedLevel++;
      if (rival.rivalRevealedLevel >= 3 &&
          rival.rivalBaseAreaID < 0)
        {
          var area = game.region.getRandom({
            noMission: true,
            noEvents: true,
            noThrow: true,
            type: AREA_CORP
          });
          if (area == null)
            area = game.region.getRandom({
              noMission: true,
              noThrow: true,
              type: AREA_CORP
            });
          if (area == null)
            return;
          rival.rivalBaseAreaID = area.id;
        }
      cult.log('reveals more about ' + rival.name);
    }

// adds one research action per active hidden rival
  public static function initiateAction(cult: Cult, actions: Array<_PlayerAction>)
    {
      for (rival in cult.game.getRivalCults(true))
        {
          if (rival.rivalRevealedLevel >= 3)
            continue;
          actions.push({
            id: 'rivalResearch',
            type: ACTION_CULT,
            name: 'Research ' + rival.name,
            energy: 0,
            obj: { rivalCultID: rival.id }
          });
        }
    }
}
