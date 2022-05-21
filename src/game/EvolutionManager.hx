// parasite evolution manager

package game;

import const.EvolutionConst;

class EvolutionManager extends _SaveObject
{
  static var _ignoredFields = [ 'player' ];
  var game: Game;
  var player: Player;

  public var difficulty: _Difficulty; // difficulty setting
  public var state: Int; // 0 - disabled, 1 - limited, 2 - full
  public var isActive: Bool; // is currently evolving?
  public var taskID: String; // string id of currently evolving improvement
  var _list: List<Improv>; // list of known improvements (that can be of level 0)

  public function new(p: Player, g: Game)
    {
      player = p;
      game = g;
      state = 0;
      isActive = false;
      difficulty = UNSET;

      _list = new List<Improv>();
      taskID = '';
    }


// list iterator
  public function iterator(): Iterator<Improv>
    {
      return _list.iterator();
    }


// end of turn
  public function turn(time: Int, ?debug: Bool = false)
    {
      // no tasks
      if (!isActive)
        return;

      // evolution is easier while in habitat
      player.host.energy -= __Math.evolutionEnergyPerTurn() * time;
      var impID = Type.createEnum(_Improv, taskID);
      var imp = getImprov(impID);
      imp.ep += 10 * time;

      // host degradation - reduce one of the host attributes
      if (!debug)
        turnDegrade(time);

      // upgrade complete
      if (imp.ep >= EvolutionConst.epCostImprovement[imp.level])
        turnUpgrade(imp);
    }


// TURN: host degradation
  function turnDegrade(time: Int)
    {
      var list = [ 'strength', 'constitution', 'intellect', 'psyche' ];

      // reduce attributes in loop
      var chance = 100;
      if (game.player.difficulty == UNSET ||
          game.player.difficulty == EASY)
        chance = 50;
      else if (game.player.difficulty == NORMAL)
        chance = 75;
      for (i in 0...time)
        {
          if (Std.random(100) > chance)
            continue;
          var attr = list[Std.random(list.length)];
          var val = Reflect.field(player.host.baseAttrs, attr) - 1;
          Reflect.setField(player.host.baseAttrs, attr, val);

          if (val > 0)
            {
              if (val == 1)
                player.log('Your host degrades to a breaking point and might die soon.', COLOR_ALERT);
              else player.log('Your host degrades.');
              game.info(attr + ': ' + val);
            }

          // when any attribute is zero, host collapses
          else if (val == 0)
            {
              player.host.recalc();
              player.host.health = 0;

              player.onHostDeath('You host has degraded completely.');

              return;
            }
        }

      player.host.recalc();
    }


// TURN: finish upgrading improvement
  function turnUpgrade(imp: Improv)
    {
      imp.level++;
      player.log('You have improved your understanding of ' + imp.info.name +
        ' to level ' + imp.level + '.', COLOR_EVOLUTION);

      // clear
      imp.ep = 0;
      taskID = '';
      isActive = false;

      // call onUpgrade() func
      if (imp.info.onUpgrade != null)
        imp.info.onUpgrade(imp.level, game, player);

      // on first learning of evolution with an organ
      if (imp.info.organ != null)
        game.goals.complete(GOAL_EVOLVE_ORGAN);
    }

// add improvement to list
  public function addImprov(id: _Improv, ?level: Int = 0): Improv
    {
      // this improvement already learned
      var tmp = getImprov(id);
      if (tmp != null && tmp.level >= level)
        return tmp;

      var ep = 0;
      if (level > 0)
        ep = EvolutionConst.epCostImprovement[level - 1];

      if (tmp != null)
        {
          tmp.level = level;
          tmp.ep = ep;

          game.info('Improvement set: ' + tmp.info.name + ' (' + level + ')');

          return tmp;
        }

      var imp: Improv = {
        id: id,
        level: level,
        ep: ep,
        info: EvolutionConst.getInfo(id)
      };
      _list.add(imp);

      game.info('Improvement gained: ' + imp.info.name + ' (' + level + ')');

      return imp;
    }


// stop the evolution
  public inline function stop()
    {
      taskID = '';
      isActive = false;
    }


// player action (called from the EvolutionWindow or by hotkey)
  public function action(action: _PlayerAction): Bool
    {
      var id = action.id;
      var actionName = id.substr(0, id.indexOf('.'));
      var actionID = id.substr(id.indexOf('.') + 1);

      // stop evolution
      if (id == 'stop')
        {
          stop();
          return true;
        }

      // set task and activate
      taskID = actionID;
      isActive = true;

//      trace(actionName + ' ' + actionID);
      return true;
    }


// is this improvement known?
  public function isKnown(id: _Improv): Bool
    {
      for (imp in _list)
        if (imp.id == id)
          return true;

      return false;
    }


// get improvement
  public function getImprov(id: _Improv): Improv
    {
      for (imp in _list)
        if (imp.id == id)
          return imp;

      return null;
    }


// get current improvement params
  public function getParams(id: _Improv): Dynamic
    {
      var imp = getImprov(id);
      if (imp == null) // improvement not learned yet
        {
          var info = EvolutionConst.getInfo(id);
          return info.levelParams[0];
        }

      return imp.info.levelParams[imp.level];
    }


// get improvement level
  public function getLevel(id: _Improv): Int
    {
      for (imp in _list)
        if (imp.id == id)
          return imp.level;

      return 0;
    }

// get current evolution direction info
  public function getEvolutionDirectionInfo(): String
    {
      if (!isActive)
        return "<font style='color:var(--text-color-red)'>None</font>";

      var buf = new StringBuf();
      buf.add("<font style='color:var(--text-color-evolution-title)'>");
      buf.add(EvolutionConst.getInfo(Type.createEnum(_Improv, taskID)).name);
      buf.add("</font> (");
      var epLeft = 0;
      var imp = getImprov(Type.createEnum(_Improv, taskID));
      epLeft = EvolutionConst.epCostImprovement[imp.level] - imp.ep;
      buf.add(Math.round(epLeft / __Math.epPerTurn()));
      buf.add(" turns)");
      return buf.toString();
    }


// gives out X starting improvements according to difficulty
  public function giveStartingImprovements()
    {
      var n = 0;
      if (difficulty == EASY)
        n = 2;
      else if (difficulty == NORMAL)
        n = 2;
      else if (difficulty == HARD)
        n = 1;
//      trace(n);

      // fill temp arrays
      var tmpOrgans = [];
      var tmpFull = [];
      for (info in EvolutionConst.improvements)
        if (info.type == TYPE_BASIC)
          {
            if (info.organ != null)
              tmpOrgans.push(info.id);
            tmpFull.push(info.id);
          }

      // last one must always be an organ (for the tutorial to work correctly)
      while (n > 0)
        {
          // pick a random improv
          var arr = (n == 1 ? tmpOrgans : tmpFull);
          var id = arr[Std.random(arr.length)];
          if (n == 1)
            tmpOrgans.remove(id);
          tmpFull.remove(id);

          addImprov(id);

          n--;
        }
    }


// update actions
  public function updateActionList()
    {
      if (isActive)
        game.ui.hud.addKeyAction({
          id: 'stop',
          type: ACTION_EVOLUTION,
          name: 'Stop evolution',
          energy: 0,
          key: 's',
        });
    }
}
