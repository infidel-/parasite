// AI organs and other body features like camouflage layers etc

package game;

import com.haxepunk.HXP;
import ai.AI;
import const.EvolutionConst;

class Organs
{
  var game: Game;

  var _ai: AI; // parent AI link
  var _list: List<Organ>; // list of organs
  var currentOrgan: Organ; // currently grown organ

  var woundRegenTurn: Int; // turns until next HP regens

  public function new(vgame: Game, vai: AI)
    {
      _ai = vai;
      game = vgame;
      currentOrgan = null;
      woundRegenTurn = 0;
      _list = new List<Organ>();
    }


  public function getGrowthInfo(): String
    {
      if (currentOrgan == null)
        return null;

      var buf = new StringBuf();
      var col: _TextColor = COLOR_ORGAN;
      buf.add("<font color='" + Const.TEXT_COLORS[col] + "'>");
      buf.add(currentOrgan.info.name);
      buf.add("</font> (");
      var gpLeft = currentOrgan.info.gp - currentOrgan.gp;
      buf.add(Math.ceil(gpLeft / game.player.vars.organGrowthPointsPerTurn));
      buf.add(" turns)");
      return buf.toString();
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


// DEBUG: complete current organ
  public function debugCompleteCurrent()
    {
      // no organ selected
      if (currentOrgan == null)
        return;

      currentOrgan.gp = 100000;
      turnGrowth(1);
    }


// TURN: organ growth
  function turnGrowth(time: Int)
    {
      // no organ selected
      if (currentOrgan == null)
        return;

      currentOrgan.gp += game.player.vars.organGrowthPointsPerTurn * time;
      _ai.energy -= game.player.vars.organGrowthEnergyPerTurn * time;

      // organ not grown yet
      if (currentOrgan.gp < currentOrgan.info.gp)
        return;

      currentOrgan.isActive = true;
      game.log(currentOrgan.info.name + ' growth completed.', COLOR_ORGAN);

      _ai.recalc(); // recalc all stats and mods

      // host energy organ restores energy to max when grown
      if (currentOrgan.id == IMP_ENERGY)
        _ai.energy = _ai.maxEnergy;

      // on first growing an organ 
      game.goals.complete(GOAL_GROW_ORGAN);

      currentOrgan = null;
    }


// TURN: organ activity 
  function turnActivity(time: Int)
    {
      // activation timeout
      for (o in _list)
        if (o.info.hasTimeout && o.timeout > 0)
          o.timeout--;

      // organ: wound regeneration
      var o = get(IMP_WOUND_REGEN);
      if (o != null && _ai.health < _ai.maxHealth)
        {
          woundRegenTurn++;

          if (woundRegenTurn >= o.params.turns)
            {
              _ai.health++;
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
            params: imp.info.levelParams[imp.level],
            timeout: 0
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


// get current organ parameters
  public function getParams(id: _Improv): Dynamic
    {
      for (o in _list)
        if (o.id == id)
          return o.params;

      return null;
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
      var impInfo = EvolutionConst.getInfo(id);
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
        params: impInfo.levelParams[0],
        timeout: 0
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

          if (game.player.energy < a.energy ||
              (o.info.hasTimeout && o.timeout > 0))
            continue;

          tmp.add(a);
        }
    }


// area action handling
  public function areaAction(a: _PlayerAction)
    {
      if (a.id == 'acidSpit')
        actionAcidSpit();

      else if (a.id == 'slimeSpit')
        actionSlimeSpit();

      else if (a.id == 'paralysisSpit')
        actionParalysisSpit();

      else if (a.id == 'panicGas')
        actionPanicGas();

      else if (a.id == 'paralysisGas')
        actionParalysisGas();
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

      var params = getParams(IMP_ACID_SPIT);

      // check for distance
      var distance = Const.getDist(ai.x, ai.y, game.playerArea.x, game.playerArea.y);
      if (distance > params.range)
        {
          game.log("Maximum range of " + params.range + " exceeded.", COLOR_HINT);
          return;
        }

      // roll damage
      var damage = Const.roll(params.minDamage, params.maxDamage);
      game.log('Your host spits a clot of corrosive substance on ' + ai.getName() +
        ' for ' + damage + ' damage. ' + ai.getNameCapped() + ' screams in pain.');

      ai.onDamage(damage); // damage event
    }


// action: slime spit
  function actionSlimeSpit()
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

      var params = getParams(IMP_SLIME_SPIT);

      // check for distance
      var distance = Const.getDist(ai.x, ai.y, game.playerArea.x, game.playerArea.y);
      if (distance > params.range)
        {
          game.log("Maximum range of " + params.range + " exceeded.", COLOR_HINT);
          return;
        }

      game.log('Your host spits a clot of adhesive slime on ' + ai.getName() +
        '. ' + ai.getNameCapped() + ' desperately tries to tear it away.');

      // set alertness
      if (ai.state == AI_STATE_IDLE)
        {
          ai.alertness = 100;
          ai.setState(AI_STATE_ALERT, REASON_PARASITE);
        }

      // AI effect event
      ai.onEffect({ type: EFFECT_SLIME, points: params.strength }); 
    }


// action: paralysis spit
  function actionParalysisSpit()
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

      var params = getParams(IMP_PARALYSIS_SPIT);

      // check for distance
      var distance = Const.getDist(ai.x, ai.y, game.playerArea.x, game.playerArea.y);
      if (distance > params.range)
        {
          game.log("Maximum range of " + params.range + " exceeded.", COLOR_HINT);
          return;
        }

      game.log('Your host releases a stream of paralyzing spores on ' + ai.getName() +
        '.');

      // set alertness
      if (ai.state == AI_STATE_IDLE)
        {
          ai.alertness = 100;
          ai.setState(AI_STATE_ALERT, REASON_PARASITE);
        }

      // AI effect event
      ai.onEffect({ type: EFFECT_PARALYSIS, points: params.time, isTimer: true }); 
    }


// action: panic gas
  function actionPanicGas()
    {
      var params = getParams(IMP_PANIC_GAS);
      var tmp = game.area.getAIinRadius(game.playerArea.x, game.playerArea.y,
        params.range, false);

      game.log('Your host emits a noxious fear-inducing gas cloud.');

      // set timeout
      var o = get(IMP_PANIC_GAS);
      o.timeout = params.timeout;

      // spawn visual effects
      var xo = game.playerArea.x;
      var yo = game.playerArea.y;
      for (yy in yo - params.range...yo + params.range)
        for (xx in xo - params.range...xo + params.range)
          {
            if (!game.area.isWalkable(xx, yy))
              continue;

            if (HXP.distanceSquared(xo, yo, xx, yy) > params.range * params.range)
              continue;

            game.scene.area.addEffect(xx, yy, 2, Const.FRAME_PANIC_GAS);
          }

      // affect all AI in range
      for (ai in tmp)
        {
          // do not affect self
          if (ai == _ai)
            continue;

          // set alertness
          if (ai.state == AI_STATE_IDLE)
            {
              ai.alertness = 100;
              ai.setState(AI_STATE_ALERT, REASON_PARASITE);
            }

          // AI effect event
          ai.onEffect({ type: EFFECT_PANIC, points: params.time, isTimer: true });
        }
    }


// action: paralysis gas
  function actionParalysisGas()
    {
      var params = getParams(IMP_PARALYSIS_GAS);
      var tmp = game.area.getAIinRadius(game.playerArea.x, game.playerArea.y,
        params.range, false);

      game.log('Your host emits a cloud of paralysis spores.');

      // set timeout
      var o = get(IMP_PARALYSIS_GAS);
      o.timeout = params.timeout;

      // spawn visual effects
      var xo = game.playerArea.x;
      var yo = game.playerArea.y;
      for (yy in yo - params.range...yo + params.range)
        for (xx in xo - params.range...xo + params.range)
          {
            if (!game.area.isWalkable(xx, yy))
              continue;

            if (HXP.distanceSquared(xo, yo, xx, yy) > params.range * params.range)
              continue;

            game.scene.area.addEffect(xx, yy, 2, Const.FRAME_PARALYSIS_GAS);
          }

      // affect all AI in range
      for (ai in tmp)
        {
          // do not affect self
          if (ai == _ai)
            continue;

          // set alertness
          if (ai.state == AI_STATE_IDLE)
            {
              ai.alertness = 100;
              ai.setState(AI_STATE_ALERT, REASON_PARASITE);
            }

          // AI effect event
          ai.onEffect({ type: EFFECT_PARALYSIS, points: params.time, isTimer: true });
        }
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
  var timeout: Int; // charge timeout
}
