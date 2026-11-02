// event definition for the Sudor Sigillum mass combat upgrade
package cult.events.upgrade;

import game.Game;
import cult.Cult;
import cult.EventHelper.*;
import cult.effects.*;
import Const;
import Const.d100;
import _CultEvent;

class SudorSigillumMass
{
// builds the Sudor Sigillum mass event descriptor
  public static function create(): _CultEvent
    {
      return {
        type: TYPE_OCCASIO,
        title: T('Sudor Sigillum Mass'),
        text: T('Abandoned maintenance chapel hums as the newly promoted commando stands within a sealed Sudor Sigillum circle, heat lamps sweating runes across hidden flesh. Cloaked medics scrape condensate into reliquaries while tactical scribes pipe encrypted telemetry underground. No outsider hears the whispered vows.'),
        choices: [
          {
            button: T('Altar Pump'),
            text: T('Divert undercity blood drives into the squad\'s combat stockpile.'),
            f: choice1
          },
          {
            button: T('LiturgyFX'),
            text: T('Weave the rite\'s bassline into shielded dampeners and riot shields.'),
            f: choice2
          },
          {
            button: T('Blade Seal'),
            text: T('Graft a sanctified knife litany into the warrior\'s palm tissue.'),
            f: choice3
          }
        ]
      };
    }

// handles altar pump choice
  public static function choice1(game: Game, cult: Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var penalty = rollResourcePayout();
          cult.resources.dec('combat', penalty);
          cult.logsg(T('{cult} altar pumps clog and drain {n, plural, one{-# combat resource} other{-# combat resources}}.', {
            cult: cult,
            n: penalty,
          }));
          return;
        }
      var amount = rollResourcePayout();
      cult.resources.inc('combat', amount);
      cult.logsg(T('{cult} altar pump surges {n, plural, one{+# combat resource} other{+# combat resources}}.', {
        cult: cult,
        n: amount,
      }));
    }

// handles liturgyfx choice
  public static function choice2(game: Game, cult: Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var penaltyTurns = d100() < 5 ? 10 : 5;
          var setback = new DecreasePower(game, penaltyTurns, 'combat');
          cult.effects.add(setback);
          cult.logsg(T('{cult} feedback whine mutates into {effect}.', {
            cult: cult,
            effect: Const.col('cult-effect', setback.customName()),
          }));
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new IncreasePower(game, turns, 'combat');
      cult.effects.add(effect);
      cult.log(T('{cult} sigil basslines kindle {effect} for {turns, plural, one{# turn} other{# turns}}.', {
        cult: cult,
        effect: Const.col('cult-effect', effect.customName()),
        turns: turns,
      }));
    }

// handles blade seal choice
  public static function choice3(game: Game, cult: Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var aiNeg = cult.getMemberByID(targetID);
          if (aiNeg != null &&
              aiNeg.addTrait(TRAIT_DRUG_ADDICT))
            aiNeg.log(T('{ai:The} inhales solvent hymns and gains the addict flaw.', { ai: aiNeg }));
          return;
        }
      var ai = cult.getMemberByID(targetID);
      if (ai == null)
        {
          cult.logsg(T('{cult} blade seal crackles without a vessel to anchor.', { cult: cult }));
          return;
        }
      if (ai.hasTrait(TRAIT_KNIFE_EXPERT))
        {
          cult.logsg(T('{cult} blade seal finds steel already sworn.', { cult: cult }));
          return;
        }
      if (ai.addTrait(TRAIT_KNIFE_EXPERT))
        ai.log(T('{ai:The} receives the Knife Expert litany carved into living grip.', { ai: ai }));
      else
        cult.logsg(T('{cult} blade seal fails to graft the promised edge.', { cult: cult }));
    }
}
