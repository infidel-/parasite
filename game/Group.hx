// conspiracy group manager

package game;

class Group
{
  var game: Game;
  public var teamTimeout: Int;
  public var teamStartDistance: Float;
  public var team: {
    var level: Int; // team level
    var size: Int; // current size
    var maxSize: Int; // total size
    var distance: Float; // distance to parasite (0-100)
  };

  public var priority: Float; // group priority (0-100%)

  public function new(g: Game)
    {
      game = g;
      priority = 0;
      team = null;
      teamTimeout = 100;
      teamStartDistance = 100.0;
    }


// new turn logic
  public function turn()
    {
      // team already spawned
      if (team != null)
        {
          turnTeam();
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

      team = {
        level: Std.int(4 * priority / 100.0) + 1,
        size: 4 + Std.random(3),
        maxSize: 0,
        distance: teamStartDistance,
      };
      team.maxSize = team.size;

      game.debug('team ' + team + ' generated');
    }


// team turn logic
  function turnTeam()
    {
      // passive distance decrease
      if (team.distance > 0)
        {
          var mod = 0.0;
          if (team.level == 1)
            mod = 0.1;
          else if (team.level == 2)
            mod = 0.2;
          else if (team.level == 3)
            mod = 0.5;
          else if (team.level == 4)
            mod = 1.0;

          var old = team.distance;
          team.distance -= mod;
          team.distance = Const.clampFloat(team.distance, 0, 150.0);

          // reduce info message amount
          if (Const.round(team.distance) == Math.floor(team.distance))
            game.info('Team distance: -' + mod + ' = ' +
              Const.round(team.distance));
        }
    }


// raise group priority
// if the team is active, lower distance instead
  public function raisePriority(mod: Float)
    {
      if (mod == 0)
        return;

      if (team != null)
        {
          team.distance -= mod;
          team.distance = Const.clampFloat(team.distance, 0, 150.0);
          game.info('Team distance: -' + mod + ' = ' +
            Const.round(team.distance));
        }

      else changeOnlyPriority(mod);
    }


// specifically raise priority, without team distance logic
  function changeOnlyPriority(mod: Float)
    {
      priority += mod;
      priority = Const.clampFloat(priority, 0, 100.0);
      game.info('Group priority: ' + (mod > 0 ? '+' : '') + mod + ' = ' +
        Const.round(priority));
    }


// specifically raise team distance
  public function raiseTeamDistance(mod: Float)
    {
      team.distance += mod;
      team.distance = Const.clampFloat(team.distance, 0, 150.0);
      game.info('Team distance: +' + mod + ' = ' +
        Const.round(team.distance));

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
}
