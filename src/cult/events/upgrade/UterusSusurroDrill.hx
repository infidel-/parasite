// event definition for the Uterus Susurro drill combat upgrade
package cult.events.upgrade;

import game.Game;
import cult.Cult;
import cult.EventHelper.*;
import cult.effects.*;
import Const;
import Const.d100;
import Icon;
import _CultEvent;

class UterusSusurroDrill
{
// builds the Uterus Susurro drill event descriptor
  public static function create(): _CultEvent
    {
      return {
        type: TYPE_OCCASIO,
        title: 'Uterus Susurro Drill',
        text: 'Rain-battered med hangar sits sealed behind blackout screens as the newly sworn squad leader sinks into an Uterus Susurro pod. Chaplain-engineers whisper fetal psalms through scrub masks while biotech interns braid fiber umbilicals along his spine. Only trusted handlers monitor the bio telemetry.',
        choices: [
          {
            button: 'Umbil Feed',
            text: 'Shunt donor stipends into the fighter\'s tactical muscle accounts.',
            f: choice1
          },
          {
            button: 'Tank Hymn',
            text: 'Sync the tank\'s resonance with urban drone interdiction grids.',
            f: choice2
          },
          {
            button: 'Spine Code',
            text: 'Etch neural scripture across his vertebrae to lock the new rank.',
            f: choice3
          }
        ]
      };
    }

// handles umbil feed choice
  public static function choice1(game: Game, cult: Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var loss = rollMoneyPayout();
          cult.resources.dec('money', loss);
          cult.logsg('silent auditors pinch ' + Const.col('cult-power', '-' + loss) + Icon.money + '.');
          return;
        }
      var amount = rollMoneyPayout();
      cult.resources.money += amount;
      cult.logsg('umbil feed secures ' + Const.col('cult-power', '+' + amount) + Icon.money + '.');
    }

// handles tank hymn choice
  public static function choice2(game: Game, cult: Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var penaltyTurns = d100() < 5 ? 10 : 5;
          var setback = new IncreaseTradeCost(game, penaltyTurns);
          cult.effects.add(setback);
          cult.logsg('pod hymn leaks, birthing ' + Const.col('cult-effect', setback.customName()) + '.');
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new IncreaseIncome(game, turns);
      cult.effects.add(effect);
      cult.log('uterus susurro harmonics awaken ' + Const.col('cult-effect', effect.customName()) + ' for ' + turns + ' turns.');
    }

// handles spine code choice
  public static function choice3(game: Game, cult: Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var ai = cult.getMemberByID(targetID);
          if (ai != null &&
              ai.addTrait(TRAIT_DRUG_ADDICT))
            ai.log('slips into stim reliance after corrupted spinal script, breath fogging his visor.');
          return;
        }
      var granted = addTrait(cult, targetID, 'mind', true);
      if (granted == null)
        {
          cult.logsg('spine code stutters without sealing a fresh insight.');
          return;
        }
      var ai = cult.getMemberByID(targetID);
      if (ai != null)
        ai.log('embraces ' + granted.name + ' threading along his upgraded nerves.');
    }
}
