// random occasio events triggered after follower upgrades
package cult;

import game.Game;
import cult.Cult;
import cult.events.upgrade.*;
import _AIJobGroup;
import _CultEvent;

class UpgradeFollowerEvents
{
  public static var list(default, null): Map<_AIJobGroup, Array<_CultEvent>> = build();

  static function build(): Map<_AIJobGroup, Array<_CultEvent>>
    {
      var map = new Map<_AIJobGroup, Array<_CultEvent>>();

      map.set(GROUP_COMBAT, [
        BastionMidnight.create(),
        InductionHangar.create(),
        RedKnifeVigil.create(),
        SudorSigillumMass.create(),
        UterusSusurroDrill.create(),
        VenaArcanumWake.create(),
      ]);

      map.set(GROUP_MEDIA, [
        BackchannelLitany.create(),
        CarnisSpeculumFeed.create(),
        InaudiblePremiere.create(),
        LinguaMareTelecast.create(),
        MassaLiturgiaStream.create(),
        SleeperCourierBrief.create(),
      ]);

      map.set(GROUP_LAWFARE, [
        EffigyArbitrament.create(),
        FleshTissueBrief.create(),
        HushLedgerConvocation.create(),
        OsNativitasHearing.create(),
        SealedDocketVigil.create(),
        VeinPrecedentRitual.create(),
      ]);

      map.set(GROUP_CORPORATE, [
        VeinTicker.create(),
        CarnisBoard.create(),
        StakeholderFlesh.create(),
      ]);

      map.set(GROUP_POLITICAL, [
        {
          type: TYPE_OCCASIO,
          title: 'Test Rite (Political)',
          text: 'Campaign banners unfurl as the council debates whether to spend influence on legislation, patronage, or future favors.',
          choices: [
            {
              button: 'Fast-Track Bill',
              text: 'Push covert legislation (+1 political resource).',
              f: function(game: Game, cult: Cult, targetID: Int) {
                cult.resources.political += 1;
                cult.log('votes fall in line; political power deepens.');
              }
            },
            {
              button: 'Fundraisers',
              text: 'Host closed-door dinners (+5,000 money).',
              f: function(game: Game, cult: Cult, targetID: Int) {
                cult.resources.money += 5000;
                cult.log('envelopes slide under velvet; coffers grow by 5,000.');
              }
            },
            {
              button: 'Backroom Pact',
              text: 'Bank favors for later (no change).',
              f: function(game: Game, cult: Cult, targetID: Int) {
                cult.log('nods are exchanged; momentum holds.');
              }
            }
          ]
        }
      ]);

      map.set(GROUP_CIVILIAN, [
        {
          type: TYPE_OCCASIO,
          title: 'Test Rite (Civilian)',
          text: 'Everyday faithful gather with offerings, debating how to celebrate the friend now raised above them.',
          choices: [
            {
              button: 'Community Feast',
              text: 'Share humble gifts (+2,500 money).',
              f: function(game: Game, cult: Cult, targetID: Int) {
                cult.resources.money += 2500;
                cult.log('neighbors empty jars; coffers gain 2,500.');
              }
            },
            {
              button: 'Hidden Shrine',
              text: 'Offer quiet prayers (+1 occult resource).',
              f: function(game: Game, cult: Cult, targetID: Int) {
                cult.resources.occult += 1;
                cult.log('candle smoke thickens; occult knowledge grows.');
              }
            },
            {
              button: 'Simple Thanks',
              text: 'Bow heads and disperse (no change).',
              f: function(game: Game, cult: Cult, targetID: Int) {
                cult.log('gratitude lingers; resources remain untouched.');
              }
            }
          ]
        }
      ]);

      return map;
    }

  public static function getRandom(group: _AIJobGroup): _CultEvent
    {
      var events = list.get(group);
      if (events == null || events.length == 0)
        events = list.get(GROUP_CIVILIAN);
      if (events == null || events.length == 0)
        return {
          type: TYPE_OCCASIO,
          title: 'Quiet Rite',
          text: 'The faithful fall into thoughtful silence. Nothing remarkable occurs.',
          choices: [
            {
              button: 'Dismiss',
              text: 'Accept the stillness.',
              f: function(game: Game, cult: Cult, targetID: Int) {}
            }
          ]
        };
      return events[Std.random(events.length)];
    }

}
