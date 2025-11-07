// event definition for the massa liturgia stream media upgrade
package cult.events.upgrade;

import game.Game;
import cult.Cult;
import cult.EventHelper.*;
import cult.effects.*;
import Const;
import Const.d100;
import _CultEvent;

class MassaLiturgiaStream
{
// builds the massa liturgia stream event descriptor
  public static function create(): _CultEvent
    {
      return {
        type: TYPE_OCCASIO,
        title: 'Massa Liturgia Stream',
        text: 'Sub-basement streaming nave thrums as the upgrade briefing coils around the journalist newly sworn to their next tier of witness. Massa Liturgia consoles sweat light across curtain walls while editors queue encrypted drops for sleeper cells. Above, commuter static masks the whisper-fed transmission.',
        choices: [
          {
            button: 'Warm Feed',
            text: 'Uncork backup syndication nodes and drip the ordeal cut through vetted smartwalls.',
            f: choice1
          },
          {
            button: 'Grey Choir',
            text: 'Draft choir drones to braid hymn loops behind anonymous billboards.',
            f: choice2
          },
          {
            button: 'Clip Rite',
            text: 'Carve a private catechism reel to rehearse the upgraded witness before future trials.',
            f: choice3
          }
        ]
      };
    }

// handles the warm feed choice outcome
  public static function choice1(game: Game, cult: Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var penalty = rollResourcePayout();
          cult.resources.dec('media', penalty);
          cult.logsg('air-gapped array rots -' + penalty + ' media resource.');
          return;
        }
      var amount = rollResourcePayout();
      cult.resources.inc('media', amount);
      cult.logsg('sealed feed swells +' + amount + ' media resource.');
    }

// handles the grey choir choice outcome
  public static function choice2(game: Game, cult: Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var penaltyTurns = d100() < 5 ? 10 : 5;
          var setback = new LoseResource(game, penaltyTurns, 'media');
          cult.effects.add(setback);
          cult.logsg('discordant drones ignite ' + Const.col('cult-effect', setback.customName()) + '.');
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new GainResource(game, turns, 'media');
      cult.effects.add(effect);
      cult.log('massa liturgia chorus weaves ' + Const.col('cult-effect', effect.customName()) + ' for ' + turns + ' turns.');
    }

// handles the clip rite choice outcome
  public static function choice3(game: Game, cult: Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var ai = cult.getMemberByID(targetID);
          if (ai != null &&
              ai.addTrait(TRAIT_WEAK_WILLED))
            ai.log('stumbles through edit loops, conceding to the weak-willed flaw.');
          return;
        }
      var granted = addTrait(cult, targetID, 'mind', true);
      if (granted == null)
        {
          cult.logsg('clip rite crystallizes without gifting a fresh recall.');
          return;
        }
      var ai = cult.getMemberByID(targetID);
      if (ai != null)
        ai.log('internalizes ' + granted.name + ' as the rite anchors their new tier.');
    }
}
