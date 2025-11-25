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
        PulpitVein.create(),
        FleshPortfolio.create(),
        ArteryDividend.create(),
      ]);

      map.set(GROUP_POLITICAL, [
        CommitteeFlesh.create(),
        CaucusSine.create(),
        FundGraft.create(),
        PolicyGraft.create(),
        BillSuture.create(),
        VoteVein.create(),
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
