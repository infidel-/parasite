// game.goals info

package const;

import game.Game;
import game.Player;

class Goals
{
  public static var map: Map<_Goal, GoalInfo> = [

    // ========================= misc goals (tutorials)

    GOAL_TUTORIAL_ALERT => {
      id: GOAL_TUTORIAL_ALERT,
      isHidden: true,
      isStarting: true,
      name: '',
      note: '',
      messageComplete: "That host is agitated, I need to flee to avoid trouble.",
    },

    GOAL_TUTORIAL_BODY => {
      id: GOAL_TUTORIAL_BODY,
      isHidden: true,
      isStarting: true,
      name: '',
      note: '',
      messageComplete: "This host has expired and its body will be found. Troublesome.",
    },

    GOAL_TUTORIAL_BODY_SEWERS => {
      id: GOAL_TUTORIAL_BODY_SEWERS,
      isHidden: true,
      isStarting: true,
      name: '',
      note: '',
      messageComplete: "This host has expired in the sewers and its body will not bring problems.",
    },

    GOAL_TUTORIAL_ENERGY => {
      id: GOAL_TUTORIAL_ENERGY,
      isHidden: true,
      isStarting: true,
      name: '',
      note: '',
      messageComplete: "This host will soon expire, time to look for another one.",
    },

    GOAL_TUTORIAL_AREA_ALERT => {
      id: GOAL_TUTORIAL_AREA_ALERT,
      isHidden: true,
      isStarting: true,
      name: '',
      note: '',
      messageComplete: "This area is getting dangerous to enter. Better to wait until things calm down.",
    },

    // ========================= main branch

    GOAL_INVADE_HOST => {
      id: GOAL_INVADE_HOST,
      isStarting: true,
      name: 'Find and invade a host',
      note: 'You need to find and invade a host or you will die from the lack of energy.',
      messageComplete: 'The bipedal hosts look like a dominant life form. They may be more useful.',
      onComplete: function (game, player) {
        game.goals.receive(GOAL_INVADE_HUMAN);
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
        game.goals.receive(GOAL_EVOLVE_PROBE);
        },
      },

    GOAL_EVOLVE_PROBE => {
      id: GOAL_EVOLVE_PROBE,
      name: 'Evolve brain probe',
      note: 'You need to evolve the brain probe improvement.',
      messageReceive: 'Evolution degrades the host. I need to be careful.',
      messageComplete: 'I can probe the host brains now. I should also evolve further.',
      onComplete: function (game, player) {
        player.evolutionManager.state = 2;
        game.player.vars.organsEnabled = true;
        game.goals.receive(GOAL_PROBE_BRAIN);
        game.goals.receive(GOAL_EVOLVE_ORGAN);

        // choose difficulty
        game.scene.event({
          state: UISTATE_DIFFICULTY,
          obj: 'evolution'
        });
      }
    },

    // ========================= camouflage layer branch

    GOAL_EVOLVE_CAMO => {
      id: GOAL_EVOLVE_CAMO,
      name: 'Evolve camouflage layer',
      note: 'You need to evolve the camouflage layer improvement.',
      messageReceive: 'These areas are much more dangerous to me. I need to be less visible on the host body.',
      onReceive: function (game, player) {
        player.evolutionManager.addImprov(IMP_CAMO_LAYER);
      },
      onComplete: function (game, player) {
        game.goals.receive(GOAL_GROW_CAMO);
      }
    },

    GOAL_GROW_CAMO => {
      id: GOAL_GROW_CAMO,
      name: 'Grow camouflage layer',
      note: 'You need to grow the camouflage layer body feature.',
    },

    // ========================= dopamine branch

    GOAL_EVOLVE_DOPAMINE => {
      id: GOAL_EVOLVE_DOPAMINE,
      name: 'Evolve dopamine regulation',
      note: 'You need to evolve the dopamine regulation improvement.',
      messageReceive: 'The addiction to chemicals of this host can be useful to me.',
      onReceive: function (game, player) {
        player.evolutionManager.addImprov(IMP_DOPAMINE);
      },
      onComplete: function (game, player) {
//        player.skills.addID(KNOW_DOPAMINE, 100);
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
        game.goals.receive(GOAL_GROW_ORGAN);
      }
    },

    GOAL_GROW_ORGAN => {
      id: GOAL_GROW_ORGAN,
      name: 'Grow any body feature',
      note: 'You need to grow any body feature.',
      messageComplete: 'Growing body features and evolving is very inefficient in a hostile environment. I need a microhabitat.',
      onComplete: function (game, player) {
        player.evolutionManager.addImprov(IMP_MICROHABITAT);
        game.goals.receive(GOAL_EVOLVE_MICROHABITAT);
      }
    },

    GOAL_EVOLVE_MICROHABITAT => {
      id: GOAL_EVOLVE_MICROHABITAT,
      name: 'Evolve the microhabitat knowledge',
      note: 'You need to evolve the knowledge of microhabitat.',
      messageComplete: 'Now that I have the knowledge I must find a place somewhere in the sewers for a habitat.',
      onComplete: function (game, player) {
//        player.skills.addID(KNOW_HABITAT, 100);
        game.goals.receive(GOAL_CREATE_HABITAT);
      }
    },

    GOAL_CREATE_HABITAT => {
      id: GOAL_CREATE_HABITAT,
      name: 'Create a new habitat',
      note: 'You need to create a microhabitat.',
      messageComplete: 'My microhabitat is complete. It allows me some degree of calm and safety.',
      onComplete: function (game, player) {
        player.evolutionManager.addImprov(IMP_BIOMINERAL);
        game.goals.receive(GOAL_PUT_BIOMINERAL);
      }
    },

    GOAL_PUT_BIOMINERAL => {
      id: GOAL_PUT_BIOMINERAL,
      name: 'Construct biomineral formation',
      note: 'You need to evolve, grow and construct a biomineral formation. It can only be constructed in a habitat.',
      messageReceive: 'I can improve it further. But I will need energy for that.',
      messageComplete: 'Ah, yes. I can feel the energy surge. A little more and I can begin the assimilation process.',
      onComplete: function (game, player) {
        player.evolutionManager.addImprov(IMP_ASSIMILATION);
        game.goals.receive(GOAL_PUT_ASSIMILATION);
        // add watcher goal if group is known
        if (game.group.isKnown)
          game.goals.receive(GOAL_PUT_WATCHER);
      }
    },

    GOAL_PUT_ASSIMILATION => {
      id: GOAL_PUT_ASSIMILATION,
      name: 'Construct assimilation cavity',
      note: 'You need to evolve, grow and construct the assimilation cavity. You can only construct it in a habitat.',
      messageComplete: 'Finally. I can begin the host assimilation process.',
    },

    // continued after player learns about the group
    GOAL_PUT_WATCHER => {
      id: GOAL_PUT_WATCHER,
      name: 'Construct watcher',
      note: 'You need to evolve, grow and construct the watcher. You can only construct it in a habitat.',
      messageReceive: 'They might try to ambush me in the habitat. I will need something to warn me.',
      onReceive: function (game, player) {
        player.evolutionManager.addImprov(IMP_WATCHER);
      },
    },

    // ========================= group branch (?)

    // ========================= main branch

    GOAL_PROBE_BRAIN => {
      id: GOAL_PROBE_BRAIN,
      name: 'Probe the host brain',
      note: 'You need to probe the brain of any host.',
      messageComplete: 'Some of the objects the hosts carry can be useful.',
      onComplete: function (game, player) {
        game.player.vars.inventoryEnabled = true;
        game.goals.receive(GOAL_LEARN_ITEMS);
      }
    },

    GOAL_LEARN_ITEMS => {
      id: GOAL_LEARN_ITEMS,
      name: 'Learn about any item',
      note: 'You need to learn information about any item.',
      messageComplete: 'I can learn how to use items effectively by improving the probe.',
      onComplete: function (game, player) {
        game.player.vars.skillsEnabled = true;

        // skill advanced brain probe goal
        var level = player.evolutionManager.getLevel(IMP_BRAIN_PROBE);
        if (level >= 2)
          game.goals.receive(GOAL_LEARN_SKILLS);
        else game.goals.receive(GOAL_PROBE_BRAIN_ADVANCED);
      }
    },

    GOAL_PROBE_BRAIN_ADVANCED => {
      id: GOAL_PROBE_BRAIN_ADVANCED,
      name: 'Improve the brain probe',
      note: 'Your brain probe is not advanced enough to gain information about host skills. You need to improve it.',
      messageComplete: 'My brain probe has improved significantly.',
      onComplete: function (game, player) {
        game.goals.receive(GOAL_LEARN_SKILLS);
      }
    },

    GOAL_LEARN_SKILLS => {
      id: GOAL_LEARN_SKILLS,
      name: 'Use the brain probe to learn any skill',
      note: 'Probe the host brain to learn useful skills.',
    },

    GOAL_LEARN_SOCIETY => {
      id: GOAL_LEARN_SOCIETY,
      name: 'Learn more about the human society',
      note: 'Probe host brains to raise the human society knowledge to 25%. This might require multiple hosts.',
      messageReceive: 'The humans have evolved a large and intricate society. I must study it some more.',
      messageComplete: 'What am I? What is my purpose? I must know. I remember a place vaguely. I should travel there.',
      onComplete: function (game, player) {
        player.vars.timelineEnabled = true;
        game.player.vars.objectsEnabled = true;
        game.timeline.unlock();
        game.goals.receive(GOAL_ENTER_SEWERS);
      }
    },

    GOAL_ENTER_SEWERS => {
      id: GOAL_ENTER_SEWERS,
      name: 'Enter the sewers',
      note: 'Find a sewers hatch and enter the sewers.',
      onComplete: function (game, player) {
        game.goals.receive(GOAL_TRAVEL_EVENT);
      }
    },

    GOAL_TRAVEL_EVENT => {
      id: GOAL_TRAVEL_EVENT,
      name: 'Travel to the location you remember',
      note: 'Find the location you remember on region map and travel there.',
      messageComplete: 'I found the location. There should be some clues here.',
      onComplete: function (game, player) {
        game.goals.receive(GOAL_LEARN_CLUE);
        }
      },

    GOAL_LEARN_CLUE => {
      id: GOAL_LEARN_CLUE,
      name: 'Find a clue',
      note: 'Find any clue about the events that happened in this location',
      messageComplete: 'The chain of events that led to my current state is long. There were many humans involved.',
      onComplete: function (game, player) {
        player.vars.npcEnabled = true;
        game.goals.receive(GOAL_LEARN_NPC);

        // choose difficulty
        game.scene.event({
          state: UISTATE_DIFFICULTY,
          obj: 'timeline'
        });
        }
      },

    GOAL_LEARN_NPC => {
      id: GOAL_LEARN_NPC,
      name: 'Learn a clue about any human',
      note: 'Find a clue about any event participant.',
      messageComplete: 'I can investigate the involved humans further by using their computational devices.',
      onComplete: function (game, player) {
        player.vars.searchEnabled = true;
        game.goals.receive(GOAL_USE_COMPUTER);
        }
      },

    GOAL_USE_COMPUTER => {
      id: GOAL_USE_COMPUTER,
      name: 'Use a computer',
      note: 'Find a laptop or a smartphone and use it successfully. You can only do that in a habitat.',
      messageComplete: 'I will learn what happened to me.',
      },
/*

     => {
      id: ,
      name: '',
      note: '',
      messageReceive: '',
      messageComplete: '',
      onComplete: function (game, player) {
        game.goals.receive();
        }
      },
*/
    ];
}


typedef GoalInfo = {
  id: _Goal, // goal id
  ?isHidden: Bool, // is this goal hidden?
  ?isStarting: Bool, // goal received on game start?
  name: String, // goal name
  note: String, // goal note (static part)
  ?note2: String, // additional goal note (dynamic part, changed ingame)

  ?messageReceive: String, // message on receiving goal
  ?messageComplete: String, // message on goal completion
  ?messageFailure: String, // message on goal failure

  ?onTurn: Game -> Player -> Void, // func to call each turn while this goal is active
  ?onReceive: Game -> Player -> Void, // func to call on receive
  ?onComplete: Game -> Player -> Void, // func to call on completion
  ?onFailure: Game -> Player -> Void, // func to call on failure
}
