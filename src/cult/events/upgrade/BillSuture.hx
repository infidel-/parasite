// event definition for the bill suture political upgrade
package cult.events.upgrade;

import game.Game;
import cult.Cult;
import cult.EventHelper.*;
import cult.effects.*;
import Const.d100;

class BillSuture
{
// builds the bill suture event descriptor
  public static function create(): _CultEvent
    {
      return {
        type: TYPE_OCCASIO,
        title: T('Bill Suture'),
        text: T('In a legislative drafting room, the newly appointed chief drafter kneels before sutured parchment made from skin grafts. Each amendment is stitched with surgical thread, bill clauses pulsing like healing wounds. Legislative aides press fingers to suture-lines, tracing policy changes through scar tissue. Outside drafters never see the true text, but trusted flesh writes the hidden law.'),
        choices: [
          {
            button: T('Suture Text'),
            text: T('Stitch amendments in skin-paper.'),
            f: choice1
          },
          {
            button: T('Graft Clause'),
            text: T('Graft clause into drafter.'),
            f: choice2
          },
          {
            button: T('Scar Archive'),
            text: T('Bind drafter into scar-tissue.'),
            f: choice3
          }
        ]
      };
    }

// handles suture text choice
  public static function choice1(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var penalty = rollResourcePayout();
          cult.resources.dec('political', penalty);
          cult.logsg(T('{cult} suture rupture bleeds {n, plural, one{-# political resource} other{-# political resources}}.', {
            cult: cult,
            n: penalty,
          }));
          return;
        }
      var amount = rollResourcePayout();
      cult.resources.inc('political', amount);
      cult.logsg(T('{cult} sutured text delivers {n, plural, one{+# political resource} other{+# political resources}}.', {
        cult: cult,
        n: amount,
      }));
    }

// handles graft clause choice
  public static function choice2(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var aiNeg = cult.getMemberByID(targetID);
          if (aiNeg != null &&
              aiNeg.addTrait(TRAIT_WEAK_WILLED))
            aiNeg.log(T('{ai:The} grafted clause weakens will, spawning flaw.', { ai: aiNeg }));
          return;
        }
      var granted = addTrait(cult, targetID, 'cultBasic', true);
      if (granted == null)
        cult.logsg(T('{cult} clause graft fuses without new devotion.', { cult: cult }));
    }

// handles scar archive choice
  public static function choice3(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var penaltyTurns = d100() < 5 ? 10 : 5;
          var setback = new DecreasePower(game, penaltyTurns, 'political');
          cult.effects.add(setback);
          cult.logsg(T('{cult} scar tissue scars into {effect}.', {
            cult: cult,
            effect: Const.col('cult-effect', setback.customName()),
          }));
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new IncreasePower(game, turns, 'political');
      cult.effects.add(effect);
      cult.log(T('{cult} scar archive seals {effect} for {turns, plural, one{# turn} other{# turns}}.', {
        cult: cult,
        effect: Const.col('cult-effect', effect.customName()),
        turns: turns,
      }));
    }
}
