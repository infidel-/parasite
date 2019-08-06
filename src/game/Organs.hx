// AI organs and other body features like camouflage layers etc

package game;

import ai.AI;
import const.EvolutionConst;

class Organs
{
  var game: Game;

  public var isGrowing(get, null): Bool; // is currently growing organ?
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


  public function getInfo(): String
    {
      var buf = new StringBuf();

      // current growing organ info
      if (currentOrgan != null)
        {
          buf.add('Body feature:<br/>  ');
          var col: _TextColor = COLOR_ORGAN;
          buf.add("<font color='" + Const.TEXT_COLORS[col] + "'>");
          buf.add(currentOrgan.info.name);
          buf.add("</font> (");
          var gpLeft = currentOrgan.info.gp - currentOrgan.gp;
          buf.add(Math.round(gpLeft / __Math.gpPerTurn()));
          buf.add(" turns)\n");
        }

      // show organs on timeout
      for (organ in game.player.host.organs)
        {
          if (!organ.isActive)
            continue;

          if (!organ.info.hasTimeout || organ.timeout == 0)
            continue;

          buf.add("<font color='#DDDD00'>" + organ.info.name + "</font>");
          buf.add(' ');
          buf.add(organ.level);
          buf.add(' (timeout: ' + organ.timeout + ')');
        }

      return buf.toString();
    }


// calculate amount of points
// saved when the body dies and used if body is eventually found by law enforcement
  public function getPoints(): Int
    {
      var cnt = 0;
      for (o in _list)
        cnt += o.level;

      // assimilated hosts count as body features
      if (_ai.hasTrait(TRAIT_ASSIMILATED))
        cnt += 2;

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

      currentOrgan.gp += __Math.gpPerTurn() * time;
      _ai.energy -= __Math.growthEnergyPerTurn() * time;

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

      // call onUpgrade() func
      if (currentOrgan.info.onGrow != null)
        currentOrgan.info.onGrow(game, game.player);

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
      if (o != null)
        {
          woundRegenTurn++;
          var ok = false;
          if (woundRegenTurn >= o.params.turns)
            {
              ok = true;
              woundRegenTurn = 0;
            }

          if (ok)
            {
              // ai health regen
              if (_ai.health < _ai.maxHealth)
                _ai.health++;

              // parasite health regen
              if (game.player.state == PLR_STATE_HOST && _ai == game.player.host)
                game.player.health++;
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


// has any mold or in progress of growing one
  public function hasMold(): Bool
    {
      for (o in _list)
        if (o.info.isMold)
          return true;

      return (currentOrgan != null ? currentOrgan.info.isMold : false);
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


// add area organ actions to list
  public function updateActionList()
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

          // save link to that organ
          a.obj = o;
          game.scene.hud.addAction(a);
        }
    }


// area action handling
  public function areaAction(a: _PlayerAction): Bool
    {
      if (a.id == 'acidSpit')
        return actionAcidSpit();

      else if (a.id == 'slimeSpit')
        return actionSlimeSpit();

      else if (a.id == 'paralysisSpit')
        return actionParalysisSpit();

      else if (a.id == 'panicGas')
        return actionPanicGas();

      else if (a.id == 'paralysisGas')
        return actionParalysisGas();

      else
        {
          var o: Organ = a.obj;
          var ret = o.info.onAction(game, game.player);
          return ret;
        }

      return false;
    }


// action: acid spit
  function actionAcidSpit(): Bool
    {
      // get ai under mouse cursor
      var pos = game.scene.mouse.getXY();
      var ai = game.area.getAI(pos.x, pos.y);

      // no ai found
      if (ai == null)
        {
          game.log("Target AI with mouse first.", COLOR_HINT);
          return false;
        }

      var params = getParams(IMP_ACID_SPIT);

      // check for distance
      var distance = Const.getDist(ai.x, ai.y, game.playerArea.x, game.playerArea.y);
      if (distance > params.range)
        {
          game.log("Maximum range of " + params.range + " exceeded.", COLOR_HINT);
          return false;
        }

      // roll damage
      var damage = __Math.damage({
        name: 'acid spit',
        min: params.minDamage,
        max: params.maxDamage,
      });
      game.log('Your host spits a clot of corrosive substance on ' + ai.getName() +
        ' for ' + damage + ' damage. ' + ai.getNameCapped() + ' howls in pain.');

      ai.onDamage(damage); // damage event

      return true;
    }


// action: slime spit
  function actionSlimeSpit(): Bool
    {
      // get ai under mouse cursor
      var pos = game.scene.mouse.getXY();
      var ai = game.area.getAI(pos.x, pos.y);

      // no ai found
      if (ai == null)
        {
          game.log("Target AI with mouse first.", COLOR_HINT);
          return false;
        }

      var params = getParams(IMP_SLIME_SPIT);

      // check for distance
      var distance = Const.getDist(ai.x, ai.y, game.playerArea.x, game.playerArea.y);
      if (distance > params.range)
        {
          game.log("Maximum range of " + params.range + " exceeded.", COLOR_HINT);
          return false;
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

      return true;
    }


// action: paralysis spit
  function actionParalysisSpit(): Bool
    {
      // get ai under mouse cursor
      var pos = game.scene.mouse.getXY();
      var ai = game.area.getAI(pos.x, pos.y);

      // no ai found
      if (ai == null)
        {
          game.log("Target AI with mouse first.", COLOR_HINT);
          return false;
        }

      var params = getParams(IMP_PARALYSIS_SPIT);

      // check for distance
      var distance = Const.getDist(ai.x, ai.y, game.playerArea.x, game.playerArea.y);
      if (distance > params.range)
        {
          game.log("Maximum range of " + params.range + " exceeded.", COLOR_HINT);
          return false;
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

      return true;
    }


// action: panic gas
  function actionPanicGas(): Bool
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

            if (Const.distanceSquared(xo, yo, xx, yy) > params.range * params.range)
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

      return true;
    }


// action: paralysis gas
  function actionParalysisGas(): Bool
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

            if (Const.distanceSquared(xo, yo, xx, yy) > params.range * params.range)
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

      return true;
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


  function get_isGrowing(): Bool
    {
      return (currentOrgan != null);
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
