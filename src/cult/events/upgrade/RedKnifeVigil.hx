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
        title: T('Red Knife Vigil'),
        text: T('Portable floodlights glare through the condemned cathedral nave as armored acolytes kneel beside the newly sworn Warmaker. Heart-rate monitors throb beneath tactical robes while medics arrange sealed scalpels and combat tourniquets, waiting to learn whether tonight\'s rite spills blood, ordinance, or bonded scars.'),
        choices: [
          {
            button: T('Stockpile'),
            text: T('Route confiscated ordnance into vacuum-sealed lockers so the strike team rolls into the next ordeal fully loaded.'),
            f: choice1
          },
          {
            button: T('Mentor Up'),
            text: T('Assign the Warmaker to run live-fire drills with a rookie, hammering doctrine into muscle memory before the patrol redeploys.'),
            f: choice2
          },
          {
            button: T('Night Sweep'),
            text: T('Spin up sensor drones and run night-long perimeter sweeps, tightening every choke point against reprisal crews.'),
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
          cult.logsg(T('{cult} botched carving bleeds {n, plural, one{-# combat resource} other{-# combat resources}}.', {
            cult: cult,
            n: penalty,
          }));
          return;
        }
      var amount = rollResourcePayout();
      cult.resources.inc('combat', amount);
      cult.logsg(T('{cult} stockpiles {n, plural, one{+# combat resource} other{+# combat resources}}.', {
        cult: cult,
        n: amount,
      }));
    }

// handles the mentor up choice outcome
  public static function choice2(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var ai = cult.getMemberByID(targetID);
          if (ai.addTrait(TRAIT_ALCOHOLIC))
            ai.logsg(T('{ai:The} stumbles into ritual spirits and gains the alcoholic flaw.', { ai: ai }));
          return;
        }
      var granted = addTrait(cult, targetID, 'skill', true);
      if (granted == null)
        cult.logsg(T('{cult} mentor session inspires but is not otherwise beneficial.', { cult: cult }));
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
          cult.logsg(T('{cult} fatigues the guard, triggering {effect}.', {
            cult: cult,
            effect: Const.col('cult-effect', setback.customName()),
          }));
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new IncreasePower(game, turns, 'combat');
      cult.effects.add(effect);
      cult.logsg(T('{cult} activates {effect} for {turns, plural, one{# turn} other{# turns}}.', {
        cult: cult,
        effect: Const.col('cult-effect', effect.customName()),
        turns: turns,
      }));
    }
}
