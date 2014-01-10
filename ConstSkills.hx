// skill info list

class ConstSkills
{
// return info by id
  public static function getInfo(id: String): SkillInfo
    {
      for (ii in skills)
        if (ii.id == id)
          return ii;

      return null;
    }


// skill infos
  public static var skills: Array<SkillInfo> = [
    {
      id: 'fists',
      name: 'fists',
      defaultLevel: 50,
    },
    {
      id: 'baton',
      name: 'baton',
      defaultLevel: 40,
    },
    {
      id: 'pistol',
      name: 'pistol',
      defaultLevel: 20,
    },
    ];
}


// skill info

typedef SkillInfo =
{
  var id: String; // skill id
  var name: String; // skill name
  var defaultLevel: Int; // default skill level
}
