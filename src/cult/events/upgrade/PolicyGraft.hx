// event definition for the policy graft political upgrade
package cult.events.upgrade;

import game.Game;
import cult.Cult;
import cult.EventHelper.*;
import cult.effects.*;
import Const.d100;

class PolicyGraft
{
// builds the policy graft event descriptor
  public static function create(): _CultEvent
    {
      return {
        type: TYPE_OCCASIO,
        title: 'Policy Graft',
        text: 'In a think-tank archive, the newly appointed policy director kneels before grafted neural tissue that encodes legislative models. Policy simulations pulse through dendritic networks, each synapse firing proposed amendments into neural pathways. Analysts press palms to the brain-membrane, reading policy outcomes through synaptic discharge. Outside academics never access the true models, but trusted neurons calculate the hidden agenda.',
        choices: [
          {
            button: 'Neural Model',
            text: 'Model policy through neurons.',
            f: choice1
          },
          {
            button: 'Graft Insight',
            text: 'Graft analyst into brain-web.',
            f: choice2
          },
          {
            button: 'Mind Archive',
            text: 'Seal director into neural vault.',
            f: choice3
          }
        ]
      };
    }

// handles neural model choice
  public static function choice1(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var failTurns = d100() < 5 ? 10 : 5;
          var drain = new LoseResource(game, failTurns, 'political');
          cult.effects.add(drain);
          cult.logsg('model error leaks into ' + Const.col('cult-effect', drain.customName()) + '.');
          return;
        }
      var amount = rollResourcePayout();
      cult.resources.inc('political', amount);
      cult.logsg('neural model computes +' + amount + ' political resource.');
    }

// handles graft insight choice
  public static function choice2(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var aiNeg = cult.getMemberByID(targetID);
          if (aiNeg != null &&
              aiNeg.addTrait(TRAIT_DUMB))
            aiNeg.log('graft overload spawns dumb flaw.');
          return;
        }
      var granted = addTrait(cult, targetID, 'mind', true);
      if (granted == null)
        cult.logsg('graft insight fails to sharpen mind.');
    }

// handles mind archive choice
  public static function choice3(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var penaltyTurns = d100() < 5 ? 10 : 5;
          var setback = new DecreasePower(game, penaltyTurns, 'political');
          cult.effects.add(setback);
          cult.logsg('archive decay erodes into ' + Const.col('cult-effect', setback.customName()) + '.');
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new IncreasePower(game, turns, 'political');
      cult.effects.add(effect);
      cult.log('neural archive sparks ' + Const.col('cult-effect', effect.customName()) + ' for ' + turns + ' turns.');
    }
}
