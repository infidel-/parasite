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
      messageComplete: '',
/*      
      onReceive: function (game, player) {
        var ev = game.timeline.getLocation();
        },*/
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
    ];
/*

     => {
      id: ,
      name: '',
      note: '',
      messageReceive: '',
      messageComplete: '',
      onComplete: function (game, player) {
        game.goals.receive();
        },
      },
*/
}
