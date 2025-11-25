// event definition for the fund graft political upgrade
package cult.events.upgrade;

import game.Game;
import cult.Cult;
import cult.EventHelper.*;
import cult.effects.*;
import Const.d100;

class FundGraft
{
// builds the fund graft event descriptor
  public static function create(): _CultEvent
    {
      return {
        type: TYPE_OCCASIO,
        title: 'Fund Graft',
        text: 'In a sub-basement vault, the newly appointed treasurer kneels before grafted veins that pump PAC money through political arteries. Campaign war chests throb with living blood, each heartbeat sending contributions through arterial networks. Fundraisers press palms to vein-walls, feeling donor pressure build. Outside watchdogs never trace the true flow, but trusted blood delivers the dark money.',
        choices: [
          {
            button: 'Artery Pump',
            text: 'Pump PAC through arteries.',
            f: choice1
          },
          {
            button: 'Graft Count',
            text: 'Count dark money flow.',
            f: choice2
          },
          {
            button: 'Vein Ledger',
            text: 'Bind treasurer to vein-books.',
            f: choice3
          }
        ]
      };
    }

// handles artery pump choice
  public static function choice1(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var loss = rollMoneyPayout();
          cult.resources.dec('money', loss);
          cult.logsg('artery rupture bleeds ' + Const.col('cult-power', '-' + loss) + Icon.money + '.');
          return;
        }
      var amount = rollMoneyPayout();
      cult.resources.money += amount;
      cult.logsg('pump flows ' + Const.col('cult-power', '+' + amount) + Icon.money + '.');
    }

// handles graft count choice
  public static function choice2(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var failTurns = d100() < 5 ? 10 : 5;
          var drain = new LoseResource(game, failTurns, 'political');
          cult.effects.add(drain);
          cult.logsg('graft rejection spills ' + Const.col('cult-effect', drain.customName()) + '.');
          return;
        }
      var amount = rollResourcePayout();
      cult.resources.inc('political', amount);
      cult.logsg('graft yields +' + amount + ' political resource.');
    }

// handles vein ledger choice
  public static function choice3(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var aiNeg = cult.getMemberByID(targetID);
          if (aiNeg != null &&
              aiNeg.addTrait(TRAIT_VORACIOUS_ACCOUNTS))
            aiNeg.log('vein ledger consumes mind, spawning voracious flaw.');
          return;
        }
      var granted = addTrait(cult, targetID, 'cultBasic', true);
      if (granted == null)
        cult.logsg('vein ledger closes without new devotion.');
    }
}
