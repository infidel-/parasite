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
        // spawn a ship on the event location
        var ev = game.timeline.getEvent('alienShipStudy');
        var area = ev.location.area;
        area.addEventObject({
          name: 'spaceship',
          action: {
            id: 'enterShip',
            type: ACTION_AREA,
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
        // one of missions
        // game.timeline.getBoolVar('shipLanded') fly away
        // game.timeline.getBoolVar('shipShotDown') send distress signal 
        //game.goals.receive();
        },
      },
    ];
/*

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
