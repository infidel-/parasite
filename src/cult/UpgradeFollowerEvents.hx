// random occasio events triggered after follower upgrades
package cult;

import game.Game;
import cult.Cult;
import cult.effects.*;
import _AIJobGroup;
import _CultEvent;

class UpgradeFollowerEvents
{
  public static var list(default, null): Map<_AIJobGroup, Array<_CultEvent>> = build();

  static function build(): Map<_AIJobGroup, Array<_CultEvent>>
    {
      var map = new Map<_AIJobGroup, Array<_CultEvent>>();

      map.set(GROUP_COMBAT, [
        {
          type: TYPE_OCCASIO,
          title: 'Test Rite (Combat)',
          text: 'The faithful sharpen ceremonial blades while debating whether to spill blood, gold, or breath in honor of the new Warmaster.',
          choices: [
            {
              button: 'Blood Hymn',
              text: 'Dedicate combat might to future battles (+1 combat resource).',
              f: function(game: Game, cult: Cult) {
                cult.resources.combat += 1;
                cult.log('occurs a militant hymn; combat power swells.');
                cult.effects.add(new GainResource(game, 10, 'lawfare'));
              }
            },
            {
              button: 'Gilded Tribute',
              text: 'Convert zeal into funding (+5,000 money).',
              f: function(game: Game, cult: Cult) {
                cult.resources.money += 5000;
                cult.log('coins pile at the altar; coffers grow by 5,000.');
              }
            },
            {
              button: 'Silent Watch',
              text: 'Hold position and merely observe (no change).',
              f: function(game: Game, cult: Cult) {
                cult.log('the sentinels keep silent vigil; nothing shifts.');
              }
            }
          ]
        }
      ]);

      map.set(GROUP_MEDIA, [
        {
          type: TYPE_OCCASIO,
          title: 'Test Rite (Media)',
          text: 'Screens flicker with curated visions as the cult weighs how loudly to trumpet the ascension of its new Voice.',
          choices: [
            {
              button: 'Broadcast',
              text: 'Seed captivating rumors (+1 media resource).',
              f: function(game: Game, cult: Cult) {
                cult.resources.media += 1;
                cult.log('whispers become headlines; media power rises.');
              }
            },
            {
              button: 'Product Placement',
              text: 'Sell branded salvation kits (+5,000 money).',
              f: function(game: Game, cult: Cult) {
                cult.resources.money += 5000;
                cult.log('merch tables empty; coffers swell by 5,000.');
              }
            },
            {
              button: 'Low Profile',
              text: 'Let the glow fade for now (no change).',
              f: function(game: Game, cult: Cult) {
                cult.log('the message is muted; influence holds steady.');
              }
            }
          ]
        }
      ]);

      map.set(GROUP_LAWFARE, [
        {
          type: TYPE_OCCASIO,
          title: 'Test Rite (Lawfare)',
          text: 'Legal tomes fan out across the sanctum as the newly elevated Arbiter weighs which precedent to set.',
          choices: [
            {
              button: 'Draft Mandate',
              text: 'Codify new doctrine (+1 lawfare resource).',
              f: function(game: Game, cult: Cult) {
                cult.resources.lawfare += 1;
                cult.log('a fresh precedent seals; lawfare power grows.');
              }
            },
            {
              button: 'Retainer Fees',
              text: 'Bill sympathetic firms (+5,000 money).',
              f: function(game: Game, cult: Cult) {
                cult.resources.money += 5000;
                cult.log('trust accounts overflow; coffers gain 5,000.');
              }
            },
            {
              button: 'Adjourn',
              text: 'Recess without ruling (no change).',
              f: function(game: Game, cult: Cult) {
                cult.log('the docket clears quietly; balance remains.');
              }
            }
          ]
        }
      ]);

      map.set(GROUP_CORPORATE, [
        {
          type: TYPE_OCCASIO,
          title: 'Test Rite (Corporate)',
          text: 'Boardroom candles flare as analysts debate whether to reinvest, redistribute, or simply dine on the victory.',
          choices: [
            {
              button: 'Reinvest',
              text: 'Channel profits into new ventures (+1 corporate resource).',
              f: function(game: Game, cult: Cult) {
                cult.resources.corporate += 1;
                cult.log('portfolios realign; corporate power increases.');
              }
            },
            {
              button: 'Dividend',
              text: 'Issue celebratory payouts (+5,000 money).',
              f: function(game: Game, cult: Cult) {
                cult.resources.money += 5000;
                cult.log('share ledgers bloom; coffers add 5,000.');
              }
            },
            {
              button: 'Gala Night',
              text: 'Toast the upgrade without action (no change).',
              f: function(game: Game, cult: Cult) {
                cult.log('crystal clinks echo; strategy sleeps.');
              }
            }
          ]
        }
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
              f: function(game: Game, cult: Cult) {
                cult.resources.political += 1;
                cult.log('votes fall in line; political power deepens.');
              }
            },
            {
              button: 'Fundraisers',
              text: 'Host closed-door dinners (+5,000 money).',
              f: function(game: Game, cult: Cult) {
                cult.resources.money += 5000;
                cult.log('envelopes slide under velvet; coffers grow by 5,000.');
              }
            },
            {
              button: 'Backroom Pact',
              text: 'Bank favors for later (no change).',
              f: function(game: Game, cult: Cult) {
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
              f: function(game: Game, cult: Cult) {
                cult.resources.money += 2500;
                cult.log('neighbors empty jars; coffers gain 2,500.');
              }
            },
            {
              button: 'Hidden Shrine',
              text: 'Offer quiet prayers (+1 occult resource).',
              f: function(game: Game, cult: Cult) {
                cult.resources.occult += 1;
                cult.log('candle smoke thickens; occult knowledge grows.');
              }
            },
            {
              button: 'Simple Thanks',
              text: 'Bow heads and disperse (no change).',
              f: function(game: Game, cult: Cult) {
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
              f: function(game: Game, cult: Cult) {}
            }
          ]
        };
      return events[Std.random(events.length)];
    }

}
