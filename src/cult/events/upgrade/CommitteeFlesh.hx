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
        title: T('Committee Flesh'),
        text: T('The newly appointed committee chair kneels before dais forged from layered dermal tissue, each fold concealing witness testimony and classified briefs. Hearing chambers pulse with living skin, absorbing testimony into dermal memory. Staffers press palms to the tissue-pulpit, reading witness truth through dermal impressions. Outside observers see only wooden panels, but trusted flesh records the hidden minutes.'),
        choices: [
          {
            button: T('Skin Minutes'),
            text: T('Record testimony in dermal folds.'),
            f: choice1
          },
          {
            button: T('Flesh Gavel'),
            text: T('Gavel strikes skin-pulpit.'),
            f: choice2
          },
          {
            button: T('Dermal Bind'),
            text: T('Bind chair into dermal dais.'),
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
          cult.logsg(T('{cult} skin minutes bleed into {effect}.', {
            cult: cult,
            effect: Const.col('cult-effect', drain.customName()),
          }));
          return;
        }
      var amount = rollResourcePayout();
      cult.resources.inc('political', amount);
      cult.logsg(T('{cult} minutes absorbed {n, plural, one{+# political resource} other{+# political resources}}.', {
        cult: cult,
        n: amount,
      }));
    }

// handles flesh gavel choice
  public static function choice2(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var penalty = rollResourcePayout();
          cult.resources.dec('political', penalty);
          cult.logsg(T('{cult} gavel splinters {n, plural, one{-# political resource} other{-# political resources}}.', {
            cult: cult,
            n: penalty,
          }));
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new IncreasePower(game, turns, 'political');
      cult.effects.add(effect);
      cult.log(T('{cult} gavel strikes pulse {effect} for {turns, plural, one{# turn} other{# turns}}.', {
        cult: cult,
        effect: Const.col('cult-effect', effect.customName()),
        turns: turns,
      }));
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
            aiNeg.log(T('{ai:The} bind buckles weak-willed flaw into flesh.', { ai: aiNeg }));
          return;
        }
      var granted = addTrait(cult, targetID, 'cultBasic', true);
      if (granted == null)
        cult.logsg(T('{cult} dermal bind fuses without new devotion.', { cult: cult }));
    }
}
