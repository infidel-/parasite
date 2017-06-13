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
        game.infoChange('Team distance', - mod, distance);
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

      // no habitats, wait until player is in area mode and spawn ambush
      var cnt = game.region.getHabitatsCount();
      if (cnt == 0)
        {
          if (game.location == LOCATION_REGION)
            return;

          // spawn blackops
          state = TEAM_FIGHT;

          var x = game.playerArea.x;
          var y = game.playerArea.y;

          game.log("Something is wrong here... It's an ambush!");
          for (i in 0...4)
            {
              var loc = game.area.findLocation({
                near: { x: x, y: y },
                radius: 10,
                isUnseen: true
                });
              if (loc == null)
                {
                  loc = game.area.findEmptyLocationNear(x, y);
                  if (loc == null)
                    {
                      Const.todo('Could not find free spot for spawn x2!');
                      return;
                    }
                }

              var ai = new BlackopsAI(game, loc.x, loc.y);

              // set roam target
              ai.roamTargetX = x;
              ai.roamTargetY = y;

              ai.alertness = 75;
              game.area.addAI(ai);
            }

          return;
        }

      // player has habitats but is not in one of them

      // pick a random habitat
      var tmp = game.region.getHabitatsList();

      // habitat destroyed
      destroyHabitat(tmp.first());
    }


// TURN: fight in progress
  function turnFight()
    {
      // decrease fight timer (to allow player to leave)
      if (timer > 0)
        timer--;
    }


// event: player entered habitat with an active team
  public function onEnterHabitat()
    {
      if (state != TEAM_AMBUSH)
        return;

      state = TEAM_FIGHT;
      timer = 3; // 3 turns until exit is available (in habitat)

      // team was in ambush, spawn blackops
      for (i in 0...4)
        {
          var loc = game.area.findEmptyLocation();
          var ai = new BlackopsAI(game, loc.x, loc.y);
          ai.alertness = 75;
          game.area.addAI(ai);
        }
    }


// event: player leaves area with an active team
  public function onLeaveArea()
    {
      if (state != TEAM_FIGHT)
        return;

      game.log("You've managed to survive the ambush.");

      // note that we do not care whether the actual ambushers are dead
      // the habitat is still burned
      if (game.area.isHabitat)
        destroyHabitat(game.area.parent);

      else
        {
          // team distance is increased a little providing a buffer
          distance = 10;

          // team goes back to search
          state = TEAM_SEARCH;
        }
    }


// destroy current player habitat
// called either on ambush timeout or when player leaves ambushed habitat
  function destroyHabitat(area: AreaGame)
    {
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
        area.x + "," + area.y + " is destroyed. This will leave a permanent mark.");

      // reduce max energy (20 min)
      if (game.player.maxEnergy > 20)
        {
          game.player.maxEnergy -= 20;
          game.player.energy = game.player.energy; // clamp current value
        }

      // control reduced
      if (game.player.state == PLR_STATE_HOST)
        {
          game.player.hostControl -= 30;
          game.log('You feel your control slipping.');
        }

      // attach hold reduced
      else if (game.player.state == PLR_STATE_ATTACHED)
        {
          game.playerArea.attachHold -= 20;
          game.log('You feel your grip slipping.');
        }
    }


  public function toString()
    {
      return '{ level: ' + level +
        ', size: ' + size + '/' + maxSize +
        ', distance: ' + Const.round(distance) +
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
      game.infoChange('Team distance', mod, v);
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
