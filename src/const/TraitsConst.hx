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

// return trait group by id
  public static function getGroup(id: String): Array<_TraitInfo>
    {
      return traits.get(id);
    }

// trait infos by group
  public static var traits: StringMap<Array<_TraitInfo>> = initTraits();

// build trait map data
  static function initTraits(): StringMap<Array<_TraitInfo>>
    {
      var map = new StringMap<Array<_TraitInfo>>();

      // misc trait group definitions
      map.set('misc', [
        {
          id: TRAIT_DRUG_ADDICT,
          name: 'drug addict',
          note: 'Addicted to drugs.',
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
          name: 'alcoholic',
          note: 'Years of booze take their toll. Control impossible to maintain fully.',
          turn: function(game: Game, ai: AIData)
            {
              if (game.player.host == ai &&
                  game.player.hostControl > 80)
                game.player.hostControl = 80;
            }
        },
        {
          id: TRAIT_ASSIMILATED,
          name: 'assimilated',
          note: 'Has been assimilated.'
        }
      ]);

      // skill trait group definitions
      map.set('skill', [
        {
          id: TRAIT_BRUISER,
          name: 'bruiser',
          note: 'Excels at fists combat.',
          onInit: function(game: Game, ai: AIData)
            {
              ai.skills.increase(SKILL_FISTS, 25);
            }
        },
        {
          id: TRAIT_KNIFE_EXPERT,
          name: 'knife expert',
          note: 'Practiced in knife combat.',
          onInit: function(game: Game, ai: AIData)
            {
              ai.skills.increase(SKILL_KNIFE, 25);
            }
        },
        {
          id: TRAIT_BATON_EXPERT,
          name: 'baton expert',
          note: 'Seasoned baton fighter.',
          onInit: function(game: Game, ai: AIData)
            {
              ai.skills.increase(SKILL_BATON, 25);
            }
        },
        {
          id: TRAIT_BATTER,
          name: 'batter',
          note: 'Experienced with club weapons.',
          onInit: function(game: Game, ai: AIData)
            {
              ai.skills.increase(SKILL_CLUB, 25);
            }
        },
        {
          id: TRAIT_GUERRERO,
          name: 'guerrero',
          note: 'Practiced with machetes.',
          onInit: function(game: Game, ai: AIData)
            {
              ai.skills.increase(SKILL_MACHETE, 25);
            }
        },
        {
          id: TRAIT_KENDOKA,
          name: 'kendoka',
          note: 'Trained with katanas.',
          onInit: function(game: Game, ai: AIData)
            {
              ai.skills.increase(SKILL_KATANA, 25);
            }
        },
        {
          id: TRAIT_PISTOL_MARKSMAN,
          name: 'pistol marksman',
          note: 'Sharpshooter with pistols.',
          onInit: function(game: Game, ai: AIData)
            {
              ai.skills.increase(SKILL_PISTOL, 25);
            }
        },
        {
          id: TRAIT_RIFLE_MARKSMAN,
          name: 'rifle marksman',
          note: 'Accurate with rifles.',
          onInit: function(game: Game, ai: AIData)
            {
              ai.skills.increase(SKILL_RIFLE, 25);
            }
        },
        {
          id: TRAIT_BREACHER,
          name: 'breacher',
          note: 'Skilled with shotguns.',
          onInit: function(game: Game, ai: AIData)
            {
              ai.skills.increase(SKILL_SHOTGUN, 25);
            }
        },
        {
          id: TRAIT_HACKER,
          name: 'hacker',
          note: 'Talented with computers.',
          onInit: function(game: Game, ai: AIData)
            {
              ai.skills.increase(SKILL_COMPUTER, 25);
            }
        },
        {
          id: TRAIT_COUNSELOR,
          name: 'counselor',
          note: 'Understands psychology.',
          onInit: function(game: Game, ai: AIData)
            {
              ai.skills.increase(SKILL_PSYCHOLOGY, 25);
            }
        },
        {
          id: TRAIT_NEGOTIATOR,
          name: 'negotiator',
          note: 'Expert at coercion.',
          onInit: function(game: Game, ai: AIData)
            {
              ai.skills.increase(SKILL_COERCION, 25);
            }
        },
        {
          id: TRAIT_CONSULTANT,
          name: 'consultant',
          note: 'Gifted at coaxing.',
          onInit: function(game: Game, ai: AIData)
            {
              ai.skills.increase(SKILL_COAXING, 25);
            }
        },
        {
          id: TRAIT_HABITUAL_LIAR,
          name: 'habitual liar',
          note: 'Adept at deception.',
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
          name: 'dumb',
          note: 'Slow to process new ideas.',
          onInit: function(game: Game, ai: AIData)
            {
              ai.baseAttrs.intellect -= 2;
            }
        },
        {
          id: TRAIT_GENIUS,
          name: 'genius',
          note: 'Exceptionally sharp intellect.',
          onInit: function(game: Game, ai: AIData)
            {
              ai.baseAttrs.intellect += 2;
            }
        },
        {
          id: TRAIT_WEAK_WILLED,
          name: 'weak-willed',
          note: 'Struggles with resolve.',
          onInit: function(game: Game, ai: AIData)
            {
              ai.baseAttrs.psyche -= 2;
            }
        },
        {
          id: TRAIT_STRONG_WILLED,
          name: 'strong-willed',
          note: 'Mentally resilient.',
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
          name: 'anorexic',
          note: 'Extremely underweight and frail.',
          onInit: function(game: Game, ai: AIData)
            {
              ai.baseAttrs.strength -= 2;
              ai.baseAttrs.constitution -= 2;
            }
        },
        {
          id: TRAIT_WEAK,
          name: 'weak',
          note: 'Noticeably lacking muscle.',
          onInit: function(game: Game, ai: AIData)
            {
              ai.baseAttrs.strength -= 1;
              ai.baseAttrs.constitution -= 1;
            }
        },
        {
          id: TRAIT_OBESE,
          name: 'obese',
          note: 'Carries significant extra weight.',
          onInit: function(game: Game, ai: AIData)
            {
              ai.baseAttrs.strength -= 1;
              ai.baseAttrs.constitution += 1;
            }
        },
        {
          id: TRAIT_HEAVILY_OBESE,
          name: 'heavily obese',
          note: 'Massively overweight frame.',
          onInit: function(game: Game, ai: AIData)
            {
              ai.baseAttrs.strength -= 2;
              ai.baseAttrs.constitution += 2;
            }
        },
        {
          id: TRAIT_MUSCULAR,
          name: 'muscular',
          note: 'Well-developed physique.',
          onInit: function(game: Game, ai: AIData)
            {
              ai.baseAttrs.strength += 1;
              ai.baseAttrs.constitution += 1;
            }
        },
        {
          id: TRAIT_HERCULEAN,
          name: 'herculean',
          note: 'Peak physical power.',
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
          name: 'devout brute',
          note: 'Zealous strength overtakes thoughtful study.',
          onInit: function(game: Game, ai: AIData)
            {
              ai.baseAttrs.strength += 2;
              ai.baseAttrs.intellect -= 2;
            }
        },
        {
          id: TRAIT_PENITENT_BASTION,
          name: 'penitent bastion',
          note: 'Endures rites through sheer fortitude, fraying the mind.',
          onInit: function(game: Game, ai: AIData)
            {
              ai.baseAttrs.constitution += 2;
              ai.baseAttrs.psyche -= 2;
            }
        },
        {
          id: TRAIT_VEILED_SCHOLAR,
          name: 'veiled scholar',
          note: 'Contemplates doctrine instead of honing muscle.',
          onInit: function(game: Game, ai: AIData)
            {
              ai.baseAttrs.strength -= 2;
              ai.baseAttrs.intellect += 2;
            }
        },
        {
          id: TRAIT_HUSHED_SEER,
          name: 'hushed seer',
          note: 'Withdrawn frame shelters an awakened psyche.',
          onInit: function(game: Game, ai: AIData)
            {
              ai.baseAttrs.constitution -= 2;
              ai.baseAttrs.psyche += 2;
            }
        },
        {
          id: TRAIT_TITHE_HUSTLER,
          name: 'tithe hustler',
          note: 'Extracts steady tithes at the cost of fraying nerves.',
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
          name: 'voracious accounts',
          note: 'Turns offerings into profit, burning through resolve.',
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
          name: 'ritual enforcer',
          note: 'Coerces compliance, neglecting combat drills.',
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
          name: 'infirm whisperer',
          note: 'Specializes in coaxing doubters, letting weapons rust.',
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
          name: 'masked liar',
          note: 'Glides through lies while martial practice withers.',
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
          name: 'vigorous flagellant',
          note: 'Refreshes flesh through painful fervor, draining vitality.',
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


// trait info

typedef _TraitInfo =
{
  id: _AITraitType, // trait id
  name: String, // trait name
  note: String, // trait note
  ?onInit: (game: Game, ai: AIData) -> Void,
  ?turn: (game: Game, ai: AIData) -> Void,
}
