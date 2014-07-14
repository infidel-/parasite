// AI organs and other body features like camouflage layers etc

import ai.AI;
import ConstEvolution;

class Organs
{
  var game: Game;

  var ai: AI; // parent AI link
  var _list: List<Organ>; // list of organs
  var currentOrgan: Organ; // currently grown organ

  var woundRegenTurn: Int; // turns until next HP regens

  public function new(vgame: Game, vai: AI)
    {
      ai = vai;
      game = vgame;
      currentOrgan = null;
      woundRegenTurn = 0;
      _list = new List<Organ>();
    }


// calculate amount of points
// saved when the body dies and used if body is eventually found by law enforcement
  public function getPoints(): Int
    {
      var cnt = 0;
      for (o in _list)
        cnt += o.level;

      return cnt;
    }


// list iterator
  public function iterator(): Iterator<Organ>
    {
      return _list.iterator();
    }


// passage of time
  public inline function turn(time: Int)
    {
      turnGrowth(time);
      turnActivity(time);
    }


// TURN: organ growth
  function turnGrowth(time: Int)
    {
      // no organ selected
      if (currentOrgan == null)
        return;

      currentOrgan.gp += 10 * time;
      game.player.energy -= 5 * time;

      // organ not grown yet
      if (currentOrgan.gp < currentOrgan.info.gp)
        return;

      currentOrgan.isActive = true;
      game.log(currentOrgan.info.name + ' growth completed.', COLOR_ORGAN);

      ai.recalc(); // recalc all stats and mods

      // host energy organ restores energy to max when grown
      if (currentOrgan.id == IMP_ENERGY)
        ai.energy = ai.maxEnergy;

      currentOrgan = null;
    }


// TURN: organ activity 
  function turnActivity(time: Int)
    {
      // organ: wound regeneration
      var o = get(IMP_WOUND_REGEN);
      if (o != null && ai.health < ai.maxHealth)
        {
          woundRegenTurn++;

          if (woundRegenTurn >= o.params.turns)
            {
              ai.health++;
              woundRegenTurn = 0;
            }
        }
    }


// player action (called from the gui window))
  public function action(id: String)
    {
      var actionName = id.substr(0, id.indexOf('.'));
      var actionID = id.substr(id.indexOf('.') + 1);

      if (actionName != 'set')
        throw(actionName);

      var impID = Type.createEnum(_Improv, actionID);
      var imp = game.player.evolutionManager.getImprov(impID);

      // if this organ does not exist yet, create it
      var o = get(imp.id);
      if (o == null)
        {
          currentOrgan = {
            id: imp.id,
            level: imp.level, 
            isActive: false,
            gp: 0,
            improvInfo: imp.info,
            info: imp.info.organ,
            params: imp.info.levelParams[imp.level]
            };
          _list.add(currentOrgan);
        }
      else currentOrgan = o;
    }


// has this organ? 
  public function has(id: _Improv): Bool 
    {
      for (o in _list)
        if (o.id == id)
          return true;

      return false;
    }


// get organ by id
  public function get(id: _Improv): Organ
    {
      for (o in _list)
        if (o.id == id)
          return o;

      return null;
    }


// get organ level by id
  public function getLevel(id: _Improv): Int 
    {
      for (o in _list)
        if (o.id == id)
          return o.level;

      return 0;
    }


// get active organ by improvement id
  public inline function getActive(id: _Improv): Organ
    {
      var o = get(id);
      return ((o != null && o.isActive) ? o : null);
    }


// add grown organ by improvement id
  public function addID(id: _Improv): Organ
    {
      var impInfo = ConstEvolution.getInfo(id);
      if (impInfo == null)
        {
          trace('No such organ: ' + id);
          return null;
        }

      var o = {
        id: id,
        level: game.player.evolutionManager.getLevel(impInfo.id),
        isActive: true,
        gp: 0,
        improvInfo: impInfo,
        info: impInfo.organ,
        params: impInfo.levelParams[0]
        };

      _list.add(o);
      return o;
    }


// get area organ actions
  public function addActions(tmp: List<_PlayerAction>)
    {
      for (o in _list)
        {
          if (!o.isActive)
            continue;
          
          var a = o.info.action;
          if (a == null)
            continue;

          if (game.player.energy >= a.energy) 
            tmp.add(a);
        }
    }


// area action handling
  public function areaAction(a: _PlayerAction)
    {
      if (a.id == 'acidSpit')
        actionAcidSpit();
    }


// action: acid spit
  function actionAcidSpit()
    {
      // get ai under mouse cursor
      var pos = game.scene.mouse.getXY();
      var ai = game.area.getAI(pos.x, pos.y);

      // no ai found
      if (ai == null)
        {
          game.log("Target AI with mouse first.", COLOR_HINT);
          return;
        }

      trace(ai.id);
    }


  public function toString(): String
    {
      var tmp = [];
      for (o in _list)
        tmp.push(o.id + ' active:' + o.isActive + ' gp:' + o.gp);
      return tmp.join(', ');
    }


// get currently grown organ info
  public function getGrowInfo(): String
    {
      if (currentOrgan == null)
        return "<font color='#FF0000'>None</font>";
      else return currentOrgan.info.name;
    }

// ================================ EVENTS =========================================


// event: host receives damage
  public function onDamage(damage: Int)
    {
      woundRegenTurn = 0;
    }
}

typedef Organ =
{
  var id: _Improv; // organ id
  var level: Int; // organ level (copied from improvement on creation)
  var isActive: Bool; // organ active?
  var gp: Int; // growth points
  var improvInfo: ImprovInfo; // evolution improvement link
  var info: OrganInfo; // organ info link
  var params: Dynamic; // current level params link
}
