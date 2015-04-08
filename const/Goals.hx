// player goals info

package const;

import game.Game;
import game.Player;

class Goals
{
  // get goal info by id
  public inline static function getInfo(id: _Goal): GoalInfo
    {
      var g = goals.get(id);
      if (g == null)
        throw "No such goal: " + id;

      return g;
    }


  static var goals: Map<_Goal, GoalInfo> = [

    // ========================= main branch

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

    // ========================= habitat branch

    GOAL_EVOLVE_ORGAN => {
      id: GOAL_EVOLVE_ORGAN,
//      isHidden: true,
      name: 'Evolve any body feature',
      note: 'You need to evolve any body feature.',
      messageComplete: 'Evolving allows me to force changes in the host body. I should try it now.',
      onComplete: function (game, player) {
        player.goals.receive(GOAL_GROW_ORGAN);
        }
      },

    GOAL_GROW_ORGAN => {
      id: GOAL_GROW_ORGAN,
      name: 'Grow any body feature',
      note: 'You need to grow any body feature.',
      messageComplete: 'Growing body features and evolving is very inefficient in a hostile environment. I need a microhabitat.',
      onComplete: function (game, player) {
        player.evolutionManager.addImprov(IMP_MICROHABITAT);
        player.goals.receive(GOAL_EVOLVE_MICROHABITAT);
        }
      },

     GOAL_EVOLVE_MICROHABITAT => {
      id: GOAL_EVOLVE_MICROHABITAT,
      name: 'Evolve a microhabitat knowledge',
      note: 'You need to evolve the knowledge of microhabitat.',
      messageComplete: 'Now that I have the knowledge I must find a place somewhere in the sewers for a habitat.',
      onComplete: function (game, player) {
        player.skills.addID(KNOW_HABITAT, 100); 
        player.goals.receive(GOAL_CREATE_HABITAT);
        }
      },

     GOAL_CREATE_HABITAT => {
      id: GOAL_CREATE_HABITAT,
      name: 'Create a new habitat',
      note: 'You need to create a microhabitat.',
      messageComplete: 'My microhabitat is complete. It allows me some degree of calm and safety.',
      },

    // ========================= main branch

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
      name: 'Learn more about human society',
      note: 'Probe host brains to raise human society knowledge to 25%. This might require multiple hosts.',
      messageReceive: 'The humans have evolved a large and intricate society. I must study it some more.',
      messageComplete: 'What am I? What is my purpose? I must know. I remember a place vaguely. I should travel there.',
      onComplete: function (game, player) {
        player.vars.timelineEnabled = true;
        game.timeline.unlock();
        player.goals.receive(GOAL_TRAVEL_EVENT);
        }
      },

    GOAL_TRAVEL_EVENT => {
      id: GOAL_TRAVEL_EVENT,
      name: 'Travel to the location you remember',
      note: 'Find the location you remember on region map and travel there.',
      messageComplete: 'I found the location. There should be some clues here.',
      onComplete: function (game, player) {
        player.goals.receive(GOAL_LEARN_CLUE);
        }
      },

    GOAL_LEARN_CLUE => {
      id: GOAL_LEARN_CLUE,
      name: 'Find a clue',
      note: 'Find any clue about the events that happened in this location',
      messageComplete: 'The chain of events that led to my current state is long. There were many humans involved.',
      onComplete: function (game, player) {
        player.vars.npcEnabled = true;
        player.goals.receive(GOAL_LEARN_NPC);
        }
      },

    GOAL_LEARN_NPC => {
      id: GOAL_LEARN_NPC,
      name: 'Learn a clue about any human',
      note: 'Find a clue about any event participant.',
      messageComplete: 'I can investigate the involved humans further by using their computational devices.',
      onComplete: function (game, player) {
        player.vars.searchEnabled = true;
        player.goals.receive(GOAL_USE_COMPUTER);
        }
      },

    GOAL_USE_COMPUTER => {
      id: GOAL_USE_COMPUTER,
      name: 'Use a computer',
      note: 'Find a laptop or mobile phone and use it successfully. You can only do that in a habitat.',
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
