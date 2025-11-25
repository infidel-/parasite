// event definition for the pulpit vein corporate upgrade
package cult.events.upgrade;

import game.Game;
import cult.Cult;
import cult.EventHelper.*;
import cult.effects.*;
import Const.d100;

class PulpitVein
{
// builds the pulpit vein event descriptor
  public static function create(): _CultEvent
    {
      return {
        type: TYPE_OCCASIO,
        title: 'Pulpit Vein',
        text: 'Executive auditorium echoes as the newly promoted VP kneels before a pulpit forged from thigh veins. Each heartbeat sends quarterly forecasts scrolling across translucent sinew. Around the chamber, other executives press palms against the membrane, feeling the market\'s arterial pulse. The outside shareholders never hear the true sermon, but trusted veins carry the inside truth.',
        choices: [
          {
            button: 'Preach Gains',
            text: 'Deliver bullish sermon to pump the quarterly forecasts through the vein-pulpit.',
            f: choice1
          },
          {
            button: 'Seal Sermon',
            text: 'Encrypt the pulpit-vein to broadcast forecasts only to trusted insiders.',
            f: choice2
          },
          {
            button: 'Vein Vow',
            text: 'Suture the promoted VP into the pulpit-flesh to swear eternal market fealty.',
            f: choice3
          }
        ]
      };
    }

// handles the preach gains choice outcome
  public static function choice1(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var failTurns = d100() < 5 ? 10 : 5;
          var drain = new LoseResource(game, failTurns, 'corporate');
          cult.effects.add(drain);
          cult.logsg('false prophecy drains into ' + Const.col('cult-effect', drain.customName()) + '.');
          return;
        }
      var amount = rollResourcePayout();
      cult.resources.inc('corporate', amount);
      cult.logsg('sermon converts +' + amount + ' corporate resource into believers.');
    }

// handles the seal sermon choice outcome
  public static function choice2(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var penaltyTurns = d100() < 5 ? 10 : 5;
          var setback = new DecreasePower(game, penaltyTurns, 'corporate');
          cult.effects.add(setback);
          cult.logsg('seal fractures into ' + Const.col('cult-effect', setback.customName()) + '.');
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new GainResource(game, turns, 'corporate');
      cult.effects.add(effect);
      cult.log('encrypted sermon channels ' + Const.col('cult-effect', effect.customName()) + ' for ' + turns + ' turns.');
    }

// handles the vein vow choice outcome
  public static function choice3(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var aiNeg = cult.getMemberByID(targetID);
          if (aiNeg != null &&
              aiNeg.addTrait(TRAIT_WEAK_WILLED))
            aiNeg.log('buckles under the vow and gains the weak-willed flaw.');
          return;
        }
      var granted = addTrait(cult, targetID, 'mind', true);
      if (granted == null)
        {
          cult.logsg('vow echoes without gifting new insight.');
          return;
        }
      var ai = cult.getMemberByID(targetID);
      if (ai != null)
        ai.log('swears the ' + granted.name + ' vow, bound to the pulpit.');
    }
}
