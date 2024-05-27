// scenario goals - alien crash landing

package scenario;

import const.ItemsConst;
import objects.EventObject;
import scenario.Scenario;
import game.*;
import objects.*;

class GoalsAlienCrashLanding
{
// helper: get alien language id
  static function getLanguageID(game: Game): Int
    {
      return game.timeline.getIntVar('alienLanguageID');
    }

// helper: find spaceship object
  static function getSpaceshipObject(game: Game): EventObject
    {
      var state: _SpaceshipState = game.timeline.getDynamicVar('spaceshipState');
      var areaID = 0;
      var objID = 0;
      if (state.location == 'study')
        {
          areaID = state.studyAreaID;
          objID = state.studyObjectID;
        }
      else if (state.location == 'hidden')
        {
          areaID = state.hiddenAreaID;
          objID = state.hiddenObjectID;
        }
      var area = game.region.get(areaID);
      return cast area.getObject(objID);
    }

// helper: get full spaceship state
  static function getSpaceshipState(game: Game): _SpaceshipState
    {
      var state: _SpaceshipState = game.timeline.getDynamicVar('spaceshipState');
      return state;
    }

// helper: get full mission state 
  public static function getMissionState(game: Game): _MissionState
    {
      var state: _MissionState = game.timeline.getDynamicVar('missionState');
      return state;
    }

  static function alienShipLocationFunc(game: Game): String
    {
      var state: _SpaceshipState = game.timeline.getDynamicVar('spaceshipState');
//      var ev = game.timeline.getEvent('alienShipStudy');
//      var area = ev.location.area;
      var area = null;
      if (state.location == 'study')
        area = game.region.get(state.studyAreaID);
      else if (state.location == 'hidden')
        area = game.region.get(state.hiddenAreaID);
      return Const.col('gray', Const.small(
        'Target location: (' + area.x + ',' + area.y + ')'));
    }

  public static var eventObjectActionsFuncs: _EventObjectActionsFuncs = [
    'spaceshipStudySlot' => function (game, player)
      {
        var inventory = player.host.inventory;
        var list: Array<_PlayerAction> = [];
        for (item in inventory.iterator())
          if (item.id == 'shipPart')
            list.push({
              id: 'installPart',
              type: ACTION_OBJECT,
              name: 'Install ' + Const.col('inventory-item', item.name),
              item: item,
              energy: 10
              // NOTE: obj field will be set up on init
            });
        return list;
      }
  ];
  public static var eventObjectActionsHooks: _EventObjectActionsHooks = [
    'spaceshipStudySlot' => function (game, player, action)
      {
//        trace('install! ' + action.item + ' ' + action.obj.infoID + ' ' + action.obj.id);
        var state = getSpaceshipState(game);
        if (action.item.name == state.part1Name && action.obj.id == state.slot1ObjectID)
          state.part1Installed = true;
        else if (action.item.name == state.part2Name && action.obj.id == state.slot2ObjectID)
          state.part2Installed = true;
        else if (action.item.name == state.part3Name && action.obj.id == state.slot3ObjectID)
          state.part3Installed = true;
        else 
          {
            player.log('This item does not fit into this slot.');
            game.scene.sounds.play('action-fail');
            return false;
          }
        player.log('You successfully install the ' +
          Const.col('inventory-item', action.item.name) +
          ' into the slot.');
        player.host.inventory.removeItem(action.item);
        game.scene.sounds.play('action-spaceship-install');
        return true;
      }
  ];

// NOTE: event objects functions moved here because of save/loading
  public static var eventObjectActions: _EventObjectActionsList = [
    'spaceshipStudyStart' => [{
      action: {
        id: 'startShip',
        type: ACTION_OBJECT,
        name: 'Initiate startup sequence',
        energy: 0
        // NOTE: obj field will be set up on init
      },
      func: function (game, player, id) {
        // player can stumble on a spaceship without having the goal
        // in that case we silently give previous goal and
        // auto-complete it
        if (!game.goals.has(SCENARIO_ALIEN_STEAL_SHIP))
          {
            game.goals.complete(GOAL_PROGRESS_TIMELINE);
            game.goals.receive(SCENARIO_ALIEN_FIND_SHIP, SILENT_ALL);
            game.goals.complete(SCENARIO_ALIEN_FIND_SHIP, SILENT_ALL);
          }
        var state = getSpaceshipState(game);
        if (!state.part1Installed ||
            !state.part2Installed ||
            !state.part3Installed)
          {
            player.log('The startup sequence fails to initialize. Not all of the necessary ship parts are installed.');
            game.scene.sounds.play('action-fail');
            return;
          }
        game.goals.complete(SCENARIO_ALIEN_STEAL_SHIP);
        game.scene.sounds.play('action-spaceship-start');
      },
    }],

    'spaceshipStart' => [{
      action: {
        id: 'enterShip',
        type: ACTION_OBJECT,
        name: 'Enter spaceship',
        energy: 0
        // NOTE: obj field will be set up on init
      },
      func: function (game, player, id) {
        if (game.goals.completed(SCENARIO_ALIEN_ENTER_SHIP))
          {
            game.log('You need to complete the mission first.');
            game.scene.sounds.play('action-fail');
            return;
          }
        game.goals.complete(SCENARIO_ALIEN_ENTER_SHIP);

        // show first event
        var ev = game.timeline.getEvent('alienMission');
        ev.isHidden = false;
        for (n in ev.notes)
          n.isKnown = true;
        game.timeline.update();
      },
    }],

    'spaceshipAbductionSuccess' => [{
      action: {
        id: 'enterShip',
        type: ACTION_OBJECT,
        name: 'Enter spaceship',
        energy: 0
        // NOTE: obj field will be set up on init
      },
      func: function (game, player, id) {
        game.goals.complete(SCENARIO_ALIEN_MISSION_ABDUCTION_GO_SPACESHIP);
      },
    }],

    'spaceshipAbductionFailure' => [{
      action: {
        id: 'enterShip',
        type: ACTION_OBJECT,
        name: 'Enter spaceship',
        energy: 0
        // NOTE: obj field will be set up on init
      },
      func: function (game, player, id) {
        game.goals.complete(SCENARIO_ALIEN_MISSION_FAILURE_GO_SPACESHIP);
      },
    }],
  ];

// goals map
  public static var map: Map<_Goal, GoalInfo> = [
    SCENARIO_ALIEN_FIND_SHIP => {
      id: SCENARIO_ALIEN_FIND_SHIP,
      name: 'Find your ship',
      note: 'You need to find out where your ship is. It should contain more useful information.',
      messageReceive: 'Now I remember. I came here on a ship from somewhere far away. But where is it now?',
      messageComplete: 'Now I know the location of the ship. I should enter it and find out more about myself.',
      onReceive: function (game, player) {
#if demo
        game.message('Thank you for playing the demo! You can restart the game now and play it to this point again but to progress further you will need to buy the full game.');
        game.ui.event({
          type: UIEVENT_FINISH,
          state: null,
          obj: {
            result: 'lose',
            condition: 'demo',
          }
        });
#else
        // spawn ship on the event location and add all variables to timeline
        addSpaceshipStudyObject(game);
#end
      },
      onComplete: function (game, player) {
        game.goals.receive(SCENARIO_ALIEN_STEAL_SHIP);
      },
    },

    SCENARIO_ALIEN_SAVE_ALIEN => {
      id: SCENARIO_ALIEN_SAVE_ALIEN,
      name: 'Save your original host',
      note: 'Your original host survived. You need to find it.',
      messageReceive: 'My original host still functions. I will need to find it and retrieve it.',
      messageComplete: 'I feel some attachment to it.',
    },

    SCENARIO_ALIEN_STEAL_SHIP => {
      id: SCENARIO_ALIEN_STEAL_SHIP,
      name: 'Relocate the ship',
      note: 'You need to activate the ship and relocate it to a safer spot.',
      noteFunc: alienShipLocationFunc,
/*
      messageComplete:
        'After initiating the startup sequence you board the ship. ' +
        'You activate the engine and move the ship away to a safer location.',*/
      onComplete: function (game, player) {
        // dynamic completion message
        var languageID = getLanguageID(game);
        game.message(
          '<span class=alien' + languageID + '>' + 'Glut</span>! After initiating the startup sequence you board the ship. ' +
          'You activate the engine and move the ship away to a safer location.');

        // move spaceship and player from lab to random wilderness spot
        moveSpaceship(game);
        game.goals.receive(SCENARIO_ALIEN_ENTER_SHIP);
      },
      onTurn: function (game, player) {
        // when in lab area, check for alertness
        var state = getSpaceshipState(game);
        if (state.location != 'study' ||
            state.alertRaised ||
            game.area.id != state.studyAreaID)
          return;

        if (game.area.alertness > 75)
          {
            state.alertRaised = true;
            var languageID = getLanguageID(game);
            game.message(
              '<span class=alien' + languageID + '>' + 'Shnakorkwa</span>! The alert was raised. I cannot leave this location without my ship now or they will move it somewhere else.');
          }
      },
      leaveAreaPre: function (game, player, area) {
        // when in lab area, disallow on alert raised
        var state = getSpaceshipState(game);
        if (state.location != 'study' ||
            game.area.id != state.studyAreaID)
          return true;
        if (state.alertRaised)
          {
            game.log('You cannot leave this area without your ship.');
            game.scene.sounds.play('action-fail');
            return false;
          }
        return true;
      },
    },

    SCENARIO_ALIEN_ENTER_SHIP => {
      id: SCENARIO_ALIEN_ENTER_SHIP,
      name: 'Enter the ship',
      note: 'You need to enter the ship and activate the onboard computer.',
      noteFunc: alienShipLocationFunc,
      messageComplete:
        'Spending some time on the computer you remember what was your initial goal on this planet. ' +
        'You have a mission. You need to complete it.',
      onComplete: function (game, player) {
        // get the mission goal
        if (game.timeline.getStringVar('alienMissionType') == 'abduction')
          game.goals.receive(SCENARIO_ALIEN_MISSION_ABDUCTION);
/*
        else if (game.timeline.getStringVar('alienMissionType') == 'infiltration')
          game.goals.receive(SCENARIO_ALIEN_MISSION_INFILTRATION);
        else if (game.timeline.getStringVar('alienMissionType') == 'research')
          game.goals.receive(SCENARIO_ALIEN_MISSION_RESEARCH);
*/
      },
    },

    SCENARIO_ALIEN_MISSION_ABDUCTION => {
      id: SCENARIO_ALIEN_MISSION_ABDUCTION,
      name: 'Mission: Abduction',
      note: 'You need to locate the target host and invade it.',
      messageComplete: 'Target invaded. I need to return to my spaceship.',
      messageFailure: 'Mission failed. I will return to the HQ now.',

      onReceive: function (game, player) {
        // find random area
        var area = game.region.getRandomWithType(AREA_CORP, true);

        // add hidden NPC to it
        // NOTE: all dynamic NPCs should belong to an event anyway
        var npc = new NPC(game);
        npc.event = game.timeline.getEvent('alienMission');
        npc.event.npc.push(npc);
        npc.isMale = true;
        npc.tileAtlasX = 3;
        npc.tileAtlasY = 4;
        npc.job = 'corporate executive';
        npc.jobKnown = true;
        npc.type = 'corpo';
        npc.areaID = area.id;
        npc.areaKnown = true;
        npc.noEventClues = true; // cannot brain probe for clues
        area.npc.add(npc);
        game.debug('' + npc);

        // store npc id for later use
        var missionState: _MissionState = {
          npcID: npc.id,
          areaID: area.id,
          areaX: 0,
          areaY: 0,
          alertRaised: false,
        };
        game.timeline.setVar('missionState', missionState);
      },

      aiInit: function (game, ai) {
        if (ai.type != 'smiler')
          return;
        // if we're in the mission target area, spawn with key card
        var missionState = getMissionState(game);
        if (game.area.id != missionState.areaID)
          return;
        var item = ai.inventory.addID('keycard');
        item.lockID = 'corp-mission';
      },

      onTurn: function (game, player) {
        var missionState = getMissionState(game);
        // if player has target host, complete goal
        if (player.state == PLR_STATE_HOST &&
            player.host.npc != null &&
            player.host.npc.id == missionState.npcID)
          game.goals.complete(SCENARIO_ALIEN_MISSION_ABDUCTION);

        // when in mission area, check for alertness
        if (!missionState.alertRaised &&
            game.area.id == missionState.areaID &&
            game.area.alertness > 75)
          {
            missionState.alertRaised = true;
            var languageID = getLanguageID(game);
            game.message(
              '<span class=alien' + languageID + '>' + 'Galbuzp</span>! The alert was raised. I cannot leave this location without completing the mission.');
          }

        // if mission npc is dead, fail the goal
        var ev = game.timeline.getEvent('alienMission');
        for (npc in ev.npc)
          {
            if (npc.id != missionState.npcID)
              continue;
            if (npc.isDead)
              game.goals.fail(SCENARIO_ALIEN_MISSION_ABDUCTION);
          }

      },
/*
      onTurn: function (game, player) {
        // if player does not possess target host, mission failure
        var missionState = getMissionState(game);
        if (player.state != PLR_STATE_HOST ||
            player.host.npc == null ||
            player.host.npc.id != missionState.npcID)
          game.goals.fail(SCENARIO_ALIEN_MISSION_ABDUCTION_GO_SPACESHIP);
      }, */

      leaveAreaPre: function (game, player, area) {
        // when in corp area, disallow on alert raised
        var missionState = getMissionState(game);
        if (game.area.id != missionState.areaID)
          return true;
        if (missionState.alertRaised)
          {
            game.log('You cannot leave this area without completing the mission.');
            game.scene.sounds.play('action-fail');
            return false;
          }
        return true;
      },

      onEnter: function (game) {
        trace('onEnter!');
        var missionState = getMissionState(game);
        // goal active, on enter spawn CEO
        if (game.area.id != missionState.areaID)
          return;
        var x = missionState.areaX,
          y = missionState.areaY;
        // first entry - find a spot
        var firstTime = false;
        var pt = { x: x, y: y };
        if (x == 0 && y == 0)
          {
            pt = rollMissionTargetXY(game);
            missionState.areaX = pt.x;
            missionState.areaY = pt.y;
            firstTime = true;
          }

        // spawn ceo
        var npc = null;
        for (v in game.area.npc)
          if (v.id == missionState.npcID)
            {
              npc = v;
              break;
            }
        var ai = game.area.spawnAI('corpo', pt.x, pt.y);
        game.debug('spawn npc ' + npc.id + ' (ai: ' + ai.id + ', pos: ' + ai.x + ',' + ai.y + ')');
        ai.setNPC(npc);
        ai.isGuard = true;

        // find all doors leading to this room and lock them
        if (firstTime)
          {
            // find room record
            var generatorInfo = game.area.generatorInfo;
            var room = generatorInfo.getRoomAt(ai.x, ai.y);
            if (room == null)
              {
                trace('room is null for (' + ai.x + ',' + ai.y + ')!');
                return;
              }
            var doors = [];
            for (d in generatorInfo.doors)
              if (d.roomID1 == room.id ||
                  d.roomID2 == room.id)
                {
                  doors.push(d);
                  break;
                }
            // lock all doors with key card
//            trace(doors);
            for (door in doors)
              {
                var objs = game.area.getObjectsAt(door.x, door.y);
                for (o in objs)
                  if (o.type == 'door')
                    {
                      var d: objects.Door = cast o;
                      d.isLocked = true;
                      d.lockID = 'corp-mission';
                      break;
                    }
              }
          }
      },

      noteFunc: function (game) {
        var missionState = getMissionState(game);
        var area = game.world.get(0).get(missionState.areaID);
        return Const.col('gray', Const.small(
          'Target location: (' + area.x + ',' + area.y + ')'));
      },

      onComplete: function (game, player) {
        game.goals.receive(SCENARIO_ALIEN_MISSION_ABDUCTION_GO_SPACESHIP);
      },

      onFailure: function (game, player) {
        game.goals.receive(SCENARIO_ALIEN_MISSION_FAILURE_GO_SPACESHIP);
      },
    },

    SCENARIO_ALIEN_MISSION_ABDUCTION_GO_SPACESHIP => {
      id: SCENARIO_ALIEN_MISSION_ABDUCTION_GO_SPACESHIP,
      name: 'Mission: Abduction',
      note: 'You need to bring the target host to the spaceship.',
      noteFunc: alienShipLocationFunc,
      messageComplete: 'Mission accomplished. I can return to the HQ now. Goodbye, Earth. For now.',
      messageFailure: 'Mission failed. I will return to the HQ now.',

      onTurn: function (game, player) {
        // if player does not possess target host, mission failure
        var missionState = getMissionState(game);
        if (player.state != PLR_STATE_HOST ||
            player.host.npc == null ||
            player.host.npc.id != missionState.npcID)
          game.goals.fail(SCENARIO_ALIEN_MISSION_ABDUCTION_GO_SPACESHIP);
      },

      onReceive: function (game, player) {
        var obj = getSpaceshipObject(game);
        obj.infoID = 'spaceshipAbductionSuccess';
      },

      onComplete: function (game, player) {
        // finish game
        game.finish('win', 'You have completed your mission.');
      },

      onFailure: function (game, player) {
        game.goals.receive(SCENARIO_ALIEN_MISSION_FAILURE_GO_SPACESHIP);
      },
    },


    SCENARIO_ALIEN_MISSION_FAILURE_GO_SPACESHIP => {
      id: SCENARIO_ALIEN_MISSION_FAILURE_GO_SPACESHIP,
      name: 'Return to spaceship',
      note: 'You need to return to the spaceship.',
      noteFunc: alienShipLocationFunc,
      messageComplete: 'Returning to the HQ now...',

      onReceive: function (game, player) {
        // change spaceship action contents
        var obj = getSpaceshipObject(game);
        obj.infoID = 'spaceshipAbductionFailure';
      },

      onComplete: function (game, player) {
        // finish game
        game.finish('win', 'You have failed in your original mission.');
      },
    },
  ];
/*

        // game.timeline.getBoolVar('shipLanded') fly away
        // game.timeline.getBoolVar('shipShotDown') send distress signal
        //game.goals.receive();

     => {
      id: ,
      name: '',
      note: '',
      messageReceive: '',
      messageComplete: '',
      onReceive: function (game, player) {
      },
      onComplete: function (game, player) {
        game.goals.receive();
        },
      },
*/

// spaceship in lab - spawn in hangar with console and parts around
  static function addSpaceshipStudyObject(game: Game)
    {
      var ev = game.timeline.getEvent('alienShipStudy');
      var area = ev.location.area;
      // generate area if it's not yet generated
      if (!area.isGenerated)
        {
          area.generate();
          area.initSpawnPoints();
        }

      // find hangar corner
      var sx = -1, sy = -1;
      var cells = area.getCells();
      for (y in 0...area.height)
        {
          for (x in 0...area.width)
            if (cells[x][y] == Const.TILE_FLOOR_CONCRETE)
              {
                sx = x;
                sy = y;
                break;
              }
          if (sx != -1)
            break;
        }
      var hangar = area.getRect(sx, sy);
      // ship tile block corner
      var loc = {
        x: hangar.x1 + Std.int(hangar.w / 2),
        y: hangar.y1 + Std.int(hangar.h / 2),
      };

      // create decoration
      var shipDeco = createShipDecoration(game, area, loc,
        Const.TILE_FLOOR_CONCRETE_UNWALKABLE);
      // console
      var console = area.addEventObject(loc.x + 1, loc.y + 2, 'console', 'spaceshipStudyStart');
      // slots
      var slot1 = area.addEventObject(loc.x - 1, loc.y + 1, 'slot', 'spaceshipStudySlot');
      var slot2 = area.addEventObject(loc.x + 3, loc.y + 1, 'slot', 'spaceshipStudySlot');
      var slot3 = area.addEventObject(loc.x + 1, loc.y - 1, 'slot', 'spaceshipStudySlot');
      // parts
      var parts = [];
      var languageID = getLanguageID(game);
      for (i in 0...3)
        {
          // force unique parts
          var item = null;
          while (true)
            {
              item = ItemsConst.spawnItem(game, 'shipPart');
              if (Lambda.has(parts, item.name))
                continue;
              break;
            }

          // first part always spawns in hangar
          // second always on random table, third random
          var x = hangar.x1 + Std.random(Std.int(hangar.w / 2) - 3);
          var y = hangar.y1 + Std.random(Std.int(hangar.h / 2) - 3);
          var randomLocation = false;
          if (i == 1)
            randomLocation = true;
          else if (i == 2 && Std.random(100) < 50)
            randomLocation = true;
          var cnt = 0;
          if (randomLocation)
            while (true)
              {
                var pt = area.clueSpawnPoints[Std.random(area.clueSpawnPoints.length)];
                x = pt.x;
                y = pt.y;
                if (!area.hasObjectAt(x, y))
                  break;
                cnt++;
                if (cnt > 100)
                  {
                    trace('cannot find free place for spawn');
                    break;
                  }
              }

          var o = area.addItem(x, y, item, Const.FRAME_SHIP_PART, true);
          o.name = '<span class=alien' + languageID + '>' + item.name + '</span>';
          o.item.name = '<span class=alien' + languageID + '>' + o.item.name + '</span>';
          parts.push(item.name);
        }

      // store state for later use
      // NOTE: we cannot store object link since this is not serializable
      var spaceshipState: _SpaceshipState = {
        location: 'study',
        studyAreaID: area.id,
        studyObjectID: console.id,
        studyDecoration: shipDeco,
        slot1ObjectID: slot1.id,
        slot2ObjectID: slot2.id,
        slot3ObjectID: slot3.id,
        part1Name: parts[0],
        part2Name: parts[1],
        part3Name: parts[2],
        part1Installed: false,
        part2Installed: false,
        part3Installed: false,
        hiddenAreaID: 0,
        hiddenObjectID: 0,
        alertRaised: false,
      }
      game.timeline.setVar('spaceshipState', spaceshipState);
    }

// move spaceship and player from lab to random wilderness spot
  static function moveSpaceship(game: Game)
    {
      var state = getSpaceshipState(game);

      // remove old objects
      var area = game.region.get(state.studyAreaID);
      var cells = area.getCells();
      for (id in state.studyDecoration)
        {
          var o = area.getObject(id);
          area.removeObject(o);
          cells[o.x][o.y] = Const.TILE_FLOOR_CONCRETE;
        }
      for (id in [ state.slot1ObjectID, state.slot2ObjectID, state.slot3ObjectID, state.studyObjectID ])
        {
          var o = area.getObject(id);
          area.removeObject(o);
        }

      // pick a random wilderness area and respawn ship there
      var newArea = game.region.getRandomWithType(AREA_GROUND, true);
      // generate area if it's not yet generated
      if (!newArea.isGenerated)
        newArea.generate();
      var newCells = newArea.getCells();
      // pick a random spot
      var loc = {
        x: Std.int(newArea.width / 2),
        y: Std.int(newArea.height / 2),
      }
      // create decoration
      createShipDecoration(game, newArea, loc,
        Const.TILE_GRASS_UNWALKABLE);
      // event object
      var obj = newArea.addEventObject(loc.x + 1, loc.y + 2, 'spaceship', 'spaceshipStart');
      // clear tile just in case there is a tree or a rock
      newCells[loc.x + 1][loc.y + 2] = Const.TILE_GRASS;
      // teleport
      game.player.teleport(newArea, loc.x + 1, loc.y + 2);
      // make known and mark on region map
      newArea.isKnown = true;
      newArea.tileID = Const.TILE_SPACESHIP;
      state.location = 'hidden';
      state.hiddenAreaID = newArea.id;
      state.hiddenObjectID = obj.id;
    }

// helper function for creating ship decoration
  static function createShipDecoration(game: Game, area: AreaGame, loc, tile: Int): Array<Int>
    {
      var block = Const.SPACESHIP_BLOCK;
      var shipDeco = [];
      var cells = area.getCells();
      for (y in 0...block.height)
        for (x in 0...block.width)
          {
            var o = new Decoration(game, area.id,
              x + loc.x, y + loc.y, y + block.row, x + block.col);
            cells[x + loc.x][y + loc.y] = tile;
            area.addObject(o);
            shipDeco.push(o.id);
          }
      return shipDeco;
    }

// helper - find new spawn point for corp mission target
  static function rollMissionTargetXY(game)
    {
      // find nearest office (marble floor)
      // NOTE: there can be no office, then the task is easier
      // limit by 100 points
      var solopts = [];
      var workpts = [];
      var meetingpts = [];
      var cells = game.area.getCells();
      for (y in 0...cells.length)
        if (solopts.length < 100)
          {
            for (x in 0...cells[y].length)
              if (cells[x][y] == Const.TILE_FLOOR_MARBLE1)
                solopts.push({ x: x, y: y });
              else if (cells[x][y] == Const.TILE_FLOOR_CARPET_MEETING)
                meetingpts.push({ x: x, y: y });
              else if (cells[x][y] == Const.TILE_FLOOR_WOOD2)
                workpts.push({ x: x, y: y });
          }
        else break;

      // solo office -> meeting room -> work room
      var pt = null;
      if (solopts.length > 0)
        {
          game.debug('solo office found');
          pt = solopts[Std.random(solopts.length)];
        }
      else if (meetingpts.length > 0)
        {
          game.debug('meeting room found');
          pt = meetingpts[Std.random(meetingpts.length)];
        }
      else
        {
          game.debug('work room found');
          pt = workpts[Std.random(workpts.length)];
        }

      return pt;
    }
}

typedef _SpaceshipState = {
  var location: String; // study, hidden
  // lab related stuff
  var studyAreaID: Int;
  var studyObjectID: Int;
  var studyDecoration: Array<Int>;
  var slot1ObjectID: Int;
  var slot2ObjectID: Int;
  var slot3ObjectID: Int;
  var part1Name: String;
  var part2Name: String;
  var part3Name: String;
  var part1Installed: Bool;
  var part2Installed: Bool;
  var part3Installed: Bool;
  var alertRaised: Bool;

  // hidden location
  var hiddenAreaID: Int;
  var hiddenObjectID: Int;
}

typedef _MissionState = {
  var npcID: Int;
  var areaID: Int; // mission target area id
  var alertRaised: Bool;
  var areaX: Int;
  var areaY: Int;
}
