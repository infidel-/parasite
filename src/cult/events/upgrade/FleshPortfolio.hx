// event definition for the flesh portfolio corporate upgrade
package cult.events.upgrade;

import game.Game;
import cult.Cult;
import cult.EventHelper.*;
import cult.effects.*;
import Const.d100;

class FleshPortfolio
{
// builds the flesh portfolio event descriptor
  public static function create(): _CultEvent
    {
      return {
        type: TYPE_OCCASIO,
        title: 'Flesh Portfolio',
        text: 'Asset management vault hums as the newly promoted portfolio manager kneels before a ledger woven from living dermal tissue. Each trade sends portfolio allocations scrolling across translucent skin. Around the safe room, other managers press palms against the membrane, reading the market\'s dermal patterns. The outside auditors never see the true holdings, but trusted skin carries the insider trades.',
        choices: [
          {
            button: 'Skin Trade',
            text: 'Trade derivatives through the dermal-ledger to arbitrage price differentials.',
            f: choice1
          },
          {
            button: 'Flesh Fund',
            text: 'Allocate capital through the skin-membrane to fund covert operations.',
            f: choice2
          },
          {
            button: 'Tissue Trust',
            text: 'Inscribe the promoted manager into the skin-ledger to manage eternal assets.',
            f: choice3
          }
        ]
      };
    }

// handles the skin trade choice outcome
  public static function choice1(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var loss = rollMoneyPayout();
          cult.resources.dec('money', loss);
          cult.logsg('audit ghost clips ' + Const.col('cult-power', '-' + loss) + Icon.money + '.');
          return;
        }
      var amount = rollMoneyPayout();
      cult.resources.money += amount;
      cult.logsg('skin trade clears ' + Const.col('cult-power', '+' + amount) + Icon.money + '.');
    }

// handles the flesh fund choice outcome
  public static function choice2(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var penaltyTurns = d100() < 5 ? 10 : 5;
          var setback = new LoseResource(game, penaltyTurns, 'corporate');
          cult.effects.add(setback);
          cult.logsg('fund leak bleeds into ' + Const.col('cult-effect', setback.customName()) + '.');
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new GainResource(game, turns, 'corporate');
      cult.effects.add(effect);
      cult.log('flesh fund channels ' + Const.col('cult-effect', effect.customName()) + ' for ' + turns + ' turns.');
    }

// handles the tissue trust choice outcome
  public static function choice3(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var aiNeg = cult.getMemberByID(targetID);
          if (aiNeg != null &&
              aiNeg.addTrait(TRAIT_WEAK_WILLED))
            aiNeg.log('buckles under the trust and gains the weak-willed flaw.');
          return;
        }
      var granted = addTrait(cult, targetID, 'mind', true);
      if (granted == null)
        {
          cult.logsg('trust charter remains unsigned.');
          return;
        }
      var ai = cult.getMemberByID(targetID);
      if (ai != null)
        ai.log('holds the ' + granted.name + ' trust, managing eternal assets.');
    }
}
