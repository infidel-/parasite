// player/AI skills

package game;

import const.SkillsConst;

class Skills extends _SaveObject
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

// called after load
  public function loadPost()
    {
      for (s in _list)
        s.info = SkillsConst.getInfo(s.id);
    }

// list iterator
  public function iterator(): Iterator<Skill>
    {
      return _list.iterator();
    }


// get random learnable skill
// returns null if all parasite skills are better
  public function getRandomLearnableSkill(): Skill
    {
      if (_list.length == 0)
        return null;

      var tmp = [];
      for (s in _list)
        {
          var playerSkill = game.player.skills.get(s.id);

          // skip learned knowledges
          if (playerSkill != null && s.info.isBool)
            continue;

          // skip learned skills
          if (s.info.isBool == null || !s.info.isBool)
            if (playerSkill != null &&
                playerSkill.level >= s.level)
              continue;

          tmp.push(s);
        }
      if (tmp.length == 0)
        return null;
      return tmp[Std.random(tmp.length)];
    }

// get random skill
  public function getRandomSkill(): Skill
    {
      if (_list.length == 0)
        return null;

      var tmp = Lambda.array(_list);
      return tmp[Std.random(tmp.length)];
    }


// does the player/ai have that skill?
  public function has(id: _Skill): Bool
    {
      for (o in _list)
        if (o.id == id)
          return true;

      return false;
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
          sk.level = Const.clampFloat(sk.level, 0, 99);
          newLevel = sk.level;

          if (oldLevel == newLevel)
            return;

          if (isPlayer)
            game.info('Skill increased: ' + sk.info.name + ' +' + val +
              '% = ' + sk.level + '%.');
        }

      // human society knowledge increased
      if (isPlayer && id == KNOW_SOCIETY)
        {
          // new goal: learn enough about society
          game.goals.receive(GOAL_LEARN_SOCIETY);

          // open timeline on 25%
          if (oldLevel < 25 && newLevel >= 25)
            // goal completed
            game.goals.complete(GOAL_LEARN_SOCIETY);
        }
    }


// get skill level by id
  public function getLevel(id: _Skill): Float
    {
      for (o in _list)
        if (o.id == id)
          return o.level;

      // not found, get default value
      var info = SkillsConst.getInfo(id);
      return info.defaultLevel;
    }


// add skill by id
  public function addID(id: _Skill, ?lvl: Float = 1)
    {
      // check if we already have that skill
      for (sk in _list)
        if (sk.id == id)
          {
            sk.level = lvl;
            return;
          }

      var info = SkillsConst.getInfo(id);
      if (info == null)
        {
          trace('No such skill id: ' + id);
          return;
        }

      _list.add({
        id: id,
        level: lvl,
        info: info
      });

      if (isPlayer)
        {
          if (info.isKnowledge)
            game.info('Knowledge added: ' + info.name +
              (info.isBool ? '.' : ' ' + lvl + '%.'));
          else game.info('Skill added: ' + info.name + ' ' + lvl + '%.');
        }
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

@:structInit class Skill extends _SaveObject
{
  public var id: _Skill; // skill id
  public var level: Float; // skill level
  public var info: SkillInfo; // skill info link

  public function new(id, level, info)
    {
      this.id = id;
      this.level = level;
      this.info = info;
      init();
      initPost(false);
    }

// init object before loading/post creation
  public function init()
    {
    }

// called after load or creation
  public function initPost(onLoad: Bool)
    {
      info = SkillsConst.getInfo(id);
    }
}
