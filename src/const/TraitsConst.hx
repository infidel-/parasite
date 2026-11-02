// trait info list

package const;

import ai.AI;
import ai.AIData;
import ai.AI._AIStateChangeReason;
import const.SoundConst;
import game.Game;
import haxe.ds.StringMap;

class TraitsConst
{
// return info by id
  public static function getInfo(id: _AITraitType): _TraitInfo
    {
      for (group in traits)
        for (info in group)
          if (info.id == id)
            return info;

      throw 'No such trait: ' + id;
      return null;
    }

// return trait info by id, or null if missing (used on load when a mod that
// supplied the trait is no longer enabled — caller scrubs orphan traits)
  public static function tryGetInfo(id: _AITraitType): _TraitInfo
    {
      for (group in traits)
        for (info in group)
          if (info.id == id)
            return info;
      return null;
    }

  // counts AI traits scrubbed during a load due to missing mod-supplied info.
  // Loader resets to 0 before loading and reads after the post-load chain
  public static var loadOrphanCount: Int = 0;

// return trait group by id
  public static function getGroup(id: String): Array<_TraitInfo>
    {
      return traits.get(id);
    }

// return random trait from a given group
  public static function getRandom(group: String): _TraitInfo
    {
      var groupTraits = traits.get(group);
      if (groupTraits == null || groupTraits.length == 0)
        return null;
      return groupTraits[Std.random(groupTraits.length)];
    }

// return random negative trait from a given group
  public static function getRandomNegative(group: String): _TraitInfo
    {
      var groupTraits = traits.get(group);
      if (groupTraits == null)
        return null;
      var negativeTraits = [];
      for (trait in groupTraits)
        if (trait.isNegative)
          negativeTraits.push(trait);
      if (negativeTraits.length == 0)
        return null;
      return negativeTraits[Std.random(negativeTraits.length)];
    }

// return random positive trait from a given group
  public static function getRandomPositive(group: String): _TraitInfo
    {
      var groupTraits = traits.get(group);
      if (groupTraits == null)
        return null;
      var positiveTraits = [];
      for (trait in groupTraits)
        if (!trait.isNegative)
          positiveTraits.push(trait);
      if (positiveTraits.length == 0)
        return null;
      return positiveTraits[Std.random(positiveTraits.length)];
    }

// trait infos by group; mod-registered entries are appended live via
// addTrait. the static initializer pulls builtins only; mods run after this
// fires (Haxe lazy class init), so they use addTrait to extend the map.
  public static var traits: StringMap<Array<_TraitInfo>> = initTraits();

// append a trait info to a category group, creating the group array if
// missing. id collision within the same group = last-wins + log. used by
// ModContentApi.registerTrait and any future engine code that
// wants to register traits dynamically.
  public static function addTrait(category: String, info: _TraitInfo)
    {
      var group = traits.get(category);
      if (group == null)
        {
          group = [];
          traits.set(category, group);
        }
      for (i in 0...group.length)
        if (group[i].id == info.id)
          {
            Const.p('mod content collision on trait id: ' + info.id +
              ' in group "' + category + '" (last-wins)');
            group[i] = info;
            return;
          }
      group.push(info);
    }

// build trait map data
  static function initTraits(): StringMap<Array<_TraitInfo>>
    {
      var map = new StringMap<Array<_TraitInfo>>();

      // misc trait group definitions
      map.set('misc', [
        {
          id: TRAIT_DRUG_ADDICT,
          name: T('drug addict'),
          note: T('Addicted to drugs.'),
          isNegative: true,
          turn: function(game: Game, ai: AIData)
            {
              if (Std.random(100) > 10)
                return;
              var actor = Std.downcast(ai, AI);
              if (actor == null)
                return;
              actor.onEffect(new effects.Withdrawal(game, 5));
            }
        },
        {
          id: TRAIT_ALCOHOLIC,
          name: T('alcoholic'),
          note: T('Years of booze take their toll. Control impossible to maintain fully.'),
          isNegative: true,
          turn: function(game: Game, ai: AIData)
            {
              if (game.player.host == ai &&
                  game.player.hostControl > 80)
                game.player.hostControl = 80;
            }
        },
        {
          id: TRAIT_ASSIMILATED,
          name: T('assimilated'),
          note: T('Has been assimilated.'),
          isNegative: false
        }
      ]);

      // skill trait group definitions
      map.set('skill', [
        {
          id: TRAIT_BRUISER,
          name: T('bruiser'),
          note: T('Excels at fists combat.'),
          isNegative: false,
          onInit: function(game: Game, ai: AIData)
            {
              ai.skills.increase(SKILL_FISTS, 25);
            }
        },
        {
          id: TRAIT_KNIFE_EXPERT,
          name: T('knife expert'),
          note: T('Practiced in knife combat.'),
          isNegative: false,
          onInit: function(game: Game, ai: AIData)
            {
              ai.skills.increase(SKILL_KNIFE, 25);
            }
        },
        {
          id: TRAIT_BATON_EXPERT,
          name: T('baton expert'),
          note: T('Seasoned baton fighter.'),
          isNegative: false,
          onInit: function(game: Game, ai: AIData)
            {
              ai.skills.increase(SKILL_BATON, 25);
            }
        },
        {
          id: TRAIT_BATTER,
          name: T('batter'),
          note: T('Experienced with club weapons.'),
          isNegative: false,
          onInit: function(game: Game, ai: AIData)
            {
              ai.skills.increase(SKILL_CLUB, 25);
            }
        },
        {
          id: TRAIT_GUERRERO,
          name: T('guerrero'),
          note: T('Practiced with machetes.'),
          isNegative: false,
          onInit: function(game: Game, ai: AIData)
            {
              ai.skills.increase(SKILL_MACHETE, 25);
            }
        },
        {
          id: TRAIT_KENDOKA,
          name: T('kendoka'),
          note: T('Trained with katanas.'),
          isNegative: false,
          onInit: function(game: Game, ai: AIData)
            {
              ai.skills.increase(SKILL_KATANA, 25);
            }
        },
        {
          id: TRAIT_PISTOL_MARKSMAN,
          name: T('pistol marksman'),
          note: T('Sharpshooter with pistols.'),
          isNegative: false,
          onInit: function(game: Game, ai: AIData)
            {
              ai.skills.increase(SKILL_PISTOL, 25);
            }
        },
        {
          id: TRAIT_RIFLE_MARKSMAN,
          name: T('rifle marksman'),
          note: T('Accurate with rifles.'),
          isNegative: false,
          onInit: function(game: Game, ai: AIData)
            {
              ai.skills.increase(SKILL_RIFLE, 25);
            }
        },
        {
          id: TRAIT_BREACHER,
          name: T('breacher'),
          note: T('Skilled with shotguns.'),
          isNegative: false,
          onInit: function(game: Game, ai: AIData)
            {
              ai.skills.increase(SKILL_SHOTGUN, 25);
            }
        },
        {
          id: TRAIT_HACKER,
          name: T('hacker'),
          note: T('Talented with computers.'),
          isNegative: false,
          onInit: function(game: Game, ai: AIData)
            {
              ai.skills.increase(SKILL_COMPUTER, 25);
            }
        },
        {
          id: TRAIT_COUNSELOR,
          name: T('counselor'),
          note: T('Understands psychology.'),
          isNegative: false,
          onInit: function(game: Game, ai: AIData)
            {
              ai.skills.increase(SKILL_PSYCHOLOGY, 25);
            }
        },
        {
          id: TRAIT_NEGOTIATOR,
          name: T('negotiator'),
          note: T('Expert at coercion.'),
          isNegative: false,
          onInit: function(game: Game, ai: AIData)
            {
              ai.skills.increase(SKILL_COERCION, 25);
            }
        },
        {
          id: TRAIT_CONSULTANT,
          name: T('consultant'),
          note: T('Gifted at coaxing.'),
          isNegative: false,
          onInit: function(game: Game, ai: AIData)
            {
              ai.skills.increase(SKILL_COAXING, 25);
            }
        },
        {
          id: TRAIT_HABITUAL_LIAR,
          name: T('habitual liar'),
          note: T('Adept at deception.'),
          isNegative: false,
          onInit: function(game: Game, ai: AIData)
            {
              ai.skills.increase(SKILL_DECEPTION, 25);
            }
        }
      ]);

      // mind trait group definitions
      map.set('mind', [
        {
          id: TRAIT_DUMB,
          name: T('dumb'),
          note: T('Slow to process new ideas.'),
          isNegative: true,
          onInit: function(game: Game, ai: AIData)
            {
              ai.baseAttrs.intellect -= 2;
            }
        },
        {
          id: TRAIT_ILLITERATE,
          name: T('illiterate'),
          note: T('Unable to read.'),
          isNegative: true
        },
        {
          id: TRAIT_GENIUS,
          name: T('genius'),
          note: T('Exceptionally sharp intellect.'),
          isNegative: false,
          onInit: function(game: Game, ai: AIData)
            {
              ai.baseAttrs.intellect += 2;
            }
        },
        {
          id: TRAIT_WEAK_WILLED,
          name: T('weak-willed'),
          note: T('Struggles with resolve.'),
          isNegative: true,
          onInit: function(game: Game, ai: AIData)
            {
              ai.baseAttrs.psyche -= 2;
            }
        },
        {
          id: TRAIT_STRONG_WILLED,
          name: T('strong-willed'),
          note: T('Mentally resilient.'),
          isNegative: false,
          onInit: function(game: Game, ai: AIData)
            {
              ai.baseAttrs.psyche += 2;
            }
        }
      ]);

      // body trait group definitions
      map.set('body', [
        {
          id: TRAIT_ANOREXIC,
          name: T('anorexic'),
          note: T('Extremely underweight and frail.'),
          isNegative: true,
          onInit: function(game: Game, ai: AIData)
            {
              ai.baseAttrs.strength -= 2;
              ai.baseAttrs.constitution -= 2;
            }
        },
        {
          id: TRAIT_WEAK,
          name: T('weak'),
          note: T('Noticeably lacking muscle.'),
          isNegative: true,
          onInit: function(game: Game, ai: AIData)
            {
              ai.baseAttrs.strength -= 1;
              ai.baseAttrs.constitution -= 1;
            }
        },
        {
          id: TRAIT_OBESE,
          name: T('obese'),
          note: T('Carries significant extra weight.'),
          isNegative: true,
          onInit: function(game: Game, ai: AIData)
            {
              ai.baseAttrs.strength -= 1;
              ai.baseAttrs.constitution += 1;
            }
        },
        {
          id: TRAIT_HEAVILY_OBESE,
          name: T('heavily obese'),
          note: T('Massively overweight frame.'),
          isNegative: true,
          onInit: function(game: Game, ai: AIData)
            {
              ai.baseAttrs.strength -= 2;
              ai.baseAttrs.constitution += 2;
            }
        },
        {
          id: TRAIT_MUSCULAR,
          name: T('muscular'),
          note: T('Well-developed physique.'),
          isNegative: false,
          onInit: function(game: Game, ai: AIData)
            {
              ai.baseAttrs.strength += 1;
              ai.baseAttrs.constitution += 1;
            }
        },
        {
          id: TRAIT_HERCULEAN,
          name: T('herculean'),
          note: T('Peak physical power.'),
          isNegative: false,
          onInit: function(game: Game, ai: AIData)
            {
              ai.baseAttrs.strength += 2;
              ai.baseAttrs.constitution += 2;
            }
        }
      ]);

// important note: if we add traits to cultist in the field (including player host), their member records will not be updated until despawn. so avoid doing that, add traits to despawned cultists only
      map.set('cultBasic', [
        {
          id: TRAIT_DEVOUT_BRUTE,
          name: T('devout brute'),
          note: T('Zealous strength overtakes thoughtful study.'),
          isNegative: false,
          onInit: function(game: Game, ai: AIData)
            {
              ai.baseAttrs.strength += 2;
              ai.baseAttrs.intellect -= 2;
            }
        },
        {
          id: TRAIT_PENITENT_BASTION,
          name: T('penitent bastion'),
          note: T('Endures rites through sheer fortitude, fraying the mind.'),
          isNegative: false,
          onInit: function(game: Game, ai: AIData)
            {
              ai.baseAttrs.constitution += 2;
              ai.baseAttrs.psyche -= 2;
            }
        },
        {
          id: TRAIT_VEILED_SCHOLAR,
          name: T('veiled scholar'),
          note: T('Contemplates doctrine instead of honing muscle.'),
          isNegative: false,
          onInit: function(game: Game, ai: AIData)
            {
              ai.baseAttrs.strength -= 2;
              ai.baseAttrs.intellect += 2;
            }
        },
        {
          id: TRAIT_HUSHED_SEER,
          name: T('hushed seer'),
          note: T('Withdrawn frame shelters an awakened psyche.'),
          isNegative: false,
          onInit: function(game: Game, ai: AIData)
            {
              ai.baseAttrs.constitution -= 2;
              ai.baseAttrs.psyche += 2;
            }
        },
        {
          id: TRAIT_TITHE_HUSTLER,
          name: T('tithe hustler'),
          note: T('Extracts steady tithes at the cost of fraying nerves.'),
          isNegative: false,
          onInit: function(game: Game, ai: AIData)
            {
              if (ai.income <= 0)
                ai.income = 500;
              else
                {
                  var bonus = Std.int(ai.income * 0.1);
                  if (bonus < 1)
                    bonus = 1;
                  ai.income += bonus;
                }
              ai.baseAttrs.psyche -= 1;
            }
        },
        {
          id: TRAIT_VORACIOUS_ACCOUNTS,
          name: T('voracious accounts'),
          note: T('Turns offerings into profit, burning through resolve.'),
          isNegative: false,
          onInit: function(game: Game, ai: AIData)
            {
              if (ai.income <= 0)
                ai.income = 500;
              else
                {
                  var bonus = Std.int(ai.income * 0.25);
                  if (bonus < 1)
                    bonus = 1;
                  ai.income += bonus;
                }
              ai.baseAttrs.psyche -= 2;
            }
        },
        {
          id: TRAIT_RITUAL_ENFORCER,
          name: T('ritual enforcer'),
          note: T('Coerces compliance, neglecting combat drills.'),
          isNegative: false,
          onInit: function(game: Game, ai: AIData)
            {
              ai.skills.increase(SKILL_COERCION, 25);
              for (skill in ai.skills)
                {
                  if (skill.info.group == 'Combat')
                    {
                      var newLevel = skill.level - 25;
                      if (newLevel < 1)
                        newLevel = 1;
                      skill.level = newLevel;
                    }
                }
            }
        },
        {
          id: TRAIT_INFIRM_WHISPERER,
          name: T('infirm whisperer'),
          note: T('Specializes in coaxing doubters, letting weapons rust.'),
          isNegative: false,
          onInit: function(game: Game, ai: AIData)
            {
              ai.skills.increase(SKILL_COAXING, 25);
              for (skill in ai.skills)
                {
                  if (skill.info.group == 'Combat')
                    {
                      var newLevel = skill.level - 25;
                      if (newLevel < 1)
                        newLevel = 1;
                      skill.level = newLevel;
                    }
                }
            }
        },
        {
          id: TRAIT_MASKED_LIAR,
          name: T('masked liar'),
          note: T('Glides through lies while martial practice withers.'),
          isNegative: false,
          onInit: function(game: Game, ai: AIData)
            {
              ai.skills.increase(SKILL_DECEPTION, 25);
              for (skill in ai.skills)
                {
                  if (skill.info.group == 'Combat')
                    {
                      var newLevel = skill.level - 25;
                      if (newLevel < 1)
                        newLevel = 1;
                      skill.level = newLevel;
                    }
                }
            }
        },
        {
          id: TRAIT_VIGOROUS_FLAGELLANT,
          name: T('vigorous flagellant'),
          note: T('Refreshes flesh through painful fervor, draining vitality.'),
          isNegative: false,
          turn: function(game: Game, ai: AIData)
            {
              if (ai.health >= ai.maxHealth)
                return;
              if (ai.energy <= 9) // do not die
                return;
              ai.health += 1;
              ai.energy -= 10;
              var actor = Std.downcast(ai, AI);
              if (actor == null)
                return;
              var pool = SoundConst.cultist.get('' + REASON_DAMAGE);
              var sound = pool[Std.random(pool.length)];
              actor.emitSound(sound);
            }
        }
      ]);

      return map;
    }
}

