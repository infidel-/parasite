// event definition for the vein precedent ritual lawfare upgrade
package cult.events.upgrade;

import cult.EventHelper.*;
import cult.effects.*;
import Const.d100;

class VeinPrecedentRitual
{
// builds the vein precedent ritual event descriptor
  public static function create(): _CultEvent
    {
      return {
        type: TYPE_OCCASIO,
        title: 'Vein Precedent Ritual',
        text: 'Hidden tribunal chamber throbs as the newly elevated magistrate stands before a bench carved from a single pulsing artery. Court reporters murmur testimony through veils while precedent scrolls unfurl in blood-warmed cascade. Ligature chandeliers sway overhead, casting moving shadows across the living docket that no public gallery could ever witness.',
        choices: [
          {
            button: 'Blood Docket',
            text: 'Siphon sealed verdicts through vein networks and feed the war chest.',
            f: choice1
          },
          {
            button: 'Pulse Bind',
            text: 'Weave the chamber rhythm with flowing verdicts to prime hidden rulings.',
            f: choice2
          },
          {
            button: 'Artery Mark',
            text: 'Inscribe the magistrate with precedent arteries carrying secret authority.',
            f: choice3
          }
        ]
      };
    }

// handles the blood docket choice outcome
  public static function choice1(game: game.Game, cult: cult.Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var penalty = rollResourcePayout();
          cult.resources.dec('lawfare', penalty);
          cult.logsg('blood docket hemorrhages -' + penalty + ' lawfare resource.');
          return;
        }
      var amount = rollResourcePayout();
      cult.resources.inc('lawfare', amount);
      cult.logsg('blood docket pools +' + amount + ' lawfare resource.');
    }

// handles the pulse bind choice outcome
  public static function choice2(game: game.Game, cult: cult.Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var penaltyTurns = d100() < 5 ? 10 : 5;
          var setback = new LoseResource(game, penaltyTurns, 'lawfare');
          cult.effects.add(setback);
          cult.logsg('pulse bind clots into ' + Const.col('cult-effect', setback.customName()) + '.');
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new GainResource(game, turns, 'lawfare');
      cult.effects.add(effect);
      cult.log('vein precedent ritual pulses ' + Const.col('cult-effect', effect.customName()) + ' for ' + turns + ' turns.');
    }

// handles the artery mark choice outcome
  public static function choice3(game: game.Game, cult: cult.Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var aiNeg = cult.getMemberByID(targetID);
          if (aiNeg != null &&
              aiNeg.addTrait(TRAIT_WEAK_WILLED))
            aiNeg.log('buckles under artery weight and inherits the weak-willed flaw.');
          return;
        }
      var granted = addTrait(cult, targetID, 'cultBasic', false);
      if (granted == null)
        {
          cult.logsg('artery mark fades without granting fresh doctrine.');
          return;
        }
      var ai = cult.getMemberByID(targetID);
      if (ai != null)
        ai.log('records ' + granted.name + ' as the vein precedent hardens in memory.');
    }
}
