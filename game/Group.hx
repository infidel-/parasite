// conspiracy group manager

package game;

class Group
{
  var game: Game;
  public var teamTimeout: Int;
  public var teamStartDistance: Float;
  public var team: Team;
  public var knownTimer: Int; // probe timer until the group becomes known
  public var isKnown: Bool; // group existence known?

  public var priority: Float; // group priority (0-100%)

  public function new(g: Game)
    {
      game = g;
      priority = 0;
      team = null;
      teamTimeout = 100;
      teamStartDistance = 100.0;
      knownTimer = 5 + Std.random(5); // randomized slightly
      isKnown = false;
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

      knownTimer--;
      if (knownTimer > 0)
        return;

      // player becomes aware of the group existence
      game.message('There is a group of humans that wants to destroy me.');

      isKnown = true;
    }
}
