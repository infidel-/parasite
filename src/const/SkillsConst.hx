// skill info list
package const;

class SkillsConst
{
// return info by id
  public static function getInfo(id: _Skill): SkillInfo
    {
      for (ii in skills)
        if (ii.id == id)
          return ii;

      throw 'No such skill: ' + id;
      return null;
    }

// return info by id, or null if missing (used on load when a mod that
// supplied the skill is no longer enabled — caller scrubs orphan skills)
  public static function tryGetInfo(id: _Skill): SkillInfo
    {
      for (ii in skills)
        if (ii.id == id)
          return ii;
      return null;
    }

// append a skill info; id collision = last-wins + log. used by
// ModContentApi.registerSkill and any future engine code that wants to
// register skills dynamically. the skills list is built once at class load
// and never wiped, so a pushed entry survives all new-game cycles.
  public static function addSkill(info: SkillInfo)
    {
      for (i in 0...skills.length)
        if (skills[i].id == info.id)
          {
            Const.p('mod content collision on skill id: ' + info.id +
              ' (last-wins)');
            skills[i] = info;
            return;
          }
      skills.push(info);
    }

// skill infos
  public static var skills: Array<SkillInfo> = [
    { // animal attack, hidden
      id: SKILL_ATTACK,
      name: T('attack'),
      defaultLevel: 0,
    },
    {
      id: SKILL_FISTS,
      group: N('Combat'),
      name: T('fists'),
      defaultLevel: 50,
    },
    {
      id: SKILL_BATON,
      group: N('Combat'),
      name: T('baton'),
      defaultLevel: 40,
    },
    {
      id: SKILL_CLUB,
      group: N('Combat'),
      name: T('club'),
      defaultLevel: 35,
    },
    {
      id: SKILL_KNIFE,
      group: N('Combat'),
      name: T('knife'),
      defaultLevel: 30,
    },
    {
      id: SKILL_MACHETE,
      group: N('Combat'),
      name: T('machete'),
      defaultLevel: 35,
    },
    {
      id: SKILL_KATANA,
      group: N('Combat'),
      name: T('katana'),
      defaultLevel: 45,
    },
    {
      id: SKILL_PISTOL,
      group: N('Combat'),
      name: T('pistol'),
      defaultLevel: 20,
    },
    {
      id: SKILL_RIFLE,
      group: N('Combat'),
      name: T('rifle'),
      defaultLevel: 25,
    },
    {
      id: SKILL_SHOTGUN,
      group: N('Combat'),
      name: T('shotgun'),
      defaultLevel: 30,
    },

    {
      id: SKILL_PSYCHOLOGY,
      name: T('human psychology'),
      defaultLevel: 0,
    },
    {
      id: SKILL_DECEPTION,
      group: N('Manipulation'),
      name: T('deception'),
      defaultLevel: 0,
    },
    {
      id: SKILL_COERCION,
      group: N('Manipulation'),
      name: T('coercion'),
      defaultLevel: 0,
    },
    {
      id: SKILL_COAXING,
      group: N('Manipulation'),
      name: T('coaxing'),
      defaultLevel: 0,
    },
    {
      id: SKILL_COMPUTER,
      name: T('computer use'),
      defaultLevel: 0,
    },

    // knowledges
    { // removed
      id: KNOW_SMOKING,
      name: T('smoking'),
      defaultLevel: 0,
      isKnowledge: true,
      isBool: true
    },
    { // removed
      id: KNOW_SHOPPING,
      name: T('shopping'),
      defaultLevel: 0,
      isKnowledge: true,
      isBool: true
    },
    {
      id: KNOW_SOCIETY,
      name: T('human society'),
      defaultLevel: 0,
      isKnowledge: true,
    },
  ];
}

// skill info

typedef SkillInfo =
{
  id: _Skill, // skill id
  ?group: String, // skill group
  name: String, // skill name
  defaultLevel: Int, // default skill level
  ?isKnowledge: Bool, // is this a knowledge?
  ?isBool: Bool, // is this a boolean knowledge?
}
