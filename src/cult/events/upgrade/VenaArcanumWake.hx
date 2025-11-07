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
        title: 'Vena Arcanum Wake',
        text: 'Sealed railyard infirmary glows with emergency lanterns as the newly ranked striker kneels beside a chilled Vena Arcanum cistern. Masked confessors murmur prayers through respirator hoods while trauma techs stitch synth sinew under blackout tarps. Only the inner circle watches the monitors flicker.',
        choices: [
          {
            button: 'Pulse Bank',
            text: 'Channel pressurized plasma caches toward the upgraded squadron.',
            f: choice1
          },
          {
            button: 'Veil Chant',
            text: 'Let chaplains sync electro-psalms with drone shielding routines.',
            f: choice2
          },
          {
            button: 'Bone Seal',
            text: 'Brand the promoted fighter with marrow seals that bind fresh doctrine.',
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
          cult.logsg('overdrawn pulse bank bleeds -' + penalty + ' combat resource.');
          return;
        }
      var amount = rollResourcePayout();
      cult.resources.inc('combat', amount);
      cult.logsg('arterial reservoir swells +' + amount + ' combat resource.');
    }

// handles veil chant choice
  public static function choice2(game: Game, cult: Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var penaltyTurns = d100() < 5 ? 10 : 5;
          var setback = new DecreasePower(game, penaltyTurns, 'combat');
          cult.effects.add(setback);
          cult.logsg('feedback howls corrodes into ' + Const.col('cult-effect', setback.customName()) + '.');
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new IncreasePower(game, turns, 'combat');
      cult.effects.add(effect);
      cult.log('vena arcanum choir crowns ' + Const.col('cult-effect', effect.customName()) + ' for ' + turns + ' turns.');
    }

// handles bone seal choice
  public static function choice3(game: Game, cult: Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var ai = cult.getMemberByID(targetID);
          if (ai != null &&
              ai.addTrait(TRAIT_ALCOHOLIC))
            ai.log('staggers from sour sealant and embraces the alcoholic flaw.');
          return;
        }
      var granted = addTrait(cult, targetID, 'combat', true);
      if (granted == null)
        {
          cult.logsg('bone seal scorches but reveals no new blessing.');
          return;
        }
      var ai = cult.getMemberByID(targetID);
      if (ai != null)
        ai.log('feels ' + granted.name + ' thread through the upgraded sinew.');
    }
}
