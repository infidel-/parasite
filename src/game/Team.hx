// group team

package game;

import const.*;

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
      if (level > 4)
        level = 4;
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
      if (state == TEAM_AMBUSH &&
          ambushedHabitatAreaID >= 0)
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
      if (game.location == LOCATION_AREA &&
          game.area.isHabitat)
        timer = 0;

      // no habitats, skip
      var cnt = game.region.getHabitatsCount();
      // SPOON: no ambushes in habitats
      if (game.config.spoonHabitatAmbush)
        cnt = 0;
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
          game.scene.sounds.play('watcher-ambush');
          game.message("The watcher warns they are waiting for me.", 'pedia/team_ambush',
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
          game.message("They are getting very close to me.", null, COLOR_ALERT);
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
          game.message("Something is wrong here... It's an ambush!", 'pedia/team_ambush',
            COLOR_ALERT);
          game.scene.sounds.play('event-ambush');
          onEnterHabitat();
          return;
        }
      // SPOON: no ambushes in habitats
      if (game.config.spoonHabitatAmbush &&
          game.location == LOCATION_AREA &&
          game.area.isHabitat)
        return;

      // no ambushed habitat, spawn ambush right on player
      if (ambushedHabitat == null)
        {
          // player is in the sewers
          if (game.location == LOCATION_REGION)
            return;

          // spawn blackops
          state = TEAM_FIGHT;
          timer = 3; // 3 turns until exit is available (in habitat)

          var x = game.playerArea.x;
          var y = game.playerArea.y;

          game.message("Something is wrong here... They're after me!", 'pedia/team_basics',
            COLOR_ALERT);
          game.scene.sounds.play('event-ambush');
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

              var ai = game.area.spawnAI('blackops', loc.x, loc.y);
              // set roam target and alertness
              ai.roamTargetX = x;
              ai.roamTargetY = y;
              ai.alertness = 75;
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

      // check if it is over
      checkFightFinish(false);
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
          var ai = game.area.spawnAI('blackops', loc.x, loc.y);
          ai.alertness = 75;
        }
    }

// check if ambush is over
// happens when all blackops are either dead or removed from the area
  public function checkFightFinish(onDeath: Bool)
    {
      // must be during the ambush
      if (state != TEAM_FIGHT)
        return;
      // check how many are left living
      var ai = game.area.getAIWithType('blackops');
      if (ai.length > 0)
        return;
      // last one alive and under control
      if (ai.length == 1 &&
          game.player.host == ai.first())
        return;
      // no more free blackops, ambush failed
      game.message("I've " + (onDeath ? 'eliminated' : 'successfully evaded') + " the aggressors. It will be some time before they will be able to get on my trail again.", 'pedia/team_deactivation');
      game.group.onRepelAmbush();
    }

// event: player leaves area with an active team
  public function onLeaveArea()
    {
      if (state != TEAM_FIGHT)
        return;

      // since blackops deaths should trigger the good outcome
      // this one is for when some of them are alive - habitat is burned
      if (game.area.isHabitat)
        {
          game.log("You've managed to escape the ambush.");
          destroyHabitat(game.area.parent);
        }

      // street ambush, avoidance
      else
        {
          game.log("You've managed to avoid the ambush.");
          // team distance is increased a little providing a buffer
          distance = 10;
          // team goes back to search
          state = TEAM_SEARCH;
        }
    }


// destroy current player habitat
// called either on ambush timeout or when player leaves ambushed habitat
// NOTE: area is habitat's parent area
  function destroyHabitat(area: AreaGame)
    {
      var habitatArea = game.region.get(area.habitatAreaID);
      var watcherLevel = habitatArea.habitat.watcherLevel;

      // team distance is reset providing a buffer
      // 50, 60, 75
      distance = 50 + EvolutionConst.getParams(IMP_WATCHER, watcherLevel).distanceBonus;

      // team goes back to search
      state = TEAM_SEARCH;

      // cleanup habitat links
      area.hasHabitat = false;
      ambushedHabitat = null;
      ambushedHabitatAreaID = -1;
      game.region.removeArea(area.habitatAreaID);

      // SPOON: disable habitat death shock
      if (game.config.spoonHabitats)
        {
          game.scene.sounds.play('event-habitat-destroy');
          game.message('You sense that the habitat at ' +
            area.x + ',' + area.y + ' was destroyed.',
            'pedia/habitat_destruction',
            COLOR_ALERT);
          return;
        }

      var adjective = 'great';
      if (watcherLevel >= 2)
        adjective = 'nagging';
      var msg = 'You feel ' + adjective + ' pain as the habitat at ' +
        area.x + ',' + area.y + ' is destroyed. ';
      var img = 'pedia/habitat_destruction';
      if (game.player.vars.habitatsLeft == 1)
        {
          msg += 'This is the end...';
          img = 'event/death';
        }
      else msg += 'This will leave a permanent mark.';
      game.message(msg, img, COLOR_ALERT);

      // habitat shock death
      game.player.vars.habitatsLeft--;
      if (game.player.vars.habitatsLeft == 0)
        {
          game.player.death('habitatShock');
          return;
        }
      game.scene.sounds.play('event-habitat-destroy');

      // reduce max energy
      var maxEnergy = 0;
      var energyReduction = 0;
      var shock1 = 0; // control
      var shock2 = 0; // attach hold
      if (game.group.difficulty == EASY)
        {
          maxEnergy = 50;
          shock1 = 10;
          shock2 = 10;
          energyReduction = 5;
          if (watcherLevel >= 2)
            energyReduction = 1;
        }
      else if (game.group.difficulty == NORMAL)
        {
          maxEnergy = 30;
          shock1 = 30;
          shock2 = 20;
          energyReduction = 10;
          if (watcherLevel >= 2)
            energyReduction = 2;
        }
      else if (game.group.difficulty == HARD)
        {
          maxEnergy = 10;
          shock1 = 50;
          shock2 = 50;
          energyReduction = 10;
          if (watcherLevel >= 2)
            energyReduction = 5;
        }
      if (game.player.maxEnergy > maxEnergy)
        {
          game.player.maxEnergy -= energyReduction;
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
      game.profile.addPediaArticle('habitatDestruction');
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
