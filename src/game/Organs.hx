// AI organs and other body features like camouflage layers etc

package game;

import ai.AIData;
import ai.AI;
import const.EvolutionConst;

class Organs extends _SaveObject
{
  static var _ignoredFields = [ '_ai', 'currentOrgan' ];
  var game: Game;
  public var isGrowing(get, null): Bool; // is currently growing organ?
  var _ai: AIData; // parent AI link
  var _list: List<Organ>; // list of organs
  var currentOrgan: Organ; // currently grown organ
  var currentOrganID: _Improv;
  var woundRegenTurn: Int; // turns until next HP regens

  public function new(vgame: Game, vai: AIData)
    {
      _ai = vai;
      game = vgame;
      currentOrgan = null;
      currentOrganID = null;
      woundRegenTurn = 0;
      _list = new List();
    }

// called after load
  public function loadPost()
    {
      if (currentOrganID != null)
        {
          for (o in _list)
            if (o.id == currentOrganID)
              {
                currentOrgan = o;
                break;
              }
        }
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
          buf.add(" turns)<br>");
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
          buf.add(' (timeout: ' + organ.timeout + ')<br>');
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
  public function length(): Int
    {
      return _list.length;
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
      game.scene.sounds.play('organ-complete');

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
      currentOrganID = null;
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
      currentOrganID = currentOrgan.id;
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

      var o: Organ = {
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
          game.ui.hud.addAction(a);
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
      var ai = getActionTargetAI();
      if (ai == null)
        return false;

      var params = getParams(IMP_ACID_SPIT);

      // check for distance
      var distance = game.playerArea.distance(ai.x, ai.y);
      if (distance > params.range)
        {
          game.actionFailed("Maximum range of " + params.range + " exceeded.");
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
      game.scene.sounds.play('action-acid-spit');

      ai.onDamage(damage); // damage event

      return true;
    }


// action: slime spit
  function actionSlimeSpit(): Bool
    {
      var ai = getActionTargetAI();
      if (ai == null)
        return false;

      var params = getParams(IMP_SLIME_SPIT);

      // check for distance
      var distance = game.playerArea.distance(ai.x, ai.y);
      if (distance > params.range)
        {
          game.actionFailed("Maximum range of " + params.range + " exceeded.");
          return false;
        }

      game.log('Your host spits a clot of adhesive mucus on ' + ai.getName() +
        '. ' + ai.getNameCapped() + ' desperately tries to tear it away.');
      game.scene.sounds.play('action-slime-spit');

      // set alertness
      if (ai.state == AI_STATE_IDLE)
        {
          ai.alertness = 100;
          ai.setState(AI_STATE_ALERT, REASON_PARASITE);
        }

      // AI effect event
      ai.onEffect(new effects.Slime(game, params.strength));

      return true;
    }


// action: paralysis spit
  function actionParalysisSpit(): Bool
    {
      var ai = getActionTargetAI();
      if (ai == null)
        return false;

      var params = getParams(IMP_PARALYSIS_SPIT);

      // check for distance
      var distance = game.playerArea.distance(ai.x, ai.y);
      if (distance > params.range)
        {
          game.actionFailed("Maximum range of " + params.range + " exceeded.");
          return false;
        }

      game.scene.sounds.play('action-paralysis-spit');
      var msg = 'Your host releases a paralyzing projectile on ' +
        ai.getName() + '.';
      var chance = ai.inventory.clothing.info.armor.needleDeathChance;
      if (Std.random(100) < chance)
        {
          game.log(msg + ' The toxin works quickly and lethally.');
          ai.onDamage(ai.health);
          return true;
        }

      game.log(msg);

      // set alertness
      if (ai.state == AI_STATE_IDLE)
        {
          ai.alertness = 100;
          ai.setState(AI_STATE_ALERT, REASON_PARASITE);
        }

      // AI effect event
      ai.onEffect(new effects.Paralysis(game, params.time));

      return true;
    }

// pick action target from keyboard or mouse
  function getActionTargetAI(): AI
    {
      var targeting = game.ui.hud.targeting;
      if (targeting.target != null &&
          targeting.isTargetVisibleOnScreen())
        return targeting.target;

      var pos = game.scene.mouse.getXY();
      var ai = game.area.getAI(pos.x, pos.y);
      if (ai == null)
        {
          game.actionFailed("Select a target (T/Enter) or target with mouse first.");
          return null;
        }
      return ai;
    }


// action: panic gas
  function actionPanicGas(): Bool
    {
      var params = getParams(IMP_PANIC_GAS);
      var tmp = game.area.getAIinRadius(game.playerArea.x, game.playerArea.y,
        params.range, false);

      game.log('Your host emits a noxious fear-inducing gas cloud.');
      game.scene.sounds.play('action-gas');

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
          ai.onEffect(new effects.Panic(game, params.time));
        }
      // repaint view with effects
      game.scene.updateCamera();

      return true;
    }


// action: paralysis gas
  function actionParalysisGas(): Bool
    {
      var params = getParams(IMP_PARALYSIS_GAS);
      var tmp = game.area.getAIinRadius(game.playerArea.x, game.playerArea.y,
        params.range, false);

      game.log('Your host emits a cloud of paralysis-inducing spores.');
      game.scene.sounds.play('action-gas');

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

            if (Const.distanceSquared(xo, yo, xx, yy) >
                params.range * params.range)
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
          ai.onEffect(new effects.Paralysis(game, params.time));
        }
      // repaint view with effects
      game.scene.updateCamera();

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
        return "<span style='color:var(--text-color-red)'>None</span>";
      else return "<span style='color:var(--text-color-organ-title)'>" +
        currentOrgan.info.name + "</span>";
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
