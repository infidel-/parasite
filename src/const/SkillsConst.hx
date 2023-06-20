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

// skill infos
  public static var skills: Array<SkillInfo> = [
    { // animal attack, hidden
      id: SKILL_ATTACK,
      name: 'attack',
      defaultLevel: 0,
    },
    {
      id: SKILL_FISTS,
      name: 'Combat: fists',
      defaultLevel: 50,
    },
    {
      id: SKILL_BATON,
      name: 'Combat: baton',
      defaultLevel: 40,
    },
    {
      id: SKILL_PISTOL,
      name: 'Combat: pistol',
      defaultLevel: 20,
    },
    {
      id: SKILL_RIFLE,
      name: 'Combat: rifle',
      defaultLevel: 25,
    },
    {
      id: SKILL_SHOTGUN,
      name: 'Combat: shotgun',
      defaultLevel: 30,
    },

    {
      id: SKILL_PSYCHOLOGY,
      name: 'human psychology',
      defaultLevel: 0,
    },
    {
      id: SKILL_DECEPTION,
      name: 'Manipulation: deception',
      defaultLevel: 0,
    },
    {
      id: SKILL_COERCION,
      name: 'Manipulation: coercion',
      defaultLevel: 0,
    },
    {
      id: SKILL_COAXING,
      name: 'Manipulation: coaxing',
      defaultLevel: 0,
    },
    {
      id: SKILL_COMPUTER,
      name: 'computer use',
      defaultLevel: 0,
    },

    // knowledges
    {
      id: KNOW_SMOKING,
      name: 'smoking',
      defaultLevel: 0,
      isKnowledge: true,
      isBool: true
    },
    {
      id: KNOW_SHOPPING,
      name: 'shopping',
      defaultLevel: 0,
      isKnowledge: true,
      isBool: true
    },
    {
      id: KNOW_SOCIETY,
      name: 'human society',
      defaultLevel: 0,
      isKnowledge: true,
    },
  ];
}


// skill info

typedef SkillInfo =
{
  id: _Skill, // skill id
  name: String, // skill name
  defaultLevel: Int, // default skill level
  ?isKnowledge: Bool, // is this a knowledge?
  ?isBool: Bool, // is this a boolean knowledge?
}
