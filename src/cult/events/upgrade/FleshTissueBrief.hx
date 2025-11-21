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
        title: 'Flesh Tissue Brief',
        text: 'Subterranean drafting chamber breathes as the newly promoted counsel kneels before a podium of living membrane. Law clerks chant citation numbers through respirators while brief pages pulse with arterial ink. Vein-scribed margins grip each argument, keeping the chambers hidden from public dockets. The air thickens with the scent of binding fluid as precedent awakens beneath fluorescent hum.',
        choices: [
          {
            button: 'Vein Ink',
            text: 'Route arguments through living ink to seal brief authority.',
            f: choice1
          },
          {
            button: 'Tissue Bind',
            text: 'Mesh membrane pages with ongoing cases to spread influence.',
            f: choice2
          },
          {
            button: 'Mark Bar',
            text: 'Brand the counsel with brief sigils to anchor secret knowledge.',
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
          cult.logsg('vein ink bleeds -' + penalty + ' lawfare resource.');
          return;
        }
      var amount = rollResourcePayout();
      cult.resources.inc('lawfare', amount);
      cult.logsg('vein ink binds +' + amount + ' lawfare resource.');
    }

// handles the tissue bind choice outcome
  public static function choice2(game: game.Game, cult: cult.Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var penaltyTurns = d100() < 5 ? 10 : 5;
          var setback = new DecreasePower(game, penaltyTurns, 'lawfare');
          cult.effects.add(setback);
          cult.logsg('tissue bind tears into ' + Const.col('cult-effect', setback.customName()) + '.');
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new IncreasePower(game, turns, 'lawfare');
      cult.effects.add(effect);
      cult.log('flesh tissue brief grants ' + Const.col('cult-effect', effect.customName()) + ' for ' + turns + ' turns.');
    }

// handles the mark bar choice outcome
  public static function choice3(game: game.Game, cult: cult.Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var aiNeg = cult.getMemberByID(targetID);
          if (aiNeg != null &&
              aiNeg.addTrait(TRAIT_DUMB))
            aiNeg.log('chokes on briefs and inherits the dumb flaw.');
          return;
        }
      var granted = addTrait(cult, targetID, 'mind', true);
      if (granted == null)
        {
          cult.logsg('mark bar fades without gifting new insight.');
          return;
        }
      var ai = cult.getMemberByID(targetID);
      if (ai != null)
        ai.log('internalizes ' + granted.name + ' as the tissue briefs settle.');
    }
}
