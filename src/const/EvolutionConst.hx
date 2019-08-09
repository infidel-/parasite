// evolution constants

package const;

import game.Game;
import game.Habitat;
import game.Player;
import objects.*;

class EvolutionConst
{
  // major evolution paths
  public static var paths: Array<PathInfo> =
    [
      { id: PATH_PROTECTION, name: 'Protection' },
      { id: PATH_CONTROL, name: 'Control' },
      { id: PATH_ATTACK, name: 'Attack' },
      { id: PATH_CONCEAL, name: 'Concealment' },
      { id: PATH_SPECIAL, name: 'Special' },
    ];


  // improvement info
  public static var improvements: Array<ImprovInfo> =
    [
      // =============== ************ CONCEAL *************** ===================
/*
      { // ***
        path: PATH_CONCEAL,
        id: IMP_HOST_RELEASE,
        name: '[TODO] Host release process',
        note: 'Controls what happens to the host when parasite leaves',
        levelNotes: [
          'Host dies with its brain melting and dripping out of its ears',
          'Host becomes crazy [TODO]',
          'Host is left intact - alive and conscious with all memory wiped [TODO]',
          'Host is left alive and conscious, and is implanted with fake memories [TODO]',
          ],
        levelParams: []
      },
*/
      { // ***
        path: PATH_CONCEAL,
        id: IMP_DECAY_ACCEL,
        name: 'Decay acceleration',
        note: 'Body feature. Special bacteria and enzymes accelerate autolysis and putrefaction allowing significantly more efficient tissue decomposition of the host body after death',
        maxLevel: 3,
        noteFunc: function (l: Dynamic)
          {
            return "Bodies will disappear in " + l.turns + " turns";
          },
        organ: {
          name: 'Decay accelerant cysts',
          note: 'Cysts of special bacteria and enzymes spread throughout the body to accelerate its decay after death',
          gp: 75
          },
        levelNotes: [
          'Only natural decomposition occurs',
          'Host body takes a lot of time to decompose',
          'Host body takes some time to decompose',
          'Host body takes a little time to decompose',
          ],
        levelParams: [
          { turns: 1000 },
          { turns: 10 },
          { turns: 5 },
          { turns: 2 },
          ],
      },

      // =============== ************ PROTECTION *************** ===================

      { // ***
        path: PATH_PROTECTION,
        id: IMP_PROT_COVER,
        name: 'Protective cover',
        note: 'Body feature. Heavy epidermis keratinization and dermis densification later allows for an armor-like body cover on the host with the downside of significantly altered host appearance',
        maxLevel: 3,
        noteFunc: function (l: Dynamic)
          {
            return "Host armor bonus (minus to damage): " + l.armor + "<br/>" +
              "AI alertness bonus: " + l.alertness;
          },
        organ: {
          name: 'Protective cover',
          note: 'Armor-like host body cover providing protection against damage at the expense of appearance',
          gp: 120
          },
        levelNotes: [
          'Normal host skin',
          'Pigmented skin layer looks grayish to the eye',
          'Collagen fibres running through the dermis layer',
          'Heavily keratinized and densified skin provides the body with an effective armor',
          ],
        levelParams: [
          { armor: 0, alertness: 0 },
          { armor: 1, alertness: 1 },
          { armor: 2, alertness: 5 },
          { armor: 3, alertness: 10 },
          ],
      },

      { // ***
        path: PATH_PROTECTION,
        id: IMP_WOUND_REGEN,
        name: 'Stem cell reservoirs',
        note: 'Body feature. Microreservoirs of adult stem cells form in many tissues of the host body greatly increasing the efficacy and speed of wound healing process',
        maxLevel: 3,
        noteFunc: function (l: Dynamic)
          {
            return l.turns + " turns to restore 1 health of host and parasite";
          },
        organ: {
          name: 'Stem cell reservoirs',
          note: 'Microreservoirs of adult stem cells that increase wound recovery speed',
          gp: 100
          },
        levelNotes: [
          'Normal wound recovery',
          'Wound recovery speed is slightly increased',
          'Wound recovery speed is moderately increased',
          'Wound recovery speed is greatly increased',
          ],
        levelParams: [
          { turns: 100 },
          { turns: 20 },
          { turns: 10 },
          { turns: 5 },
          ],
      },

      { // ***
        path: PATH_PROTECTION,
        id: IMP_HEALTH,
        name: 'Antibody generators',
        note: 'Body feature. Direct synthesis of antibodies through specialized biofactories increases the responce speed of adaptive immune system adding to overall host health',
        maxLevel: 3,
        noteFunc: function (l: Dynamic)
          {
            return "+" + l.health + " health to host";
          },
        organ: {
          name: 'Antibody generators',
          note: 'Specialized producers of antibodies that increase overall host health',
          gp: 80
          },
        levelNotes: [
          'Normal health',
          'Health is slightly increased',
          'Health is moderately increased',
          'Health is greatly increased',
          ],
        levelParams: [
          { health: 0 },
          { health: 1 },
          { health: 2 },
          { health: 3 },
          ],
      },

      { // ***
        path: PATH_PROTECTION,
        id: IMP_ENERGY,
        name: '??Host energy bonus',
        note: 'Body feature. Grown body feature gives a bonus to maximum host energy',
        maxLevel: 3,
        noteFunc: function (l: Dynamic)
          {
            return "Host maximum energy multiplier: " + l.hostEnergyMod +
              "<br/>Restores energy to maximum on completion";
          },
        organ: {
          name: '??Host energy bonus',
          note: 'Gives a bonus to maximum host energy',
          gp: 180
          },
        levelNotes: [
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          ],
        levelParams: [
          { hostEnergyMod: 1.0 },
          { hostEnergyMod: 1.25 },
          { hostEnergyMod: 1.50 },
          { hostEnergyMod: 2.0 },
          ],
      },

      // =============== ************ ATTACK *************** ===================

      { // ***
        path: PATH_ATTACK,
        id: IMP_MUSCLE,
        name: 'Microvascular networks',
        note: 'Body feature. Neovascularization within muscles enhances the ability to move waste products out and maintain contraction reducing the accumulated metabolic fatigue which results in increased host strength',
        maxLevel: 3,
        noteFunc: function (l: Dynamic)
          {
            return "+" + l.strength + " strength to host";
          },
        organ: {
          name: 'Microvascular networks',
          note: 'Functional miscrovascular networks throughout the muscle tissue enhance host body strength',
          gp: 120
          },
        levelNotes: [
          'Normal host strength',
          'Basic muscle neovascularization',
          'Enhanced muscle neovascularization',
          'Improved neovascularization with additional substrate storage',
          ],
        levelParams: [
          { strength: 0 },
          { strength: 1 },
          { strength: 2 },
          { strength: 3 },
          ],
      },

      { // ***
        path: PATH_ATTACK,
        id: IMP_ACID_SPIT,
        name: '??Acid spit',
        note: 'Body feature. Grown body feature gives the host an ability to spit acid on an NPC',
        maxLevel: 3,
        noteFunc: function (l: Dynamic)
          {
            return "Spit damage: " + l.minDamage + "-" + l.maxDamage +
              "<br/>Spit range: " + l.range;
          },
        organ: {
          name: '??Acid spit',
          note: 'Gives the host an ability to spit acid on an NPC',
          gp: 150,
          action: {
            id: 'acidSpit',
            type: ACTION_ORGAN,
            name: '??Acid spit',
            energy: 10
            },
          },
        levelNotes: [
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          ],
        levelParams: [
          {
            minDamage: 0,
            maxDamage: 0,
            range: 0
          },
          {
            minDamage: 1,
            maxDamage: 2,
            range: 1
          },
          {
            minDamage: 1,
            maxDamage: 3,
            range: 2
          },
          {
            minDamage: 1,
            maxDamage: 4,
            range: 3
          },
          ],
      },

      { // ***
        path: PATH_ATTACK,
        id: IMP_SLIME_SPIT,
        name: '??Slime spit',
        note: 'Body feature. Grown body feature gives the host an ability to spit slime on an NPC to slow them down',
        maxLevel: 3,
        noteFunc: function (l: Dynamic)
          {
            return "Slime strength: " + l.strength +
              "<br/>Spit range: " + l.range;
          },
        organ: {
          name: '??Slime spit',
          note: 'Gives the host an ability to spit slime on an NPC to slow them down',
          gp: 100,
          action: {
            id: 'slimeSpit',
            type: ACTION_ORGAN,
            name: '??Slime spit',
            energy: 10
            },
          },
        levelNotes: [
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          ],
        levelParams: [
          {
            strength: 0,
            range: 0
          },
          {
            strength: 10,
            range: 1
          },
          {
            strength: 20,
            range: 2
          },
          {
            strength: 30,
            range: 3
          },
          ],
      },

      { // ***
        path: PATH_ATTACK,
        id: IMP_PARALYSIS_SPIT,
        name: '??Paralysis spit',
        note: 'Body feature. Grown body feature gives the host an ability to paralyze an NPC',
        maxLevel: 3,
        noteFunc: function (l: Dynamic)
          {
            return "Paralysis effect time: " + l.time +
              "<br/>Spit range: " + l.range;
          },
        organ: {
          name: '??Paralysis spit',
          note: 'Gives the host an ability to paralyze an NPC',
          gp: 100,
          action: {
            id: 'paralysisSpit',
            type: ACTION_ORGAN,
            name: '??Paralysis spit',
            energy: 5
            },
          },
        levelNotes: [
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          ],
        levelParams: [
          {
            time: 0,
            range: 0
          },
          {
            time: 3,
            range: 1
          },
          {
            time: 4,
            range: 2
          },
          {
            time: 5,
            range: 3
          },
          ],
      },

      { // ***
        path: PATH_ATTACK,
        id: IMP_PANIC_GAS,
        name: '??Panic gas',
        note: 'Body feature. Grown body feature gives the host an ability to emit a cloud of panic gas that will make NPCs run away',
        maxLevel: 3,
        noteFunc: function (l: Dynamic)
          {
            return "Cloud range: " + l.range +
              "<br/>Cloud dissipation time: " + l.timeout +
              "<br/>Panic effect time: " + l.time;
          },
        organ: {
          name: '??Panic gas',
          note: 'Gives the host an ability to emit a cloud of panic gas that will make NPCs run away',
          gp: 150,
          hasTimeout: true,
          action: {
            id: 'panicGas',
            type: ACTION_ORGAN,
            name: '??Panic gas',
            energy: 10
            },
          },
        levelNotes: [
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          ],
        levelParams: [
          {
            range: 0,
            timeout: 0,
            time: 0
          },
          {
            range: 2,
            timeout: 20,
            time: 3
          },
          {
            range: 3,
            timeout: 10,
            time: 5
          },
          {
            range: 4,
            timeout: 5,
            time: 10
          },
          ],
      },

      { // ***
        path: PATH_ATTACK,
        id: IMP_PARALYSIS_GAS,
        name: '??Paralysis gas',
        note: 'Body feature. Grown body feature gives the host an ability to emit a cloud of paralytic gas',
        maxLevel: 3,
        noteFunc: function (l: Dynamic)
          {
            return "Cloud range: " + l.range +
              "<br/>Cloud dissipation time: " + l.timeout +
              "<br/>Paralysis effect time: " + l.time;
          },
        organ: {
          name: '??Paralysis gas',
          note: 'Gives the host an ability to emit a cloud of paralytic gas',
          gp: 180,
          hasTimeout: true,
          action: {
            id: 'paralysisGas',
            type: ACTION_ORGAN,
            name: '??Paralysis gas',
            energy: 12
            },
          },
        levelNotes: [
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          ],
        levelParams: [
          {
            range: 0,
            timeout: 0,
            time: 0
          },
          {
            range: 2,
            timeout: 20,
            time: 3
          },
          {
            range: 3,
            timeout: 10,
            time: 5
          },
          {
            range: 4,
            timeout: 5,
            time: 10
          },
          ],
      },


      // =============== ************ CONTROL *************** ===================

      { // ***
        path: PATH_CONTROL,
        id: IMP_ATTACH,
        name: '??Attach efficiency',
        note: 'Knowledge. Improves base grip on attach to host',
        maxLevel: 3,
        noteFunc: function (l: Dynamic)
          {
            return "Base attach grip: " + l.attachHoldBase;
          },
        levelNotes: [
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          ],
        levelParams: [
          { attachHoldBase: 10 },
          { attachHoldBase: 15 },
          { attachHoldBase: 20 },
          { attachHoldBase: 25 },
          ],
      },

      { // ***
        path: PATH_CONTROL,
        id: IMP_HARDEN_GRIP,
        name: '??Hold efficiency',
        note: 'Knowledge. Improves base grip on harden grip action',
        maxLevel: 3,
        noteFunc: function (l: Dynamic)
          {
            return "Base harden grip: " + l.attachHoldBase;
          },
        levelNotes: [
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          ],
        levelParams: [
          { attachHoldBase: 20 },
          { attachHoldBase: 25 },
          { attachHoldBase: 30 },
          { attachHoldBase: 35 },
          ],
      },

      { // ***
        path: PATH_CONTROL,
        id: IMP_REINFORCE,
        name: '??Control efficiency',
        note: 'Knowledge. Improves base control on reinforce control action',
        maxLevel: 3,
        noteFunc: function (l: Dynamic)
          {
            return "Base reinforce control: " + l.reinforceControlBase;
          },
        levelNotes: [
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          ],
        levelParams: [
          { reinforceControlBase: 20 },
          { reinforceControlBase: 25 },
          { reinforceControlBase: 30 },
          { reinforceControlBase: 35 },
          ],
      },


      // =============== ************ SPECIAL *************** ===================
      // improvements from this direction should only appear as a result of a goal progression

      { // ***
        path: PATH_SPECIAL,
        id: IMP_BRAIN_PROBE,
        name: 'Brain probe',
        note: 'Knowledge. Allows probing host brain to learn its contents',
        maxLevel: 3,
        noteFunc: function (l: Dynamic)
          {
            return "Human society knowledge multiplier: " + l.humanSociety +
              "<br/>Base host energy cost: " + l.hostEnergyBase +
              "<br/>Base host health cost: " + l.hostHealthBase +
              "<br/>Host skills learning multiplier: " + l.hostSkillsMod +
              (l.hostAttrsMod == 1 ? "<br/>Probe shows host attributes" : "");
          },
        levelNotes: [
          'Cannot probe host brain',
          'Access with severe problems (basic knowledge)',
          'Limited access with some problems (extensive knowledge and basic skills)',
          'Full access',
          ],
        levelParams: [
          {
            humanSociety: 0,
            hostEnergyBase: 0,
            hostHealthBase: 0,
            hostHealthMod: 0,
            hostSkillsMod: 0,
            hostAttrsMod: 0,
          },
          {
            humanSociety: 0.25,
            hostEnergyBase: 20,
            hostHealthBase: 3,
            hostHealthMod: 2,
            hostSkillsMod: 0,
            hostAttrsMod: 0,
          },
          {
            humanSociety: 0.5,
            hostEnergyBase: 10,
            hostHealthBase: 1,
            hostHealthMod: 1,
            hostSkillsMod: 0.5, // can access skills from level 2
            hostAttrsMod: 0,
          },
          {
            humanSociety: 1.0,
            hostEnergyBase: 5,
            hostHealthBase: 0,
            hostHealthMod: 1,
            hostSkillsMod: 0.75,
            hostAttrsMod: 1, // can access attributes and traits from level 3
          },
          ],
        action: {
          id: 'probeBrain',
          type: ACTION_AREA,
          name: 'Probe Brain',
          energyFunc: function (player)
            {
              if (player.host == null)
                return -1;
              var level = player.evolutionManager.getLevel(IMP_BRAIN_PROBE);
              if (level == 0)
                return -1;
              var params = player.evolutionManager.getParams(IMP_BRAIN_PROBE);
              return params.hostEnergyBase + player.host.psyche;
            },
          },
        onUpgrade: function (level, game, player)
          {
            // complete goals
            if (level == 1)
              game.goals.complete(GOAL_EVOLVE_PROBE);

            else if (level == 2)
              game.goals.complete(GOAL_PROBE_BRAIN_ADVANCED);
          },
      },

      { // ***
        path: PATH_SPECIAL,
        id: IMP_CAMO_LAYER,
        name: 'Camouflage layer',
        note: 'Body feature. Allows the covering of parasite body with a self-regenerating camouflage layer that looks like host skin and clothing',
        maxLevel: 3,
        noteFunc: function (l: Dynamic)
          {
            return "AI alertness multiplier: " + l.alertness;
          },
        organ: {
          name: 'Camouflage layer',
          note: 'Self-regenerating camouflage layer that covers parasite body changing its appearance',
          gp: 100,
          onGrow: function(game, player)
            {
              // complete goals
              game.goals.complete(GOAL_GROW_CAMO);
            }
          },
        levelNotes: [
          'A perfectly visible huge purple blob on head and upper body of the host',
          'Streaks of purple running through the partly grown camouflage layer',
          'Parasite body is mostly covered by camouflage layer',
          'Camouflage layer fully covers the parasite. Only close inspection will alert bystanders',
          ],
        levelParams: [
          { alertness: 3 },
          { alertness: 2 },
          { alertness: 1 },
          { alertness: 0.5 },
          ],
        onUpgrade: function(level, game, player)
          {
            // complete goals
            if (level == 1)
              game.goals.complete(GOAL_EVOLVE_CAMO);
          }
      },

      { // ***
        path: PATH_SPECIAL,
        id: IMP_DOPAMINE,
        name: 'Dopamine regulation',
        note: 'Knowledge. Removes the need to reinforce control of the host.',
        maxLevel: 1,
        levelNotes: [
          '(fluff)',
          '(fluff)',
          '(fluff)',
          '(fluff)',
          ],
        levelParams: [
          {},
          {},
          {},
          {},
          ],
        onUpgrade: function(level, game, player)
          {
            // complete goals
            if (level == 1)
              game.goals.complete(GOAL_EVOLVE_DOPAMINE);
          }
      },

      { // ***
        path: PATH_SPECIAL,
        id: IMP_MICROHABITAT,
        name: 'Microhabitat',
        note: 'Knowledge. Gives the player an ability to build microhabitats.',
        maxLevel: 3,
        noteFunc: function (l: Dynamic)
          {
            return "Maximum number of microhabitats: " + l.numHabitats;
          },
        levelNotes: [
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          ],
        levelParams: [
          {
            numHabitats: 0,
          },
          {
            numHabitats: 1,
          },
          {
            numHabitats: 2,
          },
          {
            numHabitats: 4,
          },
          ],
        onUpgrade: function(level, game, player)
          {
            // complete goals
            if (level == 1)
              game.goals.complete(GOAL_EVOLVE_MICROHABITAT);
          }
      },

      { // ***
        path: PATH_SPECIAL,
        id: IMP_BIOMINERAL,
        name: 'Biomineral formation',
        note: 'Habitat growth. Gives the player an ability to supply microhabitat with energy. Unused biomineral energy increases the speed of organ growth and evolution, slowly restores the health and energy of the parasite, plus the energy of assimilated hosts.',
        maxLevel: 3,
        noteFunc: function (l: Dynamic)
          {
            return
              "Energy units per formation: " + l.energy +
              "<br/>Bonus organ and evolution points per turn: +" +
                l.evolutionBonus + "%" +
              "<br/>Assimilated host energy restored per turn: +" + l.hostEnergyRestored +
              "<br/>Parasite energy restored per turn: +" +
                l.parasiteEnergyRestored +
              "<br/>Parasite health restored per turn: +" +
                l.parasiteHealthRestored;
          },
        levelNotes: [
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          ],
        organ: {
          name: 'Biomineral mold',
          note: 'Mold for a biomineral formation. You can only grow that in a habitat. Host and its inventory will be destroyed!',
          gp: 150,
          isMold: true,
          action: {
            id: 'formBiomineral',
            type: ACTION_ORGAN,
            name: 'Produce biomineral formation',
            energy: 0
            },
          onAction: function(game, player)
            {
              // only in habitat
              if (!game.area.isHabitat)
                {
                  game.log('This action only works in habitat.', COLOR_HINT);
                  return false;
                }

              return game.area.habitat.putObject(IMP_BIOMINERAL);
            }
          },
/*
  evolution cost:
  base 10pt/turn + 10/20/25 from biomineral
  public static var epCostImprovement = [ 100, 200, 500 ];
  biomineral level 0 (10/t)- 10, 20, 50 turns
  biomineral level 1 (20/t) - 5, 10, 25 turns
  biomineral level 2 (30/t) - 3, 7, 17 turns
  biomineral level 3 (35/t) - 3, 6, 14 turns
*/
        levelParams: [
          {
            energy: 0,
            hostEnergyRestored: 0,
            parasiteEnergyRestored: 0,
            parasiteHealthRestored: 0,
            evolutionBonus: 0,
          },
          {
            energy: 1,
            hostEnergyRestored: 5,
            parasiteEnergyRestored: 5,
            parasiteHealthRestored: 1,
            evolutionBonus: 10,
          },
          {
            energy: 2,
            hostEnergyRestored: 10,
            parasiteEnergyRestored: 10,
            parasiteHealthRestored: 2,
            evolutionBonus: 20,
          },
          {
            energy: 3,
            hostEnergyRestored: 25,
            parasiteEnergyRestored: 25,
            parasiteHealthRestored: 3,
            evolutionBonus: 25,
          },
          ],
      },

      { // ***
        path: PATH_SPECIAL,
        id: IMP_ASSIMILATION,
        name: 'Assimilation cavity',
        note: 'Habitat growth. Gives the player an ability to assimilate hosts. Assimilated hosts do not lose energy passively and regenerate it from biominerals.',
        maxLevel: 1,
        levelNotes: [
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          ],
        organ: {
          name: 'Assimilation mold',
          note: 'Mold for an assimilation cavity. You can only grow that in a habitat. Host and its inventory will be destroyed.',
          gp: 150,
          isMold: true,
          action: {
            id: 'formAssimilation',
            type: ACTION_ORGAN,
            name: 'Form assimilation cavity',
            energy: 0
            },
          onAction: function(game, player): Bool
            {
              // only in habitat
              if (!game.area.isHabitat)
                {
                  game.log('This action only works in habitat.', COLOR_HINT);
                  return false;
                }

              return game.area.habitat.putObject(IMP_ASSIMILATION);
            }
          },
        levelParams: [
          {
          },
          {
          },
          {
          },
          {
          },
        ],
      },

      { // ***
        path: PATH_SPECIAL,
        id: IMP_WATCHER,
        name: 'Watcher',
        note: 'Watcher growth. Will warn the player of the ambush in the habitat',
        maxLevel: 2,
        levelNotes: [
          'Unavailable',
          'Watcher will warn about the ambush',
          'Watcher will attract the ambush',
          '(todo fluff)',
          ],
        organ: {
          name: 'Watcher mold',
          note: 'Mold for a watcher. You can only grow that in a habitat. Host inventory will be destroyed when it becomes the watcher.',
          gp: 150,
          isMold: true,
          action: {
            id: 'formWatcher',
            type: ACTION_ORGAN,
            name: 'Form watcher',
            energy: 0
            },
          onAction: function(game, player): Bool
            {
              // only in habitat
              if (!game.area.isHabitat)
                {
                  game.log('This action only works in habitat.', COLOR_HINT);
                  return false;
                }

              return game.area.habitat.putObject(IMP_WATCHER);
            }
          },
        levelParams: [
          {
          },
          {
          },
          {
          },
          {
          },
        ],
      },
/*
      { // ***
        path: PATH_,
        id: IMP_,
        name: '',
        note: '(todo fluff)',
        maxLevel: 3,
        organ: {
          name: '',
          note: '(todo fluff)',
          gp: 100,
          hasTimeout: false,
          action: {
            id: '',
            type: ACTION_ORGAN,
            name: '',
            energy: 10
            },
          },
        levelNotes: [
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          ],
        levelParams: [
          {},
          {},
          {},
          {},
          ],
      },
*/
    ];


// ep needed to upgrade improvement to next level (index is current level)
  public static var epCostImprovement = [ 100, 200, 500, 1000 ];
// ep needed to open new improvement on path (index is current path level)
  public static var epCostPath = [ 100, 200, 500, 1000, 2000, 5000 ];


// get improvement info
  public static function getInfo(id: _Improv): ImprovInfo
    {
      for (imp in improvements)
        if (imp.id == id)
          return imp;

      throw 'No such improvement: ' + id;
      return null;
    }


// get improvement parameters of the specified level
  public static function getParams(id: _Improv, level: Int): Dynamic
    {
      for (imp in improvements)
        if (imp.id == id)
          return imp.levelParams[level];

      throw 'No such improvement: ' + id;
      return null;
    }

/*
// get improvement info by organ id
  public static function getInfoByOrganID(id: String): ImprovInfo
    {
      for (imp in improvements)
        if (imp.organ != null && imp.organ.id == id)
          return imp;

      return null;
    }
*/

// get path info
  public static function getPathInfo(id: _Path): PathInfo
    {
      for (p in paths)
        if (p.id == id)
          return p;

      throw 'No such path: ' + id;
      return null;
    }
}


typedef ImprovInfo =
{
  id: _Improv, // improvement string ID
  path: _Path, // path ID
  name: String, // improvement name
  note: String, // improvement description
  maxLevel: Int, // maximum improvement level
  ?noteFunc: Dynamic -> String, // advanced description
  ?organ: OrganInfo, // organ that can be grown
  levelNotes: Array<String>, // improvement descriptions for different levels
  levelParams: Array<Dynamic>, // improvement-specific parameters for different levels

  ?action: _PlayerAction, // added player action
  ?onUpgrade: Int -> Game -> Player -> Void, // func to call on upgrading improvement
}

typedef PathInfo =
{
  var id: _Path; // path string ID
  var name: String; // path name
}


typedef OrganInfo =
{
  name: String, // name
  note: String, // description
  gp: Int, // gp cost to grow
  ?isMold: Bool, // is this a construction mold?
  ?action: _PlayerAction, // player action
  ?hasTimeout: Bool, // has activation timeout?
  ?onGrow: Game -> Player -> Void, // func to call on growing organ
  ?onAction: Game -> Player -> Bool, // func to call on organ action
}
