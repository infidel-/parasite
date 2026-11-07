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
    'region-load-organ' => {
      start: 's2',
      run: regionLoadOrgan,
    },
    'defense-leader-dies' => {
      start: BASE + '+cu_tdef',
      run: defenseLeaderDies,
    },
    'defense-wave-gone' => {
      start: BASE + '+cu_tdef',
      run: defenseWaveGone,
    },
    'base-leave-custos' => {
      start: BASE,
      run: baseLeaveCustos,
    },
    'npc-discovered' => {
      start: 's11',
      run: npcDiscovered,
    },
    'summon-organs' => {
      start: 's1+cu_start+cu_members',
      run: summonOrgans,
    },
    'phase2-outside' => {
      start: 's2+cu_start',
      run: phase2Outside,
    },
  ];
  // the fixture with a cult base, standing in its habitat
  static inline var BASE = 'save/habitat-cult-base-t108-v0.21.json.gz';
  // the in-memory save slot the load scenarios use (Headless keeps 5 and 93-94)
  static inline var SLOT = 95;

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

// a save made on the region map with a host growing an organ loads with the organ still growing:
// the region host is in no area's AI list, so only Player.loadPost restores it
  static function regionLoadOrgan(game: Game, bot: Bot): Array<String>
    {
      var p = game.player;
      p.evolutionManager.addImprov(IMP_MUSCLE, 1);
      p.host.organs.action('set.IMP_MUSCLE');
      if (!p.host.organs.isGrowing)
        return [ 'the organ did not start growing' ];
      Saver.save(game, SLOT);
      game.load(SLOT);
      if (game.location != LOCATION_REGION ||
          game.player.state != PLR_STATE_HOST)
        return [ 'the load did not land on the region map with a host' ];
      if (!game.player.host.organs.isGrowing)
        return [ 'the region host stopped growing its organ across the load' ];
      return [];
    }

// the cult's leader dies during a team base defense: the defense ends with the cult, and the team
// calls its attack off on its next turn
  static function defenseLeaderDies(game: Game, bot: Bot): Array<String>
    {
      var c = game.cults[0];
      var base = c.base;
      if (base == null ||
          base.activeDefenseMissionID < 0)
        return [ 'cu tdef started no team base defense' ];
      var host = game.player.host;
      var rec = (host != null ? c.getMemberByID(host.id) : null);
      if (rec == null)
        return [ 'the fixture host is not a cult member' ];
      // the host leads (no entry point hands the lead over)
      c.members.remove(rec);
      c.members.unshift(rec);
      host.energy = 0;
      if (!bot.pressAction('skipTurn'))
        return [ 'no Wait in the base habitat' ];
      if (c.state != CULT_STATE_DEAD)
        return [ 'the cult is ' + c.state + ' after its leader expired' ];
      if (base.activeDefenseMissionID >= 0)
        return [ 'the base defense outlived the cult' ];
      bot.pressAction('skipTurn');
      if (game.group.team != null &&
          game.group.team.state == TEAM_BASE_DEFENSE)
        return [ 'the team still attacks the base of a dead cult' ];
      return [];
    }

// a team base defense whose wave vanished without dying (walked out and back in, as a rebirth does)
// spawns a fresh wave, or it could never finish
  static function defenseWaveGone(game: Game, bot: Bot): Array<String>
    {
      var base = game.cults[0].base;
      if (base == null ||
          base.activeDefenseMissionID < 0)
        return [ 'cu tdef started no team base defense' ];
      var area = game.area;
      if (area.id != base.areaID)
        return [ 'the fixture does not stand in the base habitat' ];
      var m: cult.missions.TeamBaseDefense = cast game.cults[0].ordeals.getMissionByID(base.activeDefenseMissionID);
      bot.pressAction('skipTurn');
      if (m.targetIDs.length == 0)
        return [ 'no wave spawned in the base' ];
      game.setLocation(LOCATION_REGION);
      game.setLocation(LOCATION_AREA, area);
      bot.pressAction('skipTurn');
      if (!Lambda.exists(m.targetIDs, function(id) return area.getAIByID(id) != null))
        return [ 'no fresh wave after the first one vanished' ];
      return [];
    }

// a custos guards the base habitat and stays: it is no outsider that blocks the exit
  static function baseLeaveCustos(game: Game, bot: Bot): Array<String>
    {
      var base = game.cults[0].base;
      if (base == null ||
          game.location != LOCATION_AREA ||
          game.area.id != base.areaID)
        return [ 'the fixture does not stand in the base habitat' ];
      // a custos made as CultBase.createCustos makes one, minus its organ and resource costs
      var loc = game.area.findEmptyLocationNear(game.playerArea.x, game.playerArea.y, 3);
      var custos = game.createAI('firmus', loc.x, loc.y);
      custos.guardTargetX = loc.x;
      custos.guardTargetY = loc.y;
      var data = new ai.CustosAIData(game);
      data.updateFromAI(custos, base.areaID, loc.x, loc.y, 'scenario');
      base.custodes.push(data);
      game.area.addAI(custos);
      // the habitat's exit object (HabitatExit) runs the same check
      game.playerArea.leaveAreaAction({
        id: 'leaveArea',
        type: ACTION_AREA,
        name: 'Leave area',
        energy: 0,
      });
      if (game.location != LOCATION_REGION)
        return [ 'the player could not leave the base habitat past its custos' ];
      return [];
    }

// a former NPC host that despawns is reported to have died in an accident (RegionManager), and it
// does die: the NPC is never spawned again
  static function npcDiscovered(game: Game, bot: Bot): Array<String>
    {
      var npc = game.player.host.npc;
      if (npc == null)
        return [ 's11 did not tie the host to an NPC' ];
      if (!bot.pressAction('leaveHost'))
        return [ 'no Leave host' ];
      // leaving the area despawns every AI in it, the former host too
      game.setLocation(LOCATION_REGION);
      if (!npc.isDead)
        return [ 'NPC ' + npc.id + ' is alive after its body was found' ];
      return [];
    }

// a cultist spawned from its member record (Cult.onArriveCultist) grows organs and heals as itself:
// the record's organs come along by reference, and their parent link must follow
  static function summonOrgans(game: Game, bot: Bot): Array<String>
    {
      var c = game.cults[0];
      var m = null;
      for (x in c.members)
        if (x.id != game.player.host.id)
          {
            m = x;
            break;
          }
      if (m == null)
        return [ 'cu members added no follower' ];
      var loc = game.area.findEmptyLocationNear(game.playerArea.x, game.playerArea.y, 3);
      var ai = game.area.spawnAI(m.type, loc.x, loc.y, false);
      ai.updateData(m, 'on spawn');
      game.area.addAI(ai);
      if (@:privateAccess ai.organs._ai != ai)
        return [ 'the summoned cultist\'s organs belong to another AI' ];
      if (@:privateAccess ai.effects.ai != ai)
        return [ 'the summoned cultist\'s effects belong to another AI' ];
      return [];
    }

// the second metamorphosis performed outside a habitat is refused, and the ordeal stays
  static function phase2Outside(game: Game, bot: Bot): Array<String>
    {
      var c = game.cults[0];
      var o = new cult.ordeals.MetamorphosisPhaseII(game);
      c.ordeals.list.push(o);
      // the cult window's Perform button runs this
      o.getActions()[0].f();
      if (c.ordeals.list.indexOf(o) < 0)
        return [ 'the ritual was used up on the region map' ];
      if (c.base != null)
        return [ 'a base grew on the region map' ];
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
