// conspiracy group manager

package game;

class Group
{
  var game: Game;
  public var teamTimeout: Int;
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
      teamTimeout = 150;
      teamStartDistance = 100.0;
      knownCount = 1 + Std.random(4); // randomized slightly
      isKnown = false;
      difficulty = UNSET;
    }


// get group and team info according to difficulty
  public function getInfo(buf: StringBuf)
    {
#if mydebug
      if (!isKnown)
        buf.add('[DEBUG] Group known count: ' + knownCount + '\n');
      buf.add('[DEBUG] Group priority: ' + Const.round(priority) +
        ', team timeout: ' + teamTimeout + '\n');
      if (team != null)
        buf.add('[DEBUG] Team: ' + team + '\n');
#end

      // group existence not discovered yet
      if (!isKnown)
        return;

      // group info
      buf.add('\nGroup info [' + difficulty + ']\n');
      if (difficulty == HARD)
        {
          buf.add('  --- hidden ---\n');
          return;
        }
      buf.add('Group priority: ' +
        (difficulty == EASY ? '' + Const.round(priority) :
         numToWord(Std.int(priority), 0, 100)) + '\n');
      if (team == null)
        buf.add('Team timeout: ' +
          (difficulty == EASY ? teamTimeout + ' turns' :
           numToWord(teamTimeout, 0, 100)) + '\n');
      else
        {
          buf.add('Team level: ' +
            (difficulty == EASY ? team.level + '' :
             numToWord(team.level, 1, 4)) + '\n');
          buf.add('Team size: ' +
            (difficulty == EASY ? team.size + '' :
             numToWord(team.size, 1, team.maxSize)) + '\n');
          buf.add('Team distance: ' +
            (difficulty == EASY ? Std.int(team.distance) + '' :
             numToWord(Std.int(team.distance), 0, 150)) + '\n');
        }
    }


// convert number to word description
  function numToWord(val: Int, min: Int, max: Int): String
    {
      var percent = 100.0 * (val - min) / (max - min);
      if (percent < 20)
        return 'very low';
      else if (percent < 40)
        return 'low';
      else if (percent < 60)
        return 'medium';
      else if (percent < 80)
        return 'high';
      else return 'very high';
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
  public function teamMemberDeath()
    {
      team.size--;

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

      // show yes/no dialog about manual
      game.scene.event({
        state: UISTATE_YESNO,
        obj: {
          text: 'Do you want to read the manual about The Group?',
          func: function(yes: Bool)
            {
              // open the manual file
              if (yes)
                {
                  var doc = openfl.Assets.getText('wiki/The-Group.md');
                  game.scene.event({
                    state: UISTATE_DOCUMENT,
                    obj: doc
                  });
                }
              game.scene.event({
                state: UISTATE_DIFFICULTY,
                obj: 'group'
              });
            }
        }
      });

      isKnown = true;
    }
}
