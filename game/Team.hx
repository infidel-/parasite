// group team

package game;

import ai.BlackopsAI;

class Team extends FSM<_TeamState, _TeamFlag>
{
  public var level: Int; // team level
  public var size: Int; // current size
  public var maxSize: Int; // total size
  public var distance(get, set): Float; // distance to parasite (0-100)
  var _distance: Float;

  public var timer: Int; // generic state timer

  public function new(g: Game)
    {
      super(g, 'team');

      state = TEAM_SEARCH;
      level = Std.int(4 * game.group.priority / 100.0) + 1;
      size = 4 + Std.random(3);
      maxSize = size;
      _distance = game.group.teamStartDistance;
      timer = 0;
    }


// TURN: team turn logic
  public function turn()
    {
      if (state == TEAM_SEARCH)
        turnSearch();
      else if (state == TEAM_AMBUSH)
        turnAmbush();
      else if (state == TEAM_FIGHT)
        turnFight();
    }


// TURN: search for player
  function turnSearch()
    {
      // distance is zero, switch state and set timer
      if (distance <= 0)
        {
          state = TEAM_AMBUSH;

          // if player is currently in habitat, skip timer
          if (game.location == LOCATION_AREA && game.area.isHabitat)
            timer = 0;
          else timer = 20 + 10 * Std.random(20);
          return;
        }

      // passive distance decrease
      var mod = 0.0;
      if (level == 1)
        mod = 0.1;
      else if (level == 2)
        mod = 0.2;
      else if (level == 3)
        mod = 0.5;
      else if (level == 4)
        mod = 1.0;

      _distance -= mod;
      _distance = Const.clampFloat(distance, 0, 150.0);

      // reduce info message amount
      if (Const.round(distance) == Math.floor(distance))
        game.info('Team distance: -' + Const.round(mod) + ' = ' +
          Const.round(distance));
    }


// TURN: wait in ambush
  function turnAmbush()
    {
      // decrease timer until the team decides to torch the place and start over
      timer--;
      if (timer > 0)
        return;

      // player in habitat, spawn blackops
      if (game.location == LOCATION_AREA && game.area.isHabitat)
        {
          game.log("Something is wrong here... It's an ambush!");
          onEnterHabitat();
          return;
        }

      // pick a random habitat
      var tmp = game.region.getHabitatsList();

      // habitat destroyed
      destroyHabitat(tmp.first());
    }


// TURN: fight in progress
  function turnFight()
    {
      // increase fight timer (to allow player to leave)
      if (timer > 0)
        timer--;
    }


// event: player entered habitat with an active team
  public function onEnterHabitat()
    {
      if (state != TEAM_AMBUSH)
        return;

      state = TEAM_FIGHT;
      timer = 3; // 3 turns until exit is available

      // team was in ambush, spawn blackops
      for (i in 0...4)
        {
          var loc = game.area.findEmptyLocation();
          var ai = new BlackopsAI(game, loc.x, loc.y);
          ai.alertness = 75;
          game.area.addAI(ai);
        }
    }


// event: player leaves habitat with an active team
  public function onLeaveHabitat()
    {
      if (state != TEAM_AMBUSH && state != TEAM_FIGHT)
        return;

      // note that we do not care whether the actual ambushers are dead
      // the habitat is still burned
      destroyHabitat(game.area.parent);
    }


// destroy current player habitat
// called either on ambush timeout or when player leaves ambushed habitat
  function destroyHabitat(area: AreaGame)
    {
      game.debug('KABLAM!');

      // team distance is increased providing a buffer
      distance = 20;

      // team goes back to search
      state = TEAM_SEARCH;

      // cleanup habitat links
      area.hasHabitat = false;
      area.habitat = null;
      game.region.removeArea(area.habitatAreaID);
      game.scene.region.updateIconsArea(area.x, area.y);
      game.log("You feel great pain as the habitat at " +
        area.x + "," + area.y + " is destroyed.");
    }


  public function toString()
    {
      return '{ level: ' + level +
        ', size: ' + size + '/' + maxSize +
        ', distance: ' + distance +
        ', state: ' + state +
        ', timer: ' + timer +
        ' }';
    }


  function get_distance()
    {
      return _distance;
    }


  function set_distance(v: Float)
    {
      var mod = v - _distance;
      v = Const.clampFloat(v, 0, 150.0);
      game.info('Team distance: ' + (mod > 0 ? '+' : '') +
        Const.round(mod) + ' = ' +
        Const.round(v));
      _distance = v;
      return v;
    }
}


enum _TeamState
{
  TEAM_SEARCH; // team searching for parasite
  TEAM_AMBUSH; // team lies in ambush in one of the habitats
  TEAM_FIGHT; // team is fighting with parasite
}


enum _TeamFlag
{
}
