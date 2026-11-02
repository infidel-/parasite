// event definition for the hush ledger convocation lawfare upgrade
package cult.events.upgrade;

import cult.EventHelper.*;
import cult.effects.*;
import Const.d100;

class HushLedgerConvocation
{
// builds the hush ledger convocation event descriptor
  public static function create(): _CultEvent
    {
      return {
        type: TYPE_OCCASIO,
        title: T('Hush Ledger Convocation'),
        text: T('Night-shuttered policy cellar glows low as the newly ranked strategist stands amid racks of blood-warmed statutes. Analysts whisper precedent through gauze masks while flesh-bound ledgers inhale hush payments. Outside traffic drones past, unaware the verdict already beats beneath the floor.'),
        choices: [
          {
            button: T('Proxy Net'),
            text: T('Route sealed settlements through layered shell firms and skim reserves.'),
            f: choice1
          },
          {
            button: T('Memo Choir'),
            text: T('Sync the memo choir with encrypted dashboards to amplify unseen leverage.'),
            f: choice2
          },
          {
            button: T('Vow Ledger'),
            text: T('Tattoo the strategist with ledger sigils carrying clandestine doctrines.'),
            f: choice3
          }
        ]
      };
    }

// handles the proxy net choice outcome
  public static function choice1(game: game.Game, cult: cult.Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var loss = rollMoneyPayout();
          cult.resources.dec('money', loss);
          cult.logsg(T('{cult} proxy net unravels {money}.', {
            cult: cult,
            money: Const.col('cult-power', '-' + loss) + Icon.money,
          }));
          return;
        }
      var amount = rollMoneyPayout();
      cult.resources.money += amount;
      cult.logsg(T('{cult} proxy net sluices {money}.', {
        cult: cult,
        money: Const.col('cult-power', '+' + amount) + Icon.money,
      }));
    }

// handles the memo choir choice outcome
  public static function choice2(game: game.Game, cult: cult.Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var penaltyTurns = d100() < 5 ? 10 : 5;
          var setback = new DecreaseIncome(game, penaltyTurns);
          cult.effects.add(setback);
          cult.logsg(T('{cult} memo choir overload births {effect}.', {
            cult: cult,
            effect: Const.col('cult-effect', setback.customName()),
          }));
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new IncreaseIncome(game, turns);
      cult.effects.add(effect);
      cult.log(T('{cult} hush ledger convocation breathes {effect} for {turns, plural, one{# turn} other{# turns}}.', {
        cult: cult,
        effect: Const.col('cult-effect', effect.customName()),
        turns: turns,
      }));
    }

// handles the vow ledger choice outcome
  public static function choice3(game: game.Game, cult: cult.Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var aiNeg = cult.getMemberByID(targetID);
          if (aiNeg != null &&
              aiNeg.addTrait(TRAIT_DUMB))
            aiNeg.log(T('{ai:The} drowns in figures and takes on the dumb flaw.', { ai: aiNeg }));
          return;
        }
      var granted = addTrait(cult, targetID, 'cultBasic', false);
      if (granted == null)
        {
          cult.logsg(T('{cult} vow ledger closes without granting fresh doctrine.', { cult: cult }));
          return;
        }
      var ai = cult.getMemberByID(targetID);
      if (ai != null)
        ai.log(T('{ai:The} records {trait} into the hidden ledger vows.', {
          ai: ai,
          trait: granted.name,
        }));
    }
}
