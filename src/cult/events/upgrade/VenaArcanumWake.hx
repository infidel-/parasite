// event definition for the Vena Arcanum wake combat upgrade
package cult.events.upgrade;

import game.Game;
import cult.Cult;
import cult.EventHelper.*;
import cult.effects.*;
import Const;
import Const.d100;
import _CultEvent;

class VenaArcanumWake
{
// builds the Vena Arcanum wake event descriptor
  public static function create(): _CultEvent
    {
      return {
        type: TYPE_OCCASIO,
        title: T('Vena Arcanum Wake'),
        text: T('Sealed railyard infirmary glows with emergency lanterns as the newly ranked striker kneels beside a chilled Vena Arcanum cistern. Masked confessors murmur prayers through respirator hoods while trauma techs stitch synth sinew under blackout tarps. Only the inner circle watches the monitors flicker.'),
        choices: [
          {
            button: T('Pulse Bank'),
            text: T('Channel pressurized plasma caches toward the upgraded squadron.'),
            f: choice1
          },
          {
            button: T('Veil Chant'),
            text: T('Let chaplains sync electro-psalms with drone shielding routines.'),
            f: choice2
          },
          {
            button: T('Bone Seal'),
            text: T('Brand the promoted fighter with marrow seals that bind fresh doctrine.'),
            f: choice3
          }
        ]
      };
    }

// handles pulse bank choice
  public static function choice1(game: Game, cult: Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var penalty = rollResourcePayout();
          cult.resources.dec('combat', penalty);
          cult.logsg(T('{cult} overdrawn pulse bank bleeds {n, plural, one{-# combat resource} other{-# combat resources}}.', {
            cult: cult,
            n: penalty,
          }));
          return;
        }
      var amount = rollResourcePayout();
      cult.resources.inc('combat', amount);
      cult.logsg(T('{cult} arterial reservoir swells {n, plural, one{+# combat resource} other{+# combat resources}}.', {
        cult: cult,
        n: amount,
      }));
    }

// handles veil chant choice
  public static function choice2(game: Game, cult: Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var penaltyTurns = d100() < 5 ? 10 : 5;
          var setback = new DecreasePower(game, penaltyTurns, 'combat');
          cult.effects.add(setback);
          cult.logsg(T('{cult} feedback howls corrodes into {effect}.', {
            cult: cult,
            effect: Const.col('cult-effect', setback.customName()),
          }));
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new IncreasePower(game, turns, 'combat');
      cult.effects.add(effect);
      cult.log(T('{cult} vena arcanum choir crowns {effect} for {turns, plural, one{# turn} other{# turns}}.', {
        cult: cult,
        effect: Const.col('cult-effect', effect.customName()),
        turns: turns,
      }));
    }

// handles bone seal choice
  public static function choice3(game: Game, cult: Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var ai = cult.getMemberByID(targetID);
          if (ai != null &&
              ai.addTrait(TRAIT_ALCOHOLIC))
            ai.log(T('{ai:The} staggers from sour sealant and embraces the alcoholic flaw.', { ai: ai }));
          return;
        }
      var granted = addTrait(cult, targetID, 'combat', true);
      if (granted == null)
        {
          cult.logsg(T('{cult} bone seal scorches but reveals no new blessing.', { cult: cult }));
          return;
        }
      var ai = cult.getMemberByID(targetID);
      if (ai != null)
        ai.log(T('{ai:The} feels {trait} thread through the upgraded sinew.', {
          ai: ai,
          trait: granted.name,
        }));
    }
}
