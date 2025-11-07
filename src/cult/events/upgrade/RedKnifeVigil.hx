// event definition for the red knife vigil combat upgrade
package cult.events.upgrade;

import game.Game;
import cult.Cult;
import cult.EventHelper.*;
import cult.effects.*;
import Const;
import Const.d100;

class RedKnifeVigil
{
// builds the red knife vigil event descriptor
  public static function create(): _CultEvent
    {
      return {
        type: TYPE_OCCASIO,
        title: 'Red Knife Vigil',
        text: 'Portable floodlights glare through the condemned cathedral nave as armored acolytes kneel beside the newly sworn Warmaker. Heart-rate monitors throb beneath tactical robes while medics arrange sealed scalpels and combat tourniquets, waiting to learn whether tonight\'s rite spills blood, ordinance, or bonded scars.',
        choices: [
          {
            button: 'Stockpile',
            text: 'Route confiscated ordnance into vacuum-sealed lockers so the strike team rolls into the next ordeal fully loaded.',
            f: choice1
          },
          {
            button: 'Mentor Up',
            text: 'Assign the Warmaker to run live-fire drills with a rookie, hammering doctrine into muscle memory before the patrol redeploys.',
            f: choice2
          },
          {
            button: 'Night Sweep',
            text: 'Spin up sensor drones and run night-long perimeter sweeps, tightening every choke point against reprisal crews.',
            f: choice3
          }
        ]
      };
    }

// handles the stockpile choice outcome
  public static function choice1(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var penalty = rollResourcePayout();
          cult.resources.dec('combat', penalty);
          cult.logsg('botched carving bleeds -' + penalty + ' combat resource.');
          return;
        }
      var amount = rollResourcePayout();
      cult.resources.inc('combat', amount);
      cult.logsg('stockpiles +' + amount + ' combat resource.');
    }

// handles the mentor up choice outcome
  public static function choice2(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var ai = cult.getMemberByID(targetID);
          if (ai.addTrait(TRAIT_ALCOHOLIC))
            ai.logsg('stumbles into ritual spirits and gains the alcoholic flaw.');
          return;
        }
      var granted = addTrait(cult, targetID, 'skill', true);
      if (granted == null)
        cult.logsg('mentor session inspires but is not otherwise beneficial.');
    }

// handles the night sweep choice outcome
  public static function choice3(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var penaltyTurns = d100() < 5 ? 10 : 5;
          var setback = new DecreasePower(game, penaltyTurns, 'combat');
          cult.effects.add(setback);
          cult.logsg('fatigues the guard, triggering ' + Const.col('cult-effect', setback.customName()) + '.');
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new IncreasePower(game, turns, 'combat');
      cult.effects.add(effect);
      cult.logsg('activates ' + Const.col('cult-effect', effect.customName()) + ' for ' + turns + ' turns.');
    }
}
