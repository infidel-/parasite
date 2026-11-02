// event definition for the os nativitas hearing lawfare upgrade
package cult.events.upgrade;

import cult.EventHelper.*;
import cult.effects.*;
import Const.d100;

class OsNativitasHearing
{
// builds the os nativitas hearing event descriptor
  public static function create(): _CultEvent
    {
      return {
        type: TYPE_OCCASIO,
        title: T('Os Nativitas Hearing'),
        text: T('Bone-walled hearing chamber resonates as the newly elevated judge stands before a podium grown from fused vertebrae. Bailiffs murmur procedural codes through filtered masks while case files rustle between rib-spaced shelves. The chamber exhales formaldehyde warmth as living calcium frameworks channel verdicts that no court reporter could transcribe for public record.'),
        choices: [
          {
            button: T('Marrow Vault'),
            text: T('Route sealed settlements through bone trusts and feed the legal cache.'),
            f: choice1
          },
          {
            button: T('Skeleton Sync'),
            text: T('Bind the chamber bones with encrypted rulings to fortify covert justice.'),
            f: choice2
          },
          {
            button: T('Vertebra Mark'),
            text: T('Carve the judge with marrow sigils to anchor the secret bench.'),
            f: choice3
          }
        ]
      };
    }

// handles the marrow vault choice outcome
  public static function choice1(game: game.Game, cult: cult.Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var loss = rollMoneyPayout();
          cult.resources.dec('money', loss);
          cult.logsg(T('{cult} marrow vault crumbles {money}.', {
            cult: cult,
            money: Const.col('cult-power', '-' + loss) + Icon.money,
          }));
          return;
        }
      var amount = rollMoneyPayout();
      cult.resources.money += amount;
      cult.logsg(T('{cult} marrow vault solidifies {money}.', {
        cult: cult,
        money: Const.col('cult-power', '+' + amount) + Icon.money,
      }));
    }

// handles the skeleton sync choice outcome
  public static function choice2(game: game.Game, cult: cult.Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var penaltyTurns = d100() < 5 ? 10 : 5;
          var setback = new DecreaseIncome(game, penaltyTurns);
          cult.effects.add(setback);
          cult.logsg(T('{cult} skeleton sync fractures into {effect}.', {
            cult: cult,
            effect: Const.col('cult-effect', setback.customName()),
          }));
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new IncreaseIncome(game, turns);
      cult.effects.add(effect);
      cult.log(T('{cult} os nativitas hearing strengthens {effect} for {turns, plural, one{# turn} other{# turns}}.', {
        cult: cult,
        effect: Const.col('cult-effect', effect.customName()),
        turns: turns,
      }));
    }

// handles the vertebra mark choice outcome
  public static function choice3(game: game.Game, cult: cult.Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var aiNeg = cult.getMemberByID(targetID);
          if (aiNeg != null &&
              aiNeg.addTrait(TRAIT_DUMB))
            aiNeg.log(T('{ai:The} cracks under vertebra pressure and inherits the dumb flaw.', { ai: aiNeg }));
          return;
        }
      var granted = addTrait(cult, targetID, 'mind', true);
      if (granted == null)
        {
          cult.logsg(T('{cult} vertebra mark fractures without gifting new insight.', { cult: cult }));
          return;
        }
      var ai = cult.getMemberByID(targetID);
      if (ai != null)
        ai.log(T('{ai:The} internalizes {trait} as the os nativitas chamber seals.', {
          ai: ai,
          trait: granted.name,
        }));
    }
}
