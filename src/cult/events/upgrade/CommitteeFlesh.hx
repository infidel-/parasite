// event definition for the committee flesh political upgrade
package cult.events.upgrade;

import game.Game;
import cult.Cult;
import cult.EventHelper.*;
import cult.effects.*;
import Const;
import Const.d100;

class CommitteeFlesh
{
// builds the committee flesh event descriptor
  public static function create(): _CultEvent
    {
      return {
        type: TYPE_OCCASIO,
        title: 'Committee Flesh',
        text: 'The newly appointed committee chair kneels before dais forged from layered dermal tissue, each fold concealing witness testimony and classified briefs. Hearing chambers pulse with living skin, absorbing testimony into dermal memory. Staffers press palms to the tissue-pulpit, reading witness truth through dermal impressions. Outside observers see only wooden panels, but trusted flesh records the hidden minutes.',
        choices: [
          {
            button: 'Skin Minutes',
            text: 'Record testimony in dermal folds.',
            f: choice1
          },
          {
            button: 'Flesh Gavel',
            text: 'Gavel strikes skin-pulpit.',
            f: choice2
          },
          {
            button: 'Dermal Bind',
            text: 'Bind chair into dermal dais.',
            f: choice3
          }
        ]
      };
    }

// handles skin minutes choice
  public static function choice1(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var failTurns = d100() < 5 ? 10 : 5;
          var drain = new LoseResource(game, failTurns, 'political');
          cult.effects.add(drain);
          cult.logsg('skin minutes bleed into ' + Const.col('cult-effect', drain.customName()) + '.');
          return;
        }
      var amount = rollResourcePayout();
      cult.resources.inc('political', amount);
      cult.logsg('minutes absorbed +' + amount + ' political resource.');
    }

// handles flesh gavel choice
  public static function choice2(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var penalty = rollResourcePayout();
          cult.resources.dec('political', penalty);
          cult.logsg('gavel splinters -' + penalty + ' political resource.');
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new IncreasePower(game, turns, 'political');
      cult.effects.add(effect);
      cult.log('gavel strikes pulse ' + Const.col('cult-effect', effect.customName()) + ' for ' + turns + ' turns.');
    }

// handles dermal bind choice
  public static function choice3(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var aiNeg = cult.getMemberByID(targetID);
          if (aiNeg != null &&
              aiNeg.addTrait(TRAIT_WEAK_WILLED))
            aiNeg.log('bind buckles weak-willed flaw into flesh.');
          return;
        }
      var granted = addTrait(cult, targetID, 'cultBasic', true);
      if (granted == null)
        cult.logsg('dermal bind fuses without new devotion.');
    }
}
