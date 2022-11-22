// evolution constants

package const;

import game.Game;
import game.Habitat;
import game.Player;
import objects.*;

class EvolutionConst
{
// ovum levels xp
  public static var ovumXP = [ 2, 5, 20, 50, 100 ];
// improvement info
  public static var improvements: Array<ImprovInfo> =
    [
      // =============== BASIC ===================
/*
      { // ***
        type: TYPE_BASIC;
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
        type: TYPE_BASIC,
        id: IMP_DECAY_ACCEL,
        name: 'Decay acceleration',
        note: 'Body feature. Special bacteria and enzymes accelerate autolysis and putrefaction allowing significantly more efficient tissue decomposition of the host body after death. Moreover, the decomposition produces highly nutritional residue.',
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return "Bodies will disappear in " + l.turns +
            (l2 != null ? ' (&rarr; ' + l2.turns + ')' : '') +
            " turns";
        },
        organ: {
          name: 'Decay accelerant cysts',
          note: 'Cysts of specialized bacteria and enzymes spread throughout the body to accelerate its decay after death and transform it into a dry nutritional residue',
          gp: 50
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

      { // ***
        type: TYPE_BASIC,
        id: IMP_PROT_COVER,
        name: 'Protective cover',
        note: 'Body feature. Heavy epidermis keratinization and dermis densification later allows for an armor-like body cover on the host with the downside of significantly altered host appearance.',
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return "Host armor bonus (minus to damage): " +
            l.armor + (l2 != null ? ' &rarr; ' + l2.armor : '') +
            "<br/>" +
            "AI alertness bonus: " + l.alertness +
            (l2 != null ? ' &rarr; ' + l2.alertness : '');
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
        type: TYPE_BASIC,
        id: IMP_WOUND_REGEN,
        name: 'Stem cell reservoirs',
        note: 'Body feature. Microreservoirs of adult stem cells form in many tissues of the host body greatly increasing the efficacy and speed of wound healing process.',
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return l.turns +
            (l2 != null ? ' (&rarr; ' + l2.turns + ')' : '') +
            " turns to restore 1 health of host and parasite";
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
        type: TYPE_BASIC,
        id: IMP_HEALTH,
        name: 'Antibody generators',
        note: 'Body feature. Direct synthesis of antibodies through specialized biofactories increases the responce speed of adaptive immune system adding to overall host health.',
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return "+" + l.health +
            (l2 != null ? ' (&rarr; ' + l2.health + ')' : '') +
            " health to host";
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
          { health: 2 },
          { health: 3 },
          { health: 4 },
        ],
      },

      { // ***
        type: TYPE_BASIC,
        id: IMP_ENERGY,
        name: 'Adipose tissue layer',
        note: 'Body feature. Modifications to metabolism allow for adipose tissue outgrowths on the host body for storing energy surplus.',
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return "Host maximum energy multiplier: " + l.hostEnergyMod +
            (l2 != null ? ' &rarr; ' + l2.hostEnergyMod : '') +
            "<br/>Restores energy to maximum on completion";
        },
        organ: {
          name: 'Adipose tissue layer',
          note: 'Additional layer of adipose tissue allows for having energy surplus',
          gp: 180
        },
        levelNotes: [
          'Normal host subcutaneous tissue',
          'Increased adipose tissue in abdominal area',
          'Clusters of adipose tissue on the body',
          'Enormous protrusions of adipose tissue',
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
        name: 'Microvascular networks',
        note: 'Body feature. Neovascularization within muscles enhances the ability to move waste products out and maintain contraction reducing the accumulated metabolic fatigue which results in increased host strength.',
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return "+" + l.strength +
            (l2 != null ? ' (&rarr; ' + l2.strength + ')' : '') +
            " strength to host";
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
          { strength: 2 },
          { strength: 3 },
          { strength: 4 },
        ],
      },

      { // ***
        type: TYPE_BASIC,
        id: IMP_ACID_SPIT,
        name: 'Gastric hypersecretion',
        note: 'Body feature. Recalibration of gastric glands results in increased potency and volume of produced acid, allowing the host to forcibly eject it as a sort of weapon.',
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return "Emesis damage: " + l.minDamage + "-" + l.maxDamage +
            (l2 != null ? ' &rarr; ' + l2.minDamage + '-' + l2.maxDamage : '') +
            "<br/>Emesis range: " + l.range +
            (l2 != null ? ' &rarr; ' + l2.range :  '');
        },
        organ: {
          name: 'Improved gastric glands',
          note: 'Recalibrated gastric glands secrete enormous amounts of acid for hyperemesis attack',
          gp: 150,
          action: {
            id: 'acidSpit',
            type: ACTION_ORGAN,
            name: 'Emesis',
            energy: 5
          },
        },
        levelNotes: [
          'Normal host gastric glands',
          'Enlarged gastric glands',
          'Improved gastric glands with specialized abdominal muscles',
          'Highly-effective gastric glands with additional abdominal and neck muscles',
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
        name: 'Mucilaginous fluid',
        note: 'Body feature. Restructuring of salivary glands and surrounding buccal cavity. Secreted mucosal fluid now exhibits highly adhesive properties of mucilage produced by some plants and will force the opponent to stop.',
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return "Mucus strength: " + l.strength +
            (l2 != null ? ' &rarr; ' + l2.strength : '') +
            "<br/>Discharge range: " + l.range +
            (l2 != null ? ' &rarr; ' + l2.range :  '');
        },
        organ: {
          name: 'Salivary gland extension',
          note: 'Enhanced salivary glands produce viscous mucosal fluid useful for slowing opponents down',
          gp: 100,
          action: {
            id: 'slimeSpit',
            type: ACTION_ORGAN,
            name: 'Salivate',
            energy: 5
          },
        },
        levelNotes: [
          'Normal host salivary glands',
          'Enlarged salivary glands and buccal cavity',
          'Expanded salivary glands and further widened buccal cavity',
          'Expanded salivary glands, enormous buccal cavity and enhanced cheek muscles',
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
        name: 'Neurotoxin projectiles',
        note: 'Body feature. Hard needle-like missiles containing potent paralyzing neurotoxin can be shot with precision from a specialized organ resembling a segmented tail. The toxin can potentially be lethal.',
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return "Paralysis effect time: " + l.time +
            (l2 != null ? ' &rarr; ' + l2.time : '') +
            "<br/>Needle range: " + l.range +
            (l2 != null ? ' &rarr; ' + l2.range :  '');
        },
        organ: {
          name: 'Neurotoxin cirrus',
          note: 'The cirrus shoots paralyzing needles into the opponents that can sometimes be lethal',
          gp: 100,
          action: {
            id: 'paralysisSpit',
            type: ACTION_ORGAN,
            name: 'Needle',
            energy: 5
          },
        },
        levelNotes: [
          'No modications',
          'Small cirrus and weak neurotoxin resulting in limited effectiveness',
          'Strengthened cirrus and more potent neurotoxin',
          'Highly enhanced cirrus and strong neurotoxin',
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
        name: 'Hallucinogen gas',
        note: 'Body feature. Host stomach is increased in size and separated into two sections, with one reserved for synthesis and storage of compressed hallucinogen gas that can be released into air if necessary. When inhaled by the opponents, the gas results in fear and anxiety.',
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return "Cloud range: " + l.range +
            (l2 != null ? ' &rarr; ' + l2.range : '') +
            "<br/>Gas release timeout: " + l.timeout +
            (l2 != null ? ' &rarr; ' + l2.timeout : '') +
            "<br/>Panic effect time: " + l.time +
            (l2 != null ? ' &rarr; ' + l2.time : '');
        },
        organ: {
          name: 'Gas section',
          note: 'Hallucinogenic gas section synthesizes and stores the gas. Releasing it causes the opponents in range to panic and run away',
          gp: 150,
          hasTimeout: true,
          action: {
            id: 'panicGas',
            type: ACTION_ORGAN,
            name: 'Release gas',
            energy: 10
          },
        },
        levelNotes: [
          'No modications',
          'Small gas section with low effective radius and strength',
          'Moderate gas section with increased effective radius and strength',
          'Large gas section with high effective radius and strength',
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
        name: 'Ballistospores',
        note: 'Body feature. Clusters of sporangiums designed to produce multitudes of fungal-like ballistospores in the surrounding air. When inhaled by the hosts, the ballistospores act as a mild neurotoxin paralyzing them temporarily.',
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return "Cloud range: " + l.range +
            (l2 != null ? ' &rarr; ' + l2.range : '') +
            "<br/>Gas release time: " + l.timeout +
            (l2 != null ? ' &rarr; ' + l2.timeout : '') +
            "<br/>Panic effect time: " + l.time +
            (l2 != null ? ' &rarr; ' + l2.time : '');
        },
        organ: {
          name: 'Sporangium',
          note: 'Releases a cloud of ballistospores which paralyze the opponents for a limited amount of time',
          gp: 180,
          hasTimeout: true,
          action: {
            id: 'paralysisGas',
            type: ACTION_ORGAN,
            name: 'Emit spores',
            energy: 12
          },
        },
        levelNotes: [
          'No modications',
          'Low amount of emitter organs with limited range and repeatability',
          'Medium amount of emitters with increased range and time between emissions',
          'High amount of efficient emitters that have a wider range. Spores have faster effect',
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
        name: 'Sudden leap',
        note: 'Knowledge. Lulling the host into a false sense of security then making a sudden unexpected jump at key moment allows the parasite to gain initial advantage when attaching to it.',
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return "Base attach grip: " + l.attachHoldBase +
            (l2 != null ? ' &rarr; ' + l2.attachHoldBase : '');
        },
        levelNotes: [
          'Natural attaching method',
          'Small gains in grip',
          'Medium gains due to well-researched procedure',
          'The initial attach action is fast and precise',
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
        name: 'Constriction',
        note: 'Knowledge. Advanced constriction technique allows you to rapidly subdue the host before the invasion process.',
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return "Base harden grip: " + l.attachHoldBase +
            (l2 != null ? ' &rarr; ' + l2.attachHoldBase : '');
        },
        levelNotes: [
          'Natural grip hardening process',
          'Minor constriction bonus to the grip',
          'Significant bonus to the grip',
          'Superb constriction bonus',
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
        name: 'Regulated neurotransmission',
        note: 'Knowledge. Correctly timing the neurotransmitters release allows the parasite to more efficiently control and override the actions of the host.',
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return "Base reinforce control: " + l.reinforceControlBase +
            (l2 != null ? ' &rarr; ' + l2.reinforceControlBase : '');
        },
        levelNotes: [
          'Natural control reinforcing process',
          'Increased control reinforcing mechanism',
          'Improved control reinforcement',
          'Efficient control reinfocement',
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
        name: 'Brain probe',
        note: 'Knowledge. Temporarily joining with the host consciousness allows to partially learn its contents.',
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          var s = "Human society knowledge multiplier: " + l.humanSociety + (l2 != null ? ' &rarr; ' + l2.humanSociety : '') +
            "<br/>Base host energy cost: " + l.hostEnergyBase + (l2 != null ? ' &rarr; ' + l2.hostEnergyBase : '') +
            "<br/>Base host health cost: " + l.hostHealthBase + (l2 != null ? ' &rarr; ' + l2.hostHealthBase: '') +
            "<br/>Host skills learning multiplier: " + l.hostSkillsMod + (l2 != null ? ' &rarr; ' + l2.hostSkillsMod : '') + '<br/>';
          if (l.hostAttrsMod == 0)
            s += "Host attributes unknown ";
          if (l2 != null && l2.hostAttrsMod == 1)
            s += "&rarr; Probe shows host attributes";
          else if (l.hostAttrsMod == 1)
            s += "Probe shows host attributes";
          return s;
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
          name: 'Probe Brain',
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
        name: 'Camouflage layer',
        note: 'Body feature. Allows the covering of parasite body with a self-regenerating camouflage layer that looks like host skin and clothing.',
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return "AI alertness multiplier: " + l.alertness +
            (l2 != null ? ' &rarr; ' + l2.alertness : '');
        },
        organ: {
          name: 'Camouflage layer',
          note: 'Self-regenerating camouflage layer that covers parasite body changing its appearance',
          gp: 100,
          onGrow: function(game, player) {
            // complete goals
            game.goals.complete(GOAL_GROW_CAMO);
          }
        },
        levelNotes: [
          'A perfectly visible huge purple blob on the head and upper body of the host',
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
        onUpgrade: function(level, game, player) {
          // complete goals
          if (level == 1)
            game.goals.complete(GOAL_EVOLVE_CAMO);
        }
      },

      { // ***
        type: TYPE_SPECIAL,
        id: IMP_DOPAMINE,
        name: 'Dopamine regulation',
        note: 'Knowledge. Direct control of the host\'s adrenal glands alows regulating the amount of produced dopamine which in turn removes the need to reinforce control of the host.',
        maxLevel: 1,
        levelNotes: [
          'No regulation',
          'Direct control',
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
        name: 'Pseudocampus',
        note: 'Body feature. A short-term interface into the human brain allows the parasite to engrain the host with false memories also resulting in the short-term host confusion after activation.',
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return "Team distance increase: " + l.distanceBonus +
            (l2 != null ? ' &rarr; ' + l2.distanceBonus : '');
        },
        organ: {
          name: 'Pseudocampus',
          note: 'A small interface outgrowth on the side of hippocampus allows for one-time projection of a set of false memories into the host brain',
          gp: 100,
/*
          onGrow: function(game, player) {
            // complete goals
            game.goals.complete(GOAL_GROW_CAMO);
          }*/
          action: {
            id: 'plantMemories',
            type: ACTION_AREA,
            name: 'Plant Memories',
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
          'No organ',
          'Low-detail memory design resulting in poor believability',
          'Advanced memory design allowing for higher believability',
          'Highly-nuanced and detailed memory design leading to best believability',
        ],
        levelParams: [
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
        name: 'Microhabitat',
        note: 'Knowledge. Better understanding of the urban sewage system gives the parasite an ability to build microhabitats.',
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return "Maximum number of microhabitats: " + l.numHabitats +
            (l2 != null ? ' &rarr; ' + l2.numHabitats : '');
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
        name: 'Biomineral formation',
        note: 'Habitat growth. Gives the parasite an ability to supply microhabitat with energy. Unused biomineral energy increases the speed of organ growth and evolution, slowly restores the health and energy of the parasite, plus the energy of assimilated hosts.',
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return
            "Energy units per formation: " + l.energy +
            (l2 != null ? ' &rarr; ' + l2.energy : '') +
            "<br/>Bonus organ and evolution points per turn: +" +
              l.evolutionBonus + "%" +
              (l2 != null ? ' &rarr; ' + l2.evolutionBonus + '%' : '') +
            "<br/>Assimilated host energy restored per turn: +" + l.hostEnergyRestored +
            (l2 != null ? ' &rarr; +' + l2.hostEnergyRestored : '') +
            "<br/>Parasite energy restored per turn: +" +
            l.parasiteEnergyRestored +
            (l2 != null ? ' &rarr; +' + l2.parasiteEnergyRestored : '') +
            "<br/>Parasite health restored per turn: +" +
            l.parasiteHealthRestored +
            (l2 != null ? ' &rarr; +' + l2.parasiteHealthRestored : '');
        },
        levelNotes: [
          '',
          '',
          '',
          '',
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
          onAction: function(game, player) {
            // only in habitat
            if (!game.area.isHabitat)
              {
                game.log('This action works only in a habitat.', COLOR_HINT);
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
        name: 'Assimilation cavity',
        note: 'Habitat growth. Gives the parasite an ability to assimilate hosts. Assimilated hosts do not lose energy passively and regenerate it from biominerals.',
        maxLevel: 1,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return
            "Assimilated hosts have 2 more body features<br/>" +
            "Assimilated hosts can hold 2 more inventory items<br/>" +
            "When you invade assimilated hosts, you start with more control over them<br/>";
        },
        levelNotes: [
          '',
          '',
          '',
          '',
        ],
        organ: {
          name: 'Assimilation mold',
          note: 'Mold for an assimilation cavity. You can only grow that in a habitat. Host and its inventory will be destroyed!',
          gp: 120,
          isMold: true,
          action: {
            id: 'formAssimilation',
            type: ACTION_ORGAN,
            name: 'Form assimilation cavity',
            energy: 0
          },
          onAction: function(game, player): Bool {
            // only in a habitat
            if (!game.area.isHabitat)
              {
                game.log('This action works only in a habitat.', COLOR_HINT);
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
        name: 'Watcher',
        note: 'Watcher growth. Will warn of the ambush in the habitat.',
        maxLevel: 2,
        levelNotes: [
          'Unavailable',
          'Watcher will warn about the ambush',
          'Watcher will attract the ambush',
          '',
        ],
        organ: {
          name: 'Watcher mold',
          note: 'Mold for a watcher. You can only grow that in a habitat. Host inventory will be destroyed when it becomes the watcher!',
          gp: 120,
          isMold: true,
          action: {
            id: 'formWatcher',
            type: ACTION_ORGAN,
            name: 'Form watcher',
            energy: 0
          },
          onAction: function(game, player): Bool {
            // only in habitat
            if (!game.area.isHabitat)
              {
                game.log('This action works only in a habitat.', COLOR_HINT);
                return false;
              }
            return game.area.habitat.putObject(IMP_WATCHER);
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
        id: IMP_PRESERVATOR,
        name: 'Host preservator',
        note: 'Habitat growth. Allows preserving hosts in a suspended state until further need.',
        maxLevel: 3,
        noteFunc: function (l: Dynamic, l2: Dynamic) {
          return
            "<br/>Amount of hosts per unit: " +
            l.hostAmount +
            (l2 != null ? ' &rarr; ' + l2.hostAmount : '');
        },
        levelNotes: [
          '',
          '',
          '',
          '',
        ],
        organ: {
          name: 'Preservator mold',
          note: 'Mold for a host preservator. You can only grow that in a habitat. Host and its inventory will be destroyed!',
          gp: 120,
          isMold: true,
          action: {
            id: 'formPreservator',
            type: ACTION_ORGAN,
            name: 'Produce host preservator',
            energy: 0
          },
          onAction: function(game, player) {
            // only in habitat
            if (!game.area.isHabitat)
              {
                game.log('This action works only in a habitat.', COLOR_HINT);
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
        name: 'Parthenogenesis',
        note: 'Knowledge. Allows the parasite the access to a form of asexual reproduction that results in what is essentially eternal life with some limitations.',
        maxLevel: 1,
        levelNotes: [
          'No access to ovum',
          'Ability to place ovum in region mode',
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
