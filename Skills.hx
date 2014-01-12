// player/AI 

import ConstSkills;

class Skills 
{
  var _list: List<Skill>; // list of skills

  public function new()
    {
      _list = new List<Skill>();
    }


// list iterator
  public function iterator(): Iterator<Skill>
    {
      return _list.iterator();
    }


// get random skill
  public function getRandomSkill(): Skill
    {
      if (_list.length == 0)
        return null;

      var tmp = Lambda.array(_list);
      return tmp[Std.random(tmp.length)];
    }


// get skill by id
  public function get(id: String): Skill
    {
      for (o in _list)
        if (o.id == id)
          return o;

      return null;
    }


// get skill level by id
  public function getLevel(id: String): Int
    {
      for (o in _list)
        if (o.id == id)
          return o.level;

      // not found, get default value
      var info = ConstSkills.getInfo(id);
      return info.defaultLevel;
    }


// add skill by id
  public function addID(id: String, lvl: Int)
    {
      // check if we already have that skill
      for (sk in _list)
        if (sk.id == id)
          {
            sk.level = lvl;
            return;
          }

      var info = ConstSkills.getInfo(id);
      if (info == null)
        {
          trace('No such skill id: ' + id);
          return;
        }

      var skill = { id: id, level: lvl, info: info };
      _list.add(skill);
    }


  public function toString(): String
    {
      var tmp = [];
      for (o in _list)
        tmp.push(o.id + ' ' + o.level + '%');
      return tmp.join(', ');
    }
}


// skill type

typedef Skill = 
{
  var id: String; // skill id
  var level: Int; // skill level
  var info: SkillInfo; // skill info link
};
