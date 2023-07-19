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

  public function new(g: Game)
    {
      game = g;
      priority = 0;
      team = null;
      teamTimeout = 250;
      teamStartDistance = 100.0;
      teamMemberLastNoticed = 0;
      knownCount = 1 + Std.random(3); // randomized slightly
      isKnown = false;
      difficulty = UNSET;
    }

// called after loading
  public function loadPost()
    {
      if (team != null)
        team.loadPost();
    }

// add team distance to hud if close
  public function hudInfo(buf: StringBuf): Bool
    {
      if (difficulty == HARD ||
          difficulty == UNSET ||
          team == null ||
          team.distance > 10)
        return false;
      buf.add('<div class=hud-team>TEAM IS VERY CLOSE!</div>');
      return true;
    }

// get group and team info according to difficulty
  public function getInfo(buf: StringBuf)
    {
      // group existence not discovered yet
      if (!isKnown)
        return;

      // group info
      buf.add('<br/>');
      buf.add(Const.col('group-title', 'Group info [' + difficulty + ']') +
        '<br/>');
      if (difficulty == HARD)
        {
          buf.add('  --- hidden ---<br/>');
          return;
        }
      buf.add(Const.col('group-note', 'Group priority: ') +
        (difficulty == EASY ? '' + Const.round(priority) :
         numToWord(Std.int(priority), 0, 100)) + '<br/>');
      if (team == null)
        buf.add(Const.col('group-note', 'Team timeout: ') +
          (difficulty == EASY ? teamTimeout + ' turns' :
           numToWord(teamTimeout, 0, 100)) + '<br/>');
      else
        {
          buf.add(Const.col('group-note', 'Team level: ') +
            (difficulty == EASY ? team.level + '' :
             numToWord(team.level, 1, 4)) + '<br/>');
          buf.add(Const.col('group-note', 'Team size: ') +
            (difficulty == EASY ? team.size + '' :
             numToWord(team.size, 1, team.maxSize)) + '<br/>');
          buf.add(Const.col('group-note', 'Team distance: ') +
            (difficulty == EASY ? Std.int(team.distance) + '' :
             numToWordDistance(Std.int(team.distance), 0, 150)) + '<br/>');
        }
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

// convert distance number to word description
  function numToWordDistance(val: Int, min: Int, max: Int): String
    {
      var percent = 100.0 * (val - min) / (max - min);
      if (percent < 20)
        return Const.col('red', 'very close');
      else if (percent < 40)
        return Const.col('red', 'close');
      else if (percent < 60)
        return Const.col('yellow', 'medium');
      else if (percent < 80)
        return Const.col('white', 'far');
      else return Const.col('white', 'very far');
    }

// TURN: new turn logic
  public function turn()
    {
      // team already spawned
      if (team != null)
        {
          team.turn();
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

      // team completely evaded, deactivate and lower priority
      changeOnlyPriority(-20);

      // larger timeout and reset starting distance
      teamStartDistance = 100.0;
      teamTimeout = 100;
      team = null;

      game.info('Team deactivated, timeout: ' + teamTimeout + ' turns');
    }

// on team member death
  public function onTeamMemberDeath()
    {
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


// on brain probing the event NPC
  public function brainProbe()
    {
      if (game.group.isKnown)
        return;

      knownCount--;
      if (knownCount > 0)
        return;

      // player becomes aware of the group existence
      game.message('There is a group of humans that wants to destroy me.');
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
