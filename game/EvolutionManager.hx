// parasite evolution manager

package game;

import const.EvolutionConst;


class EvolutionManager
{
  var game: Game;
  var player: Player;

  public var state: Int; // 0 - disabled, 1 - limited, 2 - full
  public var isTaskPath: Bool; // is current task path?
  public var taskID: String; // string id of currently evolving path/improvement
  var _list: List<Improv>; // list of known improvements (that can be of level 0)
  var _listPaths: List<Path>; // list of paths (evolution progress)

  public function new(p: Player, g: Game)
    {
      player = p;
      game = g;
      state = 0;

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


// end of turn
  public function turn(time: Int)
    {
      // no tasks
      if (taskID == '')
        return;

      // evolution is easier while in habitat
      var cost = 5;
      if (game.location == Game.LOCATION_AREA && game.area.getArea().isHabitat)
        cost = 4;
      player.host.energy -= cost * time;
      if (isTaskPath) // path evolution
        {
          var pathID = Type.createEnum(_Path, taskID);
          var path = getPath(pathID);
          path.ep += 10 * time;

          // evolution complete
          if (path.ep >= EvolutionConst.epCostPath[path.level])
            {
              var imp = openImprov(pathID);
              if (imp == null) // should not be here
                {
/*                
                  player.log('You have followed this direction to the end.',
                    COLOR_EVOLUTION);
                  path.ep = 0;
                  taskID = '';
*/
                  Const.todo('BUG EvolutionManager: You should not be here.');
                  return;
                }

              player.log('Following the ' + path.info.name +
                ' direction you now possess the knowledge about ' + imp.info.name + '.',
                COLOR_EVOLUTION);
              path.ep = 0;
              path.level++;
              taskID = '';
            }
        }

      else // upgrade improvement
        {
          var impID = Type.createEnum(_Improv, taskID);
          var imp = getImprov(impID);
          imp.ep += 10 * time;

          // upgrade complete
          if (imp.ep >= EvolutionConst.epCostImprovement[imp.level])
            {
              imp.level++;
              player.log('You have improved your understanding of ' + imp.info.name +
                ' to level ' + imp.level + '.', COLOR_EVOLUTION);

              // clear
              imp.ep = 0;
              taskID = '';

              // call onUpgrade() func
              if (imp.info.onUpgrade != null)
                imp.info.onUpgrade(imp.level, game, player);

              // on first learning of evolution with an organ
              if (imp.info.organ != null)
                player.goals.complete(GOAL_EVOLVE_ORGAN);
            }
        }
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
      
      var imp = addImprov(impID);
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
          return tmp;
        }

      var imp = {
        id: id,
        level: level,
        ep: ep,
        info: EvolutionConst.getInfo(id)
        };
      _list.add(imp);
      return imp;
    }


// player action (called from the EvolutionWindow)
  public function action(id: String)
    {
      var actionName = id.substr(0, id.indexOf('.'));
      var actionID = id.substr(id.indexOf('.') + 1);

      taskID = actionID;
      if (actionName == 'setPath')
        isTaskPath = true;
      else if (actionName == 'set')
        isTaskPath = false;

//      trace(actionName + ' ' + actionID);
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


// get full list
  public function getList(): List<Improv>
    {
      return _list;
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
      if (taskID == '')
        return "<font color='#FF0000'>None</font>";
      else if (isTaskPath)
        return EvolutionConst.getPathInfo(Type.createEnum(_Path, taskID)).name;
      return EvolutionConst.getInfo(Type.createEnum(_Improv, taskID)).name;
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