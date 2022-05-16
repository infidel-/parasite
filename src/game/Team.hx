// group team

package game;

import ai.BlackopsAI;

class Team extends FSM<_TeamState, _TeamFlag>
{
  static var _ignoredFields = [ 'ambushedHabitat',
  ];
  public var level: Int; // team level
  public var size: Int; // current size
  public var maxSize: Int; // total size
  public var distance(get, set): Float; // distance to parasite (0-100)
  public var ambushedHabitat: Habitat; // habitat with ambush
  public var ambushedHabitatAreaID: Int;
  public var lastAlertTurn: Int;
  var _distance: Float;

  public var timer: Int; // generic state timer

  public function new(g: Game)
    {
      super(g, 'team');

      lastAlertTurn = 0;
      state = TEAM_SEARCH;
      level = Std.int(4 * game.group.priority / 100.0) + 1;
      size = 4 + Std.random(3);
      maxSize = size;
      _distance = game.group.teamStartDistance;
      init();
      initPost(false);
    }

// init object before loading/post creation
  public function init()
    {
      timer = 0;
      ambushedHabitat = null;
      ambushedHabitatAreaID = -1;
    }

// called after load or creation
  public function initPost(onLoad: Bool)
    {
    }

// called after loading
  public function loadPost()
    {
      if (state == TEAM_AMBUSH)
        ambushedHabitat = game.world.get(0).get(ambushedHabitatAreaID).habitat;
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


// TURN: spawn ambush at random habitat
  function spawnAmbush()
    {
      state = TEAM_AMBUSH;
      ambushedHabitat = null; // clear just in case
      ambushedHabitatAreaID = -1;

      // set ambush timer
      // if player is currently in habitat, skip timer
      timer = 40 + 10 * Std.random(5);
      if (game.location == LOCATION_AREA && game.area.isHabitat)
        timer = 0;

      // no habitats, skip
      var cnt = game.region.getHabitatsCount();
      if (cnt == 0)
        {
          ambushedHabitat = null;
          ambushedHabitatAreaID = -1;
          return;
        }

      // pick random habitat
      var tmp = game.region.getHabitatsList();

      // L2 watcher attracts ambush
      for (area in tmp)
        if (area.habitat.watcherLevel >= 2)
          {
            ambushedHabitat = area.habitat;
            ambushedHabitatAreaID = area.id;
            break;
          }
      if (ambushedHabitat == null)
        {
          ambushedHabitat = tmp[Std.random(tmp.length)].habitat;
          ambushedHabitatAreaID = ambushedHabitat.areaID;
        }

      // watcher notification
      if (ambushedHabitat.hasWatcher)
        {
          game.scene.sounds.play('watcher-ambush', true);
          game.message("The watcher warns they are waiting for me.",
            COLOR_ALERT);
        }
    }


// TURN: search for player
  function turnSearch()
    {
      // distance is zero, switch state and set timer
      if (distance <= 0)
        {
          spawnAmbush();
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

      var prevDistance = _distance;
      _distance -= mod;
      _distance = Const.clampFloat(distance, 0, 150.0);

      // reduce info message amount
      if (Const.round(distance) == Math.floor(distance))
        game.infoChange('Team distance', - mod, distance);
      checkAlert(prevDistance, distance);
    }

// check for distance alert
  function checkAlert(prev: Float, val: Float)
    {
      if (state == TEAM_SEARCH &&
          (game.group.difficulty == EASY ||
            game.group.difficulty == NORMAL) &&
          prev >= 9.91 && val < 9.91 &&
          game.turns - lastAlertTurn > 10)
        {
          game.message("They are getting very close to me.", COLOR_ALERT);
          lastAlertTurn = game.turns;
        }
    }

// TURN: wait in ambush
  function turnAmbush()
    {
      // decrease timer until the team decides to torch the place and start over
      timer--;
      if (timer > 0)
        return;

      // player in correct habitat, spawn blackops
      if (game.location == LOCATION_AREA &&
          game.area.isHabitat &&
          ambushedHabitat != null &&
          game.area.habitat == ambushedHabitat)
        {
          game.message("Something is wrong here... It's an ambush!",
            COLOR_ALERT);
          onEnterHabitat();
          return;
        }

      // no ambushed habitat, spawn ambush right on player
      if (ambushedHabitat == null)
        {
          // player is in the sewers
          if (game.location == LOCATION_REGION)
            return;

          // spawn blackops
          state = TEAM_FIGHT;

          var x = game.playerArea.x;
          var y = game.playerArea.y;

          game.message("Something is wrong here... They're after me!",
            COLOR_ALERT);
          for (i in 0...4)
            {
              var loc = game.area.findLocation({
                near: { x: x, y: y },
                radius: 10,
                isUnseen: true
              });
              if (loc == null)
                {
                  loc = game.area.findEmptyLocationNear(x, y, 5);
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

      // habitat ambushed but player is not in it, destroy habitat
      destroyHabitat(ambushedHabitat.area.parent);
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

      // wrong habitat
      if (ambushedHabitat == null ||
          game.area.id != ambushedHabitat.area.id)
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
      // team distance is reset providing a buffer
      distance = 50;

      // team goes back to search
      state = TEAM_SEARCH;

      // cleanup habitat links
      area.hasHabitat = false;
      area.habitat = null;
      game.region.removeArea(area.habitatAreaID);
      game.scene.region.updateIconsArea(area.x, area.y);
      var msg = 'You feel great pain as the habitat at ' +
        area.x + ',' + area.y + ' is destroyed. ';
      if (game.player.vars.habitatsLeft == 1)
        msg += 'This is the end...';
      else msg += 'This will leave a permanent mark.';
      game.message(msg, COLOR_ALERT);

      // habitat shock death
      game.player.vars.habitatsLeft--;
      if (game.player.vars.habitatsLeft == 0)
        {
          game.finish('lose', 'habitatShock');
          return;
        }

      // reduce max energy
      var maxEnergy = 0;
      var shock1 = 0;
      var shock2 = 0;
      if (game.group.difficulty == EASY)
        {
          maxEnergy = 50;
          shock1 = 10;
          shock2 = 10;
        }
      else if (game.group.difficulty == NORMAL)
        {
          maxEnergy = 30;
          shock1 = 30;
          shock2 = 20;
        }
      else if (game.group.difficulty == HARD)
        {
          maxEnergy = 10;
          shock1 = 50;
          shock2 = 50;
        }
      if (game.player.maxEnergy > maxEnergy)
        {
          game.player.maxEnergy -= 10;
          game.player.energy = game.player.energy; // clamp current value
        }

      // control reduced
      if (game.player.state == PLR_STATE_HOST)
        {
          game.player.hostControl -= shock1;
          game.log('You feel your control slipping.');
        }

      // attach hold reduced
      else if (game.player.state == PLR_STATE_ATTACHED)
        {
          game.playerArea.attachHold -= shock2;
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
      checkAlert(_distance, v);
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
