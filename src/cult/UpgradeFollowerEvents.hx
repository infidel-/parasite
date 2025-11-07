// random occasio events triggered after follower upgrades
package cult;

import game.Game;
import cult.Cult;
import cult.effects.*;
import const.TraitsConst;
import const.TraitsConst._TraitInfo;
import Const.d100;
import ai.AIData;
import Icon;
import Const;
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
          title: 'Red Knife Vigil',
          text: 'Portable floodlights glare through the condemned cathedral nave as armored acolytes kneel beside the newly sworn Warmaker. Heart-rate monitors throb beneath tactical robes while medics arrange sealed scalpels and combat tourniquets, waiting to learn whether tonight\'s rite spills blood, ordinance, or bonded scars.',
          choices: [
            {
              button: 'Stockpile',
              text: 'Route confiscated ordnance into vacuum-sealed lockers so the strike team rolls into the next ordeal fully loaded.',
              f: function(game: Game, cult: Cult, targetID: Int)
                {
                  // 5% setback check
                  if (d100() < 5)
                    {
                      var penalty = rollResourcePayout();
                      cult.resources.dec('combat', penalty);
                      cult.logsg('botched carving bleeds -' + penalty + ' combat resource.');
                      return;
                    }
                  var amount = rollResourcePayout();
                  cult.resources.inc('combat', amount);
                  cult.logsg('stockpiles +' + amount + ' combat resource.');
                }
            },
            {
              button: 'Mentor Up',
              text: 'Assign the Warmaker to run live-fire drills with a rookie, hammering doctrine into muscle memory before the patrol redeploys.',
              f: function(game: Game, cult: Cult, targetID: Int)
                {
                  // 5% setback check
                  if (d100() < 5)
                    {
                      var ai = cult.getMemberByID(targetID);
                      if (ai.addTrait(TRAIT_ALCOHOLIC))
                        ai.logsg('stumbles into ritual spirits and gains the alcoholic flaw.');
                      return;
                    }
                  var granted = addTrait(cult, targetID, 'skill', true);
                  if (granted == null)
                    cult.logsg('mentor session inspires but is not otherwise beneficial.');
                }
            },
            {
              button: 'Night Sweep',
              text: 'Spin up sensor drones and run night-long perimeter sweeps, tightening every choke point against reprisal crews.',
              f: function(game: Game, cult: Cult, targetID: Int)
                {
                  // 5% setback check
                  if (d100() < 5)
                    {
                      var penaltyTurns = d100() < 5 ? 10 : 5;
                      var setback = new DecreasePower(game, penaltyTurns, 'combat');
                      cult.effects.add(setback);
                      cult.logsg('fatigues the guard, triggering ' + Const.col('cult-effect', setback.customName()) + '.');
                      return;
                    }
                  var turns = d100() < 5 ? 10 : 5;
                  var effect = new IncreasePower(game, turns, 'combat');
                  cult.effects.add(effect);
                  cult.logsg('activates ' + Const.col('cult-effect', effect.customName()) + ' for ' + turns + ' turns.');
                }
            }
          ]
        },
        {
          type: TYPE_OCCASIO,
          title: 'Induction Hangar',
          text: 'Cargo drones idle over the repurposed hangar while the elevation banquet hisses on induction grills. Veteran cantors tape reinforced grips, rookies laser-etch ordeal sigils into riot shields, and the council waits to hear if this vigil yields new tactics, lean logistics, or dangers disguised as applause.',
          choices: [
            {
              button: 'Cash Grab',
              text: 'Auction ritual trophies through darknet brokers and launder the bids straight into hardened gear budgets.',
              f: function(game: Game, cult: Cult, targetID: Int)
                {
                  // 5% setback check
                  if (d100() < 5)
                    {
                      var loss = rollMoneyPayout();
                      cult.resources.dec('money', loss);
                      cult.logsg('a bribed inspector skims ' + Const.col('cult-power', '-' + loss) + Icon.money + '.');
                      return;
                    }
                  var amount = rollMoneyPayout();
                  cult.resources.money += amount;
                  cult.logsg('coffers take ' + Const.col('cult-power', '+' + amount) + Icon.money + '.');
                }
            },
            {
              button: 'Share Docs',
              text: 'Swap encrypted playbooks with allied cells so squads can cross-train on each other\'s breach patterns.',
              f: function(game: Game, cult: Cult, targetID: Int)
                {
                  // 5% setback check
                  if (d100() < 5)
                    {
                      var effTurns = d100() < 5 ? 10 : 5;
                      var eff = new IncreaseTradeCost(game, effTurns);
                      cult.effects.add(eff);
                      cult.logsg('misprints leak, causing ' + Const.col('cult-effect', eff.customName()) + '.');
                      return;
                    }
                  var turns = d100() < 5 ? 10 : 5;
                  var effect = new IncreaseIncome(game, turns);
                  cult.effects.add(effect);
                  cult.logsg('shares schematics, enabling ' + Const.col('cult-effect', effect.customName()) + ' for ' + turns + ' turns.');
                }
            },
            {
              button: 'Peer Audit',
              text: 'Pair veterans with recruits for a brutal after-action autopsy, annotating every flaw from the ordeal footage.',
              f: function(game: Game, cult: Cult, targetID: Int)
                {
                  // 5% setback check
                  if (d100() < 5)
                    {
                      var ai = cult.getMemberByID(targetID);
                      if (ai.addTrait(TRAIT_DRUG_ADDICT))
                        ai.logsg('slips into stim dependence during the long debrief.');
                      return;
                    }
                  var awarded = addTrait(cult, targetID, 'cultBasic', false);
                  if (awarded == null)
                    cult.logsg('evaluations end with respect but no new trait.');
                }
            }
          ]
        },
        {
          type: TYPE_OCCASIO,
          title: 'Bastion Midnight',
          text: 'Midnight rain needles the subterranean muster as the honored fighter kneels before a carbon-fiber reliquary. Penitents whisper flesh psalms over diesel generators, medics map ordeal scars with biometric scanners, and scouts radio rival crews testing perimeter gaps the promotion might have opened.',
          choices: [
            {
              button: 'Depot Run',
              text: 'Re-route supply vans under police scanners to restock forward depots before the dawn curfew bites.',
              f: function(game: Game, cult: Cult, targetID: Int)
                {
                  // 5% setback check
                  if (d100() < 5)
                    {
                      var failTurns = d100() < 5 ? 10 : 5;
                      var drain = new LoseResource(game, failTurns, 'combat');
                      cult.effects.add(drain);
                      cult.logsg('bandits ambush, leaving ' + Const.col('cult-effect', drain.customName()) + '.');
                      return;
                    }
                  var amount = rollResourcePayout();
                  cult.resources.inc('combat', amount);
                  cult.logsg('channels +' + amount + ' combat resource into reserves.');
                }
            },
            {
              button: 'Vow Rally',
              text: 'Stage a midnight oath rally, pumping adrenal hymnals through the barracks loudspeakers.',
              f: function(game: Game, cult: Cult, targetID: Int)
                {
                  // 5% setback check
                  if (d100() < 5)
                    {
                      var penalty = rollResourcePayout();
                      cult.resources.dec('combat', penalty);
                      cult.logsg('overextensions bleed -' + penalty + ' combat resource.');
                      return;
                    }
                  var turns = d100() < 5 ? 10 : 5;
                  var effect = new IncreasePower(game, turns, 'combat');
                  cult.effects.add(effect);
                  cult.logsg('stirs fury into ' + Const.col('cult-effect', effect.customName()) + ' for ' + turns + ' turns.');
                }
            },
            {
              button: 'Brief Dark',
              text: 'Seclude the promoted fighter with scout handlers to stitch blackout routes and clandestine contact trees.',
              f: function(game: Game, cult: Cult, targetID: Int)
                {
                  // 5% setback check
                  if (d100() < 5)
                    {
                      var penaltyTurns = d100() < 5 ? 10 : 5;
                      var eff = new DecreasePower(game, penaltyTurns, 'combat');
                      cult.effects.add(eff);
                      cult.logsg('misdirection backfires into ' + Const.col('cult-effect', eff.customName()) + '.');
                      return;
                    }
                  var awarded = addTrait(cult, targetID, 'mind', false);
                  if (awarded == null)
                    cult.logsg('intelligence swap stays theoretical.');
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
              f: function(game: Game, cult: Cult, targetID: Int) {
                cult.resources.media += 1;
                cult.log('whispers become headlines; media power rises.');
              }
            },
            {
              button: 'Product Placement',
              text: 'Sell branded salvation kits (+5,000 money).',
              f: function(game: Game, cult: Cult, targetID: Int) {
                cult.resources.money += 5000;
                cult.log('merch tables empty; coffers swell by 5,000.');
              }
            },
            {
              button: 'Low Profile',
              text: 'Let the glow fade for now (no change).',
              f: function(game: Game, cult: Cult, targetID: Int) {
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
              f: function(game: Game, cult: Cult, targetID: Int) {
                cult.resources.lawfare += 1;
                cult.log('a fresh precedent seals; lawfare power grows.');
              }
            },
            {
              button: 'Retainer Fees',
              text: 'Bill sympathetic firms (+5,000 money).',
              f: function(game: Game, cult: Cult, targetID: Int) {
                cult.resources.money += 5000;
                cult.log('trust accounts overflow; coffers gain 5,000.');
              }
            },
            {
              button: 'Adjourn',
              text: 'Recess without ruling (no change).',
              f: function(game: Game, cult: Cult, targetID: Int) {
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
              f: function(game: Game, cult: Cult, targetID: Int) {
                cult.resources.corporate += 1;
                cult.log('portfolios realign; corporate power increases.');
              }
            },
            {
              button: 'Dividend',
              text: 'Issue celebratory payouts (+5,000 money).',
              f: function(game: Game, cult: Cult, targetID: Int) {
                cult.resources.money += 5000;
                cult.log('share ledgers bloom; coffers add 5,000.');
              }
            },
            {
              button: 'Gala Night',
              text: 'Toast the upgrade without action (no change).',
              f: function(game: Game, cult: Cult, targetID: Int) {
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

  // rounds half upward for payout adjustments
  static function halfCeil(amount: Int): Int
    {
      return Std.int((amount + 1) / 2);
    }

  // rolls resource payout using 2/5/10 tier chances
  static function rollResourcePayout(): Int
    {
      var amount = 2;
      var roll = d100();
      if (roll < 5)
        amount = 10;
      else if (roll < 30)
        amount = 5;
      return amount;
    }

  // rolls money payout using 2/5/10 tier chances
  static function rollMoneyPayout(): Int
    {
      var base = rollResourcePayout();
      return base * 10000;
    }

  // adds a random trait from the group when it is safe to do so
  static function addTrait(cult: Cult, targetID: Int, groupID: String, positiveOnly: Bool): _TraitInfo
    {
      var member = cult.getMemberByID(targetID);
      if (member == null)
        return null;
      if (groupID != 'misc' &&
          hasTraitFromGroup(member, groupID))
        return null;

      var info: _TraitInfo = null;
      if (positiveOnly)
        info = TraitsConst.getRandomPositive(groupID);
      else
        info = TraitsConst.getRandom(groupID);
      if (info == null || info.id == TRAIT_ASSIMILATED)
        return null;
      if (!member.addTrait(info.id))
        return null;
      member.logsg('embraces the ' + Const.col('trait', info.name) + ' calling.');
      return info;
    }

  // checks if member already holds a trait from a given group
  static function hasTraitFromGroup(member: AIData, groupID: String): Bool
    {
      var group = TraitsConst.getGroup(groupID);
      if (group == null)
        return false;
      for (entry in group)
        {
          if (member.hasTrait(entry.id))
            return true;
        }
      return false;
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
