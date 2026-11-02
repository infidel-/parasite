// event definition for the flesh tissue brief lawfare upgrade
package cult.events.upgrade;

import cult.EventHelper.*;
import cult.effects.*;
import Const.d100;

class FleshTissueBrief
{
// builds the flesh tissue brief event descriptor
  public static function create(): _CultEvent
    {
      return {
        type: TYPE_OCCASIO,
        title: T('Flesh Tissue Brief'),
        text: T('Subterranean drafting chamber breathes as the newly promoted counsel kneels before a podium of living membrane. Law clerks chant citation numbers through respirators while brief pages pulse with arterial ink. Vein-scribed margins grip each argument, keeping the chambers hidden from public dockets. The air thickens with the scent of binding fluid as precedent awakens beneath fluorescent hum.'),
        choices: [
          {
            button: T('Vein Ink'),
            text: T('Route arguments through living ink to seal brief authority.'),
            f: choice1
          },
          {
            button: T('Tissue Bind'),
            text: T('Mesh membrane pages with ongoing cases to spread influence.'),
            f: choice2
          },
          {
            button: T('Mark Bar'),
            text: T('Brand the counsel with brief sigils to anchor secret knowledge.'),
            f: choice3
          }
        ]
      };
    }

// handles the vein ink choice outcome
  public static function choice1(game: game.Game, cult: cult.Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var penalty = rollResourcePayout();
          cult.resources.dec('lawfare', penalty);
          cult.logsg(T('{cult} vein ink bleeds {n, plural, one{-# lawfare resource} other{-# lawfare resources}}.', {
            cult: cult,
            n: penalty,
          }));
          return;
        }
      var amount = rollResourcePayout();
      cult.resources.inc('lawfare', amount);
      cult.logsg(T('{cult} vein ink binds {n, plural, one{+# lawfare resource} other{+# lawfare resources}}.', {
        cult: cult,
        n: amount,
      }));
    }

// handles the tissue bind choice outcome
  public static function choice2(game: game.Game, cult: cult.Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var penaltyTurns = d100() < 5 ? 10 : 5;
          var setback = new DecreasePower(game, penaltyTurns, 'lawfare');
          cult.effects.add(setback);
          cult.logsg(T('{cult} tissue bind tears into {effect}.', {
            cult: cult,
            effect: Const.col('cult-effect', setback.customName()),
          }));
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new IncreasePower(game, turns, 'lawfare');
      cult.effects.add(effect);
      cult.log(T('{cult} flesh tissue brief grants {effect} for {turns, plural, one{# turn} other{# turns}}.', {
        cult: cult,
        effect: Const.col('cult-effect', effect.customName()),
        turns: turns,
      }));
    }

// handles the mark bar choice outcome
  public static function choice3(game: game.Game, cult: cult.Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var aiNeg = cult.getMemberByID(targetID);
          if (aiNeg != null &&
              aiNeg.addTrait(TRAIT_DUMB))
            aiNeg.log(T('{ai:The} chokes on briefs and inherits the dumb flaw.', { ai: aiNeg }));
          return;
        }
      var granted = addTrait(cult, targetID, 'mind', true);
      if (granted == null)
        {
          cult.logsg(T('{cult} mark bar fades without gifting new insight.', { cult: cult }));
          return;
        }
      var ai = cult.getMemberByID(targetID);
      if (ai != null)
        ai.log(T('{ai:The} internalizes {trait} as the tissue briefs settle.', {
          ai: ai,
          trait: granted.name,
        }));
    }
}
