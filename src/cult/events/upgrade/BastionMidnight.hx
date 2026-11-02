// event definition for the bastion midnight combat upgrade
package cult.events.upgrade;

import game.Game;
import cult.Cult;
import cult.EventHelper.*;
import cult.effects.*;
import Const;
import Const.d100;
import _CultEvent;

class BastionMidnight
{
// builds the bastion midnight event descriptor
  public static function create(): _CultEvent
    {
      return {
        type: TYPE_OCCASIO,
        title: T('Bastion Midnight'),
        text: T('Midnight rain needles the subterranean muster as the honored fighter kneels before a carbon-fiber reliquary. Penitents whisper flesh psalms over diesel generators, medics map ordeal scars with biometric scanners, and scouts radio rival crews testing perimeter gaps the promotion might have opened.'),
        choices: [
          {
            button: T('Depot Run'),
            text: T('Re-route supply vans under police scanners to restock forward depots before the dawn curfew bites.'),
            f: choice1
          },
          {
            button: T('Vow Rally'),
            text: T('Stage a midnight oath rally, pumping adrenal hymnals through the barracks loudspeakers.'),
            f: choice2
          },
          {
            button: T('Brief Dark'),
            text: T('Seclude the promoted fighter with scout handlers to stitch blackout routes and clandestine contact trees.'),
            f: choice3
          }
        ]
      };
    }

// handles the depot run choice outcome
  public static function choice1(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var failTurns = d100() < 5 ? 10 : 5;
          var drain = new LoseResource(game, failTurns, 'combat');
          cult.effects.add(drain);
          cult.logsg(T('{cult} bandits ambush, leaving {effect}.', {
            cult: cult,
            effect: Const.col('cult-effect', drain.customName()),
          }));
          return;
        }
      var amount = rollResourcePayout();
      cult.resources.inc('combat', amount);
      cult.logsg(T('{cult} channels {n, plural, one{+# combat resource} other{+# combat resources}} into reserves.', {
        cult: cult,
        n: amount,
      }));
    }

// handles the vow rally choice outcome
  public static function choice2(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var penalty = rollResourcePayout();
          cult.resources.dec('combat', penalty);
          cult.logsg(T('{cult} overextensions bleed {n, plural, one{-# combat resource} other{-# combat resources}}.', {
            cult: cult,
            n: penalty,
          }));
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new IncreasePower(game, turns, 'combat');
      cult.effects.add(effect);
      cult.logsg(T('{cult} stirs fury into {effect} for {turns, plural, one{# turn} other{# turns}}.', {
        cult: cult,
        effect: Const.col('cult-effect', effect.customName()),
        turns: turns,
      }));
    }

// handles the brief dark choice outcome
  public static function choice3(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var penaltyTurns = d100() < 5 ? 10 : 5;
          var eff = new DecreasePower(game, penaltyTurns, 'combat');
          cult.effects.add(eff);
          cult.logsg(T('{cult} misdirection backfires into {effect}.', {
            cult: cult,
            effect: Const.col('cult-effect', eff.customName()),
          }));
          return;
        }
      var awarded = addTrait(cult, targetID, 'mind', false);
      if (awarded == null)
        cult.logsg(T('{cult} intelligence swap stays theoretical.', { cult: cult }));
    }
}
