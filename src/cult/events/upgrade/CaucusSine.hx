// event definition for the caucus sine political upgrade
package cult.events.upgrade;

import game.Game;
import cult.Cult;
import cult.EventHelper.*;
import cult.effects.*;
import Const.d100;

class CaucusSine
{
// builds the caucus sine event descriptor
  public static function create(): _CultEvent
    {
      return {
        type: TYPE_OCCASIO,
        title: T('Caucus Sine'),
        text: T('Behind closed caucus doors, the newly appointed whip kneels before sine-wave ribs that resonate with party discipline. Legislative chambers thrum with skeletal harmonics, converting dissent into consonant votes. Aides press ears to the bone-curves, hearing whip counts through harmonic resonance. Outside caucus never feels the true pulse, but trusted bone enforces hidden unity.'),
        choices: [
          {
            button: T('Bone Whip'),
            text: T('Crack bone resonance for discipline.'),
            f: choice1
          },
          {
            button: T('Spine Count'),
            text: T('Count votes through spine resonance.'),
            f: choice2
          },
          {
            button: T('Sine Bind'),
            text: T('Bind whip to sine-bone structure.'),
            f: choice3
          }
        ]
      };
    }

// handles bone whip choice
  public static function choice1(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var aiNeg = cult.getMemberByID(targetID);
          if (aiNeg != null &&
              aiNeg.addTrait(TRAIT_WEAK_WILLED))
            aiNeg.log(T('{ai:The} whip snaps weak-willed flaw into spine.', { ai: aiNeg }));
          return;
        }
      var granted = addTrait(cult, targetID, 'skill', true);
      if (granted == null)
        cult.logsg(T('{cult} bone whip cracks without new skill.', { cult: cult }));
    }

// handles spine count choice
  public static function choice2(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var penalty = rollResourcePayout();
          cult.resources.dec('political', penalty);
          cult.logsg(T('{cult} spine count misfires {n, plural, one{-# political resource} other{-# political resources}}.', {
            cult: cult,
            n: penalty,
          }));
          return;
        }
      var amount = rollResourcePayout();
      cult.resources.inc('political', amount);
      cult.logsg(T('{cult} spine resonates {n, plural, one{+# political resource} other{+# political resources}}.', {
        cult: cult,
        n: amount,
      }));
    }

// handles sine bind choice
  public static function choice3(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var penaltyTurns = d100() < 5 ? 10 : 5;
          var setback = new DecreasePower(game, penaltyTurns, 'political');
          cult.effects.add(setback);
          cult.logsg(T('{cult} bind fractures into {effect}.', {
            cult: cult,
            effect: Const.col('cult-effect', setback.customName()),
          }));
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new IncreasePower(game, turns, 'political');
      cult.effects.add(effect);
      cult.log(T('{cult} sine bind harmonizes {effect} for {turns, plural, one{# turn} other{# turns}}.', {
        cult: cult,
        effect: Const.col('cult-effect', effect.customName()),
        turns: turns,
      }));
    }
}
