// conspiracy group manager

package game;

class Group extends _SaveObject
{
  var game: Game;
  public var teamTimeout: Int;
  public var teamMemberLastNoticed: Int;
  public var teamStartDistance: Float;
  public var team: Team;
  public var knownCount: Int; // probe timer until the group becomes known
  public var isKnown: Bool; // group existence known?

  public var priority: Float; // group priority (0-100%)
  public var difficulty: _Difficulty; // difficulty setting
  public var isNeutralized: Bool; // parasite file closed: no new teams until the priority climbs back
  public var intel: Int; // intel gathered towards finding the regional director
  static inline var TEAM_VERY_CLOSE = 10.0; // team distance under which the hud group mark pulses and warns
  static inline var REOPEN_PRIORITY = 100.0; // priority at which a neutralized group reopens the file

  public function new(g: Game)
    {
      game = g;
      init();
    }

// init group state before loading/post creation
  public function init()
    {
      priority = 0;
      team = null;
      teamTimeout = 250;
      teamStartDistance = 100.0;
      teamMemberLastNoticed = 0;
      knownCount = 1 + Std.random(3); // randomized slightly
      isKnown = false;
      difficulty = UNSET;
      isNeutralized = false;
      intel = 0;
    }

// called after loading
  public function loadPost()
    {
      if (team != null)
        team.loadPost();
    }

// hud group mark state class: '' until the group is known and a difficulty is picked, then the
// team state + distance band, with ' pulse' once the team is very close. an ambush only reads as
// one when a watcher in that habitat reported it, otherwise the mark would give it away
  public function hudMarkClass(): String
    {
      if (!isKnown ||
          difficulty == UNSET)
        return '';
      if (difficulty == HARD)
        return 'hard';
      if (team == null)
        return (isNeutralized ? 'neutral' : 'idle');
      switch (team.state)
        {
          case TEAM_FIGHT, TEAM_BASE_DEFENSE:
            return 'alert';
          case TEAM_AMBUSH:
            if (team.ambushedHabitat != null &&
                team.ambushedHabitat.hasWatcher)
              return 'alert';
          default:
        }
      return ['vclose', 'close', 'mid', 'far', 'far'][distanceBand(team.distance)] +
        (team.distance < TEAM_VERY_CLOSE ? ' pulse' : '');
    }

// add team distance to hud if close
  public function hudInfo(buf: StringBuf): Bool
    {
      if (difficulty == HARD ||
          difficulty == UNSET ||
          team == null ||
          team.distance > TEAM_VERY_CLOSE)
        return false;
      buf.add('<div class=hud-team>TEAM IS VERY CLOSE!</div>');
      return true;
    }

// get group and team info according to difficulty: a title over a name -> value table
// (the hud group mark's tip)
  public function getInfo(buf: StringBuf)
    {
      // group existence not discovered yet
      if (!isKnown)
        return;

      // group info
      buf.add(Const.col('group-title', 'Group info [' + difficulty + ']'));
      if (difficulty == HARD)
        {
          buf.add('<br/>  --- hidden ---');
          return;
        }
      function row(k: String, v: String)
        buf.add('<tr><td>' + Const.col('group-note', k) + '</td><td>' + v + '</td></tr>');
      buf.add('<table class="tip-table">');
      row('Group priority', (difficulty == EASY ? '' + Const.round(priority) :
        numToWord(Std.int(priority), 0, 100)));
      if (team == null &&
          isNeutralized)
        row('Team', Const.col('white', 'file closed'));
      else if (team == null)
        row('Team timeout', (difficulty == EASY ? teamTimeout + 't' :
          numToWord(teamTimeout, 0, 100)));
      else
        {
          row('Team level', (difficulty == EASY ? team.level + '' :
            numToWord(team.level, 1, 4)));
          row('Team size', (difficulty == EASY ? team.size + '' :
            numToWord(team.size, 1, team.maxSize)));
          row('Team distance', (difficulty == EASY ? Std.int(team.distance) + '' :
            numToWordDistance(team.distance)));
        }
      buf.add('</table>');
    }

// convert number to word description
  function numToWord(val: Int, min: Int, max: Int): String
    {
      var percent = 100.0 * (val - min) / (max - min);
      if (percent < 20)
        return Const.col('white', 'very low');
      else if (percent < 40)
        return Const.col('white', 'low');
      else if (percent < 60)
        return Const.col('yellow', 'medium');
      else if (percent < 80)
        return Const.col('red', 'high');
      else return Const.col('red', 'very high');
    }

// team distance band over its 0-150 range: 0 very close .. 4 very far
  function distanceBand(val: Float): Int
    {
      var band = Std.int(val / 30);
      return (band > 4 ? 4 : band);
    }

// convert team distance to word description
  function numToWordDistance(val: Float): String
    {
      return [
        Const.col('red', 'very close'),
        Const.col('red', 'close'),
        Const.col('yellow', 'medium'),
        Const.col('white', 'far'),
        Const.col('white', 'very far'),
      ][distanceBand(val)];
    }

// TURN: new turn logic
  public function turn()
    {
      // pause passage of time when in mission area
      if (game.player.inMissionArea())
        return;

      // team already spawned (a team mid-fight plays out even when neutralized)
      if (team != null)
        {
          team.turn();
          return;
        }

      // file closed: no new teams until the priority climbs back
      if (isNeutralized)
        {
          if (priority >= REOPEN_PRIORITY)
            reopen();
          return;
        }

      // every time the team is wiped, we give some time to the player
      // first time spawns on the same principle
      teamTimeout--;
      if (teamTimeout > 0)
        return;

      // roll a chance just to make it a bit randomy
      if (Std.random(100) > 20)
        return;

      team = new Team(game);

      game.debug('team ' + team + ' generated');
    }


// raise group priority
// if the team is active, lower distance instead
  public function raisePriority(mod: Float)
    {
      if (mod == 0)
        return;

      if (team != null)
        team.distance -= mod;

      else
        {
          // reduce team timer
          teamTimeout--;

          changeOnlyPriority(mod);
        }
    }


// specifically raise priority, without team distance logic
  function changeOnlyPriority(mod: Float)
    {
      priority += mod;
      priority = Const.clampFloat(priority, 0, 100.0);
      game.infoChange('Group priority', mod, priority);
    }


// specifically raise team distance
  public function raiseTeamDistance(mod: Float)
    {
      // could be after repelling the ambush
      if (team == null)
        {
          teamTimeout += 10 + Std.int(mod);
          return;
        }
      team.distance += mod;

      if (team.distance < 150)
        return;

      // team completely evaded
      deactivateTeam(20);
    }

// deactivate the active team and lower group priority by the given amount
// (team evaded completely, or false memories planted into a blackops agent)
  public function deactivateTeam(priorityDrop: Float)
    {
      changeOnlyPriority(-priorityDrop);

      // larger timeout and reset starting distance
      teamStartDistance = 100.0;
      teamTimeout = 100;
      team = null;

      game.info('Team deactivated, timeout: ' + teamTimeout + ' turns');
    }

// lower group priority
// if the team is active, raise distance instead
  public function lowerPriority(mod: Float)
    {
      if (mod == 0)
        return;

      if (team != null)
        team.distance += mod;
      else
        changeOnlyPriority(-mod);
    }

// on team member death
  public function onTeamMemberDeath()
    {
      // kludge
      if (team == null)
        return;
      team.size--;

      // team dead, raise priority
      changeOnlyPriority(10);

      if (team.size > 0)
        return;

      // each new team starts with some distance covered
      teamStartDistance = 1.5 * team.distance;
      if (teamStartDistance > 100.0)
        teamStartDistance = 100.0;

      // team wipe, timeout
      teamTimeout = 50;
      team = null;
      game.info('Team wiped, timeout: ' + teamTimeout + ' turns');
    }

// on repelling an ambush
  public function onRepelAmbush()
    {
      // attack team dead, raise priority (larger)
      changeOnlyPriority(15);

      // larger timeout and reset starting distance
      teamStartDistance = 100.0;
      teamTimeout = 100;
      team = null;
      game.info('Team destroyed in ambush, timeout: ' + teamTimeout + ' turns');
    }


// close the parasite file: no new teams until the priority climbs back to REOPEN_PRIORITY.
// a team that is fighting or attacking the cult base plays out first (turn() keeps running it)
  public function neutralize()
    {
      isNeutralized = true;
      changeOnlyPriority(-priority);
      if (team != null &&
          (team.state == TEAM_SEARCH ||
           team.state == TEAM_AMBUSH))
        team = null;
      game.info('Group neutralized');
    }

// the priority climbed back: the group reopens the parasite file
  function reopen()
    {
      isNeutralized = false;
      teamTimeout = 50;
      intel = 0;
      game.goals.reset(GOAL_GROUP_INTEL);
      game.message({
        text: 'They have reopened my file. The Group is hunting me again.',
        img: 'pedia/group',
        col: 'alert'
      });
    }

// intel needed to find the regional director, by group difficulty
  public function intelNeeded(): Int
    {
      return switch (difficulty)
        {
          case EASY: 3;
          case HARD: 10;
          default: 6;
        };
    }

// brain probe of a group member: the first probe of each one yields intel
  public function probeIntel(ai: ai.AI, amount: Int)
    {
      if (!isKnown ||
          ai.intelTaken)
        return;
      ai.intelTaken = true;
      addIntel(amount);
    }

// add intel on the group; enough of it reveals the regional director
  public function addIntel(amount: Int)
    {
      if (isNeutralized ||
          game.goals.completed(GOAL_GROUP_INTEL))
        return;
      intel += amount;
      game.goals.receive(GOAL_GROUP_INTEL);
      game.log('I piece together more about the Group (intel: ' +
        intel + '/' + intelNeeded() + ').');
      if (intel >= intelNeeded())
        game.goals.complete(GOAL_GROUP_INTEL);
    }

// blackops loadout level when there is no team to take it from (director guards)
  public function guardLevel(): Int
    {
      return switch (difficulty)
        {
          case EASY: 2;
          case HARD: 4;
          default: 3;
        };
    }

// on brain probing the event NPC
  public function brainProbe()
    {
      if (game.group.isKnown)
        return;

      knownCount--;
      if (knownCount > 0)
        return;

      // player becomes aware of the group existence
      game.message({
        text: 'There is a group of humans that wants to destroy me.',
        img: 'pedia/group'
      });
      // receive watcher goal if habitat was created already
      if (game.goals.completed(GOAL_CREATE_HABITAT))
        game.goals.receive(GOAL_PUT_WATCHER);

      game.ui.event({
        type: UIEVENT_STATE,
        state: UISTATE_DIFFICULTY,
        obj: 'group'
      });
      // group pedia articles
      var articleAdded = false;
      for (a in const.PediaConst.getGroup('group').articles)
        if (a.groupAddFlag && game.profile.addPediaArticle(a.id, false))
          articleAdded = true;
      if (articleAdded)
        {
          game.scene.sounds.play('pedia-new');
          game.log(Const.small('New pedia articles about the Group available.'), COLOR_PEDIA);
        }

      isKnown = true;
    }
}
