// parasite evolution manager

package game;

import const.EvolutionConst;

class EvolutionManager
{
  var game: Game;
  var player: Player;

  public var difficulty: _Difficulty; // difficulty setting
  public var state: Int; // 0 - disabled, 1 - limited, 2 - full
  public var isTaskPath: Bool; // is current task path?
  public var isActive: Bool; // is currently evolving?
  public var taskID: String; // string id of currently evolving path/improvement
  var _list: List<Improv>; // list of known improvements (that can be of level 0)
  var _listPaths: List<Path>; // list of paths (evolution progress)

  public function new(p: Player, g: Game)
    {
      player = p;
      game = g;
      state = 0;
      isActive = false;
      difficulty = UNSET;

      _list = new List<Improv>();
      _listPaths = new List<Path>();
      taskID = '';
      isTaskPath = false;

      for (p in EvolutionConst.paths) // we may have hidden paths later ;)
        _listPaths.add({
          id: p.id,
          ep: 0,
          level: 0,
          info: EvolutionConst.getPathInfo(p.id)
        });
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

      var imp = null;

      // evolution is easier while in habitat
      player.host.energy -= __Math.evolutionEnergyPerTurn() * time;
      if (isTaskPath) // path evolution
        {
          var pathID = Type.createEnum(_Path, taskID);
          var path = getPath(pathID);
          path.ep += __Math.epPerTurn() * time;

          // evolution complete
          if (path.ep >= EvolutionConst.epCostPath[path.level])
            {
              imp = openImprov(pathID);
              if (imp == null) // should not be here
                {
                  Const.todo('BUG EvolutionManager: You should not be here.');
                  return;
                }

              player.log('Following the ' + path.info.name +
                ' direction you now possess the knowledge about ' +
                imp.info.name + '.',
                COLOR_EVOLUTION);
              path.ep = 0;
              path.level++;
              taskID = '';
              isActive = false;
            }
        }

      else // upgrade improvement
        {
          var impID = Type.createEnum(_Improv, taskID);
          imp = getImprov(impID);
          imp.ep += 10 * time;

          // host degradation - reduce one of the host attributes
          if (!debug)
            turnDegrade(time);

          // upgrade complete
          if (imp.ep >= EvolutionConst.epCostImprovement[imp.level])
            turnUpgrade(imp);
        }
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


// open improvement on that path
  function openImprov(path: _Path): Improv
    {
      // get list of improvs on that path that player does not yet have
      var tmp = [];
      for (imp in EvolutionConst.improvements)
        if (imp.path == path && !isKnown(imp.id))
          tmp.push(imp.id);

      // no improvs left on that path
      if (tmp.length == 0)
        return null;

      // get random improv
      var index = Std.random(tmp.length);
      var impID = tmp[index];

      var imp = addImprov(impID, 1);
      return imp;
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

      var imp = {
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

      // set evolution path
      if (actionName == 'setPath')
        isTaskPath = true;

      // set improvement path
      else if (actionName == 'set')
        isTaskPath = false;

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


// get path object
  public function getPath(id: _Path): Path
    {
      for (p in _listPaths)
        if (p.id == id)
          return p;

      return null;
    }


// get full list of paths
  public function getPathList(): List<Path>
    {
      return _listPaths;
    }


// is this path complete?
  public function isPathComplete(id: _Path)
    {
      var isComplete = true;
      for (imp in EvolutionConst.improvements)
        {
          if (imp.path != id)
            continue;

          if (!isKnown(imp.id))
            {
              isComplete = false;
              break;
            }
        }

      return isComplete;
    }


// get current evolution direction info
  public function getEvolutionDirectionInfo(): String
    {
      if (!isActive)
        return "<font style='color:var(--text-color-red)'>None</font>";

      var buf = new StringBuf();
      buf.add("<font style='color:var(--text-color-evolution-title)'>");
      if (isTaskPath)
        buf.add(EvolutionConst.getPathInfo(Type.createEnum(_Path, taskID)).name);
      else buf.add(EvolutionConst.getInfo(Type.createEnum(_Improv, taskID)).name);
      buf.add("</font> (");
      var epLeft = 0;
      if (isTaskPath)
        {
          var path = getPath(Type.createEnum(_Path, taskID));
          epLeft = EvolutionConst.epCostPath[path.level] - path.ep;
        }
      else
        {
          var imp = getImprov(Type.createEnum(_Improv, taskID));
          epLeft = EvolutionConst.epCostImprovement[imp.level] - imp.ep;
        }
      buf.add(Math.round(epLeft / __Math.epPerTurn()));
      buf.add(" turns)");
      return buf.toString();
    }


// gives out X starting improvements according to difficulty
  public function giveStartingImprovements()
    {
      var n = 0;
      if (difficulty == EASY)
        n = 4;
      else if (difficulty == NORMAL)
        n = 2;
      else if (difficulty == HARD)
        n = 1;
//      trace(n);

      // fill temp arrays
      var tmpOrgans = [];
      var tmpFull = [];
      for (info in EvolutionConst.improvements)
        if (info.path != PATH_SPECIAL)
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

typedef Improv =
{
  var id: _Improv; // improvement string ID
  var level: Int; // improvement level
  var ep: Int; // evolution points
  var info: ImprovInfo; // improvement info link
}


typedef Path =
{
  var id: _Path; // string ID
  var level: Int; // path level is mainly a convenience var, equals number of opened improvements on that path
  var ep: Int; // evolution points
  var info: PathInfo; // path info link
}
