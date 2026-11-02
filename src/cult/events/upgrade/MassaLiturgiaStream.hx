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
        title: T('Massa Liturgia Stream'),
        text: T('Sub-basement streaming nave thrums as the upgrade briefing coils around the journalist newly sworn to their next tier of witness. Massa Liturgia consoles sweat light across curtain walls while editors queue encrypted drops for sleeper cells. Above, commuter static masks the whisper-fed transmission.'),
        choices: [
          {
            button: T('Warm Feed'),
            text: T('Uncork backup syndication nodes and drip the ordeal cut through vetted smartwalls.'),
            f: choice1
          },
          {
            button: T('Grey Choir'),
            text: T('Draft choir drones to braid hymn loops behind anonymous billboards.'),
            f: choice2
          },
          {
            button: T('Clip Rite'),
            text: T('Carve a private catechism reel to rehearse the upgraded witness before future trials.'),
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
          cult.logsg(T('{cult} air-gapped array rots {n, plural, one{-# media resource} other{-# media resources}}.', {
            cult: cult,
            n: penalty,
          }));
          return;
        }
      var amount = rollResourcePayout();
      cult.resources.inc('media', amount);
      cult.logsg(T('{cult} sealed feed swells {n, plural, one{+# media resource} other{+# media resources}}.', {
        cult: cult,
        n: amount,
      }));
    }

// handles the grey choir choice outcome
  public static function choice2(game: Game, cult: Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var penaltyTurns = d100() < 5 ? 10 : 5;
          var setback = new LoseResource(game, penaltyTurns, 'media');
          cult.effects.add(setback);
          cult.logsg(T('{cult} discordant drones ignite {effect}.', {
            cult: cult,
            effect: Const.col('cult-effect', setback.customName()),
          }));
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new GainResource(game, turns, 'media');
      cult.effects.add(effect);
      cult.log(T('{cult} massa liturgia chorus weaves {effect} for {turns, plural, one{# turn} other{# turns}}.', {
        cult: cult,
        effect: Const.col('cult-effect', effect.customName()),
        turns: turns,
      }));
    }

// handles the clip rite choice outcome
  public static function choice3(game: Game, cult: Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var ai = cult.getMemberByID(targetID);
          if (ai != null &&
              ai.addTrait(TRAIT_WEAK_WILLED))
            ai.log(T('{ai:The} stumbles through edit loops, conceding to the weak-willed flaw.', { ai: ai }));
          return;
        }
      var granted = addTrait(cult, targetID, 'mind', true);
      if (granted == null)
        {
          cult.logsg(T('{cult} clip rite crystallizes without gifting a fresh recall.', { cult: cult }));
          return;
        }
      var ai = cult.getMemberByID(targetID);
      if (ai != null)
        ai.log(T('{ai:The} internalizes {trait} as the rite anchors their new tier.', {
          ai: ai,
          trait: granted.name,
        }));
    }
}
