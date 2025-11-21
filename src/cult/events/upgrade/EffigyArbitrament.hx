// event definition for the effigy arbitrament lawfare upgrade
package cult.events.upgrade;

import cult.EventHelper.*;
import cult.effects.*;
import Const.d100;

class EffigyArbitrament
{
// builds the effigy arbitrament event descriptor
  public static function create(): _CultEvent
    {
      return {
        type: TYPE_OCCASIO,
        title: 'Effigy Arbitrament',
        text: 'Windowless arbitration suite hums as the newly promoted advocate rehearses before a jury of still-breathing effigies. Fiber veins coil beneath the table, syncing plea scripts with encrypted archives. Elevator chimes upstairs swallow each whispered precedent before it can escape into daylight.',
        choices: [
          {
            button: 'Case Draw',
            text: 'Draft shadow amicus briefs to siphon precedent into private files.',
            f: choice1
          },
          {
            button: 'Echo Seal',
            text: 'Bind the effigy choir to pulse covert rulings through secure relays.',
            f: choice2
          },
          {
            button: 'Script Lash',
            text: 'Carve mnemonic lashes across the advocate to brand deeper compliance.',
            f: choice3
          }
        ]
      };
    }

// handles the case draw choice outcome
  public static function choice1(game: game.Game, cult: cult.Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var penalty = rollResourcePayout();
          cult.resources.dec('lawfare', penalty);
          cult.logsg('case draw leaks -' + penalty + ' lawfare resource.');
          return;
        }
      var amount = rollResourcePayout();
      cult.resources.inc('lawfare', amount);
      cult.logsg('case draw locks +' + amount + ' lawfare resource.');
    }

// handles the echo seal choice outcome
  public static function choice2(game: game.Game, cult: cult.Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var penaltyTurns = d100() < 5 ? 10 : 5;
          var setback = new LoseResource(game, penaltyTurns, 'lawfare');
          cult.effects.add(setback);
          cult.logsg('echo seal fractures into ' + Const.col('cult-effect', setback.customName()) + '.');
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new GainResource(game, turns, 'lawfare');
      cult.effects.add(effect);
      cult.log('effigy arbitrament channels ' + Const.col('cult-effect', effect.customName()) + ' for ' + turns + ' turns.');
    }

// handles the script lash choice outcome
  public static function choice3(game: game.Game, cult: cult.Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var aiNeg = cult.getMemberByID(targetID);
          if (aiNeg != null &&
              aiNeg.addTrait(TRAIT_WEAK_WILLED))
            aiNeg.log('flinches from the lashes and gains the weak-willed flaw.');
          return;
        }
      var granted = addTrait(cult, targetID, 'mind', true);
      if (granted == null)
        {
          cult.logsg('script lash fades without etching new recall.');
          return;
        }
      var ai = cult.getMemberByID(targetID);
      if (ai != null)
        ai.log('feels ' + granted.name + ' sear along the clandestine charter.');
    }
}
