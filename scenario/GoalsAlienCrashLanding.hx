// scenario goals - alien crash landing

package scenario;

import const.Goals;

class GoalsAlienCrashLanding
{
  public static var map: Map<_Goal, GoalInfo> = [
    SCENARIO_ALIEN_FIND_SHIP => {
      id: SCENARIO_ALIEN_FIND_SHIP,
      name: 'Find your ship',
      note: 'You need to find out where your ship is. It should contain more useful information.',
      messageReceive: 'Now I remember. I came here on a ship from somewhere far away. But where is it now?',
      messageComplete: 'Now I know its location. I should enter it and find out more about myself.',
      onReceive: function (game, player) {
        // spawn ship on the event location
        var ev = game.timeline.getEvent('alienShipStudy');
        var area = ev.location.area;
        area.addEventObject({
          name: 'spaceship',
          action: {
            id: 'enterShip',
            type: ACTION_OBJECT,
            name: 'Enter Spaceship',
            energy: 0 
            },
          onAction: function (game, player, id)
            {
              game.goals.complete(SCENARIO_ALIEN_ENTER_SHIP);

              // show first event
              var ev = game.timeline.getEvent('alienMission');
              ev.isHidden = false;
              for (n in ev.notes)
                n.isKnown = true;
              game.timeline.update();
            }
          });
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
      messageComplete:
        'The onboard computer recognizes your signature and allows you to enter the ship. ' +
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
      messageComplete: 'Target invaded. I need to return to my habitat.',
      onTurn: function (game, player) {
        // check if player has target host and complete
        if (player.state == PLR_STATE_HOST && player.host.npc != null &&
            player.host.npc.id == game.timeline.getIntVar('missionTargetID'))
          game.goals.complete(SCENARIO_ALIEN_MISSION_ABDUCTION); 
      },
      onReceive: function (game, player) {
        // find random area
        var area = game.region.getRandomWithType(AREA_CITY_HIGH, true);

        // add NPC to it
        var npc = new NPC(game);
        // TODO: maybe link to first event, but that would break brain probe
        npc.event = null;
        npc.job = 'corporate executive';
        npc.jobKnown = true;
        npc.type = 'civilian';
        npc.area = area;
        area.npc.add(npc);

        // store npc id to check against later
        game.timeline.setVar('missionTargetID', npc.id);

        // put location in text
        var goal = game.goals.getInfo(SCENARIO_ALIEN_MISSION_ABDUCTION);

        goal.note += ' Target location: (' + area.x + ',' + area.y + ')';
      },
      onComplete: function (game, player) {
        game.goals.receive(SCENARIO_ALIEN_MISSION_ABDUCTION_GO_HABITAT);
        },
      },

    SCENARIO_ALIEN_MISSION_ABDUCTION_GO_HABITAT => {
      id: SCENARIO_ALIEN_MISSION_ABDUCTION_GO_HABITAT,
      name: 'Mission: Abduction',
      note: 'You need to bring the target host to a habitat.',
      messageComplete: 'Mission accomplished. I can return to the HQ.',
      onTurn: function (game, player) {
        // TODO if player is in habitat, complete mission
        // TODO if player does not possess target host, failure
      },
      onComplete: function (game, player) {
//        game.goals.receive();
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
}
