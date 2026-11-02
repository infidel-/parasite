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
        title: T('Sealed Docket Vigil'),
        text: T('Underground docket vault hums as the newly elevated advocate kneels before a magistrate bench upholstered in living hide. Masked clerks murmur citations into respirators while filings pulse under ligature wraps. Flesh sutures trace the statute shelves, keeping city cameras blind to the oath.'),
        choices: [
          {
            button: T('Seal Bank'),
            text: T('Sweep hush retainers through bonded trusts to feed the legal war chest.'),
            f: choice1
          },
          {
            button: T('Clerk Sync'),
            text: T('Mesh the clerk choir with encrypted case flows to prime covert rulings.'),
            f: choice2
          },
          {
            button: T('Oath Mark'),
            text: T('Brand the advocate with living statutes to anchor the hidden mandate.'),
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
          cult.logsg(T('{cult} seized retainers bleed {n, plural, one{-# lawfare resource} other{-# lawfare resources}}.', {
            cult: cult,
            n: penalty,
          }));
          return;
        }
      var amount = rollResourcePayout();
      cult.resources.inc('lawfare', amount);
      cult.logsg(T('{cult} seal bank swells {n, plural, one{+# lawfare resource} other{+# lawfare resources}}.', {
        cult: cult,
        n: amount,
      }));
    }

// handles the clerk sync choice outcome
  public static function choice2(game: game.Game, cult: cult.Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var penaltyTurns = d100() < 5 ? 10 : 5;
          var setback = new DecreasePower(game, penaltyTurns, 'lawfare');
          cult.effects.add(setback);
          cult.logsg(T('{cult} clerk sync glitches into {effect}.', {
            cult: cult,
            effect: Const.col('cult-effect', setback.customName()),
          }));
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new IncreasePower(game, turns, 'lawfare');
      cult.effects.add(effect);
      cult.log(T('{cult} sealed docket vigil weaves {effect} for {turns, plural, one{# turn} other{# turns}}.', {
        cult: cult,
        effect: Const.col('cult-effect', effect.customName()),
        turns: turns,
      }));
    }

// handles the oath mark choice outcome
  public static function choice3(game: game.Game, cult: cult.Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var aiNeg = cult.getMemberByID(targetID);
          if (aiNeg != null &&
              aiNeg.addTrait(TRAIT_WEAK_WILLED))
            aiNeg.log(T('{ai:The} buckles beneath the oath mark and inherits the weak-willed flaw.', { ai: aiNeg }));
          return;
        }
      var granted = addTrait(cult, targetID, 'mind', true);
      if (granted == null)
        {
          cult.logsg(T('{cult} oath mark flickers without gifting new doctrine.', { cult: cult }));
          return;
        }
      var ai = cult.getMemberByID(targetID);
      if (ai != null)
        ai.log(T('{ai:The} memorizes {trait} as the sealed docket cools around them.', {
          ai: ai,
          trait: granted.name,
        }));
    }
}
