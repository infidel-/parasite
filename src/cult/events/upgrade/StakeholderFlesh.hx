// event definition for the stakeholder flesh corporate upgrade
package cult.events.upgrade;

import game.Game;
import cult.Cult;
import cult.EventHelper.*;
import cult.effects.*;
import Const.d100;

class StakeholderFlesh
{
// builds the proxy flesh event descriptor
  public static function create(): _CultEvent
    {
      return {
        type: TYPE_OCCASIO,
        title: 'Stakeholder Flesh',
        text: 'Conference room leather bleeds as the newly promoted director kneels before a stakeholder table of living flesh. The surface pulses with buried capillaries. Around the slab, other stakeholders press palms to the membrane, feeling dividends whisper through arterial channels. The outside investors never hear the true returns, but trusted flesh carries the stakeholder flow.',
        choices: [
          {
            button: 'Proxy Rally',
            text: 'Stage a midnight proxy rally, pumping adrenal hymnals through the corporate loudspeakers.',
            f: choice1
          },
          {
            button: 'Flesh Run',
            text: 'Re-route flesh vans under police scanners to restock forward depots before the dawn curfew bites.',
            f: choice2
          },
          {
            button: 'Stake Dark',
            text: 'Seclude the promoted director with stakeholder handlers to stitch blackout routes and clandestine contact trees.',
            f: choice3
          }
        ]
      };
    }

// handles the proxy rally choice outcome
  public static function choice1(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var penaltyTurns = d100() < 5 ? 10 : 5;
          var setback = new DecreasePower(game, penaltyTurns, 'corporate');
          cult.effects.add(setback);
          cult.logsg('overextensions bleed into ' + Const.col('cult-effect', setback.customName()) + '.');
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new IncreasePower(game, turns, 'corporate');
      cult.effects.add(effect);
      cult.logsg('stirs fury into ' + Const.col('cult-effect', effect.customName()) + ' for ' + turns + ' turns.');
    }

// handles the proxy run choice outcome
  public static function choice2(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var penalty = rollMoneyPayout();
          cult.resources.dec('money', penalty);
          cult.logsg('bandits ambush, clipping ' + Const.col('cult-power', '-' + penalty) + Icon.money + '.');
          return;
        }
      var amount = rollMoneyPayout();
      cult.resources.money += amount;
      cult.logsg('channels +' + amount + Icon.money + ' into reserves.');
    }

// handles the proxy dark choice outcome
  public static function choice3(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var aiNeg = cult.getMemberByID(targetID);
          if (aiNeg != null &&
              aiNeg.addTrait(TRAIT_WEAK_WILLED))
            aiNeg.log('buckles under the sealed refrain, inheriting the weak-willed flaw.');
          return;
        }
      var granted = addTrait(cult, targetID, 'mind', true);
      if (granted == null)
        {
          cult.logsg('proxy dark flares without gifting new insight.');
          return;
        }
      var ai = cult.getMemberByID(targetID);
      if (ai != null)
        ai.log('holds ' + granted.name + ' close, sworn to the hidden proxy.');
    }
}
