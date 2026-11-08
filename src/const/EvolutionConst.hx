// evolution constants

package const;

import game.Game;
import game.Player;

class EvolutionConst
{
// ovum levels xp
  public static var ovumXP = [ 2, 5, 20, 50, 100 ];
// improvement info
  public static var improvements: Array<ImprovInfo> =
    [
      // =============== BASIC ===================
      { // ***
        type: TYPE_BASIC,
        id: IMP_DECAY_ACCEL,
        name: T('Decay acceleration'),
        note: T('Body feature. Special bacteria and enzymes accelerate autolysis and putrefaction allowing significantly more efficient tissue decomposition of the host body after death. Moreover, the decomposition produces highly nutritional residue.'),
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return T('Bodies will disappear in {turns} turns', {
            turns: l.turns + (l2 != null ? ' (&rarr; ' + l2.turns + ')' : ''),
          });
        },
        organ: {
          name: T('Decay accelerant cysts'),
          note: T('Cysts of specialized bacteria and enzymes spread throughout the body to accelerate its decay after death and transform it into a dry nutritional residue'),
          gp: 50
        },
        levelNotes: [
          T('Only natural decomposition occurs'),
          T('Host body takes a lot of time to decompose'),
          T('Host body takes some time to decompose'),
          T('Host body takes a little time to decompose'),
        ],
        levelParams: [
          { turns: 1000 },
          { turns: 10 },
          { turns: 5 },
          { turns: 2 },
        ],
      },

      { // ***
        type: TYPE_BASIC,
        id: IMP_PROT_COVER,
        name: T('Protective cover'),
        note: T('Body feature. Heavy epidermis keratinization and dermis densification later allows for an armor-like body cover on the host with the downside of significantly altered host appearance.'),
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return T('Host armor bonus (minus to damage): {armor}<br/>' +
            'AI alertness bonus: {alertness}', {
            armor: l.armor + (l2 != null ? ' &rarr; ' + l2.armor : ''),
            alertness: l.alertness + (l2 != null ? ' &rarr; ' + l2.alertness : ''),
          });
        },
        organ: {
          name: T('Protective cover'),
          note: T('Armor-like host body cover providing protection against damage at the expense of appearance'),
          gp: 120
        },
        levelNotes: [
          T('Normal host skin'),
          T('Pigmented skin layer looks grayish to the eye'),
          T('Collagen fibres running through the dermis layer'),
          T('Heavily keratinized and densified skin provides the body with an effective armor'),
        ],
        levelParams: [
          { armor: 0, alertness: 0 },
          { armor: 1, alertness: 1 },
          { armor: 2, alertness: 5 },
          { armor: 3, alertness: 10 },
        ],
      },

      { // ***
        type: TYPE_BASIC,
        id: IMP_WOUND_REGEN,
        name: T('Stem cell reservoirs'),
        note: T('Body feature. Microreservoirs of adult stem cells form in many tissues of the host body greatly increasing the efficacy and speed of wound healing process.'),
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return T('{turns} turns to restore 1 health of host and parasite', {
            turns: l.turns + (l2 != null ? ' (&rarr; ' + l2.turns + ')' : ''),
          });
        },
        organ: {
          name: T('Stem cell reservoirs'),
          note: T('Microreservoirs of adult stem cells that increase wound recovery speed'),
          gp: 100
        },
        levelNotes: [
          T('Normal wound recovery'),
          T('Wound recovery speed is slightly increased'),
          T('Wound recovery speed is moderately increased'),
          T('Wound recovery speed is greatly increased'),
        ],
        levelParams: [
          { turns: 100 },
          { turns: 20 },
          { turns: 10 },
          { turns: 5 },
        ],
      },

      { // ***
        type: TYPE_BASIC,
        id: IMP_HEALTH,
        name: T('Antibody generators'),
        note: T('Body feature. Direct synthesis of antibodies through specialized biofactories increases the responce speed of adaptive immune system adding to overall host health.'),
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return T('+{health} health to host', {
            health: l.health + (l2 != null ? ' (&rarr; ' + l2.health + ')' : ''),
          });
        },
        organ: {
          name: T('Antibody generators'),
          note: T('Specialized producers of antibodies that increase overall host health'),
          gp: 80
        },
        levelNotes: [
          T('Normal health'),
          T('Health is slightly increased'),
          T('Health is moderately increased'),
          T('Health is greatly increased'),
        ],
        levelParams: [
          { health: 0 },
          { health: 2 },
          { health: 3 },
          { health: 4 },
        ],
      },

      { // ***
        type: TYPE_BASIC,
        id: IMP_ENERGY,
        name: T('Adipose tissue layer'),
        note: T('Body feature. Modifications to metabolism allow for adipose tissue outgrowths on the host body for storing energy surplus.'),
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return T('Host maximum energy multiplier: {mod}<br/>' +
            'Restores energy to maximum on completion', {
            mod: l.hostEnergyMod + (l2 != null ? ' &rarr; ' + l2.hostEnergyMod : ''),
          });
        },
        organ: {
          name: T('Adipose tissue layer'),
          note: T('Additional layer of adipose tissue allows for having energy surplus'),
          gp: 180
        },
        levelNotes: [
          T('Normal host subcutaneous tissue'),
          T('Increased adipose tissue in abdominal area'),
          T('Clusters of adipose tissue on the body'),
          T('Enormous protrusions of adipose tissue'),
        ],
        levelParams: [
          { hostEnergyMod: 1.0 },
          { hostEnergyMod: 1.25 },
          { hostEnergyMod: 1.50 },
          { hostEnergyMod: 2.0 },
        ],
      },

      { // ***
        type: TYPE_BASIC,
        id: IMP_MUSCLE,
        name: T('Microvascular networks'),
        note: T('Body feature. Neovascularization within muscles enhances the ability to move waste products out and maintain contraction reducing the accumulated metabolic fatigue which results in increased host strength.'),
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return T('+{strength} strength to host', {
            strength: l.strength + (l2 != null ? ' (&rarr; ' + l2.strength + ')' : ''),
          });
        },
        organ: {
          name: T('Microvascular networks'),
          note: T('Functional miscrovascular networks throughout the muscle tissue enhance host body strength'),
          gp: 120
        },
        levelNotes: [
          T('Normal host strength'),
          T('Basic muscle neovascularization'),
          T('Enhanced muscle neovascularization'),
          T('Improved neovascularization with additional substrate storage'),
        ],
        levelParams: [
          { strength: 0 },
          { strength: 2 },
          { strength: 3 },
          { strength: 4 },
        ],
      },

      { // ***
        type: TYPE_BASIC,
        id: IMP_ACID_SPIT,
        name: T('Gastric hypersecretion'),
        note: T('Body feature. Recalibration of gastric glands results in increased potency and volume of produced acid, allowing the host to forcibly eject it as a sort of weapon.'),
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return T('Emesis damage: {damage}<br/>Emesis range: {range}', {
            damage: l.minDamage + '-' + l.maxDamage +
              (l2 != null ? ' &rarr; ' + l2.minDamage + '-' + l2.maxDamage : ''),
            range: l.range + (l2 != null ? ' &rarr; ' + l2.range : ''),
          });
        },
        organ: {
          name: T('Improved gastric glands'),
          note: T('Recalibrated gastric glands secrete enormous amounts of acid for hyperemesis attack'),
          gp: 150,
          action: {
            id: 'acidSpit',
            type: ACTION_ORGAN,
            name: T('Emesis'),
            energy: 5
          },
        },
        levelNotes: [
          T('Normal host gastric glands'),
          T('Enlarged gastric glands'),
          T('Improved gastric glands with specialized abdominal muscles'),
          T('Highly-effective gastric glands with additional abdominal and neck muscles'),
        ],
        levelParams: [
          {
            minDamage: 0,
            maxDamage: 0,
            range: 0
          },
          {
            minDamage: 1,
            maxDamage: 6,
            range: 1
          },
          {
            minDamage: 1,
            maxDamage: 8,
            range: 2
          },
          {
            minDamage: 1,
            maxDamage: 10,
            range: 3
          },
        ],
      },

      { // ***
        type: TYPE_BASIC,
        id: IMP_SLIME_SPIT,
        name: T('Mucilaginous fluid'),
        note: T('Body feature. Restructuring of salivary glands and surrounding buccal cavity. Mucosal fluid secreted in open air exhibits highly adhesive properties of mucilage produced by some plants and will force the opponent to stop.'),
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return T('Mucus strength: {strength}<br/>Discharge range: {range}', {
            strength: l.strength + (l2 != null ? ' &rarr; ' + l2.strength : ''),
            range: l.range + (l2 != null ? ' &rarr; ' + l2.range : ''),
          });
        },
        organ: {
          name: T('Salivary gland extension'),
          note: T('Enhanced salivary glands produce viscous mucosal fluid useful for slowing opponents down'),
          gp: 100,
          action: {
            id: 'slimeSpit',
            type: ACTION_ORGAN,
            name: T('Salivate'),
            energy: 5
          },
        },
        levelNotes: [
          T('Normal host salivary glands'),
          T('Enlarged salivary glands and buccal cavity'),
          T('Expanded salivary glands and further widened buccal cavity'),
          T('Expanded salivary glands, enormous buccal cavity and enhanced cheek muscles'),
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
        type: TYPE_BASIC,
        id: IMP_PARALYSIS_SPIT,
        name: T('Neurotoxin projectiles'),
        note: T('Body feature. Hard needle-like missiles containing potent paralyzing neurotoxin can be shot with precision from a specialized organ resembling a segmented tail. The toxin can potentially be lethal.'),
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return T('Paralysis effect time: {time}<br/>Needle range: {range}', {
            time: l.time + (l2 != null ? ' &rarr; ' + l2.time : ''),
            range: l.range + (l2 != null ? ' &rarr; ' + l2.range : ''),
          });
        },
        organ: {
          name: T('Neurotoxin cirrus'),
          note: T('The cirrus shoots paralyzing needles into the opponents that can sometimes be lethal'),
          gp: 100,
          action: {
            id: 'paralysisSpit',
            type: ACTION_ORGAN,
            name: T('Needle'),
            energy: 5
          },
        },
        levelNotes: [
          T('No modications'),
          T('Small cirrus and weak neurotoxin resulting in limited effectiveness'),
          T('Strengthened cirrus and more potent neurotoxin'),
          T('Highly enhanced cirrus and strong neurotoxin'),
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
        type: TYPE_BASIC,
        id: IMP_PANIC_GAS,
        name: T('Hallucinogen gas'),
        note: T('Body feature. Host stomach is increased in size and separated into two sections, with one reserved for synthesis and storage of compressed hallucinogen gas that can be released into air if necessary. When inhaled by the opponents, the gas results in fear and anxiety.'),
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return T('Cloud range: {range}<br/>Gas release timeout: {timeout}<br/>' +
            'Panic effect time: {time}', {
            range: l.range + (l2 != null ? ' &rarr; ' + l2.range : ''),
            timeout: l.timeout + (l2 != null ? ' &rarr; ' + l2.timeout : ''),
            time: l.time + (l2 != null ? ' &rarr; ' + l2.time : ''),
          });
        },
        organ: {
          name: T('Gas section'),
          note: T('Hallucinogenic gas section synthesizes and stores the gas. Releasing it causes the opponents in range to panic and run away'),
          gp: 150,
          hasTimeout: true,
          action: {
            id: 'panicGas',
            type: ACTION_ORGAN,
            name: T('Release gas'),
            energy: 10
          },
        },
        levelNotes: [
          T('No modications'),
          T('Small gas section with low effective radius and strength'),
          T('Moderate gas section with increased effective radius and strength'),
          T('Large gas section with high effective radius and strength'),
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
        type: TYPE_BASIC,
        id: IMP_PARALYSIS_GAS,
        name: T('Ballistospores'),
        note: T('Body feature. Clusters of sporangiums designed to produce multitudes of fungal-like ballistospores in the surrounding air. When inhaled by the hosts, the ballistospores act as a mild neurotoxin paralyzing them temporarily.'),
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return T('Cloud range: {range}<br/>Gas release timeout: {timeout}<br/>' +
            'Paralysis effect time: {time}', {
            range: l.range + (l2 != null ? ' &rarr; ' + l2.range : ''),
            timeout: l.timeout + (l2 != null ? ' &rarr; ' + l2.timeout : ''),
            time: l.time + (l2 != null ? ' &rarr; ' + l2.time : ''),
          });
        },
        organ: {
          name: T('Sporangium'),
          note: T('Releases a cloud of ballistospores which paralyze the opponents for a limited amount of time'),
          gp: 180,
          hasTimeout: true,
          action: {
            id: 'paralysisGas',
            type: ACTION_ORGAN,
            name: T('Emit spores'),
            energy: 12
          },
        },
        levelNotes: [
          T('No modications'),
          T('Low amount of emitter organs with limited range and repeatability'),
          T('Medium amount of emitters with increased range and time between emissions'),
          T('High amount of efficient emitters that have a wider range. Spores have faster effect'),
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
        type: TYPE_BASIC,
        id: IMP_ATTACH,
        name: T('Sudden leap'),
        note: T('Knowledge. Lulling the host into a false sense of security then making a sudden unexpected jump at key moment allows the parasite to gain initial advantage when attaching to it.'),
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return T('Base attach grip: {grip}', {
            grip: l.attachHoldBase + (l2 != null ? ' &rarr; ' + l2.attachHoldBase : ''),
          });
        },
        levelNotes: [
          T('Natural attaching method'),
          T('Small gains in grip'),
          T('Medium gains due to well-researched procedure'),
          T('The initial attach action is fast and precise'),
        ],
        levelParams: [
          { attachHoldBase: 10 },
          { attachHoldBase: 15 },
          { attachHoldBase: 20 },
          { attachHoldBase: 25 },
        ],
      },

      { // ***
        type: TYPE_BASIC,
        id: IMP_HARDEN_GRIP,
        name: T('Constriction'),
        note: T('Knowledge. Advanced constriction technique allows you to rapidly subdue the host before the invasion process.'),
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return T('Base harden grip: {grip}', {
            grip: l.attachHoldBase + (l2 != null ? ' &rarr; ' + l2.attachHoldBase : ''),
          });
        },
        levelNotes: [
          T('Natural grip hardening process'),
          T('Minor constriction bonus to the grip'),
          T('Significant bonus to the grip'),
          T('Superb constriction bonus'),
        ],
        levelParams: [
          { attachHoldBase: 20 },
          { attachHoldBase: 25 },
          { attachHoldBase: 30 },
          { attachHoldBase: 35 },
        ],
      },

      { // ***
        type: TYPE_BASIC,
        id: IMP_REINFORCE,
        name: T('Regulated neurotransmission'),
        note: T('Knowledge. Correctly timing the neurotransmitters release allows the parasite to more efficiently control and override the actions of the host.'),
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return T('Base reinforce control: {control}', {
            control: l.reinforceControlBase + (l2 != null ? ' &rarr; ' + l2.reinforceControlBase : ''),
          });
        },
        levelNotes: [
          T('Natural control reinforcing process'),
          T('Increased control reinforcing mechanism'),
          T('Improved control reinforcement'),
          T('Efficient control reinfocement'),
        ],
        levelParams: [
          { reinforceControlBase: 20 },
          { reinforceControlBase: 25 },
          { reinforceControlBase: 30 },
          { reinforceControlBase: 35 },
        ],
      },

      // =============== SPECIAL ===================
      // improvements of this type should only appear as a result of a goal progression

      { // ***
        type: TYPE_SPECIAL,
        id: IMP_BRAIN_PROBE,
        name: T('Brain probe'),
        note: T('Knowledge. Temporarily joining with the host consciousness allows to partially learn its contents.'),
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          var s = T('Human society knowledge multiplier: {society}<br/>' +
            'Base host energy cost: {energy}<br/>' +
            'Base host health cost: {health}<br/>' +
            'Host skills learning multiplier: {skills}', {
            society: l.humanSociety + (l2 != null ? ' &rarr; ' + l2.humanSociety : ''),
            energy: l.hostEnergyBase + (l2 != null ? ' &rarr; ' + l2.hostEnergyBase : ''),
            health: l.hostHealthBase + (l2 != null ? ' &rarr; ' + l2.hostHealthBase : ''),
            skills: l.hostSkillsMod + (l2 != null ? ' &rarr; ' + l2.hostSkillsMod : ''),
          }) + '<br/>';
          if (l.hostAttrsMod == 0)
            s += T('Host attributes unknown') + ' ';
          if (l2 != null && l2.hostAttrsMod == 1)
            s += '&rarr; ' + T('Probe shows host attributes');
          else if (l.hostAttrsMod == 1)
            s += T('Probe shows host attributes');
          return s;
        },
        levelNotes: [
          T('Cannot probe host brain'),
          T('Access with severe problems (basic knowledge)'),
          T('Limited access with some problems (extensive knowledge and basic skills)'),
          T('Full access'),
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
            humanSociety: 0.5,
            hostEnergyBase: 20,
            hostHealthBase: 2,
            hostHealthMod: 1,
            hostSkillsMod: 0,
            hostAttrsMod: 0,
          },
          {
            humanSociety: 1.0,
            hostEnergyBase: 10,
            hostHealthBase: 1,
            hostHealthMod: 1,
            hostSkillsMod: 0.5, // can access skills from level 2
            hostAttrsMod: 0,
          },
          {
            humanSociety: 2.0,
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
          name: T('Probe Brain'),
          canRepeat: true,
          energyFunc: function (player) {
            if (player.state != PLR_STATE_HOST)
              return -1;
            var level = player.evolutionManager.getLevel(IMP_BRAIN_PROBE);
            if (level == 0)
              return -1;
            var params = player.evolutionManager.getParams(IMP_BRAIN_PROBE);
            return params.hostEnergyBase + player.host.psyche;
          },
        },
        onUpgrade: function (level, game, player) {
          // complete goals
          if (level == 1)
            game.goals.complete(GOAL_EVOLVE_PROBE);

          else if (level == 2)
            game.goals.complete(GOAL_PROBE_BRAIN_ADVANCED);
        },
      },

      { // ***
        type: TYPE_SPECIAL,
        id: IMP_CAMO_LAYER,
        name: T('Camouflage layer'),
        note: T('Body feature. Allows the covering of parasite body with a self-regenerating camouflage layer that looks like host skin and clothing.'),
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return T('AI alertness multiplier: {alertness}', {
            alertness: l.alertness + (l2 != null ? ' &rarr; ' + l2.alertness : ''),
          });
        },
        organ: {
          name: T('Camouflage layer'),
          note: T('Self-regenerating camouflage layer that covers parasite body changing its appearance'),
          gp: 100,
          onGrow: function(game, player) {
            // complete goals
            game.goals.complete(GOAL_GROW_CAMO);
          }
        },
        levelNotes: [
          T('A perfectly visible huge purple blob on the head and upper body of the host'),
          T('Streaks of purple running through the partly grown camouflage layer'),
          T('Parasite body is mostly covered by camouflage layer'),
          T('Camouflage layer fully covers the parasite. Only close inspection will alert bystanders'),
        ],
        levelParams: [
          { alertness: 3 },
          { alertness: 2 },
          { alertness: 1 },
          { alertness: 0.5 },
        ],
        onUpgrade: function(level, game, player) {
          // complete goals
          if (level == 1)
            game.goals.complete(GOAL_EVOLVE_CAMO);
        }
      },

      { // ***
        type: TYPE_SPECIAL,
        id: IMP_DOPAMINE,
        name: T('Dopamine regulation'),
        note: T('Knowledge. Direct control of the host\'s adrenal glands alows regulating the amount of produced dopamine which in turn removes the need to reinforce control of the host.'),
        maxLevel: 1,
        levelNotes: [
          T('No regulation'),
          T('Direct control'),
          '',
          '',
        ],
        levelParams: [
          {},
          {},
          {},
          {},
        ],
        onUpgrade: function(level, game, player) {
          // complete goals
          if (level == 1)
            game.goals.complete(GOAL_EVOLVE_DOPAMINE);
        }
      },

      { // ***
        type: TYPE_SPECIAL,
        id: IMP_FALSE_MEMORIES,
        name: T('Pseudocampus'),
        note: T('Body feature. A short-term interface into the human brain allows the parasite to engrain the host with false memories also resulting in the short-term host confusion after activation.'),
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return T('Team timeout/distance increase: {bonus}<br/>' +
            'Blackops: team deactivated, group priority -25', {
            bonus: l.distanceBonus + (l2 != null ? ' &rarr; ' + l2.distanceBonus : ''),
          });
        },
        organ: {
          name: T('Pseudocampus'),
          note: T('A small interface outgrowth on the side of hippocampus allows for one-time projection of a set of false memories into the host brain'),
          gp: 100,
/*
          onGrow: function(game, player) {
            // complete goals
            game.goals.complete(GOAL_GROW_CAMO);
          }*/
          action: {
            id: 'plantMemories',
            type: ACTION_AREA,
            name: T('Plant Memories'),
            energyFunc: function (player) {
              if (player.state != PLR_STATE_HOST)
                return -1;
              var level = player.evolutionManager.getLevel(IMP_FALSE_MEMORIES);
              if (level == 0)
                return -1;
              return 10;
            },
          },
        },
        levelNotes: [
          T('No organ'),
          T('Low-detail memory design resulting in poor believability'),
          T('Advanced memory design allowing for higher believability'),
          T('Highly-nuanced and detailed memory design leading to best believability'),
        ],
        levelParams: [
          // NOTE: blackops deactivate the team instead (PlayerArea.plantMemoriesAction)
          // distance decrease per turn (team level): 0.1, 0.2, 0.5, 1.0
          // bonus turns (imp level 1): 50, 25, 10, 5
          // bonus turns (imp level 2): 100, 50, 20, 10
          { distanceBonus: 0 },
          { distanceBonus: 5 },
          { distanceBonus: 10 },
          { distanceBonus: 20 },
        ],
/*
        onUpgrade: function(level, game, player) {
          // complete goals
          if (level == 1)
            game.goals.complete(GOAL_EVOLVE_CAMO);
        }*/
      },

      { // ***
        type: TYPE_SPECIAL,
        id: IMP_MICROHABITAT,
        name: T('Microhabitat'),
        note: T('Knowledge. Better understanding of the urban sewage system gives the parasite an ability to build microhabitats. The natural caves of the mountains will serve as well.'),
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return T('Maximum number of microhabitats: {num}', {
            num: l.numHabitats + (l2 != null ? ' &rarr; ' + l2.numHabitats : ''),
          });
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
        onUpgrade: function(level, game, player) {
          // complete goals
          if (level == 1)
            game.goals.complete(GOAL_EVOLVE_MICROHABITAT);
        }
      },

      { // ***
        type: TYPE_SPECIAL,
        id: IMP_BIOMINERAL,
        name: T('Biomineral formation'),
        note: T('Habitat growth. Gives the parasite an ability to supply microhabitat with energy. Unused biomineral energy increases the speed of organ growth and evolution, slowly restores the health and energy of the parasite, plus the energy of assimilated and consenting hosts.'),
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return T('Energy units per formation: {energy}<br/>' +
            'Bonus organ and evolution points per turn: +{bonus}<br/>' +
            'Assimilated or consenting host energy restored per turn: +{hostEnergy}<br/>' +
            'Parasite energy restored per turn: +{parasiteEnergy}<br/>' +
            'Parasite health restored per turn: +{parasiteHealth}', {
            energy: l.energy + (l2 != null ? ' &rarr; ' + l2.energy : ''),
            bonus: l.evolutionBonus + '%' +
              (l2 != null ? ' &rarr; ' + l2.evolutionBonus + '%' : ''),
            hostEnergy: l.hostEnergyRestored +
              (l2 != null ? ' &rarr; +' + l2.hostEnergyRestored : ''),
            parasiteEnergy: l.parasiteEnergyRestored +
              (l2 != null ? ' &rarr; +' + l2.parasiteEnergyRestored : ''),
            parasiteHealth: l.parasiteHealthRestored +
              (l2 != null ? ' &rarr; +' + l2.parasiteHealthRestored : ''),
          });
        },
        levelNotes: [
          '',
          '',
          '',
          '',
        ],
        organ: {
          name: T('Biomineral mold'),
          note: T('Mold for a biomineral formation. You can only grow that in a habitat. Host and its inventory will be destroyed!'),
          gp: 150,
          isMold: true,
          action: {
            id: 'formBiomineral',
            type: ACTION_ORGAN,
            name: T('Produce biomineral formation'),
            energy: 0
          },
          onAction: function(game, player) {
            // only in habitat
            if (!game.area.isHabitat)
              {
                game.actionFailed(T('This action only works in a habitat.'));
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
        type: TYPE_SPECIAL,
        id: IMP_ASSIMILATION,
        name: T('Assimilation cavity'),
        note: T('Habitat growth. Gives the parasite an ability to assimilate hosts. Assimilated hosts do not lose energy passively and regenerate it from biominerals.'),
        maxLevel: 1,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return T('Assimilated hosts have 2 more body features<br/>' +
            'Assimilated hosts can hold 2 more inventory items<br/>' +
            'When you invade assimilated hosts, you start with more control over them') + '<br/>';
        },
        levelNotes: [
          '',
          '',
          '',
          '',
        ],
        organ: {
          name: T('Assimilation mold'),
          note: T('Mold for an assimilation cavity. You can only grow that in a habitat. Host and its inventory will be destroyed!'),
          gp: 120,
          isMold: true,
          action: {
            id: 'formAssimilation',
            type: ACTION_ORGAN,
            name: T('Form assimilation cavity'),
            energy: 0
          },
          onAction: function(game, player): Bool {
            // only in a habitat
            if (!game.area.isHabitat)
              {
                game.actionFailed(T('This action only works in a habitat.'));
                return false;
              }
            return game.area.habitat.putObject(IMP_ASSIMILATION);
          }
        },
        levelParams: [
          {},
          {},
          {},
          {},
        ],
      },

      { // ***
        type: TYPE_SPECIAL,
        id: IMP_WATCHER,
        name: T('Watcher'),
        note: T('Watcher growth. Will warn of the ambush in the habitat and reduce the max energy loss on habitat destruction.'),
        maxLevel: 2,
        levelNotes: [
          T('Unavailable'),
          T('Watcher will warn about the ambush and give more distance'),
          T('Watcher will attract the ambush, reduce max energy loss and give even more distance'),
          '',
        ],
        organ: {
          name: T('Watcher mold'),
          note: T('Mold for a watcher. You can only grow that in a habitat. Host inventory will be destroyed when it becomes the watcher!'),
          gp: 120,
          isMold: true,
          action: {
            id: 'formWatcher',
            type: ACTION_ORGAN,
            name: T('Form watcher'),
            energy: 0
          },
          onAction: function(game, player): Bool {
            // only in habitat
            if (!game.area.isHabitat)
              {
                game.actionFailed(T('This action only works in a habitat.'));
                return false;
              }
            return game.area.habitat.putObject(IMP_WATCHER);
          }
        },
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return '<br/>' + T('Distance bonus: {bonus}', {
            bonus: l.distanceBonus + (l2 != null ? ' &rarr; ' + l2.distanceBonus : ''),
          });
        },
        levelParams: [
          {
            distanceBonus: 0,
          },
          {
            distanceBonus: 10,
          },
          {
            distanceBonus: 25,
          },
          {
            distanceBonus: 0,
          },
        ],
      },

      { // ***
        type: TYPE_SPECIAL,
        id: IMP_PRESERVATOR,
        name: T('Host preservator'),
        note: T('Habitat growth. Allows preserving hosts in a suspended state until further need.'),
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return '<br/>' + T('Amount of hosts per unit: {amount}', {
            amount: l.hostAmount + (l2 != null ? ' &rarr; ' + l2.hostAmount : ''),
          });
        },
        levelNotes: [
          '',
          '',
          '',
          '',
        ],
        organ: {
          name: T('Preservator mold'),
          note: T('Mold for a host preservator. You can only grow that in a habitat. Host and its inventory will be destroyed!'),
          gp: 120,
          isMold: true,
          action: {
            id: 'formPreservator',
            type: ACTION_ORGAN,
            name: T('Produce host preservator'),
            energy: 0
          },
          onAction: function(game, player) {
            // only in habitat
            if (!game.area.isHabitat)
              {
                game.actionFailed(T('This action only works in a habitat.'));
                return false;
              }
            return game.area.habitat.putObject(IMP_PRESERVATOR);
          }
        },
        levelParams: [
          {
            hostAmount: 0,
          },
          {
            hostAmount: 1,
          },
          {
            hostAmount: 2,
          },
          {
            hostAmount: 4,
          },
        ],
      },

      { // ***
        type: TYPE_SPECIAL,
        id: IMP_OVUM,
        name: T('Parthenogenesis'),
        note: T('Knowledge. Allows the parasite the access to a form of asexual reproduction that results in what is essentially eternal life with some limitations.'),
        maxLevel: 1,
        levelNotes: [
          T('No access to ovum'),
          T('Ability to place ovum in region mode'),
          '',
          '',
        ],
        levelParams: [
          {},
          {},
          {},
          {},
        ],
        onUpgrade: function(level, game, player) {
          // complete goals
//          if (level == 1)
//            game.goals.complete(GOAL_EVOLVE_DOPAMINE);
        }
      },

      { // ***
        type: TYPE_SPECIAL,
        id: IMP_ENGRAM,
        name: T('Limited engram encoding'),
        note: T("Knowledge. Enhancing synaptic plasticity and integrating targeted engrams allows storage and retrieval of specific information within the host's neural circuits without disrupting normal cognitive functions."),

        maxLevel: 1,
        levelNotes: [
          T('No additional memory access'),
          T('Access to minimap (use computer)'),
          '',
          '',
        ],
        levelParams: [
          {},
          {},
          {},
          {},
        ],
        onUpgrade: function(level, game, player) {
          // complete goals
//          if (level == 1)
//            game.goals.complete(GOAL_EVOLVE_DOPAMINE);
        }
      },

    ];


// ep needed to upgrade improvement to next level (index is current level)
  public static var epCostImprovement = [ 100, 200, 500, 1000 ];

// get improvement info
  public static function getInfo(id: _Improv): ImprovInfo
    {
      for (imp in improvements)
        if (imp.id == id)
          return imp;

      throw 'No such improvement: ' + id;
      return null;
    }

// return improvement info by id, or null if missing (used on load when a mod
// that supplied the improvement is no longer enabled — caller scrubs orphan
// improvs)
  public static function tryGetInfo(id: _Improv): ImprovInfo
    {
      for (imp in improvements)
        if (imp.id == id)
          return imp;
      return null;
    }

// append an improvement info; id collision = last-wins + log. used by
// ModContentApi.registerEvolution and any future engine code that wants to
// register improvements dynamically. the list is built once at class load
// and never wiped, so a pushed entry survives all new-game cycles.
  public static function addImprovement(info: ImprovInfo)
    {
      for (i in 0...improvements.length)
        if (improvements[i].id == info.id)
          {
            Const.p('mod content collision on improvement id: ' + info.id +
              ' (last-wins)');
            improvements[i] = info;
            return;
          }
      improvements.push(info);
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
}

typedef ImprovInfo =
{
  id: _Improv, // improvement string ID
  type: _ImprovType, // type id
  name: String, // improvement name
  note: String, // improvement description
  maxLevel: Int, // maximum improvement level
  ?noteFunc: Dynamic -> Dynamic -> String, // advanced description
  ?organ: OrganInfo, // organ that can be grown
  levelNotes: Array<String>, // improvement descriptions for different levels
  levelParams: Array<Dynamic>, // improvement-specific parameters for different levels

  ?action: _PlayerAction, // added player action
  ?onUpgrade: Int -> Game -> Player -> Void, // func to call on upgrading improvement
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
