// event definition for the sealed docket vigil lawfare upgrade
package cult.events.upgrade;

import cult.EventHelper.*;
import cult.effects.*;
import Const.d100;

class SealedDocketVigil
{
// builds the sealed docket vigil event descriptor
  public static function create(): _CultEvent
    {
      return {
        type: TYPE_OCCASIO,
        title: 'Sealed Docket Vigil',
        text: 'Underground docket vault hums as the newly elevated advocate kneels before a magistrate bench upholstered in living hide. Masked clerks murmur citations into respirators while filings pulse under ligature wraps. Flesh sutures trace the statute shelves, keeping city cameras blind to the oath.',
        choices: [
          {
            button: 'Seal Bank',
            text: 'Sweep hush retainers through bonded trusts to feed the legal war chest.',
            f: choice1
          },
          {
            button: 'Clerk Sync',
            text: 'Mesh the clerk choir with encrypted case flows to prime covert rulings.',
            f: choice2
          },
          {
            button: 'Oath Mark',
            text: 'Brand the advocate with living statutes to anchor the hidden mandate.',
            f: choice3
          }
        ]
      };
    }

// handles the seal bank choice outcome
  public static function choice1(game: game.Game, cult: cult.Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var penalty = rollResourcePayout();
          cult.resources.dec('lawfare', penalty);
          cult.logsg('seized retainers bleed -' + penalty + ' lawfare resource.');
          return;
        }
      var amount = rollResourcePayout();
      cult.resources.inc('lawfare', amount);
      cult.logsg('seal bank swells +' + amount + ' lawfare resource.');
    }

// handles the clerk sync choice outcome
  public static function choice2(game: game.Game, cult: cult.Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var penaltyTurns = d100() < 5 ? 10 : 5;
          var setback = new DecreasePower(game, penaltyTurns, 'lawfare');
          cult.effects.add(setback);
          cult.logsg('clerk sync glitches into ' + Const.col('cult-effect', setback.customName()) + '.');
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new IncreasePower(game, turns, 'lawfare');
      cult.effects.add(effect);
      cult.log('sealed docket vigil weaves ' + Const.col('cult-effect', effect.customName()) + ' for ' + turns + ' turns.');
    }

// handles the oath mark choice outcome
  public static function choice3(game: game.Game, cult: cult.Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var aiNeg = cult.getMemberByID(targetID);
          if (aiNeg != null &&
              aiNeg.addTrait(TRAIT_WEAK_WILLED))
            aiNeg.log('buckles beneath the oath mark and inherits the weak-willed flaw.');
          return;
        }
      var granted = addTrait(cult, targetID, 'mind', true);
      if (granted == null)
        {
          cult.logsg('oath mark flickers without gifting new doctrine.');
          return;
        }
      var ai = cult.getMemberByID(targetID);
      if (ai != null)
        ai.log('memorizes ' + granted.name + ' as the sealed docket cools around them.');
    }
}
