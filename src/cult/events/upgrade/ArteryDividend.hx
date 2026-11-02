// event definition for the artery dividend corporate upgrade
package cult.events.upgrade;

import game.Game;
import cult.Cult;
import cult.EventHelper.*;
import cult.effects.*;
import Const.d100;

class ArteryDividend
{
// builds the artery dividend event descriptor
  public static function create(): _CultEvent
    {
      return {
        type: TYPE_OCCASIO,
        title: T('Artery Dividend'),
        text: T('Shareholder assembly throbs as the newly promoted CFO kneels before a dividend channel forged from coronary arteries. Each heartbeat sends distributions pumping through the arterial network. Around the forum, other shareholders press palms against the membrane, feeling the dividend\'s arterial flow. The outside investors never receive the true payout, but trusted arteries carry the inside return.'),
        choices: [
          {
            button: T('Pump Payout'),
            text: T('Accelerate the arterial pump to increase dividend distributions.'),
            f: choice1
          },
          {
            button: T('Artery Audit'),
            text: T('Seal the arterial network to audit distributions through secure channels.'),
            f: choice2
          },
          {
            button: T('Dividend Vow'),
            text: T('Suture the promoted CFO into the artery-ledger to manage eternal dividends.'),
            f: choice3
          }
        ]
      };
    }

// handles the pump payout choice outcome
  public static function choice1(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var loss = rollMoneyPayout();
          cult.resources.dec('money', loss);
          cult.logsg(T('{cult} overpump drains {money}.', {
            cult: cult,
            money: Const.col('cult-power', '-' + loss) + Icon.money,
          }));
          return;
        }
      var amount = rollMoneyPayout();
      cult.resources.money += amount;
      cult.logsg(T('{cult} pump distributes {money}.', {
        cult: cult,
        money: Const.col('cult-power', '+' + amount) + Icon.money,
      }));
    }

// handles the artery audit choice outcome
  public static function choice2(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var failTurns = d100() < 5 ? 10 : 5;
          var drain = new LoseResource(game, failTurns, 'corporate');
          cult.effects.add(drain);
          cult.logsg(T('{cult} audit fracture leaks into {effect}.', {
            cult: cult,
            effect: Const.col('cult-effect', drain.customName()),
          }));
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new IncreasePower(game, turns, 'corporate');
      cult.effects.add(effect);
      cult.log(T('{cult} artery audit pumps {effect} for {turns, plural, one{# turn} other{# turns}}.', {
        cult: cult,
        effect: Const.col('cult-effect', effect.customName()),
        turns: turns,
      }));
    }

// handles the dividend vow choice outcome
  public static function choice3(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var aiNeg = cult.getMemberByID(targetID);
          if (aiNeg != null &&
              aiNeg.addTrait(TRAIT_WEAK_WILLED))
            aiNeg.log(T('{ai:The} buckles under the vow and gains the weak-willed flaw.', { ai: aiNeg }));
          return;
        }
      var granted = addTrait(cult, targetID, 'mind', true);
      if (granted == null)
        {
          cult.logsg(T('{cult} dividend vow echoes without gifting new insight.', { cult: cult }));
          return;
        }
      var ai = cult.getMemberByID(targetID);
      if (ai != null)
        ai.log(T('{ai:The} swears the {trait} vow, bound to the artery.', {
          ai: ai,
          trait: granted.name,
        }));
    }
}
