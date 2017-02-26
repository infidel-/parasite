// conspiracy group manager

package game;

class Group
{
  var game: Game;
  var teamTimeout: Int;
  public var team: {
    var level: Int;
    var size: Int;
    var distance: Float;
  };

  public var priority: Float; // group priority (0-100%)

  public function new(g: Game)
    {
      game = g;
      priority = 0;
      team = null;
      teamTimeout = 0;
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
      teamTimeout++;
      if (teamTimeout < 50)
        return;

      // roll a chance just to make it a bit randomy
      if (Std.random(100) > 20)
        return;

      team = {
        level: Std.int(4 * priority / 100.0) + 1,
        size: 4 + Std.random(3),
        distance: 100,
      };
      teamTimeout = 0;

      game.debug('team ' + team + ' generated');
    }


// team turn logic
  function turnTeam()
    {
      // passive distance decrease
      var mod = 0.0;
      if (team.level == 1)
        mod = 0.1;
      else if (team.level == 2)
        mod = 0.2;
      else if (team.level == 3)
        mod = 0.5;
      else if (team.level == 4)
        mod = 1.0;

      team.distance -= mod;
      team.distance = Const.clampFloat(team.distance, 0, 100.0);
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
          team.distance = Const.clampFloat(team.distance, 0, 100.0);
          game.info('Team distance: -' + mod + ' = ' + team.distance);
        }

      else
        {
          priority += mod;
          priority = Const.clampFloat(priority, 0, 100.0);
          game.info('Group priority: +' + mod + ' = ' + priority);
        }
    }
}
