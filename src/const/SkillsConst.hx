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
      group: 'Combat',
      name: 'fists',
      defaultLevel: 50,
    },
    {
      id: SKILL_BATON,
      group: 'Combat',
      name: 'baton',
      defaultLevel: 40,
    },
    {
      id: SKILL_CLUB,
      group: 'Combat',
      name: 'club',
      defaultLevel: 35,
    },
    {
      id: SKILL_KNIFE,
      group: 'Combat',
      name: 'knife',
      defaultLevel: 30,
    },
    {
      id: SKILL_MACHETE,
      group: 'Combat',
      name: 'machete',
      defaultLevel: 35,
    },
    {
      id: SKILL_KATANA,
      group: 'Combat',
      name: 'katana',
      defaultLevel: 45,
    },
    {
      id: SKILL_PISTOL,
      group: 'Combat',
      name: 'pistol',
      defaultLevel: 20,
    },
    {
      id: SKILL_RIFLE,
      group: 'Combat',
      name: 'rifle',
      defaultLevel: 25,
    },
    {
      id: SKILL_SHOTGUN,
      group: 'Combat',
      name: 'shotgun',
      defaultLevel: 30,
    },

    {
      id: SKILL_PSYCHOLOGY,
      name: 'human psychology',
      defaultLevel: 0,
    },
    {
      id: SKILL_DECEPTION,
      group: 'Manipulation',
      name: 'deception',
      defaultLevel: 0,
    },
    {
      id: SKILL_COERCION,
      group: 'Manipulation',
      name: 'coercion',
      defaultLevel: 0,
    },
    {
      id: SKILL_COAXING,
      group: 'Manipulation',
      name: 'coaxing',
      defaultLevel: 0,
    },
    {
      id: SKILL_COMPUTER,
      name: 'computer use',
      defaultLevel: 0,
    },

    // knowledges
    { // removed
      id: KNOW_SMOKING,
      name: 'smoking',
      defaultLevel: 0,
      isKnowledge: true,
      isBool: true
    },
    { // removed
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
  ?group: String, // skill group
  name: String, // skill name
  defaultLevel: Int, // default skill level
  ?isKnowledge: Bool, // is this a knowledge?
  ?isBool: Bool, // is this a boolean knowledge?
}
