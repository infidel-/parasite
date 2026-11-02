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
        title: T('Pulpit Vein'),
        text: T('Executive auditorium echoes as the newly promoted VP kneels before a pulpit forged from thigh veins. Each heartbeat sends quarterly forecasts scrolling across translucent sinew. Around the chamber, other executives press palms against the membrane, feeling the market\'s arterial pulse. The outside shareholders never hear the true sermon, but trusted veins carry the inside truth.'),
        choices: [
          {
            button: T('Preach Gains'),
            text: T('Deliver bullish sermon to pump the quarterly forecasts through the vein-pulpit.'),
            f: choice1
          },
          {
            button: T('Seal Sermon'),
            text: T('Encrypt the pulpit-vein to broadcast forecasts only to trusted insiders.'),
            f: choice2
          },
          {
            button: T('Vein Vow'),
            text: T('Suture the promoted VP into the pulpit-flesh to swear eternal market fealty.'),
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
          cult.logsg(T('{cult} false prophecy drains into {effect}.', {
            cult: cult,
            effect: Const.col('cult-effect', drain.customName()),
          }));
          return;
        }
      var amount = rollResourcePayout();
      cult.resources.inc('corporate', amount);
      cult.logsg(T('{cult} sermon converts {n, plural, one{+# corporate resource} other{+# corporate resources}} into believers.', {
        cult: cult,
        n: amount,
      }));
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
          cult.logsg(T('{cult} seal fractures into {effect}.', {
            cult: cult,
            effect: Const.col('cult-effect', setback.customName()),
          }));
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new GainResource(game, turns, 'corporate');
      cult.effects.add(effect);
      cult.log(T('{cult} encrypted sermon channels {effect} for {turns, plural, one{# turn} other{# turns}}.', {
        cult: cult,
        effect: Const.col('cult-effect', effect.customName()),
        turns: turns,
      }));
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
            aiNeg.log(T('{ai:The} buckles under the vow and gains the weak-willed flaw.', { ai: aiNeg }));
          return;
        }
      var granted = addTrait(cult, targetID, 'mind', true);
      if (granted == null)
        {
          cult.logsg(T('{cult} vow echoes without gifting new insight.', { cult: cult }));
          return;
        }
      var ai = cult.getMemberByID(targetID);
      if (ai != null)
        ai.log(T('{ai:The} swears the {trait} vow, bound to the pulpit.', {
          ai: ai,
          trait: granted.name,
        }));
    }
}
