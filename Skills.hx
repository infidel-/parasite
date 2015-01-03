// player/AI skills

import ConstSkills;

class Skills 
{
  var game: Game;
  var _list: List<Skill>; // list of skills
  var isPlayer: Bool;

  public function new(g: Game, ispv: Bool)
    {
      game = g;
      isPlayer = ispv;
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
  public function get(id: _Skill): Skill
    {
      for (o in _list)
        if (o.id == id)
          return o;

      return null;
    }


// increase skill level
  public function increase(id: _Skill, val: Float)
    {
      var sk = get(id);
      var oldLevel = 0.0;
      var newLevel = 0.0;
      if (sk == null)
        {
          addID(id, val);
          newLevel = val;
        }
      else
        {
          oldLevel = sk.level;

          sk.level += val;
          sk.level = Const.clampFloat(sk.level, 0, 99.9);
          newLevel = sk.level;
        }

      // human society knowledge increased
      if (isPlayer && id == KNOW_SOCIETY)
        {
          // new goal: learn enough about society
          game.player.goals.receive(GOAL_LEARN_SOCIETY);

          // open timeline on 25% 
          if (oldLevel < 25 && newLevel >= 25)
            // goal completed
            game.player.goals.complete(GOAL_LEARN_SOCIETY);
        }
    }


// get skill level by id
  public function getLevel(id: _Skill): Float
    {
      for (o in _list)
        if (o.id == id)
          return o.level;

      // not found, get default value
      var info = ConstSkills.getInfo(id);
      return info.defaultLevel;
    }


// add skill by id
  public function addID(id: _Skill, lvl: Float)
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
  var id: _Skill; // skill id
  var level: Float; // skill level
  var info: SkillInfo; // skill info link
};
