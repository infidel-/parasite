// skill info list

class ConstSkills
{
// return info by id
  public static function getInfo(id: _Skill): SkillInfo
    {
      for (ii in skills)
        if (ii.id == id)
          return ii;

      return null;
    }


// skill infos
  public static var skills: Array<SkillInfo> = [
    {
      id: SKILL_FISTS,
      name: 'fists',
      defaultLevel: 50,
    },
    {
      id: SKILL_BATON,
      name: 'baton',
      defaultLevel: 40,
    },
    {
      id: SKILL_PISTOL,
      name: 'pistol',
      defaultLevel: 20,
    },
    {
      id: KNOW_SOCIETY,
      name: 'human society',
      defaultLevel: 0,
      isKnowledge: true
    }
    ];
}


// skill info

typedef SkillInfo =
{
  id: _Skill, // skill id
  name: String, // skill name
  defaultLevel: Int, // default skill level
  ?isKnowledge: Bool, // is this a knowledge?
}
