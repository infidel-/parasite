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
        title: 'Caucus Sine',
        text: 'Behind closed caucus doors, the newly appointed whip kneels before sine-wave ribs that resonate with party discipline. Legislative chambers thrum with skeletal harmonics, converting dissent into consonant votes. Aides press ears to the bone-curves, hearing whip counts through harmonic resonance. Outside caucus never feels the true pulse, but trusted bone enforces hidden unity.',
        choices: [
          {
            button: 'Bone Whip',
            text: 'Crack bone resonance for discipline.',
            f: choice1
          },
          {
            button: 'Spine Count',
            text: 'Count votes through spine resonance.',
            f: choice2
          },
          {
            button: 'Sine Bind',
            text: 'Bind whip to sine-bone structure.',
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
            aiNeg.log('whip snaps weak-willed flaw into spine.');
          return;
        }
      var granted = addTrait(cult, targetID, 'skill', true);
      if (granted == null)
        cult.logsg('bone whip cracks without new skill.');
    }

// handles spine count choice
  public static function choice2(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var penalty = rollResourcePayout();
          cult.resources.dec('political', penalty);
          cult.logsg('spine count misfires -' + penalty + ' political resource.');
          return;
        }
      var amount = rollResourcePayout();
      cult.resources.inc('political', amount);
      cult.logsg('spine resonates +' + amount + ' political resource.');
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
          cult.logsg('bind fractures into ' + Const.col('cult-effect', setback.customName()) + '.');
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new IncreasePower(game, turns, 'political');
      cult.effects.add(effect);
      cult.log('sine bind harmonizes ' + Const.col('cult-effect', effect.customName()) + ' for ' + turns + ' turns.');
    }
}
