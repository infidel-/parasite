// scenario goals - alien crash landing

package scenario;

import const.Goals;
import const.ItemsConst;
import objects.EventObject;
import scenario.Scenario;
import game.*;
import objects.*;

class GoalsAlienCrashLanding
{
// helper: find spaceship object
  static function getSpaceshipObject(game: Game): EventObject
    {
      var state: _SpaceshipState = game.timeline.getDynamicVar('spaceshipState');
      var area = game.world.get(0).get(state.studyAreaID);
      return cast area.getObject(state.studyObjectID);
    }

// helper: get full spaceship state
  static function getSpaceshipState(game: Game): _SpaceshipState
    {
      var state: _SpaceshipState = game.timeline.getDynamicVar('spaceshipState');
      return state;
    }

  static function alienShipLocationFunc(game: Game): String
    {
      var ev = game.timeline.getEvent('alienShipStudy');
      var area = ev.location.area;
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
            return false;
          }
        player.log('You successfully install the ' +
          Const.col('inventory-item', action.item.name) +
          ' into the slot.');
        player.host.inventory.removeItem(action.item);
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
        if (!game.goals.has(SCENARIO_ALIEN_ENTER_SHIP))
          {
            game.goals.receive(SCENARIO_ALIEN_FIND_SHIP, SILENT_ALL);
            game.goals.complete(SCENARIO_ALIEN_FIND_SHIP, SILENT_ALL);
          }
        var state = getSpaceshipState(game);
        if (!state.part1Installed ||
            !state.part2Installed ||
            !state.part3Installed)
          {
            player.log('The startup sequence fails to initialize. Not all of the necessary ship parts are installed.');
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
/*
    'spaceshipStart' => [{
      action: {
        id: 'enterShip',
        type: ACTION_OBJECT,
        name: 'Enter Spaceship',
        energy: 0
        // NOTE: obj field will be set up on init
      },
      func: function (game, player, id) {
        // player can stumble on a spaceship without having the goal
        // in that case we silently give previous goal and
        // auto-complete it
        if (!game.goals.has(SCENARIO_ALIEN_ENTER_SHIP))
          {
            game.goals.receive(SCENARIO_ALIEN_FIND_SHIP, SILENT_ALL);
            game.goals.complete(SCENARIO_ALIEN_FIND_SHIP, SILENT_ALL);
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
*/

    'spaceshipAbductionSuccess' => [{
      action: {
        id: 'enterShip',
        type: ACTION_OBJECT,
        name: 'Enter Spaceship',
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
        name: 'Enter Spaceship',
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
        game.goals.receive(SCENARIO_ALIEN_ENTER_SHIP);
      },
    },

    SCENARIO_ALIEN_SAVE_ALIEN => {
      id: SCENARIO_ALIEN_SAVE_ALIEN,
      name: 'Save your original host',
      note: 'Your original host survived. You need to find it.',
      messageReceive: 'My original host still functions. I will need to find it and retrieve it.',
      messageComplete: 'I feel some attachment to it.',
    },

    SCENARIO_ALIEN_ENTER_SHIP => {
      id: SCENARIO_ALIEN_ENTER_SHIP,
      name: 'Enter the ship',
      note: 'You need to enter the ship and activate the onboard computer.',
      noteFunc: alienShipLocationFunc,
      messageComplete:
        'After initiating the startup sequence you board the ship. ' +
        'Spending some time on the computer you remember what was your initial goal on this planet. ' +
        'You have a mission. You need to complete it. ' +
        'You also move the ship away into a safer location.',
      onComplete: function (game, player) {
        // move spaceship and player from lab to random wilderness spot
        moveSpaceship(game);

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

      onTurn: function (game, player) {
        // if player has target host, complete
        if (player.state == PLR_STATE_HOST &&
            player.host.npc != null &&
            player.host.npc.id == game.timeline.getIntVar('missionTargetID'))
          game.goals.complete(SCENARIO_ALIEN_MISSION_ABDUCTION);
      },

      onReceive: function (game, player) {
        // find random area
        var area = game.region.getRandomWithType(AREA_CITY_HIGH, true);

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
        npc.type = 'civilian';
        npc.areaID = area.id;
        npc.areaKnown = true;
        npc.noEventClues = true; // cannot brain probe for clues
        area.npc.add(npc);
        game.debug('' + npc);

        // store npc id for later use
        game.timeline.setVar('missionTargetID', npc.id);
        game.timeline.setVar('missionTargetAreaID', area.id);
      },

      noteFunc: function (game) {
        var areaID = game.timeline.getIntVar('missionTargetAreaID');
        var area = game.world.get(0).get(areaID);
        return Const.col('gray', Const.small(
          'Target location: (' + area.x + ',' + area.y + ')'));
      },

      onComplete: function (game, player) {
        game.goals.receive(SCENARIO_ALIEN_MISSION_ABDUCTION_GO_SPACESHIP);
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
/*
        // if player is in habitat and has target host, complete mission
        if (game.location == LOCATION_AREA &&
            game.area.isHabitat &&
            player.state == PLR_STATE_HOST &&
            player.host.npc != null &&
            player.host.npc.id == game.timeline.getIntVar('missionTargetID'))
          game.goals.complete(SCENARIO_ALIEN_MISSION_ABDUCTION_GO_SPACESHIP);
*/
        // if player does not possess target host, mission failure
        if (player.state != PLR_STATE_HOST ||
            player.host.npc == null ||
            player.host.npc.id != game.timeline.getIntVar('missionTargetID'))
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
        area.generate();

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
          var x = hangar.x1 + Std.random(Std.int(hangar.w / 2) - 3);
          var y = hangar.y1 + Std.random(Std.int(hangar.h / 2) - 3);
          var o = area.addItem(x, y, item);
          parts.push(item.name);
        }

      var spaceshipState: _SpaceshipState = {
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
      }

      // store object/area id for later use
      // NOTE: we cannot store object link since this is not serializable
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
      // pick a random spot
      var loc = {
        x: Std.int(newArea.width / 2),
        y: Std.int(newArea.height / 2),
      }
      // create decoration
      var shipDeco = createShipDecoration(game, newArea, loc,
        Const.TILE_GRASS_UNWALKABLE);
      // TODO event object (maybe give mission on first use instead?)
      // teleport
      game.player.teleport(newArea, loc.x + 1, loc.y + 2);
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
}

typedef _SpaceshipState = {
  // spaceship in lab related stuff
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
}
