// scenario goals - alien crash landing

package scenario;

import const.ItemsConst;
import gen.facility.FacilityTemp;
import objects.EventObject;
import render.facility.FacilityModel;
import render.facility.FacilityStyle;
import scenario.Scenario;
import game.*;
import objects.*;

class GoalsAlienCrashLanding
{
// helper: get alien language id
  public static function getLanguageID(game: Game): Int
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
              energy: 10,
              isAgreeable: true,
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
            game.actionFailed('This item does not fit into this slot.');
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
            game.actionFailed('The startup sequence fails to initialize. Not all of the necessary ship parts are installed.');
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
            game.actionFailed('You need to complete the mission first.');
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

    'spaceshipSuccess' => [{
      action: {
        id: 'enterShip',
        type: ACTION_OBJECT,
        name: 'Enter spaceship',
        energy: 0
        // NOTE: obj field will be set up on init
      },
      func: function (game, player, id) {
        var missionType = game.timeline.getStringVar('alienMissionType');
        var goalID: _Goal = null;
        switch (missionType)
          {
            case 'abduction':
              goalID = SCENARIO_ALIEN_MISSION_ABDUCTION_GO_SPACESHIP;
            default:
              goalID = SCENARIO_ALIEN_MISSION_SUCCESS_GO_SPACESHIP;
          }
        game.goals.complete(goalID);
      },
    }],


    'spaceshipFailure' => [{
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
        game.finishDemo();
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
        game.message({
          text: '<span class=alien' + languageID + '>' + 'Glut</span>! After initiating the startup sequence you board the ship. ' +
          'You activate the engine and move the ship away to a safer location.',
          img: 'event/scenario_alien_steal_ship_complete'
        });

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
            game.message({
              text: '<span class=alien' + languageID + '>' + 'Shnakorkwa</span>! The alert was raised. I cannot leave this location without my ship now or they will move it somewhere else.',
              img: 'event/security_alert'
            });
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
            game.actionFailed('You cannot leave this area without your ship.');
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
        var missionType = game.timeline.getStringVar('alienMissionType');
        var goalID: _Goal = null;
        switch (missionType)
          {
            case 'abduction':
              goalID = SCENARIO_ALIEN_MISSION_ABDUCTION;
            case 'liquidation':
              goalID = SCENARIO_ALIEN_MISSION_LIQUIDATION;
            case 'intel':
              goalID = SCENARIO_ALIEN_MISSION_INTEL;
          }
        game.goals.receive(goalID);
      },
    },

    SCENARIO_ALIEN_MISSION_ABDUCTION => {
      id: SCENARIO_ALIEN_MISSION_ABDUCTION,
      name: 'Mission: Abduction',
      note: 'You need to locate the target host and invade it.',
      messageComplete: 'Target invaded. I need to return to my spaceship.',
      messageFailure: 'Mission failed. I will return to the HQ now.',
      imageComplete: 'event/scenario_alien_return',
      imageFailure: 'event/scenario_alien_return',

      aiInit: AlienMissionCommon.aiInit,
      leaveAreaPre: AlienMissionCommon.leaveAreaPre,
      onEnter: AlienMissionCommon.onEnter,
      onReceive: AlienMissionCommon.onReceive,
      onTurn: AlienMissionCommon.onTurn,
      noteFunc: AlienMissionCommon.noteFunc,

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
      imageComplete: 'event/scenario_alien_return',
      imageFailure: 'event/scenario_alien_return',

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
        obj.infoID = 'spaceshipSuccess';
      },

      onComplete: function (game, player) {
        // finish game
        game.finish({
          result: 'win',
          text: 'You have completed your mission.',
          filter: 'alien'
        });
      },

      onFailure: function (game, player) {
        game.goals.receive(SCENARIO_ALIEN_MISSION_FAILURE_GO_SPACESHIP);
      },
    },

    SCENARIO_ALIEN_MISSION_LIQUIDATION => {
      id: SCENARIO_ALIEN_MISSION_LIQUIDATION,
      name: 'Mission: Liquidation',
      note: 'You need to locate the target host and liquidate it.',
      messageComplete: 'Target liquidated. I need to return to my spaceship.',
      messageFailure: 'Mission failed. I will return to the HQ now.',
      imageComplete: 'event/scenario_alien_return',
      imageFailure: 'event/scenario_alien_return',

      aiInit: AlienMissionCommon.aiInit,
      leaveAreaPre: AlienMissionCommon.leaveAreaPre,
      onEnter: AlienMissionCommon.onEnter,
      onReceive: AlienMissionCommon.onReceive,
      onTurn: AlienMissionCommon.onTurn,
      noteFunc: AlienMissionCommon.noteFunc,

      onComplete: function (game, player) {
        game.goals.receive(SCENARIO_ALIEN_MISSION_SUCCESS_GO_SPACESHIP);
      },

      onFailure: function (game, player) {
        game.goals.receive(SCENARIO_ALIEN_MISSION_FAILURE_GO_SPACESHIP);
      },
    },

    SCENARIO_ALIEN_MISSION_INTEL => {
      id: SCENARIO_ALIEN_MISSION_INTEL,
      name: 'Mission: Intel Collection',
      note: 'You need to locate the target host and probe its brain.',
      messageComplete: 'Target scanned. I need to return to my spaceship.',
      messageFailure: 'Mission failed. I will return to the HQ now.',
      imageComplete: 'event/scenario_alien_return',
      imageFailure: 'event/scenario_alien_return',

      aiInit: AlienMissionCommon.aiInit,
      leaveAreaPre: AlienMissionCommon.leaveAreaPre,
      onEnter: AlienMissionCommon.onEnter,
      onReceive: AlienMissionCommon.onReceive,
      onTurn: AlienMissionCommon.onTurn,
      noteFunc: AlienMissionCommon.noteFunc,

      onComplete: function (game, player) {
        game.goals.receive(SCENARIO_ALIEN_MISSION_SUCCESS_GO_SPACESHIP);
      },

      onFailure: function (game, player) {
        game.goals.receive(SCENARIO_ALIEN_MISSION_FAILURE_GO_SPACESHIP);
      },
    },

// common success goal for some missions
    SCENARIO_ALIEN_MISSION_SUCCESS_GO_SPACESHIP => {
      id: SCENARIO_ALIEN_MISSION_SUCCESS_GO_SPACESHIP,
      name: 'Return to spaceship',
      note: 'You need to return to the spaceship.',
      noteFunc: alienShipLocationFunc,
      messageComplete: 'Returning to the HQ now...',
      imageComplete: 'event/scenario_alien_mission_complete',

      onReceive: function (game, player) {
        // change spaceship action contents
        var obj = getSpaceshipObject(game);
        obj.infoID = 'spaceshipSuccess';
      },

      onComplete: function (game, player) {
        // finish game
        game.finish({
          result: 'win',
          text: 'You have succeeded in your mission.',
          img: 'event/scenario_alien_finish_win' + (1 + Std.random(5)),
          filter: 'alien'
        });
      },
    },

// common failure goal for all missions
    SCENARIO_ALIEN_MISSION_FAILURE_GO_SPACESHIP => {
      id: SCENARIO_ALIEN_MISSION_FAILURE_GO_SPACESHIP,
      name: 'Return to spaceship',
      note: 'You need to return to the spaceship.',
      noteFunc: alienShipLocationFunc,
      messageComplete: 'Returning to the HQ now...',
      imageComplete: 'event/scenario_alien_mission_complete',

      onReceive: function (game, player) {
        // change spaceship action contents
        var obj = getSpaceshipObject(game);
        obj.infoID = 'spaceshipFailure';
      },

      onComplete: function (game, player) {
        // finish game
        game.finish({
          result: 'win',
          text: 'You have failed in your mission.',
          img: 'event/scenario_alien_finish_lose',
          filter: 'alien'
        });
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

// spaceship in lab - spawn in the hangar, on the study podium, with console and slots round it
//
// WRITES NO TILES AT ALL, which is the point rather than an economy. The hangar's study pad is
// already a 5x5 square of unwalkable concrete (gen.blocks.HangarBlock carves it, and it carves it
// FOR this set piece), so the ship needs no footprint of its own — and because nothing is stamped,
// nothing has to be un-stamped when the ship leaves. That is what retires the whole
// paint-it-then-repaint-it dance moveSpaceship used to do on the study side.
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

      var shed = findStudyPad(area);
      // the ship stands ON the pad: unwalkable concrete, and an infoID with no row in
      // eventObjectActions, so it offers nothing and never needs a cell the player can reach.
      // the console owns the startup action
      var ship = area.addEventObject(shed.x, shed.y, 'spaceship', 'spaceshipStudyShip');
      // console and slots on the apron round it. THE CELLS ARE TESTED, not computed: an event
      // object is only usable from its OWN cell (objects.EventObject does not override
      // canActivateNear, and game.PlayerArea skips anything off the player's tile), so one that
      // lands on a fitting or in a wall is dead rather than merely ugly
      var apron = apronCells(area, shed);
      var console = area.addEventObject(apron[0].x, apron[0].y, 'console', 'spaceshipStudyStart');
      var slot1 = area.addEventObject(apron[1].x, apron[1].y, 'slot', 'spaceshipStudySlot');
      var slot2 = area.addEventObject(apron[2].x, apron[2].y, 'slot', 'spaceshipStudySlot');
      var slot3 = area.addEventObject(apron[3].x, apron[3].y, 'slot', 'spaceshipStudySlot');
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

          // the first case always spawns in the hangar, the second in a store room when the
          // compound has one, and the third on a random table half the time
          var pt = null;
          if (i == 1)
            pt = storeCell(area);
          if (pt == null &&
              (i == 1 || (i == 2 && Std.random(100) < 50)))
            pt = clueCell(area);
          if (pt == null)
            pt = freeCell(area, shed.x1, shed.y1, shed.x2, shed.y2);
          if (pt == null)
            {
              trace('cannot find free place for spawn');
              continue;
            }

          var o = area.addItem(pt.x, pt.y, item, Const.FRAME_SHIP_PART, true);
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
        studyShipObjectID: ship.id,
        studyDecoration: [],
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

// helper: the hangar's study pad centre, plus the shed's interior box
//
// DERIVED FROM THE SAVED GRID, because there is nothing else to read: the generator's block tree is
// in-memory only (gen._GenNode) and a loaded save never had one. render.facility.FacilityModel is
// this repo's one reader of that grid and recovers both the sheds and their pads from it, which is
// the same call console.GoBlock makes for `go block study-pad`. The old scan — first cell of
// Const.TILE_FLOOR_CONCRETE in the area — broke the day gen.facility.FacilityRooms gave a lab
// building a STORE ROOM, which floors in exactly that tile: the ship spawned in the store
  static function findStudyPad(area: AreaGame): { x: Int, y: Int, x1: Int, y1: Int, x2: Int, y2: Int }
    {
      var m = FacilityModel.fromArea(area);
      var shed = null;
      for (st in m.structures)
        if (st.hangar)
          {
            shed = st;
            break;
          }
      // a shed too small for gen.blocks.HangarBlock to carve a pad in falls back to its middle
      var x1 = (shed != null ? shed.x1 : 1);
      var y1 = (shed != null ? shed.y1 : 1);
      var x2 = (shed != null ? shed.x2 : area.width - 2);
      var y2 = (shed != null ? shed.y2 : area.height - 2);
      return {
        x: (m.pads.length > 0 ? m.pads[0].col : x1 + Std.int((x2 - x1) / 2)),
        y: (m.pads.length > 0 ? m.pads[0].row : y1 + Std.int((y2 - y1) / 2)),
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
      };
    }

// helper: standable cells round the study pad, the apron's CORNERS first
//
// the corners and not the compass points, and that is the one piece of arithmetic here that is not
// arbitrary: gen.blocks.HangarBlock stands its machine banks on the four spokes and
// render.facility.FacilityHangar runs a cable from each of them to the dais rim, so a console on a
// spoke stands in a cable lane. The ring itself is already kept clear of floor clutter
// (FacilityHangar.floor's own CLEAR margin), which is why it is bare enough to use
  static function apronCells(area: AreaGame,
      shed: { x: Int, y: Int, x1: Int, y1: Int, x2: Int, y2: Int }): Array<{ x: Int, y: Int }>
    {
      var out = [];
      var r = Std.int(FacilityStyle.PODIUM_PAD / 2) + 1;
      // west corners first, so the console lands on the side the shed's one real door is on
      for (d in r...r + 3)
        {
          var ring = [
            { x: shed.x - d, y: shed.y - d },
            { x: shed.x - d, y: shed.y + d },
            { x: shed.x + d, y: shed.y - d },
            { x: shed.x + d, y: shed.y + d },
          ];
          for (i in -d + 1...d)
            {
              ring.push({ x: shed.x - d, y: shed.y + i });
              ring.push({ x: shed.x + d, y: shed.y + i });
              ring.push({ x: shed.x + i, y: shed.y - d });
              ring.push({ x: shed.x + i, y: shed.y + d });
            }
          for (pt in ring)
            if (pt.x > 0 &&
                pt.y > 0 &&
                pt.x < area.width - 1 &&
                pt.y < area.height - 1 &&
                area.isWalkable(pt.x, pt.y) &&
                !area.hasObjectAt(pt.x, pt.y))
              out.push(pt);
          if (out.length >= 4)
            break;
        }
      // a shed whose apron is somehow full takes anything standable it has: four DISTINCT usable
      // cells is the contract this returns on, and the caller indexes it
      if (out.length < 4)
        for (y in shed.y1...shed.y2 + 1)
          for (x in shed.x1...shed.x2 + 1)
            if (area.isWalkable(x, y) &&
                !area.hasObjectAt(x, y) &&
                !Lambda.exists(out, function (p) return p.x == x && p.y == y))
              out.push({
                x: x,
                y: y,
              });
      return out;
    }

// helper: a random free standable cell in a rect, or null when it has none
  static function freeCell(area: AreaGame, x1: Int, y1: Int, x2: Int, y2: Int): { x: Int, y: Int }
    {
      var list = [];
      for (y in y1...y2 + 1)
        for (x in x1...x2 + 1)
          if (area.isWalkable(x, y) &&
              !area.hasObjectAt(x, y))
            list.push({
              x: x,
              y: y,
            });
      if (list.length == 0)
        return null;
      return list[Std.random(list.length)];
    }

// helper: a free cell in a store room, or null when the compound has no store
//
// isWalkable IS the whole test. A store's racking and pallets all went through
// gen.facility.FacilityRooms.placeFitting, which stamps the unwalkable floor id, so what is left
// walkable in that room IS its aisles — no zone knowledge needed, and none available anyway
  static function storeCell(area: AreaGame): { x: Int, y: Int }
    {
      if (area.generatorInfo == null)
        return null;
      for (room in area.generatorInfo.rooms)
        {
          if (room.role != FacilityTemp.ROLE_STORAGE)
            continue;
          var pt = freeCell(area, room.x1, room.y1, room.x2, room.y2);
          if (pt != null)
            return pt;
        }
      return null;
    }

// helper: a free lab table to leave a case on, or null when every one of them is taken
  static function clueCell(area: AreaGame): { x: Int, y: Int }
    {
      var list = [];
      for (pt in area.clueSpawnPoints)
        if (!area.hasObjectAt(pt.x, pt.y))
          list.push(pt);
      if (list.length == 0)
        return null;
      return list[Std.random(list.length)];
    }

// move spaceship and player from lab to random wilderness spot
  static function moveSpaceship(game: Game)
    {
      var state = getSpaceshipState(game);

      // remove old objects
      var area = game.region.get(state.studyAreaID);
      var cells = area.getCells();
      // A SAVE FROM BEFORE THE SHIP STOOD ON THE PODIUM still holds six decoration objects on six
      // painted cells, and those really do have to be given their floor back. A save made since
      // carries an empty list and paints nothing — which is also what keeps the study pad intact:
      // repainting it walkable would break the 5x5 square of unwalkable concrete
      // render.facility.FacilityModel.findPads recovers the podium from, and the podium would be
      // gone for the rest of the game
      if (state.studyDecoration != null)
        for (id in state.studyDecoration)
          {
            var o = area.getObject(id);
            area.removeObject(o);
            cells[o.x][o.y] = Const.TILE_FLOOR_CONCRETE;
          }
      var ids = [ state.slot1ObjectID, state.slot2ObjectID, state.slot3ObjectID, state.studyObjectID ];
      if (state.studyShipObjectID != null)
        ids.push(state.studyShipObjectID);
      for (id in ids)
        {
          var o = area.getObject(id);
          if (o != null)
            area.removeObject(o);
        }

      // pick a random wilderness area and respawn ship there
      var newArea = game.region.getRandom({ type: AREA_GROUND, noEvents: true });
      // generate area if it's not yet generated
      if (!newArea.isGenerated)
        newArea.generate();
      var newCells = newArea.getCells();
      // pick a random spot
      var loc = {
        x: Std.int(newArea.width / 2),
        y: Std.int(newArea.height / 2),
      }
      // the hull's footprint, painted AROUND the cell the event object stands on. out here there is
      // no study pad to stand on, so these tiles are the only thing that makes the ship solid —
      // and the middle cell stays walkable on purpose: it is the way in, and the player boards by
      // stepping into it (the prop's own GHOST batch fades the hull off them, see
      // render.world.ObjModels)
      paintShipFootprint(newArea, loc.x, loc.y, Const.TILE_GRASS_UNWALKABLE);
      // event object
      var obj = newArea.addEventObject(loc.x, loc.y, 'spaceship', 'spaceshipStart');
      // clear tile just in case there is a tree or a rock
      newCells[loc.x][loc.y] = Const.TILE_GRASS;
      // teleport
      game.player.teleport(newArea, loc.x, loc.y);
      // make known and mark on region map
      newArea.isKnown = true;
      newArea.tileID = Const.TILE_SPACESHIP;
      state.location = 'hidden';
      state.hiddenAreaID = newArea.id;
      state.hiddenObjectID = obj.id;
    }

// helper: paint the ship's footprint round a centre cell, leaving that cell alone
//
// TILES AND NOTHING ELSE. It used to also stand six objects.Decoration on those cells, one per
// frame of the 3x2 spaceship block of entities64 — which is a drawn ship seen from above, right on
// a 2D map and six upright billboards of it standing INSIDE the glb in 3D
  static function paintShipFootprint(area: AreaGame, cx: Int, cy: Int, tile: Int)
    {
      var block = Const.SPACESHIP_BLOCK;
      var cells = area.getCells();
      for (y in 0...block.height)
        for (x in 0...block.width)
          {
            var px = cx + x - Std.int(block.width / 2);
            var py = cy + y - Std.int(block.height / 2);
            if (px < 0 ||
                py < 0 ||
                px >= area.width ||
                py >= area.height ||
                (px == cx && py == cy))
              continue;
            cells[px][py] = tile;
          }
    }
}

typedef _SpaceshipState = {
  var location: String; // study, hidden
  // lab related stuff
  var studyAreaID: Int;
  var studyObjectID: Int;
  // the ship in the lab. OPTIONAL because a save made before the ship became one object standing on
  // the hangar podium has no such object at all — it has the six decorations below instead
  @:optional var studyShipObjectID: Int;
  // the six objects.Decoration a PRE-PODIUM save painted the ship with, and the cells they owe their
  // floor back to. Written empty by everything since; kept because those saves still load
  @:optional var studyDecoration: Array<Int>;
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
  var guardX: Int;
  var guardY: Int;
}
