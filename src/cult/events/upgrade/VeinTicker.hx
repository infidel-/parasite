// event definition for the vein ticker corporate upgrade
package cult.events.upgrade;

import game.Game;
import cult.Cult;
import cult.EventHelper.*;
import cult.effects.*;
import Const.d100;

class VeinTicker
{
// builds the vein ticker event descriptor
  public static function create(): _CultEvent
    {
      return {
        type: TYPE_OCCASIO,
        title: 'Vein Ticker',
        text: 'Trading floor neon stutters red as the newly promoted analyst kneels before a ticker woven from pulsing forearm veins. Each heartbeat sends stock symbols scrolling across translucent flesh. Around the pit, other brokers press palms against the membrane, reading the market\'s arterial rhythm. The outside exchanges never hear the true price, but trusted veins carry the insider flow.',
        choices: [
          {
            button: 'Pump Ticker',
            text: 'Inject adrenaline into the vein-ticker to accelerate the pulse and push favorable trades.',
            f: choice1
          },
          {
            button: 'Short Veins',
            text: 'Drain rival veins from the ticker network, consolidating flow into our arterial channels.',
            f: choice2
          },
          {
            button: 'Seal Ticker',
            text: 'Suture the promoted broker into a hidden ticker node for vetted trades only.',
            f: choice3
          }
        ]
      };
    }

// handles the signal fog choice outcome
  public static function choice1(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var failTurns = d100() < 5 ? 10 : 5;
          var drain = new LoseResource(game, failTurns, 'corporate');
          cult.effects.add(drain);
          cult.logsg('audit ghosts ambush, leaving ' + Const.col('cult-effect', drain.customName()) + '.');
          return;
        }
      var amount = rollResourcePayout();
      cult.resources.inc('corporate', amount);
      cult.logsg('channels +' + amount + ' corporate resource into reserves.');
    }

// handles the covert ad choice outcome
  public static function choice2(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var loss = rollMoneyPayout();
          cult.resources.dec('money', loss);
          cult.logsg('audit ghost clips ' + Const.col('cult-power', '-' + loss) + Icon.money + '.');
          return;
        }
      var amount = rollMoneyPayout();
      cult.resources.money += amount;
      cult.logsg('backchannel invoices clear ' + Const.col('cult-power', '+' + amount) + Icon.money + '.');
    }

// handles the proxy seal choice outcome
  public static function choice3(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var aiNeg = cult.getMemberByID(targetID);
          if (aiNeg != null &&
              aiNeg.addTrait(TRAIT_WEAK_WILLED))
            aiNeg.log('buckles under the sealed refrain, inheriting the weak-willed flaw.');
          return;
        }
      var granted = addTrait(cult, targetID, 'mind', true);
      if (granted == null)
        {
          cult.logsg('proxy seal flares without gifting new insight.');
          return;
        }
      var ai = cult.getMemberByID(targetID);
      if (ai != null)
        ai.log('holds ' + granted.name + ' close, sworn to the hidden proxy.');
    }
}
