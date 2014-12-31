// player goals info

package const;

class Goals
{
  // get goal info by id
  public inline static function getInfo(id: _Goal): GoalInfo
    {
      return goals.get(id);
    }


  static var goals: Map<_Goal, GoalInfo> = [
    GOAL_INVADE_HOST => {
      id: GOAL_INVADE_HOST,
      name: 'Find and invade a host',
      note: 'You need to find and invade a host or you will die from lack of energy.',
      messageComplete: 'These bipedal hosts look like a dominant life form. They may be more useful.',
      onComplete: function (game, player) {
        player.goals.receive(GOAL_INVADE_HUMAN);
        }
      },

    GOAL_INVADE_HUMAN => {
      id: GOAL_INVADE_HUMAN,
      name: 'Find and invade a bipedal host',
      note: 'You need to find and invade a bipedal host', 
      messageComplete: 'This host is intelligent. I need to evolve and understand it further.',
      onComplete: function (game, player) {
        player.evolutionManager.state = 1;
        player.evolutionManager.addImprov(IMP_BRAIN_PROBE);
        player.goals.receive(GOAL_EVOLVE_PROBE);
        },
      },

    GOAL_EVOLVE_PROBE => {
      id: GOAL_EVOLVE_PROBE,
      name: 'Evolve brain probe',
      note: 'You need to evolve brain probe improvement.',
      messageComplete: 'I can probe the brain of this host now. I should also evolve further.',
      onComplete: function (game, player) {
        player.evolutionManager.state = 2;
        game.player.vars.organsEnabled = true;
        player.goals.receive(GOAL_PROBE_BRAIN);
        player.goals.receive(GOAL_EVOLVE_ORGAN);
        }
      },

    GOAL_EVOLVE_ORGAN => {
      id: GOAL_EVOLVE_ORGAN,
      isHidden: true,
      name: 'Evolve any body feature',
      note: 'You need to evolve any body feature.',
      messageComplete: 'Evolving allows me to force changes in the host body.'
      },

    GOAL_PROBE_BRAIN => {
      id: GOAL_PROBE_BRAIN,
      name: 'Probe host brain',
      note: 'You need to probe the brain of any host.',
      messageComplete: 'Some of the objects the hosts carry can be useful. There are also functional objects around.',
      onComplete: function (game, player) {
        game.player.vars.inventoryEnabled = true;
        player.goals.receive(GOAL_LEARN_ITEMS);
        }
      },

    GOAL_LEARN_ITEMS => {
      id: GOAL_LEARN_ITEMS,
      name: 'Learn any item',
      note: 'You need to learn information about any item.',
      messageComplete: 'I can learn how to use items effectively by probing the host brain for more.',
      onComplete: function (game, player) {
        game.player.vars.skillsEnabled = true;

        // skill advanced brain probe goal
        var level = player.evolutionManager.getLevel(IMP_BRAIN_PROBE);
        if (level >= 2)
          player.goals.receive(GOAL_LEARN_SKILLS);
        else player.goals.receive(GOAL_PROBE_BRAIN_ADVANCED);
        }
      },

    GOAL_PROBE_BRAIN_ADVANCED => {
      id: GOAL_PROBE_BRAIN_ADVANCED,
      name: 'Improve brain probe',
      note: 'Your brain probe is not advanced enough to gain information about host skills. You need to improve it.',
      messageComplete: 'My brain probe has improved significantly.',
      onComplete: function (game, player) {
        player.goals.receive(GOAL_LEARN_SKILLS);
        }
      },

    GOAL_LEARN_SKILLS => {
      id: GOAL_LEARN_SKILLS,
      name: 'Use brain probe to learn any skill',
      note: 'Probe the host brain to learn useful skills.',
      },

    GOAL_LEARN_SOCIETY => {
      id: GOAL_LEARN_SOCIETY,
      name: '',
      note: '',
      messageReceive: '',
      messageComplete: '',
      },
/*

     => {
      id: ,
      name: '',
      note: '',
      messageReceive: '',
      messageComplete: '',
      onComplete: function (game, player) {
        player.goals.receive();
        }
      },
*/
    ];
}


typedef GoalInfo = {
  id: _Goal, // goal id
  ?isHidden: Bool, // is this goal hidden?
  name: String, // goal name
  note: String, // goal note
  ?messageReceive: String, // message on receiving goal
  ?messageComplete: String, // message on goal completion 
  ?onComplete: Game -> Player -> Void, // func to call on completion
}
