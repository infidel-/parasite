// scripted lifecycle scenarios for the headless tests: one per entry point of a lifecycle event in
// docs/relations.md. Each starts the way a fuzz run does (a preset or fixture, console commands
// chained with `+`, `_` for a space), sets up by hand only what no entry point reaches, acts through
// the player's own entry points (Bot.pressAction), and returns its broken expectations. Headless runs
// Bot.check after it.

package test;

import game.Game;
import game.Team;
import cult.ordeals.profane.GenericProfaneOrdeal;
import cult.ordeals.profane.ProfaneConst;
import cult.base.CultBase;
import cult.base.CultBaseOrgan;
import cult.base.CultBaseResources;
import const.CultBaseConst;

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
    'base-build' => {
      start: BASE + '+cu_br_200',
      run: baseBuild,
    },
    'base-tend' => {
      start: BASE + '+cu_br_300',
      run: baseTend,
    },
    'base-custos' => {
      start: BASE + '+cu_br_200',
      run: baseCustos,
    },
    'defense-rival' => {
      start: BASE + '+cu_br_100+cu_def',
      run: defenseRival,
    },
    'defense-timeout' => {
      start: BASE + '+cu_def',
      run: defenseTimeout,
    },
    'ambush-base-turn' => {
      start: BASE,
      run: ambushBaseTurn,
    },
    'base-economy' => {
      start: BASE + '+cu_br_50',
      run: baseEconomy,
    },
    'rival-lifecycle' => {
      start: BASE,
      run: rivalLifecycle,
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
    'ambush-base' => {
      start: BASE,
      run: ambushBase,
    },
    'load-habitat-fight' => {
      start: 's22',
      run: loadHabitatFight,
    },
    'despawn-target' => {
      start: 's1',
      run: despawnTarget,
    },
    'kill-target' => {
      start: 's1+cu_start+cu_members',
      run: killTarget,
    },
    'ordeal-member-dies' => {
      start: 's2+cu_start+cu_members',
      run: ordealMemberDies,
    },
    'region-effects' => {
      start: 's2',
      run: regionEffects,
    },
    'rebirth-region' => {
      start: 's11',
      run: rebirthRegion,
    },
    'rebirth-area' => {
      start: 's11',
      run: rebirthArea,
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

// every organ grows from Forma on a free spot for its build cost, a Porta grows over a Murus and
// replaces it, and a blocked footprint or an empty stockpile refuses the build and spends nothing
  static function baseBuild(game: Game, bot: Bot): Array<String>
    {
      var base = game.cults[0].base;
      if (!bot.pressAction('forma'))
        return [ 'no Forma in the base habitat' ];
      var errs = [];
      var wall: CultBaseOrgan = null;
      for (type in CultBaseConst.buildableTypes)
        {
          if (type == RIBGATE)
            continue;
          var spot = freeSpot(game, base, type);
          if (spot == null)
            {
              errs.push('no room for ' + type);
              continue;
            }
          var before = base.resources.clone();
          var n = base.organs.length;
          // Q in Forma: a turret's west is a wall's north-south run
          base.selectedDirection = (type == RIBWALL ? 3 : 0);
          grow(game, type, spot.x, spot.y);
          var organ = base.getOrganAt(spot.x, spot.y);
          if (organ == null ||
              organ.type != type ||
              organ.x != spot.x ||
              organ.y != spot.y ||
              base.organs.length != n + 1)
            {
              errs.push(type + ' did not grow at ' + spot.x + ',' + spot.y);
              continue;
            }
          errs = errs.concat(paid(base, before, CultBaseConst.buildCost(type), 'growing ' + type));
          if (type == RIBWALL)
            {
              wall = organ;
              if (wall.direction != 1)
                errs.push('a Murus grown at direction 3 runs ' + wall.direction + ', not 1 (north-south)');
            }
        }
      if (wall == null)
        return errs;

      // the Porta tool on a Murus grows the gate in its place
      var before = base.resources.clone();
      grow(game, RIBGATE, wall.x, wall.y);
      var gate = base.getOrganAt(wall.x, wall.y);
      if (gate == null ||
          gate.type != RIBGATE)
        errs.push('no Porta grew over the Murus');
      else if (gate.direction != wall.direction)
        errs.push('the Porta runs ' + gate.direction + ', its Murus ran ' + wall.direction);
      if (base.organs.indexOf(wall) >= 0)
        errs.push('the Murus record outlived its Porta');
      for (o in game.area.getObjects())
        if (o.type == 'base_organ' &&
            (cast o : objects.base.BaseOrganObject).organID == wall.id)
          errs.push('the Murus object outlived its Porta');
      errs = errs.concat(paid(base, before, CultBaseConst.buildCost(RIBGATE), 'growing the Porta'));

      // a footprint over the heart is refused
      var heart = base.getHeart();
      var n = base.organs.length;
      before = base.resources.clone();
      if (base.getOrganAt(heart.x - 1, heart.y) != null ||
          !base.canUseCursorTile(heart.x - 1, heart.y))
        return errs.concat([ 'the fixture has no free tile left of the heart' ]);
      grow(game, RAT_NEST, heart.x - 1, heart.y);
      if (base.organs.length != n)
        errs.push('a Nidus grew over the heart');
      errs = errs.concat(paid(base, before, new CultBaseResources(), 'a blocked build'));

      // an empty stockpile is refused
      base.resources = new CultBaseResources();
      var spot = freeSpot(game, base, FLESH_BLOCK);
      grow(game, FLESH_BLOCK, spot.x, spot.y);
      if (base.organs.length != n)
        errs.push('a Quadrum grew for nothing');
      if (!base.resources.isEmpty())
        errs.push('a refused build left resources ' + text(base.resources));
      return errs;
    }

// a Nidus upgraded from its tend menu pays its build cost, then double, and stops at its top level;
// the heart upgraded from its object raises the stockpile cap; a broken organ repaired from its
// object is whole again for a quarter of its build cost, and a whole organ offers no repair
  static function baseTend(game: Game, bot: Bot): Array<String>
    {
      var base = game.cults[0].base;
      var forma = game.ui.hud.forma;
      if (!bot.pressAction('forma'))
        return [ 'no Forma in the base habitat' ];
      var spot = freeSpot(game, base, RAT_NEST);
      grow(game, RAT_NEST, spot.x, spot.y);
      var nest = base.getOrganAt(spot.x, spot.y);
      if (nest == null)
        return [ 'no Nidus grew' ];
      var errs = [];
      var costs = [
        new CultBaseResources(8, 2, 4),
        new CultBaseResources(16, 4, 8),
      ];
      for (i in 0...3)
        {
          var before = base.resources.clone();
          var level = nest.level;
          // a click on the organ opens its tend menu; its first row upgrades
          forma.onMapClick(nest.x, nest.y);
          @:privateAccess forma.tendOptions(nest)[0].run();
          @:privateAccess forma.closeTend();
          if (i < 2)
            {
              if (nest.level != level + 1)
                errs.push('the Nidus stayed at level ' + nest.level);
              if (nest.health != nest.maxHealth())
                errs.push('the upgraded Nidus has ' + nest.health + ' of ' + nest.maxHealth() + ' health');
              errs = errs.concat(paid(base, before, costs[i], 'upgrade to level ' + (level + 1)));
            }
          else
            {
              if (nest.level != 3)
                errs.push('the Nidus grew past its top level to ' + nest.level);
              errs = errs.concat(paid(base, before, new CultBaseResources(), 'an upgrade past the top level'));
            }
        }
      bot.pressAction('baseExit');

      // the heart, from its own object, listed once from a tile two of its parts touch
      var heart = base.getHeart();
      var before = base.resources.clone();
      var touch = (game.area.isWalkable(heart.x, heart.y - 1) ?
        { x: heart.x, y: heart.y - 1 } :
        { x: heart.x - 1, y: heart.y });
      if (!game.playerArea.moveTo(touch.x, touch.y))
        return errs.concat([ 'no free tile beside the heart' ]);
      game.updateHUD();
      var offered = Lambda.count(@:privateAccess bot.options(), function(o) return o.id == 'upgradeHeart');
      if (offered != 1)
        errs.push('Upgrade Cor Nefandum is listed ' + offered + ' times beside the heart');
      if (!bot.pressAction('upgradeHeart'))
        return errs.concat([ 'no Upgrade Cor Nefandum next to the heart' ]);
      if (heart.level != 2 ||
          heart.health != 80)
        errs.push('the heart is level ' + heart.level + ' with ' + heart.health + ' health, not 2 with 80');
      if (base.stockpileCap() != 150)
        errs.push('the stockpile cap is ' + base.stockpileCap() + ' after a heart upgrade, not 150');
      errs = errs.concat(paid(base, before, new CultBaseResources(40, 30, 30), 'the heart upgrade'));

      // a broken Nidus, from its own object
      base.damageOrgan(nest, nest.health);
      if (!nest.broken)
        errs.push('the Nidus at 0 health is not broken');
      before = base.resources.clone();
      if (!standNextTo(game, nest) ||
          !bot.pressAction('repairBaseOrgan'))
        return errs.concat([ 'no Repair next to the broken Nidus' ]);
      if (nest.broken ||
          nest.health != nest.maxHealth())
        errs.push('the repaired Nidus is broken ' + nest.broken + ' at ' + nest.health + ' health');
      errs = errs.concat(paid(base, before, new CultBaseResources(2, 1, 1), 'the repair'));
      game.updateHUD();
      if (bot.pressAction('repairBaseOrgan'))
        errs.push('a whole organ offers a repair');

      // the heart mends for a quarter of its first upgrade, 10/8/8
      base.damageOrgan(heart, 10);
      before = base.resources.clone();
      if (!standNextTo(game, heart) ||
          !bot.pressAction('repairBaseOrgan'))
        return errs.concat([ 'no Repair next to the wounded heart' ]);
      if (heart.health != heart.maxHealth())
        errs.push('the repaired heart has ' + heart.health + ' of ' + heart.maxHealth() + ' health');
      errs = errs.concat(paid(base, before, new CultBaseResources(10, 8, 8), 'the heart repair'));
      return errs.concat(baseDefenses(game, bot, base));
    }

// the defense organs grow to level 3 for their build cost, then double, with the level's health; a
// working Murus or Porta blocks sight and a broken one does not; a Porta bites and makes bleed by
// level, a Tardans slimes and wears down by level, a turret hits one foe in line (two at level 3)
// for its level's damage, turns a quarter from the Forma menu for nothing and from its object for
// one turn, and neither turns while broken
  static function baseDefenses(game: Game, bot: Bot, base: CultBase): Array<String>
    {
      var errs = [];
      var forma = game.ui.hud.forma;
      base.resources = new CultBaseResources(100, 100, 100);
      if (!bot.pressAction('forma'))
        return [ 'no Forma for the defense organs' ];
      var health: Map<String, Array<Int>> = [
        'RIBWALL' => [ 18, 26, 34 ],
        'RIBGATE' => [ 24, 32, 40 ],
        'SPINE_TURRET' => [ 18, 24, 30 ],
        'BLOOD_TRAP' => [ 10, 14, 18 ],
      ];
      var organs: Map<String, CultBaseOrgan> = [];
      var turretDir = 0;
      var types: Array<_CultBaseOrganType> = [ RIBWALL, RIBGATE, SPINE_TURRET, BLOOD_TRAP ];
      for (type in types)
        {
          // a gate grows over a wall, a turret needs three clear tiles to shoot along
          var spot = freeSpot(game, base, (type == RIBGATE ? RIBWALL : type));
          if (type == SPINE_TURRET)
            {
              spot = null;
              for (y in 0...game.area.height)
                for (x in 0...game.area.width)
                  if (spot == null &&
                      base.validateBuild(type, x, y) == '')
                    for (d in 0...4)
                      if (spot == null &&
                          clearLine(game, x, y, d))
                        {
                          spot = { x: x, y: y };
                          turretDir = d;
                        }
            }
          if (spot == null)
            return errs.concat([ 'no room for ' + type ]);
          base.selectedDirection = turretDir;
          if (type == RIBGATE)
            grow(game, RIBWALL, spot.x, spot.y);
          grow(game, type, spot.x, spot.y);
          var organ = base.getOrganAt(spot.x, spot.y);
          if (organ == null ||
              organ.type != type)
            return errs.concat([ 'no ' + type + ' grew at ' + spot.x + ',' + spot.y ]);
          organs[type] = organ;
          var hp = health[type];
          if (CultBaseConst.info(type).maxLevel != 3)
            errs.push(type + ' tops at level ' + CultBaseConst.info(type).maxLevel + ', not 3');
          var unit = CultBaseConst.buildCost(type);
          for (i in 0...3)
            {
              if (organ.health != hp[i])
                errs.push(type + ' level ' + organ.level + ' has ' + organ.health + ' health, not ' + hp[i]);
              var before = base.resources.clone();
              forma.onMapClick(organ.x, organ.y);
              @:privateAccess forma.tendOptions(organ)[0].run();
              @:privateAccess forma.closeTend();
              var mult = (i == 0 ? 1 : (i == 1 ? 2 : 0));
              errs = errs.concat(paid(base, before, new CultBaseResources(unit.flesh * mult,
                unit.blood * mult, unit.bone * mult), type + ' upgrade ' + (i + 1)));
            }
          if (organ.level != 3)
            errs.push(type + ' is level ' + organ.level + ' after its upgrades, not 3');
        }

      // sight: a working Murus and Porta block it, a broken one does not, a mended one blocks again
      var seeing: Array<_CultBaseOrganType> = [ RIBWALL, RIBGATE ];
      for (type in seeing)
        {
          var organ = organs[type];
          if (game.area.canSeeThrough(organ.x, organ.y))
            errs.push('a working ' + type + ' lets sight through');
          base.damageOrgan(organ, organ.health);
          if (!game.area.canSeeThrough(organ.x, organ.y))
            errs.push('a broken ' + type + ' blocks sight');
          base.resources = new CultBaseResources(100, 100, 100);
          forma.onMapClick(organ.x, organ.y);
          @:privateAccess forma.tendOptions(organ)[1].run();
          @:privateAccess forma.closeTend();
          if (game.area.canSeeThrough(organ.x, organ.y))
            errs.push('a mended ' + type + ' lets sight through');
        }

      // the turret turns from the Forma menu for nothing, and not while broken
      var turret = organs['SPINE_TURRET'];
      var before = base.resources.clone();
      var dir = turret.direction;
      forma.onMapClick(turret.x, turret.y);
      @:privateAccess forma.tendOptions(turret)[2].run();
      @:privateAccess forma.closeTend();
      if (turret.direction != (dir + 1) % 4)
        errs.push('the Turn row left the turret at ' + turret.direction + ', not ' + ((dir + 1) % 4));
      errs = errs.concat(paid(base, before, new CultBaseResources(), 'turning the turret'));
      // back to the clear line: three more quarters
      for (i in 0...3)
        base.turnTurret(turret);
      if (turret.direction != dir)
        errs.push('four turns left the turret at ' + turret.direction + ', not ' + dir);
      base.damageOrgan(turret, turret.health);
      if (base.validateTurn(turret) == '')
        errs.push('a broken turret turns');
      base.resources = new CultBaseResources(100, 100, 100);
      base.setCursor(turret.x, turret.y);
      base.repairAtCursor();
      bot.pressAction('baseExit');

      // the object action costs one turn and turns the turret
      if (!standNextTo(game, turret))
        return errs.concat([ 'no tile beside the turret' ]);
      var turns = game.turns;
      var ap = game.playerArea.ap;
      if (!bot.pressAction('turnTurret'))
        return errs.concat([ 'no Turn turret beside the turret' ]);
      if (turret.direction != (dir + 1) % 4)
        errs.push('Turn turret left the turret at ' + turret.direction + ', not ' + ((dir + 1) % 4));
      // one action point, which ends the turn when it was the last
      if (game.turns != turns + 1 &&
          game.playerArea.ap != ap - 1)
        errs.push('Turn turret spent no action point and no turn');
      for (i in 0...3)
        base.turnTurret(turret);

      // the shots: a level 3 turret hits two foes in line, a level 1 turret one
      var obj: objects.base.SpineTurret = null;
      for (o in game.area.getObjects())
        if (o.type == 'base_organ' &&
            Std.isOfType(o, objects.base.SpineTurret) &&
            cast(o, objects.base.BaseOrganObject).organID == turret.id)
          obj = cast o;
      var dx = [ 0, 1, 0, -1 ][turret.direction];
      var dy = [ -1, 0, 1, 0 ][turret.direction];
      var thugs = [ for (k in 1...4) game.area.spawnAI('thug', turret.x + dx * k, turret.y + dy * k) ];
      for (t in thugs)
        {
          t.maxHealth = 500;
          t.health = 500;
        }
      for (level in [ 3, 1 ])
        {
          turret.level = level;
          turret.health = turret.maxHealth();
          var hp = [ for (t in thugs) t.health ];
          obj.turn();
          var hit = [ for (i in 0...3) hp[i] - thugs[i].health ];
          var dmg = CultBaseConst.turretDamage(level);
          var want = (level == 3 ? 2 : 1);
          var hits = Lambda.count(hit, function(h) return h > 0);
          if (hits != want ||
              hit[2] != 0)
            errs.push('a level ' + level + ' turret hit ' + hit.join('/') + ', not the first ' + want);
          for (h in hit)
            if (h > 0 &&
                (h < dmg.min ||
                 h > dmg.max))
              errs.push('a level ' + level + ' turret did ' + h + ' damage, not ' + dmg.min + '-' + dmg.max);
          for (i in 0...3)
            thugs[i].health = 500;
        }
      // the player host and a preserved host stand in line and are never shot, the foe behind them is
      var host = game.player.host;
      var keep = { x: host.x, y: host.y, health: host.health };
      var preserved = thugs[1];
      turret.level = 1;
      turret.health = turret.maxHealth();
      for (t in thugs)
        t.health = 500;
      host.x = thugs[0].x;
      host.y = thugs[0].y;
      thugs[0].x = turret.x + dx * 4;
      thugs[0].y = turret.y + dy * 4;
      preserved.state = AI_STATE_PRESERVED;
      var hostHP = host.health;
      var preservedHP = preserved.health;
      var behindHP = thugs[2].health;
      obj.turn();
      if (host.health != hostHP)
        errs.push('the turret shot the player host');
      if (preserved.health != preservedHP)
        errs.push('the turret shot a preserved host');
      if (thugs[2].health == behindHP)
        errs.push('the turret did not shoot the foe behind the host');
      host.x = keep.x;
      host.y = keep.y;
      host.health = keep.health;
      thugs[0].x = turret.x + dx;
      thugs[0].y = turret.y + dy;
      preserved.state = AI_STATE_IDLE;
      if (CultBaseConst.turretDamage(1).max != 8 ||
          CultBaseConst.turretDamage(3).min != 5)
        errs.push('the turret damage table is wrong');

      // the Porta bite and the Tardans mud, by level
      var gate: objects.base.BaseOrganObject = null;
      var trap: objects.base.BaseOrganObject = null;
      for (o in game.area.getObjects())
        if (o.type == 'base_organ')
          {
            var b: objects.base.BaseOrganObject = cast o;
            if (b.organID == organs['RIBGATE'].id)
              gate = b;
            else if (b.organID == organs['BLOOD_TRAP'].id)
              trap = b;
          }
      var effs: Array<_AIEffectType> = [ EFFECT_BLEEDING, EFFECT_SLIME ];
      for (level in [ 1, 2, 3 ])
        {
          var g = organs['RIBGATE'];
          var t = organs['BLOOD_TRAP'];
          g.level = level;
          t.level = level;
          g.health = g.maxHealth();
          t.health = t.maxHealth();
          var foe = thugs[0];
          foe.health = 500;
          var hp0 = foe.health;
          for (e in effs)
            if (foe.effects.has(e))
              foe.effects.decrease(e, 9999, foe);
          if (gate.frob(false, foe) != 0)
            errs.push('a Porta let a foe through');
          var bite = CultBaseConst.gateBite(level);
          var lost = hp0 - foe.health;
          if (lost < bite.min ||
              lost > bite.max)
            errs.push('a level ' + level + ' Porta bit for ' + lost + ', not ' + bite.min + '-' + bite.max);
          if (!foe.effects.has(effs[0]))
            errs.push('a level ' + level + ' Porta left the foe unhurt by bleeding');
          if (g.health != g.maxHealth() - 1)
            errs.push('a Porta bite cost the gate ' + (g.maxHealth() - g.health) + ' health, not 1');
          trap.frob(false, foe);
          var slime = foe.effects.get(effs[1]);
          if (slime == null ||
              slime.points != CultBaseConst.trapSlime(level))
            errs.push('a level ' + level + ' Tardans left slime ' + (slime == null ? 'none' : '' + slime.points) +
              ', not ' + CultBaseConst.trapSlime(level));
          if (t.health != t.maxHealth() - 1)
            errs.push('a Tardans trigger cost the pool ' + (t.maxHealth() - t.health) + ' health, not 1');
        }
      for (o in [ organs['RIBGATE'], organs['BLOOD_TRAP'], turret ])
        {
          o.level = 3;
          o.health = o.maxHealth();
        }
      return errs;
    }

// true when the three tiles from (x, y) one way (0 north, 1 east, 2 south, 3 west) are free floor
// and let sight through
  static function clearLine(game: Game, x: Int, y: Int, d: Int): Bool
    {
      for (k in 1...4)
        {
          var tx = x + [ 0, 1, 0, -1 ][d] * k;
          var ty = y + [ -1, 0, 1, 0 ][d] * k;
          if (tx < 0 ||
              ty < 0 ||
              tx >= game.area.width ||
              ty >= game.area.height ||
              !game.area.isWalkable(tx, ty) ||
              !game.area.canSeeThrough(tx, ty) ||
              game.area.hasAI(tx, ty))
            return false;
        }
      return true;
    }

// custodes are crafted from Forma only with a working Caldarium, two per level, for their cost, and
// walk out and back in with the same ids
  static function baseCustos(game: Game, bot: Bot): Array<String>
    {
      var base = game.cults[0].base;
      var forma = game.ui.hud.forma;
      if (!bot.pressAction('forma'))
        return [ 'no Forma in the base habitat' ];
      var errs = [];
      var craft = function(id: String, label: String, ok: Bool)
        {
          var tile = freeTile(game, base);
          var before = base.resources.clone();
          var n = base.custodes.length;
          forma.pick(id, false);
          forma.onMapClick(tile.x, tile.y);
          if (!ok)
            {
              if (base.custodes.length != n)
                errs.push('a custos was crafted ' + label);
              errs = errs.concat(paid(base, before, new CultBaseResources(), 'a custos ' + label));
              return;
            }
          var ai = game.area.getAI(tile.x, tile.y);
          if (base.custodes.length != n + 1 ||
              ai == null ||
              !ai.isCustos ||
              base.custodes[n].id != ai.id)
            {
              errs.push('no ' + id + ' custos crafted at ' + tile.x + ',' + tile.y);
              return;
            }
          errs = errs.concat(paid(base, before, new CultBaseResources(10, 8, 0), 'a custos'));
        };
      craft('firmus', 'without a Caldarium', false);
      var spot = freeSpot(game, base, CAULDRON);
      grow(game, CAULDRON, spot.x, spot.y);
      if (base.custosCap() != 2)
        return errs.concat([ 'a Caldarium holds ' + base.custosCap() + ' custodes, not 2' ]);
      craft('firmus', '', true);
      craft('mordax', '', true);
      craft('firmus', 'past the cap', false);
      bot.pressAction('baseExit');
      errs = errs.concat(custosStats(game, bot, base));

      // out to the region map and back in: the records spawn their custodes again
      var ids = [ for (d in base.custodes) d.id ];
      var area = game.area;
      game.setLocation(LOCATION_REGION);
      game.setLocation(LOCATION_AREA, area);
      for (id in ids)
        {
          var ai = game.area.getAIByID(id);
          if (ai == null ||
              !ai.isCustos)
            errs.push('custos ' + id + ' did not come back with the player');
        }
      return errs;
    }

// the two custodes against design.md: life 26 (Firmus) and 16 (Mordax) at the base stats, a ±1 STR/CON roll
// moving it by 2 at most, their own attacks (slam 1-4, bite 3-8), a cult turn healing a hurt one a point
// while the player is in the base and none while a raid runs, and no custos picks the player's host
  static function custosStats(game: Game, bot: Bot, base: CultBase): Array<String>
    {
      var errs = [];
      var firmus = game.area.getAIByID(base.custodes[0].id);
      var mordax = game.area.getAIByID(base.custodes[1].id);
      if (firmus.type != 'firmus' ||
          mordax.type != 'mordax')
        return [ 'the custodes are ' + firmus.type + ' and ' + mordax.type ];
      if (firmus.maxHealth < 24 ||
          firmus.maxHealth > 28)
        errs.push('a Firmus has ' + firmus.maxHealth + ' life, not 24-28');
      if (mordax.maxHealth < 14 ||
          mordax.maxHealth > 18)
        errs.push('a Mordax has ' + mordax.maxHealth + ' life, not 14-18');
      var slam = firmus.getCurrentWeaponItemInfo().weapon;
      if (slam.minDamage != 1 ||
          slam.maxDamage != 4)
        errs.push('a Firmus hits for ' + slam.minDamage + '-' + slam.maxDamage + ', not 1-4');
      var bite = mordax.getCurrentWeaponItemInfo().weapon;
      if (bite.minDamage != 3 ||
          bite.maxDamage != 8)
        errs.push('a Mordax hits for ' + bite.minDamage + '-' + bite.maxDamage + ', not 3-8');

      // heals a point a cult turn in the base, not while a raid runs
      firmus.health = 1;
      if (!cultTurn(game, bot))
        return errs.concat([ 'no cult turn in 10 Waits' ]);
      if (firmus.health != 2)
        errs.push('a hurt Firmus has ' + firmus.health + ' health after a cult turn, not 2');
      base.activeDefenseMissionID = 0;
      cultTurn(game, bot);
      base.activeDefenseMissionID = -1;
      if (firmus.health != 2)
        errs.push('a Firmus healed to ' + firmus.health + ' during a raid');

      // the player's host is no intruder, any other AI in sight is
      var host = game.player.host;
      host.isCultist = false;
      var beside = game.area.findEmptyLocationNear(mordax.x, mordax.y, 1);
      game.playerArea.moveTo(beside.x, beside.y);
      // a free tile the Mordax sees, farther from it than the host
      var loc: _Point = null;
      for (y in (mordax.y - 5)...(mordax.y + 6))
        for (x in (mordax.x - 5)...(mordax.x + 6))
          if (loc == null &&
              game.area.isWalkable(x, y) &&
              !game.area.hasAI(x, y) &&
              mordax.seesPosition(x, y) &&
              Const.distanceSquared(mordax.x, mordax.y, x, y) >
              Const.distanceSquared(mordax.x, mordax.y, host.x, host.y))
            loc = { x: x, y: y };
      if (loc == null)
        return errs.concat([ 'no tile the Mordax sees beyond the host' ]);
      var thug = game.area.spawnAI('thug', loc.x, loc.y);
      var target = @:privateAccess ai.CustosLogic.findTarget(mordax);
      if (target == host)
        errs.push('a custos picked the player host');
      if (target != thug)
        errs.push('a custos does not pick the thug in sight');
      return errs;
    }

// a cult turn pays each working organ its income: a body each to Fractor and Cumulus while any are
// stored, Cumulus's fallback without, nothing from a broken organ; the stockpile clamps to its cap,
// a heart upgrade raises the cap and the pressure per turn, and Cadaverum stores 8 bodies
  static function baseEconomy(game: Game, bot: Bot): Array<String>
    {
      var base = game.cults[0].base;
      if (!bot.pressAction('forma'))
        return [ 'no Forma in the base habitat' ];
      var nest: CultBaseOrgan = null;
      var types: Array<_CultBaseOrganType> = [ RAT_NEST, FLESH_BLOCK, CRUSHER, GARBAGE_HEAP, BODY_STORAGE ];
      for (type in types)
        {
          var spot = freeSpot(game, base, type);
          grow(game, type, spot.x, spot.y);
          if (type == RAT_NEST)
            nest = base.getOrganAt(spot.x, spot.y);
        }
      bot.pressAction('baseExit');
      if (base.organs.length != 6)
        return [ 'the economy organs did not all grow: ' + base.organs.length + ' organs' ];
      // 30/20/20 + 50 each, less 58/14/36 of organs
      var errs = stock(base, 22, 56, 34, 'after growing');
      var overflow = base.addBodies(20);
      if (overflow != 12 ||
          base.storedBodies != 8)
        errs.push('20 bodies left ' + overflow + ' over and ' + base.storedBodies + ' stored, not 12 and 8');

      // Nidus 3/1/1, Quadrum 5 flesh, Fractor a body to 5 bone, Cumulus a body to 5 flesh
      var pressure = base.attackPressure;
      if (!cultTurn(game, bot))
        return errs.concat([ 'no cult turn in 10 Waits' ]);
      errs = errs.concat(stock(base, 35, 57, 40, 'after the first turn'));
      if (base.storedBodies != 6)
        errs.push('the first turn left ' + base.storedBodies + ' bodies, not 6');
      if (base.attackPressure != pressure + 1)
        errs.push('pressure rose by ' + (base.attackPressure - pressure) + ' in a turn, not 1');

      // no bodies: Fractor idles, Cumulus falls back to 2 flesh
      base.storedBodies = 0;
      cultTurn(game, bot);
      errs = errs.concat(stock(base, 45, 58, 41, 'after a turn with no bodies'));

      // a broken Nidus pays nothing
      base.damageOrgan(nest, nest.health);
      cultTurn(game, bot);
      errs = errs.concat(stock(base, 52, 58, 41, 'after a turn with the Nidus broken'));
      // Corpus Basilica counts working organs: Quadrum, Fractor, Cumulus and Cadaverum, not the Nidus
      if (base.readiness().organLevels != 4)
        errs.push('readiness counts ' + base.readiness().organLevels + ' organ levels with a broken Nidus, not 4');

      // the stockpile clamps to its cap
      base.resources = new CultBaseResources(99, 99, 99);
      cultTurn(game, bot);
      errs = errs.concat(stock(base, 100, 99, 99, 'at the cap'));

      // a heart upgrade: the cap rises to 150 and pressure by 2 a turn
      var heart = base.getHeart();
      if (!standNextTo(game, heart) ||
          !bot.pressAction('upgradeHeart'))
        return errs.concat([ 'no Upgrade Cor Nefandum next to the heart' ]);
      base.resources = new CultBaseResources(149, 10, 10);
      pressure = base.attackPressure;
      cultTurn(game, bot);
      errs = errs.concat(stock(base, 150, 10, 10, 'at the raised cap'));
      if (base.attackPressure != pressure + 2)
        errs.push('pressure rose by ' + (base.attackPressure - pressure) + ' in a turn after a heart upgrade, not 2');

      // the Nidus focus: 3 of the focus and 1 of each other per level (the Nidus mended, no bodies)
      nest.broken = false;
      nest.health = nest.maxHealth();
      base.storedBodies = 0;
      base.resources = new CultBaseResources();
      for (focus in CultBaseConst.focusTypes)
        {
          if (!base.setFocus(nest, focus) &&
              focus != FLESH)
            errs.push('the Nidus refused the focus ' + focus);
          // plus Quadrum 5 flesh and Cumulus 2 flesh
          cultTurn(game, bot);
          errs = errs.concat(stock(base, 8 + (focus == FLESH ? 2 : 0), (focus == BLOOD ? 3 : 1), (focus == BONE ? 3 : 1),
            'after a turn on focus ' + focus));
          base.resources = new CultBaseResources();
        }

      // a body drained at Cadaverum is 4 blood at once, refused with none stored or a full blood stockpile
      var storage: CultBaseOrgan = null;
      for (organ in base.organs)
        if (organ.type == BODY_STORAGE)
          storage = organ;
      base.storedBodies = 2;
      if (!base.drainBody(storage) ||
          base.storedBodies != 1 ||
          base.resources.blood != 4)
        errs.push('draining a body left ' + base.storedBodies + ' bodies and ' + base.resources.blood + ' blood, not 1 and 4');
      base.storedBodies = 0;
      if (base.validateDrain(storage) == '')
        errs.push('a body drained with none stored');
      base.storedBodies = 1;
      base.resources.blood = base.stockpileCap();
      if (base.validateDrain(storage) == '')
        errs.push('a body drained into a full blood stockpile');

      // Reap the Unwary: 100k money or two of the four powers, and no payment without a working Cadaverum
      var c = game.cults[0];
      var reap = new cult.ordeals.ReapTheUnwary(game);
      var paying = (reap.powerTypes.length == 1 ? reap.powerTypes[0] == 'money' :
        (reap.powerTypes.length == 2 && reap.powerTypes.indexOf('money') < 0));
      if (!paying)
        errs.push('Reap the Unwary costs ' + reap.powerTypes.join('+'));
      // a new ordeal waits for the next cult turn to give its members their actions
      reap.actions = 0;
      c.resources.set('money', 1000000);
      for (power in [ 'media', 'lawfare', 'corporate', 'political' ])
        c.resources.set(power, 5);
      if (Lambda.count(reap.getActions(), function(a) return a.id.indexOf('spend.') == 0) == 0)
        errs.push('no payment offered with a working Cadaverum');
      base.damageOrgan(storage, storage.health);
      if (Lambda.count(reap.getActions(), function(a) return a.id.indexOf('spend.') == 0) > 0)
        errs.push('a payment is offered with Cadaverum broken');
      return errs;
    }

// a rival's raid on the base: its attackers are armed by member level, walk to Cor Nefandum and break the
// organs that wall it in, the bodies of the raid (and no older body) go to Cadaverum off the floor when the
// last attacker is dead, and the defense counts as survived; the next pressure defense names a live rival
  static function defenseRival(game: Game, bot: Bot): Array<String>
    {
      var c = game.cults[0];
      var base = c.base;
      var ordeal: cult.ordeals.BaseDefense = null;
      for (o in c.ordeals.list)
        if (Std.isOfType(o, cult.ordeals.BaseDefense))
          ordeal = cast o;
      if (base == null ||
          ordeal == null)
        return [ 'cu def started no base defense' ];
      if (ordeal.cultID < 0)
        return [ 'cu def named no rival cult' ];
      var m: cult.missions.BaseDefense = cast ordeal.missions[0];
      var errs = [];

      // a Cadaverum for the bodies, and a body from before the raid
      // (Forma is closed while a raid runs: the organ is placed by hand)
      var spot = freeSpot(game, base, BODY_STORAGE);
      var storage = new CultBaseOrgan(BODY_STORAGE, base.areaID, spot.x, spot.y, 0);
      base.organs.push(storage);
      @:privateAccess base.createOrganObject(storage);
      if (base.bodyCapacity() != 8)
        return [ 'no Cadaverum grew' ];
      var tile = freeTile(game, base);
      var decoy = new objects.BodyObject(game, game.area.id, tile.x, tile.y, 'civilian');
      base.defenseFirstBodyID = objects.AreaObject._maxID;

      // the wave comes in on the next turn, armed by its members' levels
      if (!bot.pressAction('skipTurn'))
        return errs.concat([ 'no Wait in the base habitat' ]);
      if (m.targetIDs.length < 1)
        return errs.concat([ 'no attackers spawned' ]);
      var attackers = [ for (id in m.targetIDs) game.area.getAIByID(id) ];
      for (a in attackers)
        {
          if (a == null)
            {
              errs.push('an attacker is not in the area');
              continue;
            }
          var level = game.jobs.getJobInfo(a.job).level;
          if (!a.inventory.hasWeapon())
            errs.push('a level ' + level + ' attacker has no weapon');
          if (level >= 2 &&
              a.inventory.getCurrentRangedWeapon() == null)
            errs.push('a level ' + level + ' attacker has no ranged weapon');
          if (level >= 3 &&
              a.inventory.clothing.id != 'kevlarArmor')
            errs.push('a level 3 attacker has no kevlar');
        }

      // Cor Nefandum walled in by ribs: the route breaks one, then hits the heart
      var heart = base.getHeart();
      var walls = 0;
      for (y in (heart.y - 1)...(heart.y + 3))
        for (x in (heart.x - 1)...(heart.x + 3))
          if (base.getOrganAt(x, y) == null &&
              base.canUseCursorTile(x, y) &&
              game.area.isWalkable(x, y))
            {
              // whoever stands there is moved off the wall's tile
              var occupant = game.area.getAI(x, y);
              if (occupant != null)
                {
                  var away = game.area.findEmptyLocationNear(x, y, 6);
                  occupant.setPosition(away.x, away.y);
                }
              var wall = new CultBaseOrgan(RIBWALL, base.areaID, x, y, 0);
              base.organs.push(wall);
              @:privateAccess base.createOrganObject(wall);
              walls++;
            }
      var a = attackers[0];
      var hits: Array<_CultBaseOrganType> = [];
      for (i in 0...40)
        {
          var step = @:privateAccess cult.missions.BaseDefenseLogic.getHeartRoute(game, base, heart, a);
          if (step == null)
            {
              errs.push('no route to the heart');
              break;
            }
          if (step.obj == null)
            {
              a.setPosition(step.x, step.y);
              continue;
            }
          var organ = step.obj.getOrgan();
          hits.push(organ.type);
          if (organ == heart)
            break;
          base.damageOrgan(organ, organ.health);
        }
      if (hits.length == 0 ||
          hits[hits.length - 1] != COR_NEFANDUM)
        errs.push('the attacker never reached the heart: it hit ' + hits);
      else if (walls > 0 &&
          hits.length < 2)
        errs.push('the attacker walked through ' + walls + ' ribwalls to the heart');

      // the last attacker falls: its body is made after the death event, and the mission ends next turn
      var stored = base.storedBodies;
      var survived = base.defensesSurvived;
      for (id in m.targetIDs.copy())
        game.area.getAIByID(id).die();
      if (!bot.pressAction('skipTurn'))
        return errs.concat([ 'no Wait after the raid' ]);
      if (base.activeDefenseMissionID >= 0)
        errs.push('the defense is still running with no attacker left');
      if (base.defensesSurvived != survived + 1)
        errs.push('defenses survived is ' + base.defensesSurvived + ', not ' + (survived + 1));
      if (base.storedBodies != stored + attackers.length)
        errs.push('Cadaverum holds ' + base.storedBodies + ' bodies, not ' + (stored + attackers.length));
      var left = [ for (o in game.area.getObjects()) if (o.type == 'body') o ];
      if (left.length != 1 ||
          left[0] != decoy)
        errs.push(left.length + ' bodies lie on the floor after loading, not just the older one');

      // pressure with no culprit raids with a live rival
      base.attackPressure = 29;
      base.addPressure(1);
      if (base.activeDefenseMissionID < 0)
        return errs.concat([ 'pressure 30 started no defense' ]);
      var next: cult.ordeals.BaseDefense = null;
      for (o in c.ordeals.list)
        if (Std.isOfType(o, cult.ordeals.BaseDefense))
          next = cast o;
      if (next == null ||
          next.cultID < 0)
        errs.push('the pressure defense did not name a rival');
      return errs;
    }

// a rival's life: generated from its tuning table (roster size, level limits, a staggered strategic turn),
// its strategic turn presses on the base by its tactic and recruits one level 1 member up to the cap, and the
// research dead end finds a base area
  static function rivalLifecycle(game: Game, bot: Bot): Array<String>
    {
      var base = game.cults[0].base;
      var errs = [];
      var before = game.getRivalCults(true).length;

      // generation: the table's roster, the cult's level limits, power derived from the roster
      var rival = cult.RivalCult.generate(game, RIVAL_COMBAT);
      if (game.getRivalCults(true).length != before + 1)
        errs.push('generate did not add the rival to the cults');
      if (rival.members.length != const.CultConst.tunings.get(RIVAL_COMBAT).startMembers)
        errs.push('a new rival has ' + rival.members.length + ' members');
      if (rival.countMembers(2) > 5 ||
          rival.countMembers(3) > 2)
        errs.push('a new rival breaks the level limits: ' + rival.countMembers(2) + ' level 2, ' +
          rival.countMembers(3) + ' level 3');
      if (rival.power.combat <= 0)
        errs.push('a new combat rival has no combat power');
      if (rival.strategicTimer < 1 ||
          rival.strategicTimer > const.CultConst.RIVAL_TURN_PERIOD)
        errs.push('the first strategic turn is ' + rival.strategicTimer + ' turns off');

      // its own strategic turn: nothing until the timer runs out, then pressure by tactic
      base.attackPressure = 0;
      rival.strategicTimer = 2;
      rival.turn();
      if (base.attackPressure != 0)
        errs.push('the rival pressed on the base before its strategic turn');
      rival.turn();
      if (base.attackPressure != 10)
        errs.push('a combat rival\'s strategic turn added ' + base.attackPressure + ' pressure, not 10');
      if (rival.strategicTimer != const.CultConst.RIVAL_TURN_PERIOD)
        errs.push('the strategic timer was not reset: ' + rival.strategicTimer);

      // growth: recruits come one level 1 member at a time and stop at the cap
      var start = rival.members.length;
      for (i in 0...300)
        {
          base.attackPressure = 0;
          rival.strategicTimer = 1;
          rival.turn();
        }
      if (rival.members.length <= start)
        errs.push('the rival never recruited in 300 strategic turns');
      if (rival.members.length > rival.maxSize())
        errs.push('the rival grew past its cap: ' + rival.members.length);
      if (rival.countMembers(2) > 5 ||
          rival.countMembers(3) > 2)
        errs.push('recruits broke the level limits');
      base.attackPressure = 0;

      // research dead end: a base area is always found, never another rival's
      var research = new cult.ordeals.RivalResearch(game, rival.id);
      var area = @:privateAccess research.findRivalBaseMarker();
      if (area == null)
        errs.push('research found no base area');
      else
        {
          for (other in game.getRivalCults())
            if (other.rivalBaseAreaID == area.id)
              errs.push('research picked the base area of ' + other.name);
        }

      // a player cult that is down (or has no base) takes no pressure and the rival still grows
      var player = game.cults[0];
      var members = rival.members.length;
      player.state = CULT_STATE_INACTIVE;
      rival.strategicTimer = 1;
      rival.turn();
      player.state = CULT_STATE_ACTIVE;
      if (base.attackPressure != 0)
        errs.push('a rival pressed on the base of a downed player cult');
      var keep = player.base;
      player.base = null;
      rival.strategicTimer = 1;
      rival.turn();
      player.base = keep;
      if (rival.members.length < members)
        errs.push('the rival shrank on a strategic turn');

      // a failed raid sometimes gives the rival one level 1 member, never past its cap
      var spare = cult.RivalCult.generate(game, RIVAL_NON_COMBAT);
      var raid = new cult.missions.RivalBase(game, spare.id, area.id);
      var size = spare.members.length;
      for (i in 0...100)
        raid.onFail();
      if (spare.members.length <= size)
        errs.push('100 failed raids never gave the rival a recruit');
      if (spare.members.length > spare.maxSize())
        errs.push('failed raids grew the rival past its cap');

      // a rival whose leader dies is wiped the same way: kept as a dead husk, a replacement pending
      spare.onDeath(spare.members[0]);
      if (spare.state != CULT_STATE_DEAD ||
          game.cults.indexOf(spare) < 0 ||
          spare.members.length != 0 ||
          spare.replaceTimer < const.CultConst.RIVAL_REPLACE_TURNS)
        errs.push('the rival whose leader died is ' + spare.state + ', replace timer ' + spare.replaceTimer);

      // the raid on the combat rival: Cadaverum for the bodies, a sanctum down, a defender still alive
      var spot = freeSpot(game, base, BODY_STORAGE);
      var storage = new CultBaseOrgan(BODY_STORAGE, base.areaID, spot.x, spot.y, 0);
      base.organs.push(storage);
      @:privateAccess base.createOrganObject(storage);
      var tile = freeTile(game, base);
      new objects.BodyObject(game, game.area.id, tile.x, tile.y, 'civilian');
      var bodies = 0;
      for (o in game.area.getObjects())
        if (o.type == 'body')
          bodies++;
      var stored = base.storedBodies;
      var mission = new cult.missions.RivalBase(game, rival.id, area.id);
      mission.areaID = game.area.id;
      mission.spawned = true;
      var sanctum = new cult.base.RivalBaseOrgan(RIVAL_SANCTUM, 'sanctum', game.area.id, tile.x, tile.y, 1, 1, 1,
        { row: 0, col: 0 });
      sanctum.destroyed = true;
      mission.organs.push(sanctum);
      var data = rival.members[1];
      var defender = game.area.spawnAI(data.type, tile.x, tile.y, false);
      defender.updateData(data, 'on rival base spawn');
      defender.setCult(rival);
      game.area.addAI(defender);
      mission.turn();
      if (mission.isCompleted ||
          rival.state != CULT_STATE_ACTIVE)
        errs.push('the raid won with its sanctum down and a defender alive');
      game.area.removeAI(defender);
      var resources = base.resources.clone();
      mission.turn();
      if (!mission.isCompleted)
        errs.push('the raid did not win with its sanctum down and no defender left');
      if (rival.state != CULT_STATE_DEAD ||
          rival.members.length != 0)
        errs.push('the wiped rival is ' + rival.state + ' with ' + rival.members.length + ' members');
      if (rival.replaceTimer < const.CultConst.RIVAL_REPLACE_TURNS)
        errs.push('no replacement scheduled: ' + rival.replaceTimer);
      var cap = base.stockpileCap();
      var loot = const.CultConst.RIVAL_LOOT;
      if (base.resources.flesh != Std.int(Math.min(cap, resources.flesh + loot)) ||
          base.resources.blood != Std.int(Math.min(cap, resources.blood + loot)) ||
          base.resources.bone != Std.int(Math.min(cap, resources.bone + loot)))
        errs.push('the raid paid ' + text(base.resources) + ' on ' + text(resources));
      if (base.storedBodies != stored + bodies)
        errs.push('Cadaverum holds ' + base.storedBodies + ' bodies, not ' + (stored + bodies));
      for (o in game.area.getObjects())
        if (o.type == 'body')
          errs.push('a stored body is still on the floor');

      // the replacement: one more live rival, made when the timer runs out
      var alive = game.getRivalCults(true).length;
      rival.replaceTimer = 1;
      @:privateAccess base.turnRivalReplacements();
      if (game.getRivalCults(true).length != alive + 1)
        errs.push('the wiped rival was not replaced: ' + alive + ' live rivals, ' +
          game.getRivalCults(true).length + ' after');
      if (rival.replaceTimer != 0)
        errs.push('the replacement timer was not spent');
      return errs;
    }

// the timer of a rival's raid runs out: Cor Nefandum is destroyed and the game is lost
  static function defenseTimeout(game: Game, bot: Bot): Array<String>
    {
      var base = game.cults[0].base;
      if (base == null ||
          base.activeDefenseMissionID < 0)
        return [ 'cu def started no base defense' ];
      // no attacker comes: the ordeal's own timer is the only clock
      var errs = [];
      var ordeal: cult.Ordeal = null;
      for (o in game.cults[0].ordeals.list)
        if (Std.isOfType(o, cult.ordeals.BaseDefense))
          ordeal = o;
      ordeal.missions = [];
      for (i in 0...base.activeDefenseTimer + 3)
        {
          if (game.state == GAMESTATE_FINISH)
            break;
          if (!cultTurn(game, bot))
            break;
        }
      if (game.state != GAMESTATE_FINISH)
        errs.push('the game goes on after the defense timer ran out');
      else if (base.getHeart().health > 0)
        errs.push('Cor Nefandum is whole after the timer ran out');
      // the ordeal failed and left the list with its mission: the invariants would look for it
      base.activeDefenseMissionID = -1;
      return errs;
    }

// a team in ambush when a base exists turns on the base, never on the habitat: with the base free it
// starts a base defense, with another defense running it waits (no TEAM_FIGHT in the habitat either way)
  static function ambushBaseTurn(game: Game, bot: Bot): Array<String>
    {
      var base = game.cults[0].base;
      if (base == null ||
          game.location != LOCATION_AREA ||
          game.area.id != base.areaID)
        return [ 'the fixture does not stand in the base habitat' ];
      var errs = [];
      var team = new Team(game);
      team.state = TEAM_AMBUSH;
      team.ambushedHabitat = game.area.habitat;
      team.ambushedHabitatAreaID = base.areaID;
      team.timer = 1;
      game.group.team = team;
      // the player stands in the ambushed habitat
      if (!bot.pressAction('skipTurn'))
        return [ 'no Wait in the base habitat' ];
      if (team.state != TEAM_BASE_DEFENSE ||
          base.activeDefenseMissionID < 0)
        return [ 'the team is ' + team.state + ' after its ambush met the base, not attacking it' ];

      // a second team in ambush while that defense runs: it waits
      var second = new Team(game);
      second.state = TEAM_AMBUSH;
      second.ambushedHabitat = game.area.habitat;
      second.ambushedHabitatAreaID = base.areaID;
      second.timer = 1;
      game.group.team = second;
      for (i in 0...3)
        bot.pressAction('skipTurn');
      if (second.state == TEAM_FIGHT)
        errs.push('the second team fought in the habitat while the base was under attack');
      return errs;
    }

// the first tile, row by row, the organ type may grow on; null when none
  static function freeSpot(game: Game, base: CultBase, type: _CultBaseOrganType): _Point
    {
      for (y in 0...game.area.height)
        for (x in 0...game.area.width)
          if (base.canUseCursorTile(x, y) &&
              base.validateBuild(type, x, y) == '')
            return { x: x, y: y };
      return null;
    }

// the first tile, row by row, a custos could be crafted on: no organ, walkable, empty
  static function freeTile(game: Game, base: CultBase): _Point
    {
      for (y in 0...game.area.height)
        for (x in 0...game.area.width)
          if (base.canUseCursorTile(x, y) &&
              base.getOrganAt(x, y) == null &&
              game.area.isWalkable(x, y) &&
              !game.area.hasAI(x, y))
            return { x: x, y: y };
      return null;
    }

// picks the organ tool in Forma and clicks the tile, as the player grows an organ
  static function grow(game: Game, type: _CultBaseOrganType, x: Int, y: Int)
    {
      var forma = game.ui.hud.forma;
      forma.pick(type, false);
      forma.onMapClick(x, y);
    }

// moves the player onto a free tile next to the organ's footprint, where its object actions are offered
  static function standNextTo(game: Game, organ: CultBaseOrgan): Bool
    {
      for (pt in organ.footprint())
        for (dy in -1...2)
          for (dx in -1...2)
            {
              var x = pt.x + dx;
              var y = pt.y + dy;
              if (game.area.isWalkable(x, y) &&
                  !game.area.hasAI(x, y))
                {
                  game.playerArea.moveTo(x, y);
                  game.updateHUD();
                  return true;
                }
            }
      return false;
    }

// presses Wait until the cult's turn counter wraps: one cult turn, false when none came in 10
  static function cultTurn(game: Game, bot: Bot): Bool
    {
      var c = game.cults[0];
      for (i in 0...10)
        {
          if (!bot.pressAction('skipTurn'))
            return false;
          if (@:privateAccess c.turnCounter == 0)
            return true;
        }
      return false;
    }

// what the base spent since the snapshot, against the expected cost
  static function paid(base: CultBase, before: CultBaseResources, cost: CultBaseResources,
      what: String): Array<String>
    {
      var r = base.resources;
      var spent = new CultBaseResources(before.flesh - r.flesh, before.blood - r.blood,
        before.bone - r.bone);
      if (spent.flesh != cost.flesh ||
          spent.blood != cost.blood ||
          spent.bone != cost.bone)
        return [ what + ' cost ' + text(spent) + ', not ' + text(cost) ];
      return [];
    }

// the base stockpile against the expected flesh, blood and bone
  static function stock(base: CultBase, flesh: Int, blood: Int, bone: Int, when: String): Array<String>
    {
      var r = base.resources;
      if (r.flesh != flesh ||
          r.blood != blood ||
          r.bone != bone)
        return [ 'stockpile ' + text(r) + ' ' + when + ', not ' + flesh + '/' + blood + '/' + bone ];
      return [];
    }

// flesh/blood/bone, for the failure lines
  static function text(r: CultBaseResources): String
    {
      return r.flesh + '/' + r.blood + '/' + r.bone;
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

// an ambush laid in the habitat before the base grew in it times out (Team.destroyHabitat): the base
// habitat is not burned, the team turns on Cor Nefandum, and the game still saves and loads
  static function ambushBase(game: Game, bot: Bot): Array<String>
    {
      var base = game.cults[0].base;
      if (base == null ||
          game.location != LOCATION_AREA ||
          game.area.id != base.areaID)
        return [ 'the fixture does not stand in the base habitat' ];
      var team = new Team(game);
      team.state = TEAM_AMBUSH;
      team.ambushedHabitat = game.area.habitat;
      team.ambushedHabitatAreaID = base.areaID;
      team.timer = 1;
      game.group.team = team;
      // the ambush fires while the player is away from the habitat
      game.setLocation(LOCATION_REGION);
      if (!bot.pressAction('skipTurn'))
        return [ 'no Wait on the region map' ];
      if (game.region.get(base.areaID) == null)
        return [ 'the team burned the base habitat' ];
      if (team.state != TEAM_BASE_DEFENSE)
        return [ 'the team is ' + team.state + ' after its ambush met the base, not attacking it' ];
      Saver.save(game, SLOT);
      game.load(SLOT);
      return [];
    }

// a load during a habitat ambush (Game.restartPre → AreaGame.leave) runs no gameplay on the game it
// tears down: the habitat is not burned and no habitat shock is dealt
  static function loadHabitatFight(game: Game, bot: Bot): Array<String>
    {
      if (game.location != LOCATION_AREA ||
          !game.area.isHabitat)
        return [ 's22 does not stand in a habitat' ];
      Saver.save(game, SLOT);
      var team = new Team(game);
      team.state = TEAM_FIGHT;
      game.group.team = team;
      // the torn-down game's own objects: the load builds new ones
      var region = game.region;
      var vars = game.player.vars;
      var habitatID = game.area.id;
      var left = vars.habitatsLeft;
      game.load(SLOT);
      var errs = [];
      if (region.get(habitatID) == null)
        errs.push('the load burned the habitat of the game it replaced');
      if (vars.habitatsLeft != left)
        errs.push('the load dealt a habitat shock: ' + left + ' habitats left became ' + vars.habitatsLeft);
      return errs;
    }

// a targeted AI that despawns (AreaGame.removeAI) leaves no target behind, or the next attack hits a
// body that is no longer in the area
  static function despawnTarget(game: Game, bot: Bot): Array<String>
    {
      var target = null;
      for (ai in game.area.getAllAI())
        if (ai != game.player.host)
          {
            target = ai;
            break;
          }
      if (target == null)
        return [ 's1 has no AI besides the host' ];
      var t = game.ui.hud.targeting;
      t.target = new AttackTarget(game, TARGET_AI, target);
      // AI.checkDespawn, a backup going idle and the leave-area command all remove it this way
      game.area.removeAI(target);
      if (t.target != null)
        return [ 'the despawned AI ' + target.id + ' is still the attack target' ];
      return [];
    }

// a Kill target is marked as the area mission's target, never despawns (AI.checkDespawn), and keeps
// its mark across a save and load
  static function killTarget(game: Game, bot: Bot): Array<String>
    {
      var o = profaneOrdeal(game, MISSION_KILL);
      if (o == null)
        return [ 'no profane ordeal has a Kill mission' ];
      game.cults[0].ordeals.list.push(o);
      var m: cult.missions.Kill = cast o.missions[0];
      // the mission is in the area the player stands in
      m.x = game.area.x;
      m.y = game.area.y;
      if (!bot.pressAction('skipTurn'))
        return [ 'no Wait in the mission area' ];
      var ai = game.area.getAIByID(m.target.id);
      if (ai == null)
        return [ 'the Kill target did not spawn in its area' ];
      if (!marked(ai))
        return [ 'the Kill target has no mission mark' ];
      // idle, calm and out of sight for longer than AI.checkDespawn waits
      var loc = game.area.findUnseenEmptyLocation();
      if (loc.x >= 0)
        ai.setPosition(loc.x, loc.y);
      ai.setState(AI_STATE_IDLE);
      ai.alertness = 0;
      @:privateAccess ai._turnsInvisible = 1000;
      ai.checkDespawn();
      if (game.area.getAIByID(m.target.id) == null)
        return [ 'the Kill target despawned' ];
      Saver.save(game, SLOT);
      game.load(SLOT);
      ai = game.area.getAIByID(m.target.id);
      if (ai == null ||
          !marked(ai))
        return [ 'the Kill target lost its mission mark across a load' ];
      return [];
    }

// a member of an ordeal that had no death hook of its own (the profane ordeals, Metamorphosis
// Phase II, Reap the Unwary, Rival Research) dies: the ordeal fails, as every other one does
  static function ordealMemberDies(game: Game, bot: Bot): Array<String>
    {
      var hostID = makeHostFollower(game);
      var c = game.cults[0];
      var o = profaneOrdeal(game, MISSION_KILL);
      if (o == null)
        return [ 'no profane ordeal has a Kill mission' ];
      c.ordeals.list.push(o);
      o.addMembers([ hostID ]);
      game.player.host.energy = 0;
      game.updateHUD();
      if (!bot.pressAction('skipTurn'))
        return [ 'no Wait on the region map' ];
      if (game.player.state != PLR_STATE_PARASITE)
        return [ 'the host did not expire' ];
      if (c.ordeals.list.indexOf(o) >= 0)
        return [ 'the profane ordeal lives on with its dead member ' + hostID ];
      return [];
    }

// the host's effects tick on the region map (PlayerRegion.turn): a timer runs out, and bleeding that
// kills the host takes the region death path (Player.onHostDeath → AI.dieRegion)
  static function regionEffects(game: Game, bot: Bot): Array<String>
    {
      var host = game.player.host;
      host.onEffect(new effects.Paralysis(game, 3));
      game.updateHUD();
      if (!bot.pressAction('skipTurn'))
        return [ 'no Wait on the region map' ];
      if (host.effects.has(EFFECT_PARALYSIS))
        return [ 'a 3-turn paralysis outlasted a 5-turn region turn' ];
      host.onEffect(new effects.Bleeding(game, 10));
      host.health = 2;
      game.updateHUD();
      bot.pressAction('skipTurn');
      if (game.player.state != PLR_STATE_PARASITE)
        return [ 'the host outlived bleeding past its health: player is ' + game.player.state ];
      return [];
    }

// the final habitat shock kills the parasite inside its host on the region map (Player.death): it
// is reborn at the ovum without the host, which is no longer its NPC's body
  static function rebirthRegion(game: Game, bot: Bot): Array<String>
    {
      var npc = game.player.host.npc;
      if (npc == null)
        return [ 's11 did not tie the host to an NPC' ];
      game.setLocation(LOCATION_REGION);
      var errs = makeOvum(game, bot);
      if (errs.length > 0)
        return errs;
      game.player.death('habitatShock');
      game.endRebirth();
      return rebornFree(game, npc);
    }

// the same death in an area: the host is left behind there, alive, and despawns as a former host
  static function rebirthArea(game: Game, bot: Bot): Array<String>
    {
      var npc = game.player.host.npc;
      if (npc == null)
        return [ 's11 did not tie the host to an NPC' ];
      var area = game.area;
      game.setLocation(LOCATION_REGION);
      var errs = makeOvum(game, bot);
      if (errs.length > 0)
        return errs;
      game.setLocation(LOCATION_AREA, area);
      game.player.death('habitatShock');
      game.endRebirth();
      return rebornFree(game, npc);
    }

// a rebirth left the parasite free and its old host's NPC unlinked
  static function rebornFree(game: Game, npc: scenario.NPC): Array<String>
    {
      var errs = [];
      if (game.player.state != PLR_STATE_PARASITE)
        errs.push('reborn as ' + game.player.state + ', not a free parasite');
      if (game.player.host != null)
        errs.push('reborn still in host ' + game.player.host.id);
      if (npc.ai != null)
        errs.push('NPC ' + npc.id + ' is still linked to the host left behind');
      return errs;
    }

// learn the ovum and create it where the parasite stands on the region map, with a life in it
  static function makeOvum(game: Game, bot: Bot): Array<String>
    {
      game.player.evolutionManager.addImprov(IMP_OVUM, 1);
      game.updateHUD();
      if (!bot.pressAction('createOvum'))
        return [ 'no Create ovum on the region map' ];
      game.player.evolutionManager.ovum.level = 1;
      return [];
    }

// a new profane ordeal whose mission is of this type, or null
  static function profaneOrdeal(game: Game, type: _MissionType): GenericProfaneOrdeal
    {
      for (power in ProfaneConst.availableTypes)
        {
          var infos = ProfaneConst.constMap.get(power).getInfos();
          for (i in 0...infos.length)
            if (infos[i].mission == type)
              return new GenericProfaneOrdeal(game, power, i);
        }
      return null;
    }

// the AI wears the mission-target badge
  static function marked(ai: ai.AI): Bool
    {
      return Lambda.exists(ai.getBadges(), function(b) return b.svg == 'missiontarget');
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
