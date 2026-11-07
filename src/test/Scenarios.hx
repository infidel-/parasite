// scripted lifecycle scenarios for the headless tests: one per entry point of a lifecycle event in
// docs/relations.md. Each starts the way a fuzz run does (a preset or fixture, console commands
// chained with `+`, `_` for a space), sets up by hand only what no entry point reaches, acts through
// the player's own entry points (Bot.pressAction), and returns its broken expectations. Headless runs
// Bot.check after it.

package test;

import game.Game;

typedef _Scenario = {
  var start: String; // the start a fuzz run would take (Headless.begin)
  var run: Game -> Bot -> Array<String>; // the steps and asserts; returns what broke
}

class Scenarios
{
  public static var list: Map<String, _Scenario> = [
    'ovum-leader' => {
      start: 's2+cu_start',
      run: ovumLeader,
    },
    'ovum-member' => {
      start: 's2+cu_start+cu_members',
      run: ovumMember,
    },
    'expiry-member' => {
      start: 's2+cu_start+cu_members',
      run: expiryMember,
    },
    'npc-reenter' => {
      start: 's11',
      run: npcReenter,
    },
    'organ-npc' => {
      start: 's22',
      run: organNPC,
    },
  ];

// the scenario names in a stable order, for the run ids
  public static function names(): Array<String>
    {
      var ret = [ for (k in list.keys()) k ];
      ret.sort(Reflect.compare);
      return ret;
    }

// the leader's host fed to the ovum: the region death path (AI.dieRegion) destroys the cult
  static function ovumLeader(game: Game, bot: Bot): Array<String>
    {
      var errs = feedOvum(game, bot);
      if (errs.length > 0)
        return errs;
      var c = game.cults[0];
      if (c.state != CULT_STATE_DEAD)
        errs.push('the cult is ' + c.state + ' after its leader died');
      if (c.members.length > 0)
        errs.push('the dead cult keeps ' + c.members.length + ' members');
      return errs;
    }

// a follower's host fed to the ovum: it leaves the roster, the cult lives on
  static function ovumMember(game: Game, bot: Bot): Array<String>
    {
      var hostID = makeHostFollower(game);
      var n = game.cults[0].members.length;
      var errs = feedOvum(game, bot);
      if (errs.length > 0)
        return errs;
      return rosterLost(game, hostID, n);
    }

// a follower's host expires on the region map: the same death path, through PlayerRegion.actionPost
  static function expiryMember(game: Game, bot: Bot): Array<String>
    {
      var hostID = makeHostFollower(game);
      var n = game.cults[0].members.length;
      game.player.host.energy = 0;
      game.updateHUD();
      if (!bot.pressAction('skipTurn'))
        return [ 'no Wait on the region map' ];
      if (game.player.state != PLR_STATE_PARASITE)
        return [ 'the host did not expire' ];
      return rosterLost(game, hostID, n);
    }

// an NPC host carried out of its area and back in stays that NPC's one body: AreaGame.enter re-adds
// the host, and an unlinked NPC is spawned again by AreaGame.turnSpawnNPC
  static function npcReenter(game: Game, bot: Bot): Array<String>
    {
      var host = game.player.host;
      var npc = host.npc;
      if (npc == null)
        return [ 's11 did not tie the host to an NPC' ];
      // the NPC's own area, by teleport: the walk there is not what is tested
      game.setLocation(LOCATION_REGION);
      game.setLocation(LOCATION_AREA, npc.area);
      if (npc.ai != host)
        return [ 'NPC ' + npc.id + ' lost its link to the host on re-entry' ];
      return [];
    }

// an NPC host grown into a habitat organ (Habitat.putObject) dies as that NPC: the third death path,
// which has no AI.die and no corpse
  static function organNPC(game: Game, bot: Bot): Array<String>
    {
      var host = game.player.host;
      var npc = linkNPC(game, host);
      if (npc == null)
        return [ 'no live NPC to tie the host to' ];
      game.player.evolutionManager.addImprov(IMP_ASSIMILATION, 1);
      host.organs.action('set.IMP_ASSIMILATION');
      host.organs.debugCompleteCurrent();
      // off the biomineral s22 grew where the host stands
      game.playerArea.moveBy(1, 0);
      game.updateHUD();
      if (!bot.pressAction('formAssimilation'))
        return [ 'no Form assimilation cavity in the habitat' ];
      if (game.player.state != PLR_STATE_PARASITE)
        return [ 'the host outlived the organ: player is ' + game.player.state ];
      if (!npc.isDead)
        return [ 'NPC ' + npc.id + ' is alive after its body became an organ' ];
      return [];
    }

// tie the AI to a live NPC of the start events, as the s11 preset does for its host
  static function linkNPC(game: Game, ai: ai.AI): scenario.NPC
    {
      for (id in [ 'parasiteRemoval', 'parasiteTransportation' ])
        {
          var ev = game.timeline.getEvent(id);
          for (n in ev.npc)
            if (!n.isDead)
              {
                n.ai = ai;
                ai.eventID = ev.id;
                ai.npcID = n.id;
                ai.isNPC = true;
                return n;
              }
        }
      return null;
    }

// make the host a follower: a generated follower takes the lead (no entry point hands it over)
  static function makeHostFollower(game: Game): Int
    {
      var c = game.cults[0];
      var rec = c.getMemberByID(game.player.host.id);
      c.members.remove(rec);
      c.members.push(rec);
      return rec.id;
    }

// learn the ovum, create it where the parasite stands and feed it the host
  static function feedOvum(game: Game, bot: Bot): Array<String>
    {
      var p = game.player;
      p.evolutionManager.addImprov(IMP_OVUM, 1);
      game.updateHUD();
      if (!bot.pressAction('createOvum'))
        return [ 'no Create ovum on the region map' ];
      game.updateHUD();
      if (!bot.pressAction('nurtureOvum'))
        return [ 'no Nurture ovum on the ovum' ];
      if (p.state != PLR_STATE_PARASITE)
        return [ 'the host outlived the ovum: player is ' + p.state ];
      if (p.evolutionManager.ovum.xp <= 0)
        return [ 'the ovum gained nothing' ];
      return [];
    }

// a follower that died left the roster of a cult that lives on
  static function rosterLost(game: Game, hostID: Int, n: Int): Array<String>
    {
      var errs = [];
      var c = game.cults[0];
      if (c.state != CULT_STATE_ACTIVE)
        errs.push('the cult is ' + c.state + ' after a follower died');
      if (c.getMemberByID(hostID) != null)
        errs.push('the dead host ' + hostID + ' is still a member');
      if (c.members.length != n - 1)
        errs.push(n + ' members became ' + c.members.length + ', not ' + (n - 1));
      return errs;
    }
}
